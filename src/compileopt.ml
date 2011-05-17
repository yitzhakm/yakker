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

(* Compile-time options for Yakker *)
let inline_cs = ref false
let inline_regular = ref false
let unroll_star_n = ref 3
let lookahead = ref false
let case_sensitive = ref true
let coalesce = ref true
let memoize_history = ref true
let check_labels = ref false

let skip_opt = ref true
  (** Perform the label-skipping optimization for late actions. *)

let skip_opt_coroutine = ref false
  (** Perform the label-skipping optimization early actions. *)

let late_only_dbranch = ref true
  (** Treat dbranch as a late-only construct. *)

let use_dbranch = ref false

let use_fsm = ref false
  (** Use FSM toolkit to build transducer; use FST otherwise. *)

(* testing-related *)
let unit_history = ref false
let repress_replay = ref false

let use_coroutines = ref true
