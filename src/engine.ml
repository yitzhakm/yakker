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

(*
 m4 magic: 
 
*)

(** Turn on/off support for full-blown lookahead. *)
let support_FLA = true






(* DEF_ARG(argname, argval, body) *)




















(** Debugging use. For internal use only. *)
module Imp_position = struct
  let current_position = ref 0

  let set_position i =
    if Logging.activated then
      begin
	if i mod 100 = 0 then
	  Logging.log Logging.Features.position "CP=%d\n%!" i;
      end;
    current_position := i

  let get_position () = !current_position
end

(** ordered queue, mapping ints to lists of elements. *)
module Ordered_queue : sig
  type 'a t
  val init : unit -> 'a t
  val insert : 'a t -> int -> 'a -> unit
  val next : 'a t -> int
  val pop : 'a t -> (int * 'a list)
end = struct

  type 'a t = { mutable count : int; mutable lists : (int * 'a list) array; }

  let init () = { count = 0; lists = Array.make 11 (-1,[]); }

  let _insert q i elt =    
    let lists = q.lists in
    let len = Array.length lists in
    if q.count < len then begin
      for k = q.count downto i + 1 do
	Array.unsafe_set lists k (Array.unsafe_get lists (k - 1));
      done;
      Array.unsafe_set lists i elt
    end else begin
      let arr = (Obj.obj (Obj.new_block 0 (len * 2))) in
      Array.blit lists 0 arr 0 i;
      Array.unsafe_set arr i elt;
      Array.blit lists i arr (i + 1) (len - i);
      q.lists <- arr;
    end;
    q.count <- q.count + 1

  let _remove q i =
    let from = i + 1 in
    Array.blit q.lists from q.lists i (q.count - from);
    q.count <- q.count - 1

  let insert q x v =
    if q.count = 0 then _insert q 0 (x, [v])
    else
      let rec bfind arr (key : int) b e =
	if b < e then begin
	  let m = (b + e) / 2 in
	  let c = key - (fst arr.(m)) in
	  if c = 0 then m
	  else if c > 0 then bfind arr key (m + 1) e
	  else bfind arr key b (m - 1)
	end else e in
      let i = bfind q.lists x 0 (q.count - 1) in
      let (y, l) = q.lists.(i) in
      if x = y then q.lists.(i) <- (y, v::l)
      else if x < y then _insert q i (x, [v])
      else _insert q (i + 1) (x, [v])

  let next q = if q.count > 0 then (fst q.lists.(0)) else -1
  let pop q = 
    if q.count > 0 then begin
      let x = q.lists.(0) in 
      _remove q 0;
      x
    end else
      (-1, [])
end

module PJ = PamJIT
module PI = Pam_internal
module WI = Wf_set.Int_map

(* 

Part I

How should we treat the semval sets? There are two models:

  1) On creation of the map, initialize each element with a freshly allocated
    unique set. Thereafter, only reset existing sets.
  2) On creation of the map, initialize each element to None, and replace with
    Some on demand.
  2a) On creation of the map, initialize each element with the same, dummy,
   set and replace that set with a real one on demand.
  3) Use functional sets, and update the array position on each insertion.
   On creation of the map, initialize each element with the same `empty` element.

Going from 1) to 2) is trading time for space, because 2) avoids preallocating 
lots of sets which will possibly never get used but requires a check for None
upon each access. However, if the set data structure has a (very) small representation for 
empty sets, then there might little space saving moving from 1) to 2),
making 1) a win-win for time and space.

2a) is an optimization, where a well-known dummy element is used
(kind of like C's NULL) avoiding the None check on each insertion. Instead, the 
check for the dummy can be performed once per initialization of a map element, that 
is, whereever 1) would call `reset`, 2a) will check for dummy, allocate a fresh set 
if needed and reset otherwise. The disadvantage of 2a) compared with 2) is that it
opens up the risk of accidentally using the dummy element (like dereferencing NULL
 in C, only worse, because nothing like SEGFAULT will occur). 2a) seems like the best
choice for representations which require significant space even when empty. For example,
our sparse sets or OCaml's hashtables.


I will use 2a) for starters.

Part II

In practice, I wonder how many different semvals appear for any given 
(callset, state) pair in an Earley set, or for every state an NFA set. If the number 
is generally small, then it might be worth investigating this strategy for managing
those sets: employ two element comparison functions, one exact and the other an 
approximation. Then, let sets grow to fixed sized using insertions with the approximation
and then compact with the exact comparison. If, after compaction, the set is still larger
than the threshold, raise the threshold (to avoid constantly recompacting). From this 
general approach we can derive familiar structures:
  1. sets: threshold = 1 and approx. comparison = exact comparison
  2. multi-sets: threshold = inf. and approx. comparison = false.
  3. single-element: threshold = anything > 0 and approx. comparison = true.

I won't start out this general. Instead, I'll start with a standard set abstraction
while allowing the comp. function to be an approximation.

Part III

An alternative to all this, certainly worth comparing for performance, is using
the built-in hashtables of OCaml.  A delta from this would be to use the sparse
sets as a representation for the Hashtables, although I'm not sure that buys us 
much.

*)

(*
Need to pass callset by reference b/c might still change. wish there was
a way around this. not a big deal, though.

We map states to sets of callsets (socs). Here is the API for the socs:

    module Socs = struct
      insert
      union
      iter
      mem
    end

In addtion, we have convenience functions which operate on the Int_map itself:

    insert_one int_map state callset
    insert_many int_map state socs

Callset is a subset of the current set. The question is how best to represent it. Could
have pre- version which just keeps indexes in the current set, and the post process it. or, 
we could try to get it right the first time.

  The current callset will be treated specially. We will build it as a
  list and then convert it to an array. When new items are created
  which need to point to the current callset, they will be given a ref
  to the empty array. When processing of the current set is complete,
  the current callset list will be converted to an array and saved in
  the pre-existing ref.

  An obvious question is what happens if there is return to the
  current callset? This issue is a second (novel?) motivation for our
  special treatment of returning to the current callset.

  PERF: An additional point on the representation of callsets. Since we are using direct pointers,
  we need to pair callsets with their numeric representation (id) which we use as the key. 
  But, then, the socs is actually serving as a map from keys to set-pointers. Currently, 
  comparison is done by pulling out the key field of each element and comparing the keys. We could
  speed this up by storing the keys and the data separately. Given that this is a set, we don't
  need to support a fast find operation, only a fast member operation. So, we can represent the
  callset with two data structures: a set of keyes, and an array of key-value pairs. When we need to 
  iterate over the set, we use the array; when we need to check membership, we use the set.

*)
(* PERF: does ocamlopt perform escape analysis on refs to 
   decide whether they need to be heap allocated? *)

type 'a state_map = (int * 'a) array

type 'socs callset = { id : int;
		       (** identifier, for hashing/comparison purposes. *)
		       mutable data : 'socs state_map;
		       (** (state, payload) pairs *) }

let mk_callset id = {id=id; data= [||];}			
let hash_callset {id=x} = x
let cmp_callset {id=x1} {id=x2} = x1 - x2

type insertion_result = Ignore_elt | Reprocess_elt | Process_elt


(* DEF3(`SOCVAS_ITER', `socvas', `pattern', `body', `Socvas.iter (fun pattern -> body) socvas') *)



(* 
   The current callset is not formed until *after* we're done processing
   the current Earley set. So, trying to return to it will in
   effect be a no op. So, its probably more efficient *not* to
   check for it explicitly because the cost of always
   checking outways the possible benefit of saving the no-op
   completion in the case of returns to the current
   callset.  
*)
(*define(`CURRENT_CALLSET_GUARD', `callset.id <> current_callset.id')*)


module type SEMVAL = sig 
  type t
  val cmp : t -> t -> int
end

module PJDN = PamJIT.DNELR





module Full_yakker (Sem_val : SEMVAL) = struct

  let lookahead_regexp_NELR0_tbl term_table la_nt ykb start = 

    (* BUG: Missing handling of Many_trans. *)

    (*   Printf.printf "lookahead (%d, %d\n" la_nt start; *)
    let rec loop_eof term_table la_nt ykb s =
      if s <= 0 then false
      else 
	match term_table.(s) with
	  | PJDN.Lookahead_trans col -> loop_eof term_table la_nt ykb col.(PJ.iEOF)
	  | PJDN.Det_multi_trans col ->
	      (* 	     (match col.(PJ.iEOF) with *)
	      (* 		| PJN.Scan_dtrans _ -> false *)
	      (* 		| PJN.Lookahead_dtrans t -> loop_eof term_table la_nt ykb t) *)
	      let x = col.(PJ.iEOF) in
	      let x_action = x land 0x7F000000 in
	      let t = x land 0xFFFFFF in
	      if x_action = 0 then false 
	      else loop_eof term_table la_nt ykb t
	  | PJDN.Complete_trans nt
	  | PJDN.Complete_p_trans nt -> nt = la_nt
	  | PJDN.MComplete_trans nts
	  | PJDN.MComplete_p_trans nts -> Util.array_contains la_nt nts
	  | _ -> false in
    let rec step term_table la_nt ykb s =
      if YkBuf.fill2 ykb 1 then
	let c = Char.code (YkBuf.get_current ykb) in	
	loop term_table la_nt ykb c s
      else 
	loop_eof term_table la_nt ykb s
    and loop term_table la_nt ykb c s =
      if s <= 0 then false
      else
	match term_table.(s) with
	  | PJDN.Scan_trans (c1, t) -> if c = c1 then (YkBuf.advance ykb; step term_table la_nt ykb t) else false
	  | PJDN.MScan_trans col -> YkBuf.advance ykb; step term_table la_nt ykb col.(c)
	  | PJDN.Lookahead_trans col -> loop term_table la_nt ykb c col.(c)
	  | PJDN.Det_multi_trans col ->
	      (* 	    (match col.(c) with *)
	      (* 	       | PJDN.Scan_dtrans t -> YkBuf.advance ykb; step term_table la_nt ykb t *)
	      (* 	       | PJDN.Lookahead_dtrans t -> loop term_table la_nt ykb c t) *)
	      let x = col.(c) in
	      let x_action = x land 0x7F000000 in
	      let t = x land 0xFFFFFF in
	      if x_action = 0 
	      then (YkBuf.advance ykb; step term_table la_nt ykb t)
	      else loop term_table la_nt ykb c t
	  | PJDN.Complete_trans nt
	  | PJDN.Complete_p_trans nt -> nt = la_nt
	  | PJDN.MComplete_trans nts
	  | PJDN.MComplete_p_trans nts -> Util.array_contains la_nt nts
	  | _ -> false in
    step term_table la_nt ykb start

  module type MYSET = sig
    type elt
    type many_set
    type t = Empty | Singleton of elt | Other of many_set

    val empty : t
    val singleton : elt -> t

    val is_empty : t -> bool
    val cardinal : t -> int

    val mem : elt -> t -> bool
    val add : elt -> t -> t

    val diff : t -> t -> t
    val union : t -> t -> t

    val iter : (elt -> unit) -> t -> unit
    val fold : (elt -> 'a -> 'a) -> t -> 'a -> 'a

    val iter_ms :  (elt -> unit) -> many_set -> unit
  end

  module rec CVA : sig
    type t = Socvas.t callset * Sem_val.t * Sem_val.t
    val compare: t -> t -> int
  end = struct
    type t = Socvas.t callset * Sem_val.t * Sem_val.t
    let compare (c1,v1,a1) (c2,v2,a2) = 
      let c = cmp_callset c1 c2 in
      if c <> 0 then c
      else let c = Sem_val.cmp v1 v2 in
      if c <> 0 then c
      else Sem_val.cmp a1 a2
  end

  and Socvas : MYSET with type elt = CVA.t 
    = 
(* Set.Make(CVA) *)
  struct
    module Many_set = Set.Make(CVA)
    type elt = CVA.t
    type many_set = Many_set.t
    type t = Empty | Singleton of elt | Other of many_set

    let empty = Empty
    let singleton x = Singleton x
    let is_empty = function
      | Empty -> true
      | _ -> false

    let cardinal = function
      | Empty -> 0
      | Singleton _ -> 1
      | Other s -> Many_set.cardinal s

    let mem x = function
      | Empty -> false
      | Singleton y -> CVA.compare x y = 0
      | Other s -> Many_set.mem x s

    let add x = function
      | Empty -> Singleton x
      | Singleton y -> Other (Many_set.add x (Many_set.singleton y))
      | Other s -> Other (Many_set.add x s)

     let diff s1 s2 =
       match s1, s2 with
	 | Empty, _  -> Empty
	 | _, Empty  -> s1
	 | Singleton x, Singleton y -> if CVA.compare x y = 0 then Empty else s1
	 | Singleton x, Other s -> if Many_set.mem x s then Empty else s1
	 | Other s, Singleton y -> Other (Many_set.remove y s)
	 | Other ms1, Other ms2 -> Other (Many_set.diff ms1 ms2)

     let union s1 s2 =
       match s1, s2 with
	 | Empty, _  -> s2
	 | _, Empty  -> s1
	 | Singleton x, Singleton y ->
	     if CVA.compare x y = 0 then s1
	     else Other (Many_set.add x (Many_set.singleton y))
	 | Singleton x, Other s -> Other (Many_set.add x s)
	 | Other s, Singleton y -> Other (Many_set.add y s)
	 | Other ms1, Other ms2 -> Other (Many_set.union ms1 ms2)

     let iter f = function
      | Empty -> ()
      | Singleton y -> f y
      | Other s -> Many_set.iter f s

     let iter_ms = Many_set.iter

     let fold f s v =
       match s with
	 | Empty -> v
	 | Singleton y -> f y v
	 | Other s -> Many_set.fold f s v
  end

  module Proto_callset_list = struct

    let empty = (0, [])

    let reset pcc = pcc := empty

    let add_call_state pcc s = 
      let (pcc_n, pre_cc) = !pcc in
      if List.memq s pre_cc then ()
      else begin
	pcc := (pcc_n + 1, s::pre_cc)
      end

    (** Precondition: [length cc = len]. *)
    let convert_current_callset item_set pcc =     
      let rec loop arr item_set i = function
	| [] -> ()
	| x1::[] -> 
	    Array.unsafe_set arr i (x1, WI.get item_set x1); 
	| x1::x2::[] -> 
	    Array.unsafe_set arr i (x1, WI.get item_set x1); 
	    Array.unsafe_set arr (i + 1) (x2, WI.get item_set x2)
	| x1::x2::x3::[] -> 
	    Array.unsafe_set arr i (x1, WI.get item_set x1); 
	    Array.unsafe_set arr (i + 1) (x2, WI.get item_set x2); 
	    Array.unsafe_set arr (i + 2) (x3, WI.get item_set x3)
	| x1::x2::x3::x4::[] -> 
	    Array.unsafe_set arr i (x1, WI.get item_set x1); 
	    Array.unsafe_set arr (i + 1) (x2, WI.get item_set x2); 
	    Array.unsafe_set arr (i + 2) (x3, WI.get item_set x3);
	    Array.unsafe_set arr (i + 3) (x4, WI.get item_set x4)
	| x1::x2::x3::x4::xs -> 
	    Array.unsafe_set arr i (x1, WI.get item_set x1); 
	    Array.unsafe_set arr (i + 1) (x2, WI.get item_set x2); 
	    Array.unsafe_set arr (i + 2) (x3, WI.get item_set x3);
	    Array.unsafe_set arr (i + 3) (x4, WI.get item_set x4);
	    loop arr item_set (i + 4) xs in
      let (len, cc) = !pcc in
      let arr = (Obj.obj (Obj.new_block 0 len) : Socvas.t state_map) in
      loop arr item_set 0 cc;
      arr
  end

  module Proto_callset_wfis = struct

    module S = Wf_set.Int_set

    let empty n = S.make n

    let reset pcc = S.clear pcc

    let add_call_state pcc s = 
      if S.mem pcc s then ()
      else S.insert pcc s

    let convert_current_callset item_set pcc =     
      let len = pcc.S.count in
      let arr = (Obj.obj (Obj.new_block 0 len) : Socvas.t state_map) in
      for i = 0 to len - 1 do
	let x = Array.unsafe_get pcc.S.dense i in
	Array.unsafe_set arr i (x, WI.get item_set x); 
      done;
      arr
  end

  module Pcs = Proto_callset_wfis

  (**
     Reprocess an item from the worklist. If the item has not been processed yet,
     has no effect.

     [i] is a reference to the index of the last processed element in the worklist.
     [cs] is the set representing the worklist.
     Taken together, i and cs are a worklist data structure.

     Q: do we only need to check for equality with i if this function is 
     called recursively? Otherwise, there's no need to reprocess the 
     current state separately -- can just do it now?

     We are done with the element at position [!i], but now need to
     reprocess the elment at position i_t, so we swap them. 
     We decrement [i] to restore invariant that it points to last 
     processed element.

     Need to implement a "worklist" data structure which abstracts these 
     details better. 

  *)
  let worklist_reprocess i cs t = cs.WI.sparse.(t) <= i
  (** 
      Invocation: [insert_one es overflow_list state callset].
      @return [Process_elt], if state was not already in set, 
	      [Reprocess_elt], if state already in set but callset 
		not associated with that state,
	      [Ignore_elt] otherwise. 
  *)
  let insert_one i ol es state cva =
    if WI.mem es state then 
      let socvas = WI.get es state in
      if Socvas.mem cva socvas then Ignore_elt
      else begin 
	if Logging.activated then begin
	  let (callset, _, _) = cva in
	  Logging.log Logging.Features.reg_ne 
	    "+o %d:(%d,%d).\n" (Imp_position.get_position ()) state callset.id;
	end;
	WI.set es state (Socvas.add cva socvas); 
	if worklist_reprocess i es state then
	  ol := (state, Socvas.singleton cva) :: !ol;
	Reprocess_elt
      end
    else
      begin
	if Logging.activated then begin
	  let (callset, _, _) = cva in
	  Logging.log Logging.Features.reg_ne 
	    "+n %d:(%d,%d).\n" (Imp_position.get_position ()) state callset.id;
	end;
	WI.insert es state (Socvas.singleton cva);
	Process_elt
      end


  (* PERF: inline insert_one call and drop the ignore. *)
  let insert_one_ig i ol es state x y z = ignore (insert_one i ol es state (x,y,z))

  let insert_one_nc es state cva =
    if WI.mem es state then 
      let socvas = WI.get es state in
      WI.set es state (Socvas.add cva socvas);

      if Logging.activated then begin
	let (callset, _, _) = cva in
	Logging.log Logging.Features.reg_ne 
	  "+> %d:(%d,%d).\n" (Imp_position.get_position ()) state callset.id;
      end;
    else
      begin
	WI.insert es state (Socvas.singleton cva);

	if Logging.activated then begin
	  let (callset, _, _) = cva in
	  Logging.log Logging.Features.reg_ne 
	    "+> %d:(%d,%d).\n" (Imp_position.get_position ()) state callset.id;
	end
      end
  
  let insert_many i ol es state socvas_new =
    if WI.mem es state then begin
       	    if Logging.activated then begin Logging.log Logging.Features.reg_ne 
	  "+o %d:(%d,?).\n" (Imp_position.get_position ()) state;
       end 	    ;

      let socvas = WI.get es state in
      if worklist_reprocess i es state then begin
	let s_d = Socvas.diff socvas_new socvas in
	if not (Socvas.is_empty s_d) then begin
	  WI.set es state (Socvas.union s_d socvas);
	  ol := (state, s_d) :: !ol;
	end
      end else begin
	WI.set es state (Socvas.union socvas_new socvas);
      end
    end
    else begin
       	    if Logging.activated then begin Logging.log Logging.Features.reg_ne 
	  "+n %d:(%d,?).\n" (Imp_position.get_position ()) state
       end 	    ;
      WI.insert es state socvas_new
    end

  (** [insert_many] but without checking for newness. *)
  let insert_many_nc es state socvas_new =
    if WI.mem es state then begin
       	    if Logging.activated then begin Logging.log Logging.Features.reg_ne 
	  "+> %d:(%d,?).\n" (Imp_position.get_position ()) state
       end 	    ;
      let socvas = WI.get es state in
      WI.set es state (Socvas.union socvas socvas_new)
    end
    else begin
       	    if Logging.activated then begin Logging.log Logging.Features.reg_ne 
	  "+> %d:(%d,?).\n" (Imp_position.get_position ()) state
       end 	    ;
      WI.insert es state socvas_new
    end

  let insert_future q j s cva = Ordered_queue.insert q j (s, cva)

let null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos target sv0 current_callset is_new
    nt new_sv = 
                  (
		 let t1 = PJ.lookup_trans_nt nonterm_table s nt in
		 if t1 > 0 then begin
		    	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d]\n" s t1 nt
		    end 	    ;
		   insert_many i ol cs t1 socvas_s;
		 end;

		 (* We can be sure the carg is irrelevant because the nonterminal is connected to 
		    a parameterless call. (FIX: is this really true? how can we be sure that no
		    parametered calls share this state in the transducer?) *)
		 let {PJDN.ctarget = t1; carg = _; cbinder = binder} = 
		   PJDN.lookup_trans_pnt p_nonterm_table s nt in
		 if t1 > 0 then begin  
		    	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s t1 nt
		    end 	    ;
		                           (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> ( 
				  insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) ->  
				  insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg) __s__) 			
		 end;

		 if is_new then begin
		   let t1 = PJ.lookup_trans_nt nonterm_table target nt in
		   if t1 > 0 then begin
		      	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d]\n" target t1 nt
		      end 	    ;
		     insert_one_ig i ol cs t1 current_callset sv0 sv0;
		   end;

		   let {PJDN.ctarget = t1; carg = _; cbinder = binder} = 
		     PJDN.lookup_trans_pnt p_nonterm_table target nt in
		   if t1 > 0 then begin  
		      	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" target t1 nt
		      end 	    ;
		     (* We only consider one triple for t1, rather than a set of them, because 
			we reason that state t1 is only reachable by call/call_p edges. Hence,
			each call will independently handle its own (newly created) triple.
			FIX: verify the validity of this reasoning. *)
		     insert_one_ig i ol cs t1 current_callset (binder curr_pos sv0 new_sv) sv0
		   end
		 end
) 		



(* `NULL_COMPL(nt,new_sv)') *)





let mcomplete_code nonterm_table p_nonterm_table s i ol cs socvas_s current_callset nts no_args =
   	    if Logging.activated then begin let n = Socvas.cardinal socvas_s in
    Logging.Distributions.add_value 
      (if no_args then "CSS" else "CPSS")
      n;
   end 	    ;
  let m_nts = Array.length nts - 1 in
  let curr_pos = current_callset.id in
                          (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> (let items = callset.data in
    for l = 0 to Array.length items - 1 do
      let s_l, c_l = items.(l) in
      for k = 0 to m_nts do
	let t = PJ.lookup_trans_nt nonterm_table s_l nts.(k) in
        if t > 0 then insert_many i ol cs t c_l;
        if no_args then () else 
          let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = PJDN.lookup_trans_pnt p_nonterm_table s_l nts.(k) in
           if t > 0 then begin
	                             (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
	       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
		 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
	       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
		 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l) __s__) 			
           end
      done
    done)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) -> let items = callset.data in
    for l = 0 to Array.length items - 1 do
      let s_l, c_l = items.(l) in
      for k = 0 to m_nts do
	let t = PJ.lookup_trans_nt nonterm_table s_l nts.(k) in
        if t > 0 then insert_many i ol cs t c_l;
        if no_args then () else 
          let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = PJDN.lookup_trans_pnt p_nonterm_table s_l nts.(k) in
           if t > 0 then begin
	                             (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
	       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
		 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
	       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
		 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l) __s__) 			
           end
      done
    done) __s__) 			 



(*   `(mcomplete_code nonterm_table p_nonterm_table s i ol cs socvas_s current_callset nts no_args)') *)









  (* PERF: Create this closure once, and store it in [xyz]. *)
  (** Invokes full-blown lookahead in CfgLA case. *)
  let rec mk_lookahead term_table nonterm_table p_nonterm_table sv0
      la_nt la_target ykb = 
    let cp = YkBuf.save ykb in
    if Logging.activated then begin
      let cf = !Logging.current_features in
      Logging.set_features Logging.Features.none;
      let old_pos = Imp_position.get_position () in
      
      let r = _parse false 
	{PJDN.start_symb = la_nt; start_state = la_target;
	 term_table = term_table; nonterm_table = nonterm_table; 
	 p_nonterm_table = p_nonterm_table;}
	sv0 ykb <> [] in

      Logging.set_features cf;
      Logging.log Logging.Features.lookahead 
	"Lookahead: %B @ %d.\n" r (Imp_position.get_position ());
      Imp_position.set_position old_pos;
      YkBuf.restore ykb cp;
      r
    end else begin
      let r = _parse false 
	{PJDN.start_symb = la_nt; start_state = la_target;
	 term_table = term_table; nonterm_table = nonterm_table; 
	 p_nonterm_table = p_nonterm_table;}
	sv0 ykb <> [] in
      YkBuf.restore ykb cp;
      r
    end 

  and process_trans 
      (term_table, nonterm_table, p_nonterm_table, sv0, ol, cs, ns, 
       pre_cc, current_callset, ykb, futuresq, nplookahead_fn as xyz) 
       s socvas_s i = function
	   | PJDN.No_trans -> ()
	   | PJDN.Scan_trans (c,t) ->
	       let c1 = Char.code (YkBuf.get_current ykb) in
	       if c1 = c then insert_many_nc ns t socvas_s
	   | PJDN.MScan_trans col -> (
  let col = col in
  let c = Char.code (YkBuf.get_current ykb) in
  let t = col.(c) in
  if t > 0 then insert_many_nc ns t socvas_s
)
	   | PJDN.Lookahead_trans col -> (
  let col = col in
  let c = Char.code (YkBuf.get_current ykb) in
  let t = col.(c) in
  if t > 0 then insert_many i ol cs t socvas_s
)
	   | PJDN.Det_multi_trans col ->
	       let c = Char.code (YkBuf.get_current ykb) in
  (* 	     (match col.(c) with *)
  (* 		| PJDN.Scan_dtrans t -> if t > 0 then insert_many_nc ns t socvas_s *)
  (* 		| PJDN.Lookahead_dtrans t ->  *)
  (* 		    if t > 0 then insert_many i ol cs t socvas_s) *)
	       let x = col.(c) in
	       let x_action = x land 0x7F000000 in
	       let t = x land 0xFFFFFF in
	       if t > 0 then begin
		 if x_action = 0 
		 then insert_many_nc ns t socvas_s
		 else insert_many i ol cs t socvas_s
	       end
	   | PJDN.RegLookahead_trans (presence, la_target, la_nt, target) -> 
	                                       (let cp = YkBuf.save ykb in
  if Logging.activated then begin
    let cf = !Logging.current_features in
    Logging.set_features Logging.Features.none;
    let old_pos = Imp_position.get_position () in    

    let b = lookahead_regexp_NELR0_tbl term_table la_nt ykb la_target in

    Logging.set_features cf;
    let lookahead_pos = Imp_position.get_position () in
    Imp_position.set_position old_pos;
    if b = presence then begin
      Logging.log Logging.Features.lookahead 
	"Lookahead failed: %d.\n" lookahead_pos;
      insert_many i ol cs target socvas_s;
    end else begin
      Logging.log Logging.Features.lookahead 
	"Lookahead succeeded: %d.\n" lookahead_pos;
    end;
    YkBuf.restore ykb cp;
  end else begin
    let b = lookahead_regexp_NELR0_tbl term_table la_nt ykb la_target in
    YkBuf.restore ykb cp;
    if b = presence then insert_many i ol cs target socvas_s
  end
)         			

	   | PJDN.ExtLookahead_trans (presence, la_target, la_nt, target) -> 
	                                       (if presence = nplookahead_fn la_nt la_target ykb then insert_many i ol cs target socvas_s)         			

	   | PJDN.Call_trans t ->                 (Pcs.add_call_state pre_cc s;  
       let curr_pos = current_callset.id in
       let is_new = 
	 match insert_one i ol cs t (current_callset, sv0, sv0) with
	   | Ignore_elt -> false
	   | Reprocess_elt -> true
	   | Process_elt ->
	       Pcs.add_call_state pre_cc t;
		 true in

       if Logging.activated && is_new then begin
	Logging.log Logging.Features.calls_ne 
	  "+C %d:%d.\n" (Imp_position.get_position ()) t;
       end;

     (* Nullability check. *)
     (match term_table.(t) with
	| PJDN.Maybe_nullable_trans2 (nt, p) ->
	    if Logging.activated then begin
	      Logging.log Logging.Features.calls_ne 
		"Checking maybe nullable (@%d)\n" t;
	    end;

	  (match p nplookahead_fn ykb sv0 with
	     | None -> ()
	     | Some new_sv ->                 (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt new_sv) 		)

	| PJDN.Complete_p_trans nt ->                 (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt sv0) 		
	| PJDN.MComplete_p_trans nts ->
	    for k = 0 to Array.length nts - 1 do
	      let nt = nts.(k) in
	                      (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt sv0) 		
	    done

	| PJDN.Complete_trans nt -> 
	    let t1 = PJ.lookup_trans_nt nonterm_table s nt in
	    if t1 > 0 then insert_many i ol cs t1 socvas_s;
	    if is_new then
	      let t1 = PJ.lookup_trans_nt nonterm_table t nt in
	      if t1 > 0 then 
		insert_one_ig i ol cs t1 current_callset sv0 sv0
	| PJDN.MComplete_trans nts -> 
	    for k = 0 to Array.length nts - 1 do
	      let nt = nts.(k) in
	      let t1 = PJ.lookup_trans_nt nonterm_table s nt in
	      if t1 > 0 then insert_many i ol cs t1 socvas_s;
	      if is_new then
		let t1 = PJ.lookup_trans_nt nonterm_table t nt in
		if t1 > 0 then 
		  insert_one_ig i ol cs t1 current_callset sv0 sv0
	    done
	| PJDN.Many_trans txs -> 
	    for j = 0 to Array.length txs - 1 do
	      match txs.(j) with
		| PJDN.Maybe_nullable_trans2 (nt, p) ->
		    if Logging.activated then begin
		      Logging.log Logging.Features.calls_ne 
			"Checking maybe nullable (@%d)\n" t;
		    end;
		    (match p nplookahead_fn ykb sv0 with
		       | None -> ()
		       | Some new_sv ->                 (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt new_sv) 		)
		      
		| PJDN.Complete_p_trans nt ->                 (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt sv0) 		
		| PJDN.MComplete_p_trans nts ->
		    for k = 0 to Array.length nts - 1 do
		      let nt = nts.(k) in
		                      (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt sv0) 		
		    done
		| PJDN.Complete_trans nt -> 
		    let t1 = PJ.lookup_trans_nt nonterm_table s nt in
		    if t1 > 0 then insert_many i ol cs t1 socvas_s;
		    if is_new then
		      let t1 = PJ.lookup_trans_nt nonterm_table t nt in
		      if t1 > 0 then 
			insert_one_ig i ol cs t1 current_callset sv0 sv0
		| PJDN.MComplete_trans nts -> 
		    for k = 0 to Array.length nts - 1 do
		      let nt = nts.(k) in
		      let t1 = PJ.lookup_trans_nt nonterm_table s nt in
		      if t1 > 0 then insert_many i ol cs t1 socvas_s;
		      if is_new then
			let t1 = PJ.lookup_trans_nt nonterm_table t nt in
			if t1 > 0 then 
			  insert_one_ig i ol cs t1 current_callset sv0 sv0
		    done
		| _ -> ()	      
	    done
	| _ -> ())
   ) 		
	   | PJDN.Call_p_trans (call_act, t) ->                         (Pcs.add_call_state pre_cc s;  
                          (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> (let	curr_pos = current_callset.id in
     let arg = call_act curr_pos sv in
    (match insert_one i ol cs t (current_callset, arg, arg) with
	| Ignore_elt | Reprocess_elt -> ()
	| Process_elt -> Pcs.add_call_state pre_cc t);

    (* Nullability check. We only check source state [s], 
       because there is no call-collapsing for parameterized calls. *)
    match term_table.(t) with
      | PJDN.Maybe_nullable_trans2 (nt, p) ->
	  (match p nplookahead_fn ykb arg with
	     | None -> ()
	     | Some new_sv ->
		 let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		   PJDN.lookup_trans_pnt p_nonterm_table s nt in
		 if t1 > 0  && arg_act == call_act then begin  
		   (* Only need to check for physical equality 
		      of call_act and arg_act. if not equal, then there will be another 
		      call tagged with arg_act, which will be checked when it is invoked.  *)
		   insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg
		 end)
      | PJDN.Complete_p_trans nt -> 
	  let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
	    PJDN.lookup_trans_pnt p_nonterm_table s nt in
	  if t1 > 0  && arg_act == call_act then begin
	    insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
	  end
      | PJDN.MComplete_p_trans nts ->
	  for k = 0 to Array.length nts - 1 do
	    let nt = nts.(k) in
	    let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
	      PJDN.lookup_trans_pnt p_nonterm_table s nt in
	    if t1 > 0  && arg_act == call_act then begin
	      insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg 
	    end
	  done
      | PJDN.Many_trans trans -> 
	  let n = Array.length trans in
	  for j = 0 to n-1 do
	    match trans.(j) with
	      | PJDN.Maybe_nullable_trans2 (nt, p) ->
		  (match p nplookahead_fn ykb arg with
		     | None -> ()
		     | Some new_sv ->
			 let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
			   PJDN.lookup_trans_pnt p_nonterm_table s nt in
			 if t1 > 0  && arg_act == call_act then begin
			   insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg
			 end)
	      | PJDN.Complete_p_trans nt -> 
		  let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		    PJDN.lookup_trans_pnt p_nonterm_table s nt in
		  if t1 > 0  && arg_act == call_act then begin
		    insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
		  end
	      | PJDN.MComplete_p_trans nts ->
		  for k = 0 to Array.length nts - 1 do
		    let nt = nts.(k) in
		    let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		      PJDN.lookup_trans_pnt p_nonterm_table s nt in
		    if t1 > 0  && arg_act == call_act then begin
		      insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
		    end
		  done
	      | _ -> ()
	  done
      | _ -> () )
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) -> let	curr_pos = current_callset.id in
     let arg = call_act curr_pos sv in
    (match insert_one i ol cs t (current_callset, arg, arg) with
	| Ignore_elt | Reprocess_elt -> ()
	| Process_elt -> Pcs.add_call_state pre_cc t);

    (* Nullability check. We only check source state [s], 
       because there is no call-collapsing for parameterized calls. *)
    match term_table.(t) with
      | PJDN.Maybe_nullable_trans2 (nt, p) ->
	  (match p nplookahead_fn ykb arg with
	     | None -> ()
	     | Some new_sv ->
		 let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		   PJDN.lookup_trans_pnt p_nonterm_table s nt in
		 if t1 > 0  && arg_act == call_act then begin  
		   (* Only need to check for physical equality 
		      of call_act and arg_act. if not equal, then there will be another 
		      call tagged with arg_act, which will be checked when it is invoked.  *)
		   insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg
		 end)
      | PJDN.Complete_p_trans nt -> 
	  let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
	    PJDN.lookup_trans_pnt p_nonterm_table s nt in
	  if t1 > 0  && arg_act == call_act then begin
	    insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
	  end
      | PJDN.MComplete_p_trans nts ->
	  for k = 0 to Array.length nts - 1 do
	    let nt = nts.(k) in
	    let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
	      PJDN.lookup_trans_pnt p_nonterm_table s nt in
	    if t1 > 0  && arg_act == call_act then begin
	      insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg 
	    end
	  done
      | PJDN.Many_trans trans -> 
	  let n = Array.length trans in
	  for j = 0 to n-1 do
	    match trans.(j) with
	      | PJDN.Maybe_nullable_trans2 (nt, p) ->
		  (match p nplookahead_fn ykb arg with
		     | None -> ()
		     | Some new_sv ->
			 let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
			   PJDN.lookup_trans_pnt p_nonterm_table s nt in
			 if t1 > 0  && arg_act == call_act then begin
			   insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg
			 end)
	      | PJDN.Complete_p_trans nt -> 
		  let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		    PJDN.lookup_trans_pnt p_nonterm_table s nt in
		  if t1 > 0  && arg_act == call_act then begin
		    insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
		  end
	      | PJDN.MComplete_p_trans nts ->
		  for k = 0 to Array.length nts - 1 do
		    let nt = nts.(k) in
		    let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		      PJDN.lookup_trans_pnt p_nonterm_table s nt in
		    if t1 > 0  && arg_act == call_act then begin
		      insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
		    end
		  done
	      | _ -> ()
	  done
      | _ -> () ) __s__) 			) 			

	   | PJDN.Complete_trans nt -> 
	        	    if Logging.activated then begin let n = Socvas.cardinal socvas_s in
		 Logging.Distributions.add_value "CSS" n;
	        end 	    ;
	                               (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, _, _) -> ( 
		 if true then begin
		   let items = callset.data in
		   for l = 0 to Array.length items - 1 do
		     let s_l, c_l = items.(l) in
		     let t = PJ.lookup_trans_nt nonterm_table s_l nt in
		     if t > 0 then insert_many i ol cs t c_l
		   done
		 end)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, _, _) ->  
		 if true then begin
		   let items = callset.data in
		   for l = 0 to Array.length items - 1 do
		     let s_l, c_l = items.(l) in
		     let t = PJ.lookup_trans_nt nonterm_table s_l nt in
		     if t > 0 then insert_many i ol cs t c_l
		   done
		 end) __s__) 			

	   | PJDN.Complete_p_trans nt ->
	        	    if Logging.activated then begin let n = Socvas.cardinal socvas_s in
		 Logging.Distributions.add_value "CPSS" n;
	        end 	    ;
               let curr_pos = current_callset.id in 
	                               (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> ( 
		 let items = callset.data in
		 for l = 0 to Array.length items - 1 do
		   let s_l, c_l = items.(l) in

		   let t = PJ.lookup_trans_nt nonterm_table s_l nt in
		   if t > 0 then begin
		     insert_many i ol cs t c_l;
		      	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d]\n" s_l t nt
		      end 	    ;
		   end;

		   let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = 
		     PJDN.lookup_trans_pnt p_nonterm_table s_l nt in
		   if t > 0 then begin
		                             (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
  				   if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then begin
				      	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s_l t nt
				      end 	    ;
				     insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
				   end)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
  				   if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then begin
				      	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s_l t nt
				      end 	    ;
				     insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
				   end) __s__) 			
		   end
		     done)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) ->  
		 let items = callset.data in
		 for l = 0 to Array.length items - 1 do
		   let s_l, c_l = items.(l) in

		   let t = PJ.lookup_trans_nt nonterm_table s_l nt in
		   if t > 0 then begin
		     insert_many i ol cs t c_l;
		      	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d]\n" s_l t nt
		      end 	    ;
		   end;

		   let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = 
		     PJDN.lookup_trans_pnt p_nonterm_table s_l nt in
		   if t > 0 then begin
		                             (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
  				   if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then begin
				      	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s_l t nt
				      end 	    ;
				     insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
				   end)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
  				   if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then begin
				      	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s_l t nt
				      end 	    ;
				     insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
				   end) __s__) 			
		   end
		     done) __s__) 			

	   | PJDN.MComplete_trans nts ->                                 (
   	    if Logging.activated then begin let n = Socvas.cardinal socvas_s in
    Logging.Distributions.add_value 
      "CSS" 
      n;
   end 	    ;
  let m_nts = Array.length nts - 1 in
  
                          (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, _, _)  -> (let items = callset.data in
    for l = 0 to Array.length items - 1 do
      let s_l, c_l = items.(l) in
      for k = 0 to m_nts do
	let t = PJ.lookup_trans_nt nonterm_table s_l nts.(k) in
        if t > 0 then insert_many i ol cs t c_l;
        
      done
    done)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, _, _)  -> let items = callset.data in
    for l = 0 to Array.length items - 1 do
      let s_l, c_l = items.(l) in
      for k = 0 to m_nts do
	let t = PJ.lookup_trans_nt nonterm_table s_l nts.(k) in
        if t > 0 then insert_many i ol cs t c_l;
        
      done
    done) __s__) 			 
) 		 		
	   | PJDN.MComplete_p_trans nts ->                                 (
   	    if Logging.activated then begin let n = Socvas.cardinal socvas_s in
    Logging.Distributions.add_value 
      "CPSS" 
      n;
   end 	    ;
  let m_nts = Array.length nts - 1 in
  let curr_pos = current_callset.id in
                          (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg)  -> (let items = callset.data in
    for l = 0 to Array.length items - 1 do
      let s_l, c_l = items.(l) in
      for k = 0 to m_nts do
	let t = PJ.lookup_trans_nt nonterm_table s_l nts.(k) in
        if t > 0 then insert_many i ol cs t c_l;
        let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = PJDN.lookup_trans_pnt p_nonterm_table s_l nts.(k) in
           if t > 0 then begin
	                             (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
	       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then begin
		  	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s_l t nts.(k)
		  end 	    ;
		 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
	       end)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
	       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then begin
		  	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s_l t nts.(k)
		  end 	    ;
		 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
	       end) __s__) 			
           end
      done
    done)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg)  -> let items = callset.data in
    for l = 0 to Array.length items - 1 do
      let s_l, c_l = items.(l) in
      for k = 0 to m_nts do
	let t = PJ.lookup_trans_nt nonterm_table s_l nts.(k) in
        if t > 0 then insert_many i ol cs t c_l;
        let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = PJDN.lookup_trans_pnt p_nonterm_table s_l nts.(k) in
           if t > 0 then begin
	                             (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
	       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then begin
		  	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s_l t nts.(k)
		  end 	    ;
		 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
	       end)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
	       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then begin
		  	    if Logging.activated then begin Logging.log Logging.Features.comp_ne "%d => %d [%d(_)]\n" s_l t nts.(k)
		  end 	    ;
		 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
	       end) __s__) 			
           end
      done
    done) __s__) 			 
) 		 		

	   | PJDN.Many_trans trans ->
	       let n = Array.length trans in
	       for j = 0 to n-1 do
		 process_trans xyz s socvas_s i trans.(j)
	       done

	   | PJDN.Maybe_nullable_trans2 _ -> () 
	       (* only relevant immediately after a call *)

	   | PJDN.Action_trans (act, target) -> 
               let curr_pos = current_callset.id in
	                               (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> (insert_one_ig i ol cs target callset (act curr_pos sv) sv_arg)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) -> insert_one_ig i ol cs target callset (act curr_pos sv) sv_arg) __s__) 			

	   | PJDN.When_trans (p, next, target) -> 
               let curr_pos = current_callset.id in
	                               (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> (if p curr_pos sv then insert_one_ig i ol cs target callset (next curr_pos sv) sv_arg)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) -> if p curr_pos sv then insert_one_ig i ol cs target callset (next curr_pos sv) sv_arg) __s__) 			

	   | PJDN.Box_trans (box, target) ->
	       (                        (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> (let cp = YkBuf.save ykb in
			   (match box sv current_callset.id ykb with
				Some (0, ret_sv) -> (* returns to current set *)
				  insert_one_ig i ol cs target callset ret_sv sv_arg
			      | Some (1, ret_sv) -> (* returns to next set *)
				  insert_one_nc ns target (callset, ret_sv, sv_arg)
			      | Some (n, ret_sv) ->
				  let curr_pos = current_callset.id in
				  let j = curr_pos + n in
				  insert_future futuresq j target (callset, ret_sv, sv_arg)
			      | None -> ()
			   );
			   YkBuf.restore ykb cp)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) -> let cp = YkBuf.save ykb in
			   (match box sv current_callset.id ykb with
				Some (0, ret_sv) -> (* returns to current set *)
				  insert_one_ig i ol cs target callset ret_sv sv_arg
			      | Some (1, ret_sv) -> (* returns to next set *)
				  insert_one_nc ns target (callset, ret_sv, sv_arg)
			      | Some (n, ret_sv) ->
				  let curr_pos = current_callset.id in
				  let j = curr_pos + n in
				  insert_future futuresq j target (callset, ret_sv, sv_arg)
			      | None -> ()
			   );
			   YkBuf.restore ykb cp) __s__) 			)

  and process_eof_trans start_nt succeeded ol cs socvas_s i term_table nonterm_table p_nonterm_table nplookahead_fn
      s sv0 current_callset ykb = function
	   | PJDN.No_trans -> ()
	   | PJDN.Scan_trans _ | PJDN.MScan_trans _ -> () 
	   | PJDN.Lookahead_trans col -> 
	       let t = col.(PJ.iEOF) in
	       if t > 0 then insert_many i ol cs t socvas_s
	   | PJDN.Det_multi_trans col ->
  (* 	     (match col.(PJ.iEOF) with *)
  (* 		| PJDN.Scan_dtrans t -> () *)
  (* 		| PJDN.Lookahead_dtrans t -> if t > 0 then insert_many i ol cs t socvas_s) *)
	       let x = col.(PJ.iEOF) in
	       let x_action = x land 0x7F000000 in
	       let t = x land 0xFFFFFF in
	       if t > 0 && x_action > 0 then insert_many i ol cs t socvas_s
	   | PJDN.RegLookahead_trans (presence, la_target, la_nt, target) ->
	                                       (let cp = YkBuf.save ykb in
  if Logging.activated then begin
    let cf = !Logging.current_features in
    Logging.set_features Logging.Features.none;
    let old_pos = Imp_position.get_position () in    

    let b = lookahead_regexp_NELR0_tbl term_table la_nt ykb la_target in

    Logging.set_features cf;
    let lookahead_pos = Imp_position.get_position () in
    Imp_position.set_position old_pos;
    if b = presence then begin
      Logging.log Logging.Features.lookahead 
	"Lookahead failed: %d.\n" lookahead_pos;
      insert_many i ol cs target socvas_s;
    end else begin
      Logging.log Logging.Features.lookahead 
	"Lookahead succeeded: %d.\n" lookahead_pos;
    end;
    YkBuf.restore ykb cp;
  end else begin
    let b = lookahead_regexp_NELR0_tbl term_table la_nt ykb la_target in
    YkBuf.restore ykb cp;
    if b = presence then insert_many i ol cs target socvas_s
  end
)         			
	   | PJDN.ExtLookahead_trans (presence, la_target, la_nt, target) ->
	                                       (if presence = nplookahead_fn la_nt la_target ykb then insert_many i ol cs target socvas_s)         			
	   | PJDN.Call_trans t ->                 (  
       let curr_pos = current_callset.id in
       let is_new = 
	 match insert_one i ol cs t (current_callset, sv0, sv0) with
	   | Ignore_elt -> false
	   | Reprocess_elt -> true
	   | Process_elt ->
	       
		 true in

       if Logging.activated && is_new then begin
	Logging.log Logging.Features.calls_ne 
	  "+C %d:%d.\n" (Imp_position.get_position ()) t;
       end;

     (* Nullability check. *)
     (match term_table.(t) with
	| PJDN.Maybe_nullable_trans2 (nt, p) ->
	    if Logging.activated then begin
	      Logging.log Logging.Features.calls_ne 
		"Checking maybe nullable (@%d)\n" t;
	    end;

	  (match p nplookahead_fn ykb sv0 with
	     | None -> ()
	     | Some new_sv ->                 (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt new_sv) 		)

	| PJDN.Complete_p_trans nt ->                 (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt sv0) 		
	| PJDN.MComplete_p_trans nts ->
	    for k = 0 to Array.length nts - 1 do
	      let nt = nts.(k) in
	                      (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt sv0) 		
	    done

	| PJDN.Complete_trans nt -> 
	    let t1 = PJ.lookup_trans_nt nonterm_table s nt in
	    if t1 > 0 then insert_many i ol cs t1 socvas_s;
	    if is_new then
	      let t1 = PJ.lookup_trans_nt nonterm_table t nt in
	      if t1 > 0 then 
		insert_one_ig i ol cs t1 current_callset sv0 sv0
	| PJDN.MComplete_trans nts -> 
	    for k = 0 to Array.length nts - 1 do
	      let nt = nts.(k) in
	      let t1 = PJ.lookup_trans_nt nonterm_table s nt in
	      if t1 > 0 then insert_many i ol cs t1 socvas_s;
	      if is_new then
		let t1 = PJ.lookup_trans_nt nonterm_table t nt in
		if t1 > 0 then 
		  insert_one_ig i ol cs t1 current_callset sv0 sv0
	    done
	| PJDN.Many_trans txs -> 
	    for j = 0 to Array.length txs - 1 do
	      match txs.(j) with
		| PJDN.Maybe_nullable_trans2 (nt, p) ->
		    if Logging.activated then begin
		      Logging.log Logging.Features.calls_ne 
			"Checking maybe nullable (@%d)\n" t;
		    end;
		    (match p nplookahead_fn ykb sv0 with
		       | None -> ()
		       | Some new_sv ->                 (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt new_sv) 		)
		      
		| PJDN.Complete_p_trans nt ->                 (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt sv0) 		
		| PJDN.MComplete_p_trans nts ->
		    for k = 0 to Array.length nts - 1 do
		      let nt = nts.(k) in
		                      (null_compl nonterm_table p_nonterm_table s i ol cs socvas_s curr_pos t sv0 current_callset is_new
      nt sv0) 		
		    done
		| PJDN.Complete_trans nt -> 
		    let t1 = PJ.lookup_trans_nt nonterm_table s nt in
		    if t1 > 0 then insert_many i ol cs t1 socvas_s;
		    if is_new then
		      let t1 = PJ.lookup_trans_nt nonterm_table t nt in
		      if t1 > 0 then 
			insert_one_ig i ol cs t1 current_callset sv0 sv0
		| PJDN.MComplete_trans nts -> 
		    for k = 0 to Array.length nts - 1 do
		      let nt = nts.(k) in
		      let t1 = PJ.lookup_trans_nt nonterm_table s nt in
		      if t1 > 0 then insert_many i ol cs t1 socvas_s;
		      if is_new then
			let t1 = PJ.lookup_trans_nt nonterm_table t nt in
			if t1 > 0 then 
			  insert_one_ig i ol cs t1 current_callset sv0 sv0
		    done
		| _ -> ()	      
	    done
	| _ -> ())
   ) 		
	   | PJDN.Call_p_trans (call_act, t) ->                         (  
                          (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> (let	curr_pos = current_callset.id in
     let arg = call_act curr_pos sv in
    insert_one_ig i ol cs t current_callset arg arg;

    (* Nullability check. We only check source state [s], 
       because there is no call-collapsing for parameterized calls. *)
    match term_table.(t) with
      | PJDN.Maybe_nullable_trans2 (nt, p) ->
	  (match p nplookahead_fn ykb arg with
	     | None -> ()
	     | Some new_sv ->
		 let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		   PJDN.lookup_trans_pnt p_nonterm_table s nt in
		 if t1 > 0  && arg_act == call_act then begin  
		   (* Only need to check for physical equality 
		      of call_act and arg_act. if not equal, then there will be another 
		      call tagged with arg_act, which will be checked when it is invoked.  *)
		   insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg
		 end)
      | PJDN.Complete_p_trans nt -> 
	  let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
	    PJDN.lookup_trans_pnt p_nonterm_table s nt in
	  if t1 > 0  && arg_act == call_act then begin
	    insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
	  end
      | PJDN.MComplete_p_trans nts ->
	  for k = 0 to Array.length nts - 1 do
	    let nt = nts.(k) in
	    let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
	      PJDN.lookup_trans_pnt p_nonterm_table s nt in
	    if t1 > 0  && arg_act == call_act then begin
	      insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg 
	    end
	  done
      | PJDN.Many_trans trans -> 
	  let n = Array.length trans in
	  for j = 0 to n-1 do
	    match trans.(j) with
	      | PJDN.Maybe_nullable_trans2 (nt, p) ->
		  (match p nplookahead_fn ykb arg with
		     | None -> ()
		     | Some new_sv ->
			 let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
			   PJDN.lookup_trans_pnt p_nonterm_table s nt in
			 if t1 > 0  && arg_act == call_act then begin
			   insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg
			 end)
	      | PJDN.Complete_p_trans nt -> 
		  let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		    PJDN.lookup_trans_pnt p_nonterm_table s nt in
		  if t1 > 0  && arg_act == call_act then begin
		    insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
		  end
	      | PJDN.MComplete_p_trans nts ->
		  for k = 0 to Array.length nts - 1 do
		    let nt = nts.(k) in
		    let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		      PJDN.lookup_trans_pnt p_nonterm_table s nt in
		    if t1 > 0  && arg_act == call_act then begin
		      insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
		    end
		  done
	      | _ -> ()
	  done
      | _ -> () )
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) -> let	curr_pos = current_callset.id in
     let arg = call_act curr_pos sv in
    insert_one_ig i ol cs t current_callset arg arg;

    (* Nullability check. We only check source state [s], 
       because there is no call-collapsing for parameterized calls. *)
    match term_table.(t) with
      | PJDN.Maybe_nullable_trans2 (nt, p) ->
	  (match p nplookahead_fn ykb arg with
	     | None -> ()
	     | Some new_sv ->
		 let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		   PJDN.lookup_trans_pnt p_nonterm_table s nt in
		 if t1 > 0  && arg_act == call_act then begin  
		   (* Only need to check for physical equality 
		      of call_act and arg_act. if not equal, then there will be another 
		      call tagged with arg_act, which will be checked when it is invoked.  *)
		   insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg
		 end)
      | PJDN.Complete_p_trans nt -> 
	  let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
	    PJDN.lookup_trans_pnt p_nonterm_table s nt in
	  if t1 > 0  && arg_act == call_act then begin
	    insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
	  end
      | PJDN.MComplete_p_trans nts ->
	  for k = 0 to Array.length nts - 1 do
	    let nt = nts.(k) in
	    let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
	      PJDN.lookup_trans_pnt p_nonterm_table s nt in
	    if t1 > 0  && arg_act == call_act then begin
	      insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg 
	    end
	  done
      | PJDN.Many_trans trans -> 
	  let n = Array.length trans in
	  for j = 0 to n-1 do
	    match trans.(j) with
	      | PJDN.Maybe_nullable_trans2 (nt, p) ->
		  (match p nplookahead_fn ykb arg with
		     | None -> ()
		     | Some new_sv ->
			 let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
			   PJDN.lookup_trans_pnt p_nonterm_table s nt in
			 if t1 > 0  && arg_act == call_act then begin
			   insert_one_ig i ol cs t1 callset (binder curr_pos sv new_sv) sv_arg
			 end)
	      | PJDN.Complete_p_trans nt -> 
		  let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		    PJDN.lookup_trans_pnt p_nonterm_table s nt in
		  if t1 > 0  && arg_act == call_act then begin
		    insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
		  end
	      | PJDN.MComplete_p_trans nts ->
		  for k = 0 to Array.length nts - 1 do
		    let nt = nts.(k) in
		    let {PJDN.ctarget = t1; carg = arg_act; cbinder = binder} = 
		      PJDN.lookup_trans_pnt p_nonterm_table s nt in
		    if t1 > 0  && arg_act == call_act then begin
		      insert_one_ig i ol cs t1 callset (binder curr_pos sv arg) sv_arg
		    end
		  done
	      | _ -> ()
	  done
      | _ -> () ) __s__) 			) 			

	   | PJDN.Complete_trans nt -> 
	       let is_nt = nt = start_nt in
	                               (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset,_,_) -> ( 
   	         if is_nt && callset.id = 0 then succeeded := true;
		 let items = callset.data in
		 for l = 0 to Array.length items - 1 do
		   let s_l, c_l = items.(l) in
		   let t = PJ.lookup_trans_nt nonterm_table s_l nt in
		   if t > 0 then insert_many i ol cs t c_l
		 done)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset,_,_) ->  
   	         if is_nt && callset.id = 0 then succeeded := true;
		 let items = callset.data in
		 for l = 0 to Array.length items - 1 do
		   let s_l, c_l = items.(l) in
		   let t = PJ.lookup_trans_nt nonterm_table s_l nt in
		   if t > 0 then insert_many i ol cs t c_l
		 done) __s__) 			

	   | PJDN.Complete_p_trans nt ->
	       let is_nt = nt = start_nt in
               let curr_pos = current_callset.id in
	                               (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> ( 
   	         if is_nt && callset.id = 0 then succeeded := true;
		 let items = callset.data in
		 for l = 0 to Array.length items - 1 do
		   let s_l, c_l = items.(l) in

		   let t = PJ.lookup_trans_nt nonterm_table s_l nt in
		   if t > 0 then insert_many i ol cs t c_l;

		   let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = PJDN.lookup_trans_pnt p_nonterm_table s_l nt in
		   if t > 0 then begin
		                             (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
  		       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
			 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
  		       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
			 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l) __s__) 			
		   end
		 done)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) ->  
   	         if is_nt && callset.id = 0 then succeeded := true;
		 let items = callset.data in
		 for l = 0 to Array.length items - 1 do
		   let s_l, c_l = items.(l) in

		   let t = PJ.lookup_trans_nt nonterm_table s_l nt in
		   if t > 0 then insert_many i ol cs t c_l;

		   let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = PJDN.lookup_trans_pnt p_nonterm_table s_l nt in
		   if t > 0 then begin
		                             (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
  		       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
			 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
  		       if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
			 insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l) __s__) 			
		   end
		 done) __s__) 			 

	   | PJDN.MComplete_trans nts -> 
	       let m_nts = Array.length nts - 1 in
	                               (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset,_,_) -> ( 
		   let is_start = callset.id = 0 in
		   let items = callset.data in
		   let m_items = Array.length items - 1 in
		   for k = 0 to m_nts do
		     let nt = nts.(k) in
		     if is_start && nt = start_nt then
		       succeeded := true (* ... and do not bother performing the completion. *)
		     else
		       for l = 0 to m_items do
			 let s_l, c_l = items.(l) in
			 let t = PJ.lookup_trans_nt nonterm_table s_l nt in
			 if t > 0 then insert_many i ol cs t c_l
		       done
		   done)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset,_,_) ->  
		   let is_start = callset.id = 0 in
		   let items = callset.data in
		   let m_items = Array.length items - 1 in
		   for k = 0 to m_nts do
		     let nt = nts.(k) in
		     if is_start && nt = start_nt then
		       succeeded := true (* ... and do not bother performing the completion. *)
		     else
		       for l = 0 to m_items do
			 let s_l, c_l = items.(l) in
			 let t = PJ.lookup_trans_nt nonterm_table s_l nt in
			 if t > 0 then insert_many i ol cs t c_l
		       done
		   done) __s__) 			

	   | PJDN.MComplete_p_trans nts ->
	       let m_nts = Array.length nts - 1 in
	       let curr_pos = current_callset.id in
	                               (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> ( 
		   let is_start = callset.id = 0 in
		   let items = callset.data in
		   let m_items = Array.length items - 1 in
		   for k = 0 to m_nts do
		     let nt = nts.(k) in
		     if is_start && nt = start_nt then
		       succeeded := true (* ... and do not bother performing the completion. *)
		     else
		       for l = 0 to m_items do
			 let s_l, c_l = items.(l) in

			 let t = PJ.lookup_trans_nt nonterm_table s_l nt in
			 if t > 0 then insert_many i ol cs t c_l;

			 let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = PJDN.lookup_trans_pnt p_nonterm_table s_l nt in
			 if t > 0 then begin
			                           (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
			     if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
			       insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
		            )
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
			     if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
			       insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
		            ) __s__) 			
			 end
		       done
		   done)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) ->  
		   let is_start = callset.id = 0 in
		   let items = callset.data in
		   let m_items = Array.length items - 1 in
		   for k = 0 to m_nts do
		     let nt = nts.(k) in
		     if is_start && nt = start_nt then
		       succeeded := true (* ... and do not bother performing the completion. *)
		     else
		       for l = 0 to m_items do
			 let s_l, c_l = items.(l) in

			 let t = PJ.lookup_trans_nt nonterm_table s_l nt in
			 if t > 0 then insert_many i ol cs t c_l;

			 let {PJDN.ctarget = t; carg = arg_act; cbinder = binder} = PJDN.lookup_trans_pnt p_nonterm_table s_l nt in
			 if t > 0 then begin
			                           (match c_l with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset_s_l, sv_s_l, sv_arg_s_l) -> ( 
			     if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
			       insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
		            )
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset_s_l, sv_s_l, sv_arg_s_l) ->  
			     if Sem_val.cmp (arg_act callset.id sv_s_l) sv_arg = 0 then
			       insert_one_ig i ol cs t callset_s_l (binder curr_pos sv_s_l sv) sv_arg_s_l
		            ) __s__) 			
			 end
		       done
		   done) __s__) 			

	   | PJDN.Many_trans trans ->
	       let n = Array.length trans in
	       for j = 0 to n-1 do
		 process_eof_trans start_nt succeeded ol cs socvas_s i term_table nonterm_table p_nonterm_table nplookahead_fn s sv0
		   current_callset ykb trans.(j)
	       done

	   | PJDN.Maybe_nullable_trans2 _ -> () 
	       (* only relevant immediately after a call *)

	   | PJDN.Action_trans (act, target) -> 
               let curr_pos = current_callset.id in
	       let new_s = Socvas.fold 
		 (fun (callset, sv, sv_arg) s -> 
		    Socvas.add (callset, act curr_pos sv, sv_arg) s)		      
		 socvas_s Socvas.empty in
	       insert_many i ol cs target new_s

	   | PJDN.When_trans (p, next, target) -> 
               (let curr_pos = current_callset.id in
	       let new_s = Socvas.fold 
		 (fun (callset, sv, sv_arg) s -> 
		    if p curr_pos sv then Socvas.add (callset, next curr_pos sv, sv_arg) s else s)		      
		 socvas_s Socvas.empty in
	       if not (Socvas.is_empty new_s) then insert_many i ol cs target new_s)

	   (* Only null boxes are okay now that we've reached EOF. *)
	   | PJDN.Box_trans (box, target) ->
	       (                        (match socvas_s with
	 | Socvas.Empty -> ()
	 | Socvas.Singleton (callset, sv, sv_arg) -> (let cp = YkBuf.save ykb in
			   (match box sv current_callset.id ykb with
				Some (0, ret_sv) -> (* returns to current set *)
				  insert_one_ig i ol cs target callset ret_sv sv_arg
			      | Some _ ->  	    if Logging.activated then begin Logging.log Logging.Features.verbose "BUG: Box returning success > 0 at EOF.\n" end 	    
			      | None -> ()
			   );
			   YkBuf.restore ykb cp)
	 | Socvas.Other __s__ -> Socvas.iter_ms (fun (callset, sv, sv_arg) -> let cp = YkBuf.save ykb in
			   (match box sv current_callset.id ykb with
				Some (0, ret_sv) -> (* returns to current set *)
				  insert_one_ig i ol cs target callset ret_sv sv_arg
			      | Some _ ->  	    if Logging.activated then begin Logging.log Logging.Features.verbose "BUG: Box returning success > 0 at EOF.\n" end 	    
			      | None -> ()
			   );
			   YkBuf.restore ykb cp) __s__) 			)


  and _parse is_exact_match 
      {PJDN.start_symb = start_nt; start_state = start_state; 
       term_table = term_table; nonterm_table = nonterm_table; 
       p_nonterm_table = p_nonterm_table;} 
      sv0 (ykb : YkBuf.t) = 

     	    if Logging.activated then begin Logging.Distributions.init ();
      Logging.Distributions.register "CSS";      
      Logging.Distributions.register "CPSS";      
     end 	    ;

    let num_states = Array.length term_table in
    let current_set = ref (WI.make num_states Socvas.empty) in
    let next_set = ref (WI.make num_states Socvas.empty) in

    let pre_cc = Pcs.empty num_states in (* pre-version of current callset. *)
    let start_callset = mk_callset 0 in
    let current_callset = ref start_callset in

    let futuresq = Ordered_queue.init () in
(*     let nplookahead_fn = mk_lookahead term_table nonterm_table p_nonterm_table sv0 in *)
    let nplookahead_fn = mk_lookahead term_table nonterm_table p_nonterm_table sv0 in

    if Logging.activated then begin
      Imp_position.set_position 0
    end;

    let ns = !next_set in
    let cva0 = (start_callset, sv0, sv0) in
    insert_one_nc ns start_state cva0;
    Pcs.add_call_state pre_cc start_state;

    let can_scan = ref (YkBuf.fill2 ykb 1) in

    (* Nullability check. *)
    (match term_table.(start_state) with
       | PJDN.Maybe_nullable_trans2 (nt, p) ->
	   if Util.is_some (p nplookahead_fn ykb sv0) then
	     let t1 = PJ.lookup_trans_nt nonterm_table start_state nt in
	     if t1 > 0 then insert_one_nc ns t1 cva0
       | PJDN.Complete_trans nt -> 
	   let t1 = PJ.lookup_trans_nt nonterm_table start_state nt in
	   if t1 > 0 then insert_one_nc ns t1 cva0;
       | PJDN.MComplete_trans nts -> 
	   for k = 0 to Array.length nts - 1 do
	     let nt = nts.(k) in
	     let t = PJ.lookup_trans_nt nonterm_table start_state nt in
	     if t > 0 then insert_one_nc ns t cva0
	   done
	| PJDN.Many_trans txs -> 
	    for j = 0 to Array.length txs - 1 do
	      match txs.(j) with
		| PJDN.Maybe_nullable_trans2 (nt, p) ->
		    if Util.is_some (p nplookahead_fn ykb sv0) then
		      let t1 = PJ.lookup_trans_nt nonterm_table start_state nt in
		      if t1 > 0 then insert_one_nc ns t1 cva0
		| PJDN.Complete_trans nt -> 
		    let t1 = PJ.lookup_trans_nt nonterm_table start_state nt in
		    if t1 > 0 then insert_one_nc ns t1 cva0
		| PJDN.MComplete_trans nts -> 
		    for k = 0 to Array.length nts - 1 do
		      let nt = nts.(k) in
		      let t = PJ.lookup_trans_nt nonterm_table start_state nt in
		      if t > 0 then insert_one_nc ns t cva0
		    done
		| _ -> ()	      
	    done
	| _ -> ());

    let i = ref 0 in
    let overflow = ref [] in

    let fast_forward current_callset q ns ykb =
      let (k, l) = Ordered_queue.pop q in
      if k <> -1 then begin
	List.iter (fun (s,cva) -> insert_one_nc ns s cva) l;
	ignore (YkBuf.skip ykb (k - !current_callset.id));
	current_callset := mk_callset k;
	YkBuf.fill2 ykb 1
      end else false in

    (** Check for a succesful parse. *)
    let check_done term_table d dcs start_nt count =
                      if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Checking for successful parses.\n" end 		;
      let check_callset (callset, _, _) b = b || callset.id = 0 in
      let do_check start_nt socvas = function
	| PJDN.Complete_trans nt 
	| PJDN.Complete_p_trans nt -> 
	    if nt = start_nt then begin
	                      if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Final state found, start symbol.\n" end 		;
	      Socvas.fold check_callset socvas false
	    end else begin
	                      if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Final state found, not start: %d.\n" nt end 		;
	      false
	    end

	| PJDN.MComplete_trans nts  
	| PJDN.MComplete_p_trans nts ->
	    if Util.int_array_contains start_nt nts then begin
	                      if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Final state found, start symbol.\n" end 		;
	      Socvas.fold check_callset socvas false
	    end else (                if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Final states found, no start.\n" end 		; false)
	| _ -> false in
      let rec iter_do_check start_nt socvas txs n j = 
	if j >= n then false 
	else (do_check start_nt socvas txs.(j) 
	      || iter_do_check start_nt socvas txs n (j + 1)) in
      let rec search_for_succ term_table d dcs start_nt n j  =
	if j >= n then false else begin
	  let s = d.(j) in
	                  if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Checking state %d.\n" s end 		;
	  let is_done = match term_table.(s) with
	    | PJDN.Complete_trans _ | PJDN.Complete_p_trans _ 
	    | PJDN.MComplete_trans _ | PJDN.MComplete_p_trans _ -> 
		do_check start_nt dcs.(j) term_table.(s)
	    | PJDN.Many_trans txs -> iter_do_check start_nt dcs.(j) txs (Array.length txs) 0
	    | PJDN.Box_trans _ | PJDN.When_trans _| PJDN.Action_trans _
	    | PJDN.Call_p_trans _
	    | PJDN.Maybe_nullable_trans2 _ 
	    | PJDN.Call_trans _| PJDN.Det_multi_trans _
	    | PJDN.RegLookahead_trans _ | PJDN.ExtLookahead_trans _ | PJDN.Lookahead_trans _| PJDN.MScan_trans _
	    | PJDN.Scan_trans _ | PJDN.No_trans -> false in
	  is_done || search_for_succ term_table d dcs start_nt n (j + 1)
	end in
      search_for_succ term_table d dcs start_nt count 0 in

    let s_matched = ref false in
    while (                 (if support_FLA then (is_exact_match || not !s_matched) else true) 		 &&
	      if !next_set.WI.count > 0 then !can_scan
	      else fast_forward current_callset futuresq !next_set ykb) do

      (* swap_and_clear. We place this code here,
	 rather than at the end of the loop, with the other 
	 init code, so that if there's a parse error, the 
	 previous earley set will be preserved. 
	 We surround with begin-end to limit scope of t.
      *)
      begin
	let t = !current_set in
	WI.clear t;
	current_set := !next_set;
	next_set := t;
      end;

      (* ensure that only one dereference happens for these datums. Not sure
	 if the compiler would be smart enough to do common subexpression 
	 elimination if we didn't do this aliasing by hand, given that the right
	 hand sides are mutable. *)
      let ccs = !current_callset in
      let cs = !current_set in
      let ns = !next_set in
      let d = cs.WI.dense_s in
      let dcs = cs.WI.dense_sv in
      let xyz = term_table, nonterm_table, p_nonterm_table, sv0, 
	    overflow, cs, ns, pre_cc, ccs, ykb, futuresq, nplookahead_fn in

      (* Process the worklist (which can grow during processing. *) 
      i := 0; 
      while !i < cs.WI.count do
	let rec loop xyz dcs d k =
	  let s = d.(k) in

	  (* Process state s *)
	  (* FINAL VERSION (PERF): inline this call by hand but take care with
	     socvas_s -> dcs.(!i) in inlined version because both dcs and i are mutable
	     so you need to add
	     let socvas_s = dcs.(!i) in some cases rather than simply substituting. 
	  *)
	  process_trans xyz s dcs.(k) k term_table.(s);

	  let k' = k + 1 in
	  if k' < cs.WI.count then 
	    loop xyz dcs d k'
	  else k
	in

	i := loop xyz dcs d !i;

	(* Handle overflow from the worklist. *)
	while !overflow <> [] do
	  let owl = !overflow in
	  overflow := [];
	  let rec loop xyz k term_table = function
	    | [] -> ()
	    | (s, socvas)::xs -> 
		process_trans xyz s socvas k term_table.(s);
		loop xyz k term_table xs in
	  loop xyz !i term_table owl;
	done;

	incr i;
      done;
      
       	    if support_FLA then begin if not is_exact_match && check_done term_table d dcs start_nt cs.WI.count then
	  s_matched := true;
       end 	    ;

      (* cleanup and setup for next round. *)
      ccs.data <- Pcs.convert_current_callset cs pre_cc;
      let pos = ccs.id + 1 in
      current_callset := mk_callset pos;
      YkBuf.advance ykb;
      can_scan := YkBuf.fill2 ykb 1;
      Pcs.reset pre_cc;

      (* Check whether there's any blackbox results to load into the next set. *)
      if Ordered_queue.next futuresq = pos then begin
	let l = snd (Ordered_queue.pop futuresq) in
	List.iter (fun (s,cva) -> insert_one_nc ns s cva) l
      end;

       	    if Logging.activated then begin Imp_position.set_position pos;
       end 	    ;
    done;

    (* PERF: apply the same optimizations used above to the following code. *)

    (* We've either hit a shortest match or we're either at EOF or a failure. *)
    if support_FLA && not is_exact_match && !s_matched then 
      [sv0] (* stands in for boolean true. *)  
    else if !next_set.WI.count > 0 then begin
      (* Compute closure on final set. Ignore scans b/c we're at EOF. *)

      let succeeded = ref false in
      let cs = !next_set in
      let d = cs.WI.dense_s in
      let dcs = cs.WI.dense_sv in

      let proc_eof_item (s, socvas) = 
	process_eof_trans start_nt succeeded overflow cs socvas !i 
	  term_table nonterm_table p_nonterm_table nplookahead_fn
	  s sv0 !current_callset ykb term_table.(s) in

      i := 0;
      while !i < cs.WI.count do
	while !i < cs.WI.count do
	  let s = d.(!i) in

	                  if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Processing state %d.\n" s end 		;

	  (* Process state s *)
	  process_eof_trans start_nt succeeded overflow cs dcs.(!i) !i term_table nonterm_table p_nonterm_table nplookahead_fn
	    s sv0 !current_callset ykb term_table.(s);
	  incr i;
	done;

	decr i;
	(* Handle overflow from the worklist. *)
	while !overflow <> [] do
	  let owl = !overflow in
	  overflow := [];
	  List.iter proc_eof_item owl;
	done;
	
	incr i;
      done;


      (* Check for succesful parses. *)
                      if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Checking for successful parses.\n" end 		;
      let successes = ref [] in
      let do_check socvas = function
	| PJDN.Complete_trans nt 
	| PJDN.Complete_p_trans nt -> 
	    if nt = start_nt then begin
	                      if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Final state found, start symbol.\n" end 		;
	      successes :=
		Socvas.fold (fun (callset, sv, _) a ->
			       if callset.id <> 0 then a else sv::a) 
		  socvas
		  !successes
	    end else                 if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Final state found, not start: %d.\n" nt end 		

	| PJDN.MComplete_trans nts  
	| PJDN.MComplete_p_trans nts ->
	    if Util.int_array_contains start_nt nts then begin
	                      if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Final state found, start symbol.\n" end 		;
	      successes :=
		Socvas.fold (fun (callset, sv, _) a ->
			       if callset.id <> 0 then a else sv::a) 
		  socvas
		  !successes
	    end else                 if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Final states found, no start.\n" end 		 
	| _ -> () in
      for j = 0 to cs.WI.count - 1 do
	let s = d.(j) in
	                if Logging.activated then begin 
       Logging.log Logging.Features.eof_ne "Checking state %d.\n" s end 		;
	match term_table.(s) with
	  | PJDN.Complete_trans _ | PJDN.Complete_p_trans _ 
	  | PJDN.MComplete_trans _ | PJDN.MComplete_p_trans _ -> 
	      do_check dcs.(j) term_table.(s)
	  | PJDN. Many_trans txs -> Array.iter (do_check dcs.(j)) txs
	  | PJDN.Box_trans _ | PJDN.When_trans _ | PJDN.Action_trans _
	  | PJDN.Call_p_trans _
	  | PJDN.Maybe_nullable_trans2 _ 
	  | PJDN.Call_trans _| PJDN.Det_multi_trans _
	  | PJDN.RegLookahead_trans _ | PJDN.ExtLookahead_trans _ 
	  | PJDN.Lookahead_trans _| PJDN.MScan_trans _
	  | PJDN.Scan_trans _| PJDN.No_trans -> ()
      done;

       	    if Logging.activated then begin Logging.Distributions.report ();
       end 	    ;

      !successes
    end
    else begin
      (* There was no succesful scan of the last byte, so we backtrack
	 by one to ensure proper error reporting. *)
      YkBuf.step_back ykb;      
       	    if Logging.activated then begin Logging.Distributions.report ();
       end 	    ;
      []
    end

  let parse data sv0 ykb = _parse true data sv0 ykb

end
