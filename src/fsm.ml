(*******************************************************************************
 * Copyright (c) 2010 AT&T.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *    Trevor Jim and Yitzhak Mandelbaum
 *******************************************************************************)

(* Interface to the FSM toolkit, http://www.research.att.com/~fsmtools/fsm/

Retooled for Gil.

   The FSM toolkit is a weighted transducer library.  We use it for
   building our Earley transducers.  FSM provides weighted
   determinization and minimization.  We invoke FSM as a separate
   process, via pipes, so this file mostly converts from our internal
   transducer format to the FSM text input and output format, which is
   described in the man page fsm(5).
*)

open Gil
open Util
type expr = Gul.expr
type nonterminal = Gul.nonterminal

(* Because String.quote in Batteries is somehow busted, very weird *)
let quote x = "\"" ^ String.escaped x ^ "\""

(** Defaults for call and binder transformers for symbols without
    either/both of call and return.

    We might consider making these setable by a flag.
*)
let binder_prefix = "__binder"
let default_call_tx = "__default_call"
let default_binder_tx = "__default_ret"

let min_symbol = Pam_internal.min_nonterm

(*********************** READING FROM FSM ***********************)
type fsm_line =
    Arc1 of int * int * int * float (* a line with 4 numbers is source,target,arc,weight *)
  | Arc2 of int * int * int         (* source,target,arc; default weight is ZERO *)
  | Fin1 of int * float             (* a line with 2 numbers is a final state with output weight *)
  | Fin2 of int                     (* final state; default weight is ZERO *)

let rec fsm_iter ch f =
  try
    while true do
      let l = input_line ch in
      try
        Scanf.sscanf l "%d %d %d %f"
          (fun a b c d -> f(Arc1(a,b,c,d)))
      with _ -> try
        Scanf.sscanf l "%d %d %d"
          (fun a b c -> f(Arc2(a,b,c)))
      with _ -> try
        Scanf.sscanf l "%d %f"
          (fun a b -> f(Fin1(a,b)))
      with _ ->
        Scanf.sscanf l "%d"
          (fun a -> f(Fin2(a)))
    done
  with End_of_file -> ()
(*
  | IO.No_more_input -> ()
*)

module Semiring = struct
  type weight =
      ZERO | ONE | PROB of float | INV_PROB of int

  (* conversion for real semiring (probabilities) *)
  let weight2float_real = function
      ZERO -> 0.0 | ONE -> 1.0
    | PROB f -> f
    | INV_PROB n -> 1.0 /. (float n)

  (* conversion for tropical (negative log probabilities) semiring *)
  let weight2float_tropical = function
      ZERO -> 40000.0 | ONE -> 0.0 | PROB f -> (-. (log f)) | INV_PROB n -> log (float n)

  (* IGNORE ALL WEIGHTS -- set them to 0 (corresponding to probability one) *)
  let weight2float_none w = 0.0

  let weight2float = weight2float_none

end
open Semiring

(**************** ENCODING GIL TRANSDUCERS IN FSM ****************)

(** In FSM, arcs are labeled by ints *)
type fsm_arc = int

(** Arcs in our Earley transducers, which will be encoded as ints when passed to FSM *)
type earley_arc =
  | Epsilon                              (* Epsilon *)
  | CallEps                              (* Special epsilon edge used in call collapsing*)
  | Tm of int                             (* Terminal, 0-255 *)
  | Call of expr option                  (* Call with arguments, possibly empty *)
  | Cont of nonterminal * expr option * expr option (* Continue for a nonterminal,argument,binder *)
  | ELookahead of bool * nonterminal      (* boolean value indicates whether or not following input should match
					    specified nonterminal. *)
  | ELookaheadCS of bool * Cs.t      (* boolean value indicates whether or not following input should be
					     in the character set. *)
  | Final of nonterminal                 (* Source of arc is a final state for nonterminal; target is FSM final *)
  | MaybeFinal of nonterminal            (* Source of arc might be a final state for nonterminal -- predicate
					    will need to be consulted dynamically; target is FSM final *)
  | TxFinal                              (* Source of arc is a final state for the transducer; target is FSM final *)
  | EAction of expr                      (* Perform action and match epsilon *)
  | EPred of expr * expr                 (* Predicate, if true, match epsilon, else match nothing; f_pred, f_next *)
  | EBox of expr                         (* Call a blackbox parser; f_box *)

let arc2string = function
  | Epsilon -> "EPS"
  | Tm c -> Printf.sprintf "%%d%d" c
  | Call(None) -> "Call"
  | Call(Some e) -> Printf.sprintf "Call(%s)" e
  | CallEps -> "CallEps"
  | Cont(nt,None,None) -> nt
  | Cont(nt,Some e,None) -> Printf.sprintf "%s@(%s)" nt e
  | Cont(nt,None,Some f) -> Printf.sprintf "%s${%s}" nt f
  | Cont(nt,Some e,Some f) -> Printf.sprintf "%s@(%s)${%s}" nt e f
  | ELookahead(true,n) -> Printf.sprintf "&%s" n
  | ELookahead(false,n) -> Printf.sprintf "!%s" n
  | ELookaheadCS(true,cs) -> Printf.sprintf "&(%s)" (Cs.to_nice_string cs)
  | ELookaheadCS(false,cs) -> Printf.sprintf "!(%s)" (Cs.to_nice_string cs)
  | Final nt -> Printf.sprintf "Final(%s)" nt
  | MaybeFinal nt -> Printf.sprintf "MaybeFinal(%s)" nt
  | TxFinal -> Printf.sprintf "TxFinal"
  | EAction a -> Printf.sprintf "EAction{%s}" a
  | EPred (f_pred, f_next) -> Printf.sprintf "EPred{%s,%s}" f_pred f_next
  | EBox (f_box) -> Printf.sprintf "EBox(%s)" f_box

(*************************** GLOBAL STATE ***************************)

let ch = ref stdout (* output channel, so we don't have an extra arg for every function *)
let arc_num = ref 0                          (* next FSM arc number.  nb, arc 0 must be Epsilon in FSM, see init_nfa *)
let tbl_earley_fsm = Hashtbl.create 11       (* map earley arcs to fsm arcs *)
let tbl_fsm_earley = Hashtbl.create 11       (* map fsm arcs to earley arcs *)
let tbl_nonterminal_fsm = Hashtbl.create 11  (* map nonterminals to fsm start states *)
let nfa_number_of_states = ref 1             (* next FSM state number.  nb we reserve state 0 as a dead state;
                                                this is not an FSM requirement *)

(* obtain fresh states *)
let fresh1() = postincr nfa_number_of_states
let fresh2() = (fresh1(),fresh1())
let fresh3() = (fresh1(),fresh1(),fresh1())

let earley2fsm e_arc =
  match Util.find_option tbl_earley_fsm e_arc with Some x -> x
  | None ->
      (match e_arc with Tm n when (n < 0 || 255 < n) ->
        Printf.eprintf "Internal error: terminal out of range (%d)\n%!" n
      | _ -> ());
      let fsm_arc = postincr arc_num in
      Hashtbl.add tbl_earley_fsm e_arc fsm_arc;
      Hashtbl.add tbl_fsm_earley fsm_arc e_arc;
      fsm_arc

let fsm2earley fsm_arc =
  match Util.find_option tbl_fsm_earley fsm_arc with Some x -> x
  | None ->
      (Printf.eprintf "Internal error: unknown FSM arc %d\n%!" fsm_arc; Epsilon)

(* (re)initialize the global state *)
let init_nfa chan =
  ch := chan;
  Hashtbl.clear tbl_nonterminal_fsm;
  Hashtbl.clear tbl_earley_fsm;
  Hashtbl.clear tbl_fsm_earley;
  arc_num := 0;
  ignore(earley2fsm Epsilon); (* Set Epsilon == 0, an FSM requirement; all other arcs can be treated abstractly *)
  ignore(earley2fsm CallEps); (* Set CallEps == 1, because we need to replace with Epsilon at a certain stage,
                                 and we do it with perl, so it is convenient to make it a constant.
                                 see remove_CallEps() *)
  nfa_number_of_states := 1

(* map a nonterminal to its initial FSM state *)
let nonterminal2fsm n =
  match Util.find_option tbl_nonterminal_fsm n with Some x -> x
  | None ->
      let n_start = fresh1() in
      Hashtbl.add tbl_nonterminal_fsm n n_start;
      n_start

(************************ WRITING TO FSM ************************)

(* mark a state as an FSM final state *)
let fsm_final state =
  Printf.fprintf !ch "%d\n" state

(* output an arc *)
let atrans(source, target, earley_arc, w) =
  let fsm_arc = earley2fsm earley_arc in
  let float_w = weight2float w in
  Printf.fprintf !ch "%d %d %d %f\n" source target fsm_arc float_w

(* output an epsilon arc *)
let etrans(source, target, w) =
  atrans(source, target, Epsilon, w)

(* output an arc labeled by a character set *)
let cstrans(source, target, cs, w) =
  Cs.iter
    (fun c -> atrans(source, target, Tm c, w))
    cs

(************************ CONVERSION TO NFAS ************************)

(* convert a character set to an NFA *)
let mkact_fsm cs =
  let (s,f) = fresh2() in
  let num = Cs.count cs in
  let w = INV_PROB num in
  cstrans(s,f,cs,w);
  (s,f)

(* convert a literal string to an NFA. first argument controls whether
   the resulting NFA is case sensitive or case insensitive *)
let mklit_fsm(case_sensitive, x) =
  let s = fresh1() in
  if (0 = String.length x) then
    let f = fresh1() in
    etrans(s,f,ONE);
    (s,f)
  else begin
    (* could just iterate mkact_fsm, but this gives a smaller NFA *)
    let a = ref s in
    for i = 0 to String.length x - 1  do
      let c = String.get x i in
      let b = fresh1() in
      if not case_sensitive then
        let y = Cs.singleton(Char.lowercase c) in
        let w =
	  if (Char.lowercase c <> Char.uppercase c) then
	    (Cs.insert y (Char.code (Char.uppercase c)); PROB(0.5))
          else ONE in
        cstrans(!a,b,y,w)
      else begin
        let w = ONE in
        let y = Cs.singleton c in
        cstrans(!a,b,y,w)
      end;
      a := b
    done;
    (s,!a)
  end

(* convert a RHS to an NFA according to the Thompson algorithm *)
let thompson_symb = function
  | Symb(n,f_arg,f_ret) -> (* Call() instead of CallEps as in merge *)
     (*
        s--[n(args)]-->f
        |
      call(args)
        |
        v
       sn0
      *)
      let (s,f) = fresh2() in
      let sn0 = nonterminal2fsm n in
      atrans(s,f,   Cont(n,f_arg,f_ret), ONE);
      atrans(s,sn0, Call(f_arg),   ZERO);
      (s,f)
  | _ -> fresh2() (* TODO: impossible case, report error *)

let thompson_base arc =
  let (s,f) = fresh2() in
  atrans(s,f,arc,ONE);
  (s,f)

let rec thompson =  function
  | Symb _ as r -> thompson_symb r
  | Lit(case_sensitive,x) ->
      if (x = "") then
        let (s,f) = fresh2() in
        etrans(s,f,ONE);
        (s,f) (* Could return (s,s) and no etrans, but etrans is useful for debugging the output *)
      else
        let (s,f) = mklit_fsm(case_sensitive, x) in
        (s,f)
  | CharRange(low,high) ->
      let (s,f) = mkact_fsm(Cs.range low (high+1)) in
      (s,f)
  | Action f_act -> thompson_base (EAction f_act)
  | Box (f_box, _) ->  thompson_base (EBox (f_box))
  | When (f_pred, f_next) -> thompson_base (EPred (f_pred, f_next))

  | Seq(r2,r3) ->
     (*
        s2-->f2-->s3-->f3
        ##r2###   ##r3###
      *)
      let (s2,f2) = thompson r2 in
      let (s3,f3) = thompson r3 in
      etrans(f2,s3,ONE);
      (s2,f3)
  | Alt _ as r ->
      let (s,f) = fresh2() in
      let rules = alt2rules(r) in
      let n = List.length(rules) in
      let w = INV_PROB(n) in
      for i = 0 to n-1 do (* inefficient O(n^2) b/c of List.nth *)
        let r0 = List.nth rules i in
        let (s2,f2) = thompson r0 in
        etrans(s,s2,w);
        etrans(f2,f, ONE);
      done;
      (s,f)
  | Star(r2) ->
      let (s,f) = fresh2() in
      let (s2,f2) = thompson r2 in
      etrans(s,s2,     PROB(0.5));
      etrans(s,f,      PROB(0.5));
      etrans(f2,s2,    PROB(0.5));
      etrans(f2,f,     PROB(0.5));
      (s,f)
  | Lookahead (b, Symb(nt,None,None)) -> thompson_base (ELookahead (b, nt))
  | Lookahead (b, e) ->
      (match to_cs e with
	 | Some cs -> thompson_base (ELookaheadCS (b, cs))
	 | None ->
	     Util.error Util.Sys_warn
	       "lookahead limited to character sets or argument-free symbols.\n";
	     thompson (Lit(true,"")))

(************************************************************************)
(* convert an RHS to an NFA using the CALL-collapsing algorithm *)
let merge_symb = function
  | Symb(n,None, f_ret) ->
      let (s,f,e) = fresh3() in
      let sn0 = nonterminal2fsm n in
      atrans(s,sn0, CallEps,      ZERO);  (* TODO: verify correctness *)
      atrans(s,f,   Cont(n,None,f_ret), ONE);
      (s,f,e)
  | Symb(n,f_call,f_ret) ->
      let (s,f,e) = fresh3() in
      let sn0 = nonterminal2fsm n in
      atrans(s,sn0, Call(f_call),   ZERO);  (* TODO: verify correctness *)
      atrans(s,f,   Cont(n,f_call,f_ret), ONE);
      (s,f,e)
  | _ -> fresh3() (* TODO: impossible case, report error *)

let merge_base arc =
  let (s, f, e) = fresh3() in
  atrans(s, f, arc, ONE);
  (s, f, e)

let rec merge = function
  | Symb _ as r-> merge_symb r
  | Lit(case_sensitive,x) ->
      if (x = "") then
        let (s,f,e) = fresh3() in
        etrans(s,e, ONE);
        (s,f,e) (* Could return (s,f,s) and no etrans, but etrans is useful for debugging the output *)
      else
        let (s,f) = mklit_fsm(case_sensitive, x) in
        let e = fresh1() in
        (s,f,e)
  | CharRange(low,high) ->
      let (s,f) = mkact_fsm(Cs.range low (high+1)) in
      let e = fresh1() in
      (s,f,e)
  | Action a -> merge_base (EAction a)
  | When (f_pred, f_next) -> merge_base (EPred (f_pred, f_next))
  | Box (f_box, _) -> merge_base (EBox (f_box))
  | Seq(r2,r3) ->
     (*     ~~~r2~~~~   ~~~~~ r3 ~~~~~~
        s-->|s2-->f2|-->|scall-->fcall|--+-->f
            | +-->e2|   ~~~~~~~~~~~~~~~  |
            ~~~~~~~~~                    |
                   |                     |
                   |                     |
                   |    ~~~r3~~~~        |
                   +--->|s3-->f3|--------+
                        | +-->e3|---------->e
                        ~~~~~~~~~
      *)
      let (s,f,e) = fresh3() in
      let (s2,f2,e2) = merge r2 in
      let (s3,f3,e3) = merge r3 in
      let (scall,fcall) = thompson r3 in
      etrans(s,s2,     ONE);
      etrans(f2,scall, ONE);
      etrans(e2,s3,    ONE);
      etrans(f3,f,     ONE);
      etrans(fcall,f,  ONE);
      etrans(e3,e,     ONE);
      (s,f,e)
  | Alt _ as r ->
      let (s,f,e) = fresh3() in
      let rules = alt2rules(r) in
      let n = List.length(rules) in
      let w = INV_PROB(n) in
      for i = 0 to n-1 do (* inefficient *)
        let r0 = List.nth rules i in
        let (s2,f2,e2) = merge r0 in
        etrans(s,s2,w);
        etrans(e2,e, ONE);
        etrans(f2,f, ONE);
      done;
      (s,f,e)
  | Star(r2) ->
      let (s,f,e) = fresh3() in
      let (s2,f2,e2) = merge r2 in
      let (scall,fcall) = thompson r2 in
      etrans(s,s2,     PROB(0.5));
      etrans(s,e,      PROB(0.5));
      etrans(e2,s2,    PROB(0.5));
      etrans(e2,e,     PROB(0.5));
      etrans(f2,scall, PROB(0.5));
      etrans(f2,f,     PROB(0.5));
      (* We could replace the following two transitions with this single transition:
         etrans(fcall,f2);
         and then this would resemble the standard Star construction,
         with f2 playing the role of s. *)
      etrans(fcall,scall, PROB(0.5));
      etrans(fcall,f,     PROB(0.5));
      (s,f,e)
  | Lookahead (b, Symb(nt,None,None)) -> merge_base (ELookahead (b, nt))
  | Lookahead (b, e) ->
      (match to_cs e with
	 | Some cs -> merge_base (ELookaheadCS (b, cs))
	 | None ->
	     Util.error Util.Sys_warn
	       "lookahead limited to character sets or argument-free symbols.\n";
	     merge (Lit(true,"")))

(************************************************************************)

let gen_maybe_empty gr = Nullable_pred.Gil.preds_from_grammar gr

(* Output an FSM transducer for a grammar *)
let grammar_fsm ch gr =
  let npreds = gen_maybe_empty gr in (* what nonterminals are nullable? *)

  init_nfa ch;

  (* Create an initial FSM state s0.
     For each nonterminal n, create initial state sn0, and build

     s0 --n--> sn0

     (The edge, n, is unimportant -- we are just making sure all of
     the transducer is reachable from the initial state s0.)

     Note, FSM considers s0 the initial state because it is the first
     state in the output.
   *)
  let s0 = fresh1() in
  List.iter
    (fun (n,_) ->
      let sn0 = nonterminal2fsm n in
      atrans(s0,sn0,Cont(n,None,None),ZERO)
    )
    gr;

  (* For each nonterminal n,
     let sn0 be its initial state.
     Convert its right-hand side to obtain (s,f,e).
     Construct sn0 -eps-> s.
     Mark f and e as final states for n.
     If n is nullable, sn0 needs to be marked as final as well.
  *)
  List.iter
    (function
       | (n,r) ->
          let sn0 = nonterminal2fsm n in
	  let (s,f,e) = merge r in
	  atrans(sn0,s,Epsilon,ONE);
	  let s_final = fresh1() in
	  fsm_final s_final;

	  let arc_final = Final n in
	  atrans(f,s_final,arc_final,ONE);
	  atrans(e,s_final,arc_final,ONE);
	  (match Nullable_pred.Gil.get_symbol_nullability npreds n with
	     | Nullable_pred.No_n -> ()
	     | Nullable_pred.Yes_n -> atrans(s, s_final,arc_final,ONE)
	     | Nullable_pred.Maybe_n -> atrans(s, s_final, MaybeFinal n, ONE)
	  )
    )
    gr;

  () (* TODO: supposed to return stuff... *)


(************ VISUALIZE TRANSDUCERS WITH DOT (GRAPHVIZ) ************)

(* Options for dot output *)
let print_weights = ref false
let print_final_arcs = ref false
(*let fontname = ref ",fontname=\"Miso:bold\""*)
let font_regular = ref "Sans"
let font_bold = ref "Sans, Bold"
(*let fontname = ref ""*)

let weight2string f =
  if !print_weights then
    if f = 1.0 then "" else if f = 0.0 then " [0]" else Printf.sprintf " [%.2f]" f
  else ""

(* Read an FSM file from input and output a dot file.  FSM arc numbers are
   translated back into Earley arcs. *)
let fsm_dot _ inch outch =
  let char = Hashtbl.create 11 in
  let finals = Hashtbl.create 11 in
  let calls = Hashtbl.create 11 in
  let rec f = function
      Arc1(a,b,c,d) ->
        let e_arc = fsm2earley c in
        (match e_arc with
          Tm x ->
            (* For printing later: store c arc, will be combined with other character arcs from a to b *)
            (match Util.find_option char (a,b,d) with
              None ->
                let cs = Cs.singleton (Char.chr x) in
                Hashtbl.add char (a,b,d) cs
            | Some cs ->
                Cs.insert cs x)
        | Final n when not(!print_final_arcs) ->
            (* For printing later: mark a as a final state for n, with weight d *)
            let tl = (try Hashtbl.find finals a with _ -> []) in
            Hashtbl.replace finals a ((n,d)::tl)
        | Call eopt ->
            let x = (try Hashtbl.find calls a with _ -> "") in
            Hashtbl.replace calls a
              (match eopt with None -> Printf.sprintf "%s\ncall %d" x b
              | Some e -> Printf.sprintf "%s\ncall %d(%s)" x b e)
        | _ ->
            (* Print it now *)
            if (0=a) then
              (* state 0 is used to point to a subautomaton for each nonterminal *)
              let a = fresh1() in
              Printf.fprintf outch "%d -> %d [label=\"%s\"];\n" a b (weight2string d);
              Printf.fprintf outch "%d [shape=none,label=\"%s\"];\n" a (String.escaped (arc2string e_arc))
            else
              Printf.fprintf outch "%d -> %d [label=\"%s%s\"];\n"
                a b (String.escaped (arc2string e_arc)) (weight2string d))
    | Arc2(a,b,c) ->
        f(Arc1(a,b,c,0.0)) (* NB in FSM default weight is ZERO *)
    | Fin1(a,b) ->
        if !print_final_arcs then
          Printf.fprintf outch "%d [shape=box3d]\n" a
        else ()
    | Fin2(a) ->
        if !print_final_arcs then
          Printf.fprintf outch "%d [shape=box3d]\n" a
        else () in
  Printf.fprintf outch "digraph g {\nrankdir=LR\n";
  Printf.fprintf outch "node [shape=box,fontname=%s];\n" (quote !font_regular);
  Printf.fprintf outch "edge [fontname=%s];\n" (quote !font_regular);
  fsm_iter inch f;
  Hashtbl.iter
    (fun (a,b,d) cs ->
      Printf.fprintf outch "%d -> %d [label=\"%s%s\",fontname=%s]\n" a b
        (Cs.to_nice_string cs)
        (weight2string d)
        (quote !font_bold))
    char;
  Hashtbl.iter
    (fun a l ->
      let a_calls = (try Hashtbl.find calls a with _ -> "") in
      Printf.fprintf outch "%d [shape=box3d,label=\"%d (%s)%s\"]\n" a a
        (String.concat ","
           (List.map (fun (n,w) -> n) l))
        (String.escaped a_calls))
    finals;
  Hashtbl.iter
    (fun a a_calls ->
      if not(Hashtbl.mem finals a) then
        Printf.fprintf outch "%d [label=\"%d%s\"]\n" a a
          (String.escaped a_calls))
    calls;

  Printf.fprintf outch "}\n"

let tbl_varnames = Hashtbl.create 11
let varnum = ref 0
(* varname maps strings to variable names. For strings which are already variable names,
   the string is returned. For those which isn't, a suitable name is chosen (and remembered)
   based on a modification of the string and a prepending of the specified prefix along with a
   fresh digit.
   The function uses the prefix to ensure that if two strings map to the same variable after the
   standard modification, there is a way to distinguish them.
*)
let varname prefix =
  (fun str ->
    let already_var s =
      let is_digit c = '0' <= c && c <= '9' in
      let is_lower c = 'a' <= c && c <= 'z' in
      let is_upper c = 'A' <= c && c <= 'Z' in
      let is_ok c = '_'=c || is_digit c || is_lower c || is_upper c in
      try
        for i = 0 to String.length s - 1 do
          if not(is_ok(String.get s i)) then raise Exit
        done;
        true
      with Exit ->
        false
    in (match Util.find_option tbl_varnames str with Some x ->
      x
    | None ->
        let v =
          if already_var str then str else
          let num = postincr varnum in
          Printf.sprintf "%s%d" prefix num in
        Hashtbl.add tbl_varnames str v;
        v))

let fsm_transducer gr inch outch =

  let tbl_ntnames = Hashtbl.create 11 in
  let ntnum = ref min_symbol in
  let add_nonterm nt =
    begin
      match Util.find_option tbl_ntnames nt with
      | Some x -> x
      | None ->
          let num = postincr ntnum in
          Hashtbl.add tbl_ntnames nt num;
          num
    end in

  varnum := 0; Hashtbl.clear tbl_varnames;
  let action = varname "__a" in
  let predicate = varname "__p" in
  let box = varname "__b" in
  let arg_namer = varname "__g" in
  let arg = function
      None -> default_call_tx
    | Some x -> arg_namer x in

  let binders = DynArray.init 1 (fun _ -> default_binder_tx) in
  let tbl_binders = Hashtbl.create 11 in
  let bindernum = ref 1 in
  let binder = function
    | None -> Printf.sprintf "%s0" binder_prefix
    | Some str ->
	let num = match Util.find_option tbl_binders str with
	  | Some num -> num
          | None ->
              let num = postincr bindernum in
              Hashtbl.add tbl_binders str num;
              DynArray.add binders str;
	      num in
        Printf.sprintf "%s%d" binder_prefix num in

  let tbl_instrs = Hashtbl.create 11 in

  let starts = ref [] in
  let add_start nt b = starts := (nt,b)::!starts in

  let lookaheads = ref [] in
  let add_la a b is_next nt = lookaheads := (a, b, is_next, nt)::!lookaheads in

  (* precondition: fsm file is lexically ordered; so, all transitions from a state
     a are grouped together.
  *)
  let rec f = function
      Arc1(a,b,c,d) ->
        let add_eat x =
          Printf.ksprintf
            (fun eat ->
              let (eats_tl, ops_tl) = (try Hashtbl.find tbl_instrs a with _ -> ([],[]) ) in
              Hashtbl.replace tbl_instrs a (eat::eats_tl,ops_tl)) x in
        let add_op x =
          Printf.ksprintf
            (fun op ->
              let (eats_tl, ops_tl) = (try Hashtbl.find tbl_instrs a with _ -> ([],[]) ) in
              Hashtbl.replace tbl_instrs a (eats_tl, op::ops_tl)) x in
        (match fsm2earley c with
          Tm x ->          add_eat "EatInstr(%d,%d)" x b
        | Cont(n,arg_tx,y) ->
            let n_num = add_nonterm n in
	    if a = 0 then add_start n_num b;
	    (match arg_tx with
	       | None ->
		   add_op "ASimpleCont2Instr(%d,%s,%d)" n_num (binder y) b
	       | Some x ->
		   add_op "AContInstr3(%d,%s,%s,%d)" n_num (arg_namer x) (binder y) b)
	| ELookahead (is_next, n) ->
	    let n_num = add_nonterm n in
	    add_la a b is_next n_num
	| ELookaheadCS (is_next, cs) ->
	    add_op "ALookaheadInstr(%B, CsLA(%s), %d)" is_next (Cs.to_code cs) b
        | Call x ->       add_op "ACallInstr3(%s,%d)" (arg x) b
        | Final n ->      add_op "CompleteInstr(%d)" (add_nonterm  n)
        | MaybeFinal n -> add_op "RCompleteInstr2(%d,%s)"
				    (add_nonterm  n)
				    (Nullable_pred.mk_npname n)
        | TxFinal ->     add_op "FinalInstr"  (* b is irrelevant in this fsm encoding *)
        | EAction x ->   add_op "AAction2Instr(%s,%d)" (action x) b
        | EPred (fpred, fnext) ->
	    add_op "AWhenInstr3(%s,%s,%d)" (predicate fpred) (predicate fnext) b
        | EBox (fbox) ->
	    add_op "ABlackboxInstr(%s,%d)" (box fbox) b
        | _ -> ())
    | Arc2(a,b,c) ->
        f(Arc1(a,b,c,0.0)) (* NB in FSM default weight is ZERO *)
    | Fin1(a,_) | Fin2(a) -> () in


  fsm_iter inch f;

  (* Process the lookahead instructions now that we have all the starts information. *)
  List.iter (fun (a,b,is_next,nt) ->
	       let n_start = List.assoc nt !starts in
	       let op = Printf.sprintf "ALookaheadInstr(%B,CfgLA (%d,%d),%d)" is_next n_start nt b in
               let (eats_tl, ops_tl) = (try Hashtbl.find tbl_instrs a with _ -> ([],[]) ) in
               Hashtbl.replace tbl_instrs a (eats_tl, op::ops_tl))
    !lookaheads;

  (* The ignore set of transformers starts off calls with a fresh sv0 and ignores
     returned semantic values, keeping the previous semval instead.
  *)
  Printf.fprintf outch "let __default_call _ _ = sv0;;\n";
  Printf.fprintf outch "let __default_ret _ v1 _ = v1;;\n";

  Hashtbl.iter
    (fun defn v ->
      if v<>defn then
        Printf.fprintf outch "let %s = %s;;\n" v defn)
    tbl_varnames;

  (* Print binders *)
  DynArray.iteri (fun i str -> Printf.fprintf outch "let %s%d = %s;;\n" binder_prefix i str) binders;

  (* Generate vestigial binders table (empty): *)
  Printf.fprintf outch "let binders : (sv -> sv -> sv) array = [| |]\n";

  Printf.fprintf outch "let num_symbols = %d\n\n" (Hashtbl.length tbl_ntnames);

  Printf.fprintf outch "let symbol_table = function\n";
  Hashtbl.iter
    (fun nt n ->
      Printf.fprintf outch "  | %d -> %s\n" n (quote nt))
    tbl_ntnames;
  Printf.fprintf outch "  | x -> if x < 256 then Pam_internal.default_symbol_table x else \"?unknown?\"\n\n";

  Printf.fprintf outch "let get_symb_action = function\n";
  Hashtbl.iter
    (fun nt n ->
      Printf.fprintf outch "  | %s -> %d\n" (quote nt) n)
    tbl_ntnames;
  Printf.fprintf outch "  | _ -> raise Not_found\n\n";

  Printf.fprintf outch "let get_symb_start = function\n";
  List.iter (fun (nt,b) -> Printf.fprintf outch "  | %d -> %d\n" nt b) !starts;
  Printf.fprintf outch "  | _ -> raise Not_found\n\n";

  Printf.fprintf outch "open Pam_internal\n";

  Nullable_pred.Gil.process_grammar outch (Hashtbl.find tbl_ntnames) (fun nt -> List.assoc nt !starts) gr;

  Printf.fprintf outch "let program : (int * sv instruction list) list = [\n";
  Hashtbl.iter
    (fun a (eats,ops) ->
      Printf.fprintf outch "(%d, [%s]);\n" a
        (String.concat ";" (eats @ ops)))
    tbl_instrs;
  Printf.fprintf outch "]\n";
  ()

let remove_CallEps() =
  let make_Epsilon_ZERO a = (* return a perl command that turns every transition
                               with arc a into an Epsilon transition with weight 0 *)
    Printf.sprintf
      "perl -pe 's/^([0-9]+)\\s+([0-9]+)\\s+%d\\b.*$/\\1 \\2 0 0/g'" a in
  let callepsarc = 1 in (* NB must force the CallEps arc to be encoded as 1, see init_nfa above *)
  (make_Epsilon_ZERO callepsarc)