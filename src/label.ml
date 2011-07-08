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

(* The labeling transform *)

open Yak
open Gul
open Variables

(* Label convention: 0 means unlabeled *)
(* Assumes that the input grammar has been marked relevant,
   and all pre/post labels start out at 0 *)

let start_labels_at = 1000

let transform gr =
  let current = ref start_labels_at in
  let rec loop r =
    if not(r.a.early_relevant || r.a.late_relevant) then () else
    let prelabel() = r.a.pre <- postincr current in
    let postlabel() = r.a.post <- postincr current in
    match r.r with
    | When _
    | Symb _
    | DBranch _
      -> prelabel(); postlabel()
    | Lookahead(_,r2)
    | Star(_,r2) ->
        prelabel(); postlabel();
        loop r2
    | Box _
    | Position _
    | Action _
    | Delay _ ->
        prelabel()
    | Seq(r2,early,late,r3) ->
        prelabel();
        loop r2;
        loop r3
    | Assign(r2,early,late) ->
        prelabel();
        loop r2
    | Alt(r2,r3) ->
        loop r2;
        loop r3
    | Opt r2 ->
        loop r2
    (* cases below should have been desugared *)
    | Rcount _    -> Util.impossible "Label.transform.loop.Rcount"
    | Hash _      -> Util.impossible "Label.transform.loop.Hash"
    | Minus _     -> Util.impossible "Label.transform.loop.Minus"
    (* cases below should not be relevant *)
    | Lit _       -> Util.impossible "Label.transform.loop.Lit"
    | CharRange _ -> Util.impossible "Label.transform.loop.CharRange"
    | Prose _     -> Util.impossible "Label.transform.loop.Prose"
  in
  List.iter
    (function RuleDef(n,r,a) -> loop r | _ -> ())
    gr.ds
