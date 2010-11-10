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

(* The dispatch transform *)

open Gul
open Util

let add_early_late_prologue gr =
  let hproj = if gr.wrapped_history then "Ykd_int" else "" in
  add_to_prologue gr (Printf.sprintf
  "
(*EARLY-LATE PROLOGUE*)
(*TODO:sv,sv0,sv_compare*)
type _uid = int (* for sharing *)
type _pos = int (* input positions *)
type _lab = int (* dispatch labels *)
type 'a ev = (* early values, aka coroutines.  'a is the type of values eventually computed by the coroutines *)
  | Yk_more of _uid * (_lab -> _pos -> 'a ev)
  | Yk_box of (_pos -> YkBuf.t -> (int * 'a ev) option)
  | Yk_when of bool
  | Yk_delay of 'a ev * hv
  | Yk_bind of ('a ev -> 'a ev)
  | Yk_done of 'a
let hv_compare = Yk_History.compare
let ev_compare x y =
  match x,y with
  | Yk_more(c1,_), Yk_more(c2,_) -> compare c1 c2
  | Yk_done c1, Yk_done c2 -> compare c1 c2 (* TODO: user-supplied compare *)
  | Yk_more _, Yk_done _ -> 1
  | Yk_done _, Yk_more _  -> -1
  | _,_ -> failwith \"TODO sv_compare\"
let _t_count = ref 0
let _fresh_t_id () =
  let count = !_t_count in
  incr _t_count;
  count
let _t f = Yk_more(_fresh_t_id(),f)
type sv = _wv ev * (hv*_pos) History.history
let sv0 = (Yk_done _wv0, Yk_History.new_history())
let sv_compare (x1,x2) (y1,y2) =
  (match ev_compare x1 y1 with
  | 0 -> hv_compare x2 y2
  | z -> z)
let _ev_to_string = function
  | Yk_more   _ -> \"Yk_more\"
  | Yk_box    _ -> \"Yk_box\"
  | Yk_when   _ -> \"Yk_when\"
  | Yk_delay  _ -> \"Yk_delay\"
  | Yk_bind   _ -> \"Yk_bind\"
  | Yk_done   _ -> \"Yk_done\"

let sv_hash (x,h) =
  let hash_h = Yk_History.hash h in
  (Hashtbl.hash x) lxor hash_h

(* Coroutine transformers *)

(*TJIM: we need multiple dispatch functions in a typed language, hence
  the many _d* variants.  The first argument x is the label.  Some _d*
  functions take a second argument p, which is the current input
  position.  The p is used by for history manipulations to distinguish
  two history nodes with the same label.  Some _d* functions that have
  a p argument use the p, and some do not use it.  Example: _d needs p
  even though p is unused in its body because it is used in
  Gil.Action, and there are some other Gil.Actions that need the p,
  e.g., _p and _ddelay. *)

let _d x p = function
    (Yk_more(_,t),h) -> (t x p,h)
  | (ev,_) -> failwith (Printf.sprintf \"_d(%%s)\" (_ev_to_string ev))
let _darg x p = function (*TJIM: same as _d without p*)
    (Yk_more(_,t),h) -> (t x p,h#empty)
  | _ -> failwith \"_darg\"
let _dbox x = function
    (Yk_more(_,t),h) ->
      (fun p ->
        (match t x p with
          Yk_box b ->
            (fun ykb -> (* painful! *)
              (match b p ykb with None -> None
              | Some(p2,a) -> Some(p2,(a,h))))
        | _ -> failwith \"_dbox\"))
  | _ -> failwith \"_dbox\"
let _dwhen x p = function
    (Yk_more(_,t),h) -> (match t x p with Yk_when b -> b | _ -> failwith \"_dwhen\")
  | _ -> failwith \"_dwhen\"
let _ddelay x p =
  (function
    | (Yk_more(_,t),h) -> (match t x p with Yk_delay(v,hv) -> (v,(h#push(%s(x),p))#push(hv,p)) | _ -> failwith \"_ddelay1\")
    | _ -> failwith \"_ddelay2\")
let _dret x p =
  (function
    | (Yk_more(_,t),h) ->
        (fun (r,_) ->
          (match t x p with
          | Yk_bind(f) -> (f r,h)
          | _ -> failwith \"_dret1\"))
    | _ -> failwith \"_dret2\")
let _dmerge x p =
  (function
    | (Yk_more(_,t),h1) ->
        (function
          | (Yk_done(r),h2) ->
              (match t x p with
              | Yk_bind(f) -> (f r,h1#merge(%s(x),p) h2)
              | _ -> failwith \"_dmerge1\")
          | _ -> failwith \"_dmerge2\")
    | _ -> failwith \"_dmerge3\")
let _d_and_push x p = function
    (Yk_more(_,t),h) -> (t x p,h#push(%s(x),p))
  | _ -> failwith \"_d_and_push\"
let _dnext x p = function (*TJIM: same as _d without p *)
    (Yk_more(_,t),h) -> (t x p,h)
  | _ -> failwith \"_dnext\"
(* History transformers *)
let _p x p = (fun(v,h)->(v,h#push(%s(x),p)))
let _m x p = (fun(v1,h1)->fun(_,h2)-> (v1,h1#merge(%s(x),p) h2))

" hproj hproj hproj hproj hproj)

let early_prologue = "
(*EARLY PROLOGUE*)
type _uid = int (* for sharing *)
type _pos = int (* input positions *)
type _lab = int (* dispatch labels *)
type 'a ev = (* early values, aka coroutines.  'a is the type of values eventually computed by the coroutines *)
  | Yk_more of _uid * (_lab -> _pos -> 'a ev)
  | Yk_box of (_pos -> YkBuf.t -> (int * 'a ev) option)
  | Yk_when of bool
  | Yk_bind of ('a ev -> 'a ev)
  | Yk_done of 'a
let ev_compare x y =
  match x,y with
  | Yk_more(c1,_), Yk_more(c2,_) -> compare c1 c2
  | Yk_done c1, Yk_done c2 -> compare c1 c2 (* TODO: user-supplied compare *)
  | Yk_more _, Yk_done _ -> 1
  | Yk_done _, Yk_more _  -> -1
  | _,_ -> failwith \"TODO sv_compare\"
let _t_count = ref 0
let _fresh_t_id () =
  let count = !_t_count in
  incr _t_count;
  count
let _t f = Yk_more(_fresh_t_id(),f)
type sv = _wv ev
let sv0 = Yk_done _wv0
let sv_compare = ev_compare

let sv_hash = Hashtbl.hash

(* Coroutine transformers *)
let _d x p = function
    Yk_more(_,t) -> t x p
  | _ -> failwith \"_d\"
let _darg x p = function
    Yk_more(_,t) -> t x p
  | _ -> failwith \"_darg\"
let _dbox x = function
    Yk_more(_,t) -> (fun p -> (match t x p with Yk_box b -> b p
                               | _ -> failwith \"_dbox\"))
  | _ -> failwith \"_dbox\"
let _dwhen x p = function
    Yk_more(_,t) -> (match t x p with Yk_when b -> b | _ -> failwith \"_dwhen\")
  | _ -> failwith \"_dwhen\"
let _dnext x p = function
    Yk_more(_,t) -> t x p
  | _ -> failwith \"_dnext\"
let _dret x p =
  (function
    | Yk_more(_,t) ->
        (fun r ->
          (match t x p with
          | Yk_bind(f) -> f r
          | _ -> failwith \"_dret1\"))
    | _ -> failwith \"_dret2\")

"

let add_late_prologue gr =
  let hproj = if gr.wrapped_history then "Ykd_int" else "" in
  add_to_prologue gr (Printf.sprintf
  "
(*LATE PROLOGUE*)
type _pos = int (* input positions *)
let hv_compare = Yk_History.compare
type sv = (hv*_pos) History.history
let sv0 = Yk_History.new_history()
let sv_compare = hv_compare
let sv_hash = Yk_History.hash

(* History transformers *)
let _p x p = fun h -> h#push(%s(x),p)
let _m x p = fun h -> h#merge(%s(x),p)

" hproj hproj)

let all_prologue = "let sv_eq x y = sv_compare x y = 0
let key_eq (i,v1) (j,v2) = i = j &&  sv_eq v1 v2
let key_hash (i,v) = i lxor (sv_hash v)

(** Hashtable for top-down parsing. *)
module TDHashtable = Hashtbl.Make(struct type t = int * sv let equal = key_eq let hash = key_hash end)

"

let transform gr =
  (match gr.grammar_early_relevant,gr.grammar_late_relevant with
  | true,true ->
      add_early_late_prologue gr
  | true,false ->
      add_to_prologue gr early_prologue
  | false,true ->
      add_late_prologue gr
  | false,false ->
      ());
  add_to_prologue gr all_prologue;
  let disp          = Printf.sprintf "_d %d" in
  let disp_delay    = Printf.sprintf "_ddelay %d" in
  let disp_when     = Printf.sprintf "_dwhen %d" in
  let disp_box      = Printf.sprintf "_dbox %d" in
  let disp_next     = Printf.sprintf "_dnext %d" in
  let disp_ret      = Printf.sprintf "_dret %d" in
  let disp_merge    = Printf.sprintf "_dmerge %d" in
  let disp_arg      = Printf.sprintf "_darg %d" in
  let push          = Printf.sprintf "_p %d" in
  let merge         = Printf.sprintf "_m %d" in
  let disp_and_push = Printf.sprintf "_d_and_push %d" in
  let rec gul2gil r = (* should only be called by dispatch, so invariants are satisfied *)
    match r.r with
    | CharRange(x,y) -> Gil.CharRange(x,y)
    | Lit(x,y)  -> Gil.Lit(x,y)
    | Opt(r1) -> Gil.Alt(Gil.Lit(false,""),gul2gil r1)
    | Alt(r1,r2) -> Gil.Alt(gul2gil r1,gul2gil r2)
    | Symb(n,None,[],None) -> Gil.Symb(n,None,None)
    | Action(None,None) -> Gil.Lit(false,"")
    | Seq(r1,None,None,r2) -> Gil.Seq(gul2gil r1,gul2gil r2)
    | Star(Bounds(0,Infinity),r1) -> Gil.Star(gul2gil r1)
    | Lookahead(b,r1)  -> Gil.Lookahead(b,d r1) (* CALL D <-- mutual recursion needed*)
          (* The cases below are relevant, gul2gil should not be called on relevant rhs *)
    | Star _      -> impossible "Dispatch.gul2gil.Star"
    | Delay _     -> impossible "Dispatch.gul2gil.Delay"
    | Box _       -> impossible "Dispatch.gul2gil.Box"
    | Seq _       -> impossible "Dispatch.gul2gil.Seq"
    | Assign _    -> impossible "Dispatch.gul2gil.Assign"
    | Action _    -> impossible "Dispatch.gul2gil.Action"
    | When _      -> impossible "Dispatch.gul2gil.When"
    | Symb(n,Some _,   _,     _) -> impossible (Printf.sprintf "Dispatch.gul2gil.Symb(%s) with early arguments" n)
    | Symb(n,     _,_::_,     _) -> impossible (Printf.sprintf "Dispatch.gul2gil.Symb(%s) with attributes" n)
    | Symb(n,     _,   _,Some _) -> impossible (Printf.sprintf "Dispatch.gul2gil.Symb(%s) with late arguments" n)
          (* The cases below should have been desugared *)
    | Position _  -> impossible "Dispatch.gul2gil.Position"
    | Hash _      -> impossible "Dispatch.gul2gil.Hash"
    | Rcount _    -> impossible "Dispatch.gul2gil.Rcount"
    | Minus _     -> impossible "Dispatch.gul2gil.Minus"
    | Prose _     -> impossible "Dispatch.gul2gil.Prose"
  and d r =
    if not(r.a.early_relevant || r.a.late_relevant) then gul2gil r else
    let (pre,post) = (r.a.pre,r.a.post) in
    match r.r with
      | Action (Some _,Some _) ->
          Gil.Action(disp_and_push(pre))
      | Action (Some _,_) ->
          Gil.Action(disp(pre))
      | Action (_,Some _) ->
          Gil.Action(push(pre))
      | Action (None,None) ->
          impossible "Dispatch.transform.d.Action(None,None)"
      | Symb(n,early_arg_opt,_,_) -> (* TODO: attributes *)
          let f_arg = if early_arg_opt=None then None else Some(disp_arg(pre)) in
          (match r.a.early_relevant,r.a.late_relevant with
          | true,true ->
              Gil.Seq(Gil.Action(push(pre)),
                      Gil.Symb(n,f_arg,Some(disp_merge(post))))
          | true,false ->
              Gil.Symb(n,f_arg,Some(disp_ret(post)))
          | false,true ->
              Gil.Seq(Gil.Action(push(pre)),
                      Gil.Symb(n,None,Some(merge(post))))
          | false,false ->
              (* impossible, would have been caught above *)
              gul2gil r)
      | When _ ->
          Gil.When(disp_when(pre),disp_next(post))
      | Box (_, _, bn) ->
          Gil.Box(disp_box(pre), bn)
      | Delay _ ->
          Gil.Action(disp_delay(pre))
      | Position true ->
          Gil.Action(disp(pre))
      | Opt r1 ->
          Gil.Alt(Gil.Lit(false,""),d r1)
      | Alt(r1,r2) ->
          Gil.Alt(d r1,d r2)
      | Seq(r1,early,late,r2) ->
          let disp_pre =
            (* See the corresponding code in case Seq in function coroutine *)
            match r1.a.early_relevant,r2.a.early_relevant with
            | true,true -> true
            | true,false -> false
            | false,true -> (early<>None)
            | false,false -> false in
          let push_pre =
            (* See the corresponding code in case Seq in function replay *)
            match r1.a.late_relevant,r2.a.late_relevant with
            | true,true -> true
            | true,false -> true
            | false,true -> (late<>None)
            | false,false -> false in
          (match disp_pre,push_pre with
          | true,true ->
              Gil.Seq(Gil.Action(disp_and_push(pre)),Gil.Seq(d r1,d r2))
          | false,true ->
              Gil.Seq(Gil.Action(push(pre)),Gil.Seq(d r1,d r2))
          | true,false ->
              Gil.Seq(Gil.Action(disp(pre)),Gil.Seq(d r1,d r2))
          | false,false ->
              Gil.Seq(d r1,d r2))
      | Assign(r1,early,late) ->
          let disp_pre =
            (* See the corresponding code in case Assign in function coroutine *)
            match early with
            | Some _ -> true
            | None -> false in
          let push_pre =
            (* See the corresponding code in case Assign in function replay *)
            r1.a.late_relevant in
          (match disp_pre,push_pre with
          | true,true ->
              Gil.Seq(Gil.Action(disp_and_push(pre)),d r1)
          | false,true ->
              Gil.Seq(Gil.Action(push(pre)),d r1)
          | true,false ->
              Gil.Seq(Gil.Action(disp(pre)),d r1)
          | false,false ->
              d r1)
      | Star(_,r1) ->
          (match r.a.early_relevant,r.a.late_relevant with
          | true,true ->
              Gil.Seq(Gil.Action(disp_and_push(pre)),
                      Gil.Seq(Gil.Star(d r1),
                              Gil.Action(disp_and_push(post))))
          | true,false ->
              Gil.Seq(Gil.Action(disp(pre)),
                      Gil.Seq(Gil.Star(d r1),
                              Gil.Action(disp(post))))
          | false,true ->
              Gil.Seq(Gil.Action(push(pre)),
                      Gil.Seq(Gil.Star(d r1),
                              Gil.Action(push(post))))
          | false,false ->
              impossible "dispatch Star")
      | Position _
      | CharRange(_,_)
      | Prose(_)
      | Lookahead _
      | Lit _  ->
          impossible "dispatch"
      | Rcount(_,_)
      | Hash(_,_)
      | Minus(_,_) ->
          impossible "dispatch"
  in
  gr.gildefs <-
    List.concat
      (List.map
         (function
             RuleDef(n,r,a) ->
               if not(gr.grammar_early_relevant) || not(r.a.early_relevant) then [(n,d r)] else
               let c =
                 (match gr.grammar_late_relevant,a.Attr.early_params with
                 | (false,None) ->
                     Printf.sprintf "(fun _(*pos*) _(*arg of %s*) -> %s)" n (Coroutine.transform r)
                 | (true,None) ->
                     let h = fresh() in
                     Printf.sprintf "(fun _(*pos*) (_,%s)(*arg of %s*) -> (%s,%s))" h n (Coroutine.transform r) h
                 | (false,Some x) ->
                     Printf.sprintf "(fun _(*pos*) -> (function Yk_done(%s) -> %s\n| _ -> failwith \"%s\"))"
                       x (Coroutine.transform r) n
                 | (true,Some x) ->
                     let h = fresh() in
                     Printf.sprintf "(fun _(*pos*) -> (function (Yk_done(%s),%s) -> (%s,%s)\n| _ -> failwith \"%s\"))"
                       x h (Coroutine.transform r) h n) in
               let coroutine = fresh() in
               add_to_prologue gr (Printf.sprintf "let %s =\n %s\n" coroutine c);
               [(n,Gil.Seq(Gil.Action(coroutine),d r))]
           | _ -> [])
         gr.ds)