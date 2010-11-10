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

(* Desugar a few constructs:
   @Position
   lookahead of non-symbols
*)

open Gul

let desugar g =
  let define r =
    let nt1 = fresh_nonterminal g in
    g.ds <- (RuleDef(nt1, (dupRule r), mkAttr()))::g.ds;
    Symb(nt1,None,[],None)
  in
  let rec loop r = match r.r with
    | Lookahead(b, r2) ->
        loop r2;
	(* If it is a symbol or a character set, we leave it in
	place. Otherwise, we lift it out. *)
	(match r2 with
	   | {r=Symb _}
	   | {a={css=Some(_)}} -> ()
	   | _ ->
               r2.r <- define r2)
    | Position false ->
        let x = Util.fresh() in
        r.r <- (mkSEQ2(mkPOSITION true,Some x,None,mkDELAY(x,None))).r
    | Symb _ | Position _ | Prose _
    | When _ | Action _ | Box _ | Delay _
    | CharRange _ | Minus _ | Lit _ -> ()
    | Seq(r2,_,_,r3)
    | Alt(r2,r3) ->
	loop r2; loop r3
    | Opt(r2)
    | Assign(r2,_,_)
    | Rcount(_,r2)
    | Star(_,r2)
    | Hash(_,r2) ->
	loop r2
  in
  List.iter (function RuleDef(_,r,_) -> loop r | _ -> ()) g.ds