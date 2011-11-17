
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

open Yak

type command =
| Attributes_cmd
| Close_under_core_cmd
| Compile_cmd
| Copyrule_cmd
| Coroutine_cmd
| Desugar_cmd
| Desugar_gil_cmd
| Dearrow_cmd
| Dependency_graph_cmd
| Dot_cmd
| Exec_cmd
| Extract_cmd
| Fuse_cmd
| Generators_analysis_cmd
| Hash_cmd
| Infer_ty_cmd
| Info_cmd
| Inline_regular_cmd
| Inline_nullable_cmd
| Lexer_cmd
| Lift_cmd
| Lookahead_analysis_cmd
| Lr1_lookahead_cmd
| Minus_cmd
| Pads_lift_cmd
| Parse_cmd
| Precedence_analysis_cmd
| Print_gil_cmd
| Print_gul_cmd
| Print_relevance_cmd
| Replay_cmd
| Rfc_cmd
| Sort_cmd
| Strip_late_actions_cmd
| Subset_cmd
| Translate_dypgen_cmd
| Translate_dypgen_scannerless_cmd
| Tx_prec_cmd
| Unroll_star_cmd
| Wrap_cmd

let cmd = ref Print_gul_cmd
let after = ref None
let files = ref []
let roots = ref []
let exec_l = ref []
let rfc_num = ref 0
let only = ref false

type backend =
  | Fun_BE   (** Functional backend (parser combinators).*)
  | Wadler_BE   (** Haskell functional backend (parser combinators).*)
  | Peg_BE of bool (** PEG backend. argument indicates whether
                       to use more liberal (PADS-style) star. *)
  | Trans_BE (** Transducer backend. *)

let backend = ref Trans_BE

module O = Compileopt

type hv = int
;;

module Yk_Hashed = struct
  type t = int * hv * int
  let compare i j = compare i j
  let hash i = Hashtbl.hash i
  let memoize = true
end
module Yk_History = Yak.History.Make(Yk_Hashed)

let rec
 _r_cmd_line_args(_n,_p,ykinput) = (let c = _r_command(_n,_p,ykinput) in (); (while (match _n() with (2000) -> true | _ (*2001*) -> false) do
_r_args(_n,_p,ykinput)done)
; ();  cmd := c )
and
 _r_phases(_n,_p,ykinput) = (match _n() with
 | (2002) -> ((); ();  Attributes_cmd )
 | (2003) -> ((); ();  Close_under_core_cmd )
 | (2004) -> ((); ();  Copyrule_cmd )
 | (2005) -> ((); ();  Desugar_cmd )
 | (2006) -> ((); ();  Desugar_gil_cmd )
 | (2007) -> ((); ();  Hash_cmd )
 | (2008) -> ((); ();  Dearrow_cmd )
 | (2009) -> ((); ();  Infer_ty_cmd )
 | (2010) -> ((); ();  Inline_regular_cmd )
 | (2011) -> ((); ();  Inline_nullable_cmd )
 | (2012) -> ((); ();  Lexer_cmd )
 | (2013) -> ((); ();  Lift_cmd )
 | (2014) -> ((); ();  Minus_cmd )
 | (2015) -> ((); ();  Tx_prec_cmd )
 | (2016) -> ((); ();  Subset_cmd )
 | (2017) -> ((); ();  Unroll_star_cmd )
 | (2018) -> ((); ();  Wrap_cmd )
 | (2019) -> ((); ();  Replay_cmd )
 | _ -> raise Exit)
and
 _r_command(_n,_p,ykinput) = (match _n() with
 | (2020) -> ((let p = _r_phases(_n,_p,ykinput) in  (match p with
                                               Inline_regular_cmd -> O.inline_regular := true
                                             | Unroll_star_cmd -> if !O.unroll_star_n<1 then O.unroll_star_n := 1
                                             | _ -> ());
                                            p ))
 | (2021) -> ((); ();  Compile_cmd )
 | (2022) -> ((); ();  Coroutine_cmd )
 | (2023) -> ((); ();  Dependency_graph_cmd )
 | (2024) -> ((); ();  Dot_cmd )
 | (2025) -> ((); (); (let _x4 = _p() in (); (let _x3 = _p() in (let f = Yak.YkBuf.get_string _x4 _x3 ykinput in (let l = (let _x8 = (let rec _x19 _x8 =
(match _n() with (2029) -> _x8 | _ (*2028*) ->
 _x19((let _x7 = (); (let _x6 = _p() in (); (let _x5 = _p() in (let x = Yak.YkBuf.get_string _x6 _x5 ykinput in x))) in _x7::_x8)))
in _x19(Yak.Util.nil)) in (List.rev _x8)) in ();  files := f::!files; exec_l := l; Exec_cmd )))))
 | (2032) -> ((); ();  Extract_cmd )
 | (2033) -> ((); ();  O.coalesce := true; Fuse_cmd )
 | (2034) -> ((); ();  Generators_analysis_cmd )
 | (2035) -> ((); ();  Info_cmd )
 | (2036) -> ((); ();  Lookahead_analysis_cmd )
 | (2037) -> ((); ();  Lr1_lookahead_cmd )
 | (2038) -> ((); ();  Parse_cmd )
 | (2039) -> ((); ();  Precedence_analysis_cmd )
 | (2040) -> ((); ();  Print_gul_cmd )
 | (2041) -> ((); ();  Print_gil_cmd )
 | (2042) -> ((); ();  Print_relevance_cmd )
 | (2043) -> ((); (let _x10 = _p() in (); (let _x9 = _p() in (let n = Yak.YkBuf.get_string _x10 _x9 ykinput in ();  try rfc_num := int_of_string n; Rfc_cmd with _ -> failwith "Invalid RFC number" ))))
 | (2046) -> ((); ();  Sort_cmd )
 | (2047) -> ((); ();  Pads_lift_cmd )
 | (2048) -> ((); ();  Strip_late_actions_cmd )
 | (2049) -> ((); ();  Translate_dypgen_cmd )
 | (2050) -> ((); ();  Translate_dypgen_scannerless_cmd )
 | _ -> raise Exit)
and
 _r_args(_n,_p,ykinput) = (match _n() with
 | (2051) -> ((); (); (let p = _r_phases(_n,_p,ykinput) in  after := Some p ; ()))
 | (2052) -> ((); ();  O.use_wrap_and_attr := false;      
                                            O.use_coroutines    := false ; ())
 | (2053) -> ((); ();  O.use_coroutines := false ; ())
 | (2054) -> ((); (); (let b = (match _n() with
 | (2055) -> ((); Fun_BE)
 | (2056) -> ((); Trans_BE)
 | (2057) -> ((); Wadler_BE)
 | (2058) -> ((); Peg_BE false)
 | (2059) -> ((); Peg_BE true)
 | _ -> raise Exit) in ();  backend := b ; ()))
 | (2060) -> ((); ();  O.case_sensitive := false ; ())
 | (2061) -> ((); ();  O.check_labels := true ; ())
 | (2062) -> ((); (); (let _x12 = _p() in (); (let _x11 = _p() in (let n = Yak.YkBuf.get_string _x12 _x11 ykinput in ();  Variables.counter := (int_of_string n) ; ()))))
 | (2065) -> ((); ();  O.inline_cs := true ; ())
 | (2066) -> ((); ();  O.inline_regular := true ; ())
 | (2067) -> ((); ();  O.lookahead := true ; ())
 | (2068) -> ((); ();  O.memoize_history := true ; ())
 | (2069) -> ((); ();  O.coalesce := false ; ())
 | (2070) -> ((); ();  O.collapse_calls := false ; ())
 | (2071) -> ((); ();  O.memoize_history := false ; ())
 | (2072) -> ((); ();  O.gen_nullpreds := false ; ())
 | (2073) -> ((); ();  O.gen_optimize_pam := false ; ())
 | (2074) -> ((); ();  O.repress_replay := true ; ())
 | (2075) -> ((); ();  O.skip_opt := false ; ())
 | (2076) -> ((); ();  only := true ; ())
 | (2077) -> ((); ();  O.postfix_history := false ; ())
 | (2078) -> ((); (); (let _x14 = _p() in (); (let _x13 = _p() in (let x = Yak.YkBuf.get_string _x14 _x13 ykinput in ();  roots := x::!roots ; ()))))
 | (2081) -> ((); ();  O.unit_history := true ; ())
 | (2082) -> ((); (); (let _x16 = _p() in (); (let _x15 = _p() in (let n = Yak.YkBuf.get_string _x16 _x15 ykinput in ();  O.unroll_star_n := (int_of_string n) ; ()))))
 | (2085) -> ((); ();  O.earley_ds := O.Flat_eds ; ())
 | (2086) -> ((); ();  O.earley_ds := O.Hier_eds ; ())
 | (2087) -> ((); ();  O.earley_ds := O.Sparse_eds ; ())
 | (2088) -> ((); ();  O.use_fsm := true ; ())
 | (2089) -> ((); ();  O.use_fsm := false ; ())
 | (2090) -> ((); ();  Yak.Logging.add_features Yak.Logging.Features.verbose ; ())
 | (2091) -> ((let _x18 = _p() in (); (let _x17 = _p() in (let f = Yak.YkBuf.get_string _x18 _x17 ykinput in ();  files := f::!files ; ()))))
 | _ -> raise Exit)
class ['a] rvs (labels: 'a History.enum) =
let s = ref [] in
let push x = s := x::!s in
let push_pos p = s := ( p)::!s in
let _n() = (let (_,x,_) = labels#next() in x) in
let _p() = (let (_,_,p) = labels#next() in p) in
let rec _rv_cmd_line_args() = ();();push((2001)); while (match _n() with (2000) -> true | _ (*2001*)-> false) do
 _rv_args(); push((2000))
done
;();_rv_command()
and _rv_phases() = (match _n() with
 | (2002) -> (();();(); push((2002)))
 | (2003) -> (();();(); push((2003)))
 | (2004) -> (();();(); push((2004)))
 | (2005) -> (();();(); push((2005)))
 | (2006) -> (();();(); push((2006)))
 | (2007) -> (();();(); push((2007)))
 | (2008) -> (();();(); push((2008)))
 | (2009) -> (();();(); push((2009)))
 | (2010) -> (();();(); push((2010)))
 | (2011) -> (();();(); push((2011)))
 | (2012) -> (();();(); push((2012)))
 | (2013) -> (();();(); push((2013)))
 | (2014) -> (();();(); push((2014)))
 | (2015) -> (();();(); push((2015)))
 | (2016) -> (();();(); push((2016)))
 | (2017) -> (();();(); push((2017)))
 | (2018) -> (();();(); push((2018)))
 | (2019) -> (();();(); push((2019)))
 | _ -> raise Exit)
and _rv_command() = (match _n() with
 | (2020) -> (();_rv_phases(); push((2020)))
 | (2021) -> (();();(); push((2021)))
 | (2022) -> (();();(); push((2022)))
 | (2023) -> (();();(); push((2023)))
 | (2024) -> (();();(); push((2024)))
 | (2025) -> (();();();push((2029)); while (match _n() with (2028) -> true | _ (*2029*)-> false) do
 ();();();push_pos(_p());();push_pos(_p());(); push((2028))
done
;();push_pos(_p());();push_pos(_p());();(); push((2025)))
 | (2032) -> (();();(); push((2032)))
 | (2033) -> (();();(); push((2033)))
 | (2034) -> (();();(); push((2034)))
 | (2035) -> (();();(); push((2035)))
 | (2036) -> (();();(); push((2036)))
 | (2037) -> (();();(); push((2037)))
 | (2038) -> (();();(); push((2038)))
 | (2039) -> (();();(); push((2039)))
 | (2040) -> (();();(); push((2040)))
 | (2041) -> (();();(); push((2041)))
 | (2042) -> (();();(); push((2042)))
 | (2043) -> (();();();push_pos(_p());();push_pos(_p());(); push((2043)))
 | (2046) -> (();();(); push((2046)))
 | (2047) -> (();();(); push((2047)))
 | (2048) -> (();();(); push((2048)))
 | (2049) -> (();();(); push((2049)))
 | (2050) -> (();();(); push((2050)))
 | _ -> raise Exit)
and _rv_args() = (match _n() with
 | (2051) -> (();();_rv_phases();();(); push((2051)))
 | (2052) -> (();();();(); push((2052)))
 | (2053) -> (();();();(); push((2053)))
 | (2054) -> (();();();(match _n() with
 | (2055) -> (();(); push((2055)))
 | (2056) -> (();(); push((2056)))
 | (2057) -> (();(); push((2057)))
 | (2058) -> (();(); push((2058)))
 | (2059) -> (();(); push((2059)))
 | _ -> raise Exit);();(); push((2054)))
 | (2060) -> (();();();(); push((2060)))
 | (2061) -> (();();();(); push((2061)))
 | (2062) -> (();();();();push_pos(_p());();push_pos(_p());();(); push((2062)))
 | (2065) -> (();();();(); push((2065)))
 | (2066) -> (();();();(); push((2066)))
 | (2067) -> (();();();(); push((2067)))
 | (2068) -> (();();();(); push((2068)))
 | (2069) -> (();();();(); push((2069)))
 | (2070) -> (();();();(); push((2070)))
 | (2071) -> (();();();(); push((2071)))
 | (2072) -> (();();();(); push((2072)))
 | (2073) -> (();();();(); push((2073)))
 | (2074) -> (();();();(); push((2074)))
 | (2075) -> (();();();(); push((2075)))
 | (2076) -> (();();();(); push((2076)))
 | (2077) -> (();();();(); push((2077)))
 | (2078) -> (();();();();push_pos(_p());();push_pos(_p());();(); push((2078)))
 | (2081) -> (();();();(); push((2081)))
 | (2082) -> (();();();();push_pos(_p());();push_pos(_p());();(); push((2082)))
 | (2085) -> (();();();(); push((2085)))
 | (2086) -> (();();();(); push((2086)))
 | (2087) -> (();();();(); push((2087)))
 | (2088) -> (();();();(); push((2088)))
 | (2089) -> (();();();(); push((2089)))
 | (2090) -> (();();();(); push((2090)))
 | (2091) -> (();();();();push_pos(_p());();push_pos(_p()); push((2091)))
 | _ -> raise Exit)
in
object (self)
method next() = (match !s with hd::tl -> (s := tl; hd) | _ -> raise Not_found)
initializer _rv_cmd_line_args()
end

let _replay_cmd_line_args ykinput h =
  let _o = new rvs (h#right_to_left) in
  let _n() = _o#next() in
  let _p() = _o#next() in
  _r_cmd_line_args(_n,_p,ykinput)
(* History constructors *)
let _e p h = h#empty p
let _p lbl hv p = (fun h->h#push p (lbl, hv, p))
let _m lbl p = (fun h1 h2-> h1#merge p (lbl,  lbl, p) h2)

(*LATE PROLOGUE*)
type _pos = int (* input positions *)
let hv_compare = Yk_History.compare
type sv = (int * hv * _pos, Yak.History.label) Yak.History.history
let sv0 = Yk_History.new_history()
let sv_compare = hv_compare
let sv_hash = Yk_History.hash
let sv_eq x y = sv_compare x y = 0
let key_eq (i,v1) (j,v2) = i = j &&  sv_eq v1 v2
let key_hash (i,v) = i lxor (sv_hash v)

(** Hashtable for top-down parsing. *)
module TDHashtable = Hashtbl.Make(struct type t = int * sv let equal = key_eq let hash = key_hash end)

let __default_call _ _ = sv0;;
let __cc_call _ x = x;;
let __default_ret _ v1 _ = v1;;
let num_symbols = 12

let symbol_table = function
  | 268 -> "cmd-line-args"
  | 273 -> "command"
  | 269 -> "o"
  | 265 -> "CHAR"
  | 271 -> "file"
  | 264 -> "error"
  | 266 -> "DIGIT"
  | 274 -> "args"
  | 272 -> "phases"
  | 275 -> "eof"
  | 270 -> "arg"
  | 267 -> "OCTET"
  | x -> if x < 256 then Yak.Pam_internal.default_symbol_table x else "?unknown?"

let get_symb_action = function
  | "cmd-line-args" -> 268
  | "command" -> 273
  | "o" -> 269
  | "CHAR" -> 265
  | "file" -> 271
  | "error" -> 264
  | "DIGIT" -> 266
  | "args" -> 274
  | "phases" -> 272
  | "eof" -> 275
  | "arg" -> 270
  | "OCTET" -> 267
  | _ -> raise Not_found

let get_symb_start = function
  | 275 -> 11
  | 274 -> 10
  | 273 -> 9
  | 272 -> 8
  | 271 -> 7
  | 270 -> 6
  | 269 -> 5
  | 268 -> 4
  | 267 -> 3
  | 266 -> 2
  | 265 -> 1
  | _ -> raise Not_found

module Pred3 = Yak.Pam_internal.Pred3
let __a21 = (_p 1028 ((2045)));;
let __a86 = (_p 1024 ((2048)));;
let __a28 = (_p 1051 ((2021)));;
let __a15 = (_p 1026 ((2046)));;
let __a83 = (_p 1063 ((2082)));;
let __a72 = (_p 1095 ((2052)));;
let __a74 = (_p 1070 ((2077)));;
let __a71 = (_p 1030 ((2042)));;
let __a58 = (_p 1072 ((2075)));;
let __a20 = (_p 1032 ((2040)));;
let __a16 = (_p 1005 ((2018)));;
let __a82 = (_p 1074 ((2073)));;
let __a27 = (_p 1007 ((2016)));;
let __a90 = (_p 1076 ((2071)));;
let __a18 = (_p 1009 ((2014)));;
let __a4 = (_p 1055 ((2093)));;
let __a89 = (_p 1033 ((2039)));;
let __a17 = (_p 1011 ((2012)));;
let __a68 = (_p 1013 ((2010)));;
let __a60 = (_p 1035 ((2037)));;
let __a13 = (_p 1037 ((2035)));;
let __a81 = (_p 1079 ((2068)));;
let __a7 = (_p 1057 ((2090)));;
let __a11 = (_p 1039 ((2033)));;
let __a35 = (_p 1041 ((2025)));;
let __a36 = (_p 1085 ((2063)));;
let __a73 = (_p 1081 ((2066)));;
let __a50 = (_p 1014 ((2009)));;
let __a12 = (_p 1016 ((2007)));;
let __a29 = (_p 1018 ((2005)));;
let __a38 = (_p 1058 ((2089)));;
let __a84 = (_p 1087 ((2060)));;
let __a75 = (_p 1064 ((2084)));;
let __a78 = (_p 1020 ((2003)));;
let __a76 = (_p 1060 ((2087)));;
let __a92 = (_p 1022 ((2050)));;
let __a64 = (_p 1062 ((2085)));;
let __a32 = (_p 1068 ((2080)));;
let __a87 = (_p 1090 ((2058)));;
let __a2 = (_p 1002 ((2001)));;
let __a63 = (_p 1066 ((2081)));;
let __a56 = (_p 1083 ((2062)));;
let __a45 = (_p 1092 ((2056)));;
let __a8 = (_p 1048 ((2024)));;
let __a80 = (_p 1023 ((2049)));;
let __a5 = (_p 1029 ((2044)));;
let __a23 = (_p 1069 ((2079)));;
let __a39 = (_p 1050 ((2022)));;
let __a77 = (_p 1025 ((2047)));;
let __a3 = (_p 1052 ((2020)));;
let __a62 = (_p 1094 ((2053)));;
let __a31 = (_p 1096 ((2051)));;
let __a25 = (_p 1004 ((2019)));;
let __a6 = (_p 1000 ((2000)));;
let __a40 = (_p 1031 ((2041)));;
let __a22 = (_p 1071 ((2076)));;
let __a51 = (_p 1006 ((2017)));;
let __a48 = (_p 1073 ((2074)));;
let __a91 = (_p 1075 ((2072)));;
let __a44 = (_p 1008 ((2015)));;
let __a88 = (_p 1077 ((2070)));;
let __a26 = (_p 1027 ((2043)));;
let __a41 = (_p 1067 ((2078)));;
let __a1 = (_p 1056 ((2092)));;
let __a14 = (_p 1010 ((2013)));;
let __a70 = (_p 1012 ((2011)));;
let __a24 = (fun _x0_ _x1_ -> (((_p 1045 ((2029))) _x0_) (((_p 1046 ((2027))) _x0_) _x1_)));;
let __a34 = (_p 1044 ((2030)));;
let __a19 = (_p 1034 ((2038)));;
let __a85 = (_p 1036 ((2036)));;
let __a67 = (_p 1038 ((2034)));;
let __a57 = (_p 1078 ((2069)));;
let __a55 = (_p 1088 ((2054)));;
let __a54 = (_p 1084 ((2064)));;
let __a47 = (_p 1080 ((2067)));;
let __a30 = (_p 1040 ((2032)));;
let __a66 = (_p 1015 ((2008)));;
let __a46 = (_p 1082 ((2065)));;
let __g0 = (_e);;
let __a49 = (_p 1017 ((2006)));;
let __a61 = (_p 1086 ((2061)));;
let __a9 = (_p 1054 ((2091)));;
let __a37 = (_p 1059 ((2088)));;
let __a33 = (_p 1019 ((2004)));;
let __a59 = (_p 1065 ((2083)));;
let __a10 = (_p 1047 ((2026)));;
let __a65 = (_p 1061 ((2086)));;
let __a53 = (_p 1089 ((2059)));;
let __a43 = (fun _x0_ _x1_ -> (((_p 1042 ((2028))) _x0_) (((_p 1043 ((2031))) _x0_) _x1_)));;
let __a42 = (_p 1021 ((2002)));;
let __a69 = (_p 1091 ((2057)));;
let __a79 = (_p 1049 ((2023)));;
let __a52 = (_p 1093 ((2055)));;
let __binder0 = __default_ret;;
let __binder1 = (_m 1003);;
let __binder2 = (_m 1053);;
let __binder3 = (_m 1001);;
let __binder4 = (_m 1097);;
open Yak.Pam_internal
let program = [
(383, [EatInstr(100,431)]);
(0, [ASimpleCont2Instr(275,__binder0,11);ASimpleCont2Instr(274,__binder0,10);ASimpleCont2Instr(273,__binder0,9);ASimpleCont2Instr(272,__binder0,8);ASimpleCont2Instr(271,__binder0,7);ASimpleCont2Instr(270,__binder0,6);ASimpleCont2Instr(269,__binder0,5);ASimpleCont2Instr(268,__binder0,4);ASimpleCont2Instr(267,__binder0,3);ASimpleCont2Instr(266,__binder0,2);ASimpleCont2Instr(265,__binder0,1)]);
(384, [EatInstr(97,432)]);
(1, [EatInstr(127,12);EatInstr(126,12);EatInstr(125,12);EatInstr(124,12);EatInstr(123,12);EatInstr(122,12);EatInstr(121,12);EatInstr(120,12);EatInstr(119,12);EatInstr(118,12);EatInstr(117,12);EatInstr(116,12);EatInstr(115,12);EatInstr(114,12);EatInstr(113,12);EatInstr(112,12);EatInstr(111,12);EatInstr(110,12);EatInstr(109,12);EatInstr(108,12);EatInstr(107,12);EatInstr(106,12);EatInstr(105,12);EatInstr(104,12);EatInstr(103,12);EatInstr(102,12);EatInstr(101,12);EatInstr(100,12);EatInstr(99,12);EatInstr(98,12);EatInstr(97,12);EatInstr(96,12);EatInstr(95,12);EatInstr(94,12);EatInstr(93,12);EatInstr(92,12);EatInstr(91,12);EatInstr(90,12);EatInstr(89,12);EatInstr(88,12);EatInstr(87,12);EatInstr(86,12);EatInstr(85,12);EatInstr(84,12);EatInstr(83,12);EatInstr(82,12);EatInstr(81,12);EatInstr(80,12);EatInstr(79,12);EatInstr(78,12);EatInstr(77,12);EatInstr(76,12);EatInstr(75,12);EatInstr(74,12);EatInstr(73,12);EatInstr(72,12);EatInstr(71,12);EatInstr(70,12);EatInstr(69,12);EatInstr(68,12);EatInstr(67,12);EatInstr(66,12);EatInstr(65,12);EatInstr(64,12);EatInstr(63,12);EatInstr(62,12);EatInstr(61,12);EatInstr(60,12);EatInstr(59,12);EatInstr(58,12);EatInstr(57,12);EatInstr(56,12);EatInstr(55,12);EatInstr(54,12);EatInstr(53,12);EatInstr(52,12);EatInstr(51,12);EatInstr(50,12);EatInstr(49,12);EatInstr(48,12);EatInstr(47,12);EatInstr(46,12);EatInstr(45,12);EatInstr(44,12);EatInstr(43,12);EatInstr(42,12);EatInstr(41,12);EatInstr(40,12);EatInstr(39,12);EatInstr(38,12);EatInstr(37,12);EatInstr(36,12);EatInstr(35,12);EatInstr(34,12);EatInstr(33,12);EatInstr(32,12);EatInstr(31,12);EatInstr(30,12);EatInstr(29,12);EatInstr(28,12);EatInstr(27,12);EatInstr(26,12);EatInstr(25,12);EatInstr(24,12);EatInstr(23,12);EatInstr(22,12);EatInstr(21,12);EatInstr(20,12);EatInstr(19,12);EatInstr(18,12);EatInstr(17,12);EatInstr(16,12);EatInstr(15,12);EatInstr(14,12);EatInstr(13,12);EatInstr(12,12);EatInstr(11,12);EatInstr(10,12);EatInstr(9,12);EatInstr(8,12);EatInstr(7,12);EatInstr(6,12);EatInstr(5,12);EatInstr(4,12);EatInstr(3,12);EatInstr(2,12);EatInstr(1,12)]);
(385, [EatInstr(99,433)]);
(2, [EatInstr(57,13);EatInstr(56,13);EatInstr(55,13);EatInstr(54,13);EatInstr(53,13);EatInstr(52,13);EatInstr(51,13);EatInstr(50,13);EatInstr(49,13);EatInstr(48,13)]);
(386, [EatInstr(108,434)]);
(3, [EatInstr(255,14);EatInstr(254,14);EatInstr(253,14);EatInstr(252,14);EatInstr(251,14);EatInstr(250,14);EatInstr(249,14);EatInstr(248,14);EatInstr(247,14);EatInstr(246,14);EatInstr(245,14);EatInstr(244,14);EatInstr(243,14);EatInstr(242,14);EatInstr(241,14);EatInstr(240,14);EatInstr(239,14);EatInstr(238,14);EatInstr(237,14);EatInstr(236,14);EatInstr(235,14);EatInstr(234,14);EatInstr(233,14);EatInstr(232,14);EatInstr(231,14);EatInstr(230,14);EatInstr(229,14);EatInstr(228,14);EatInstr(227,14);EatInstr(226,14);EatInstr(225,14);EatInstr(224,14);EatInstr(223,14);EatInstr(222,14);EatInstr(221,14);EatInstr(220,14);EatInstr(219,14);EatInstr(218,14);EatInstr(217,14);EatInstr(216,14);EatInstr(215,14);EatInstr(214,14);EatInstr(213,14);EatInstr(212,14);EatInstr(211,14);EatInstr(210,14);EatInstr(209,14);EatInstr(208,14);EatInstr(207,14);EatInstr(206,14);EatInstr(205,14);EatInstr(204,14);EatInstr(203,14);EatInstr(202,14);EatInstr(201,14);EatInstr(200,14);EatInstr(199,14);EatInstr(198,14);EatInstr(197,14);EatInstr(196,14);EatInstr(195,14);EatInstr(194,14);EatInstr(193,14);EatInstr(192,14);EatInstr(191,14);EatInstr(190,14);EatInstr(189,14);EatInstr(188,14);EatInstr(187,14);EatInstr(186,14);EatInstr(185,14);EatInstr(184,14);EatInstr(183,14);EatInstr(182,14);EatInstr(181,14);EatInstr(180,14);EatInstr(179,14);EatInstr(178,14);EatInstr(177,14);EatInstr(176,14);EatInstr(175,14);EatInstr(174,14);EatInstr(173,14);EatInstr(172,14);EatInstr(171,14);EatInstr(170,14);EatInstr(169,14);EatInstr(168,14);EatInstr(167,14);EatInstr(166,14);EatInstr(165,14);EatInstr(164,14);EatInstr(163,14);EatInstr(162,14);EatInstr(161,14);EatInstr(160,14);EatInstr(159,14);EatInstr(158,14);EatInstr(157,14);EatInstr(156,14);EatInstr(155,14);EatInstr(154,14);EatInstr(153,14);EatInstr(152,14);EatInstr(151,14);EatInstr(150,14);EatInstr(149,14);EatInstr(148,14);EatInstr(147,14);EatInstr(146,14);EatInstr(145,14);EatInstr(144,14);EatInstr(143,14);EatInstr(142,14);EatInstr(141,14);EatInstr(140,14);EatInstr(139,14);EatInstr(138,14);EatInstr(137,14);EatInstr(136,14);EatInstr(135,14);EatInstr(134,14);EatInstr(133,14);EatInstr(132,14);EatInstr(131,14);EatInstr(130,14);EatInstr(129,14);EatInstr(128,14);EatInstr(0,14);EatInstr(127,14);EatInstr(126,14);EatInstr(125,14);EatInstr(124,14);EatInstr(123,14);EatInstr(122,14);EatInstr(121,14);EatInstr(120,14);EatInstr(119,14);EatInstr(118,14);EatInstr(117,14);EatInstr(116,14);EatInstr(115,14);EatInstr(114,14);EatInstr(113,14);EatInstr(112,14);EatInstr(111,14);EatInstr(110,14);EatInstr(109,14);EatInstr(108,14);EatInstr(107,14);EatInstr(106,14);EatInstr(105,14);EatInstr(104,14);EatInstr(103,14);EatInstr(102,14);EatInstr(101,14);EatInstr(100,14);EatInstr(99,14);EatInstr(98,14);EatInstr(97,14);EatInstr(96,14);EatInstr(95,14);EatInstr(94,14);EatInstr(93,14);EatInstr(92,14);EatInstr(91,14);EatInstr(90,14);EatInstr(89,14);EatInstr(88,14);EatInstr(87,14);EatInstr(86,14);EatInstr(85,14);EatInstr(84,14);EatInstr(83,14);EatInstr(82,14);EatInstr(81,14);EatInstr(80,14);EatInstr(79,14);EatInstr(78,14);EatInstr(77,14);EatInstr(76,14);EatInstr(75,14);EatInstr(74,14);EatInstr(73,14);EatInstr(72,14);EatInstr(71,14);EatInstr(70,14);EatInstr(69,14);EatInstr(68,14);EatInstr(67,14);EatInstr(66,14);EatInstr(65,14);EatInstr(64,14);EatInstr(63,14);EatInstr(62,14);EatInstr(61,14);EatInstr(60,14);EatInstr(59,14);EatInstr(58,14);EatInstr(57,14);EatInstr(56,14);EatInstr(55,14);EatInstr(54,14);EatInstr(53,14);EatInstr(52,14);EatInstr(51,14);EatInstr(50,14);EatInstr(49,14);EatInstr(48,14);EatInstr(47,14);EatInstr(46,14);EatInstr(45,14);EatInstr(44,14);EatInstr(43,14);EatInstr(42,14);EatInstr(41,14);EatInstr(40,14);EatInstr(39,14);EatInstr(38,14);EatInstr(37,14);EatInstr(36,14);EatInstr(35,14);EatInstr(34,14);EatInstr(33,14);EatInstr(32,14);EatInstr(31,14);EatInstr(30,14);EatInstr(29,14);EatInstr(28,14);EatInstr(27,14);EatInstr(26,14);EatInstr(25,14);EatInstr(24,14);EatInstr(23,14);EatInstr(22,14);EatInstr(21,14);EatInstr(20,14);EatInstr(19,14);EatInstr(18,14);EatInstr(17,14);EatInstr(16,14);EatInstr(15,14);EatInstr(14,14);EatInstr(13,14);EatInstr(12,14);EatInstr(11,14);EatInstr(10,14);EatInstr(9,14);EatInstr(8,14);EatInstr(7,14);EatInstr(6,14);EatInstr(5,14);EatInstr(4,14);EatInstr(3,14);EatInstr(2,14);EatInstr(1,14)]);
(387, [EatInstr(108,435)]);
(4, [EatInstr(119,30);EatInstr(117,29);EatInstr(116,28);EatInstr(115,27);EatInstr(114,26);EatInstr(112,25);EatInstr(109,24);EatInstr(108,23);EatInstr(105,22);EatInstr(104,21);EatInstr(103,20);EatInstr(102,19);EatInstr(101,18);EatInstr(100,17);EatInstr(99,16);EatInstr(97,15);AContInstr3(272,__g0,__binder2,32);AContInstr3(273,__g0,__binder1,31)]);
(388, [EatInstr(116,436)]);
(5, [EatInstr(0,33)]);
(389, [EatInstr(101,437)]);
(6, [EatInstr(127,12);EatInstr(126,12);EatInstr(125,12);EatInstr(124,12);EatInstr(123,12);EatInstr(122,12);EatInstr(121,12);EatInstr(120,12);EatInstr(119,12);EatInstr(118,12);EatInstr(117,12);EatInstr(116,12);EatInstr(115,12);EatInstr(114,12);EatInstr(113,12);EatInstr(112,12);EatInstr(111,12);EatInstr(110,12);EatInstr(109,12);EatInstr(108,12);EatInstr(107,12);EatInstr(106,12);EatInstr(105,12);EatInstr(104,12);EatInstr(103,12);EatInstr(102,12);EatInstr(101,12);EatInstr(100,12);EatInstr(99,12);EatInstr(98,12);EatInstr(97,12);EatInstr(96,12);EatInstr(95,12);EatInstr(94,12);EatInstr(93,12);EatInstr(92,12);EatInstr(91,12);EatInstr(90,12);EatInstr(89,12);EatInstr(88,12);EatInstr(87,12);EatInstr(86,12);EatInstr(85,12);EatInstr(84,12);EatInstr(83,12);EatInstr(82,12);EatInstr(81,12);EatInstr(80,12);EatInstr(79,12);EatInstr(78,12);EatInstr(77,12);EatInstr(76,12);EatInstr(75,12);EatInstr(74,12);EatInstr(73,12);EatInstr(72,12);EatInstr(71,12);EatInstr(70,12);EatInstr(69,12);EatInstr(68,12);EatInstr(67,12);EatInstr(66,12);EatInstr(65,12);EatInstr(64,12);EatInstr(63,12);EatInstr(62,12);EatInstr(61,12);EatInstr(60,12);EatInstr(59,12);EatInstr(58,12);EatInstr(57,12);EatInstr(56,12);EatInstr(55,12);EatInstr(54,12);EatInstr(53,12);EatInstr(52,12);EatInstr(51,12);EatInstr(50,12);EatInstr(49,12);EatInstr(48,12);EatInstr(47,12);EatInstr(46,12);EatInstr(45,12);EatInstr(44,12);EatInstr(43,12);EatInstr(42,12);EatInstr(41,12);EatInstr(40,12);EatInstr(39,12);EatInstr(38,12);EatInstr(37,12);EatInstr(36,12);EatInstr(35,12);EatInstr(34,12);EatInstr(33,12);EatInstr(32,12);EatInstr(31,12);EatInstr(30,12);EatInstr(29,12);EatInstr(28,12);EatInstr(27,12);EatInstr(26,12);EatInstr(25,12);EatInstr(24,12);EatInstr(23,12);EatInstr(22,12);EatInstr(21,12);EatInstr(20,12);EatInstr(19,12);EatInstr(18,12);EatInstr(17,12);EatInstr(16,12);EatInstr(15,12);EatInstr(14,12);EatInstr(13,12);EatInstr(12,12);EatInstr(11,12);EatInstr(10,12);EatInstr(9,12);EatInstr(8,12);EatInstr(7,12);EatInstr(6,12);EatInstr(5,12);EatInstr(4,12);EatInstr(3,12);EatInstr(2,12);EatInstr(1,12);ASimpleCont2Instr(265,__binder0,73)]);
(390, [EatInstr(116,438)]);
(7, [EatInstr(127,75);EatInstr(126,75);EatInstr(125,75);EatInstr(124,75);EatInstr(123,75);EatInstr(122,75);EatInstr(121,75);EatInstr(120,75);EatInstr(119,75);EatInstr(118,75);EatInstr(117,75);EatInstr(116,75);EatInstr(115,75);EatInstr(114,75);EatInstr(113,75);EatInstr(112,75);EatInstr(111,75);EatInstr(110,75);EatInstr(109,75);EatInstr(108,75);EatInstr(107,75);EatInstr(106,75);EatInstr(105,75);EatInstr(104,75);EatInstr(103,75);EatInstr(102,75);EatInstr(101,75);EatInstr(100,75);EatInstr(99,75);EatInstr(98,75);EatInstr(97,75);EatInstr(96,75);EatInstr(95,75);EatInstr(94,75);EatInstr(93,75);EatInstr(92,75);EatInstr(91,75);EatInstr(90,75);EatInstr(89,75);EatInstr(88,75);EatInstr(87,75);EatInstr(86,75);EatInstr(85,75);EatInstr(84,75);EatInstr(83,75);EatInstr(82,75);EatInstr(81,75);EatInstr(80,75);EatInstr(79,75);EatInstr(78,75);EatInstr(77,75);EatInstr(76,75);EatInstr(75,75);EatInstr(74,75);EatInstr(73,75);EatInstr(72,75);EatInstr(71,75);EatInstr(70,75);EatInstr(69,75);EatInstr(68,75);EatInstr(67,75);EatInstr(66,75);EatInstr(65,75);EatInstr(64,75);EatInstr(63,75);EatInstr(62,75);EatInstr(61,75);EatInstr(60,75);EatInstr(59,75);EatInstr(58,75);EatInstr(57,75);EatInstr(56,75);EatInstr(55,75);EatInstr(54,75);EatInstr(53,75);EatInstr(52,75);EatInstr(51,75);EatInstr(50,75);EatInstr(49,75);EatInstr(48,75);EatInstr(47,75);EatInstr(46,75);EatInstr(44,75);EatInstr(43,75);EatInstr(42,75);EatInstr(41,75);EatInstr(40,75);EatInstr(39,75);EatInstr(38,75);EatInstr(37,75);EatInstr(36,75);EatInstr(35,75);EatInstr(34,75);EatInstr(33,75);EatInstr(32,75);EatInstr(31,75);EatInstr(30,75);EatInstr(29,75);EatInstr(28,75);EatInstr(27,75);EatInstr(26,75);EatInstr(25,75);EatInstr(24,75);EatInstr(23,75);EatInstr(22,75);EatInstr(21,75);EatInstr(20,75);EatInstr(19,75);EatInstr(18,75);EatInstr(17,75);EatInstr(16,75);EatInstr(15,75);EatInstr(14,75);EatInstr(13,75);EatInstr(12,75);EatInstr(11,75);EatInstr(10,75);EatInstr(9,75);EatInstr(8,75);EatInstr(7,75);EatInstr(6,75);EatInstr(5,75);EatInstr(4,75);EatInstr(3,75);EatInstr(2,75);EatInstr(1,75)]);
(391, [EatInstr(99,439)]);
(8, [EatInstr(119,30);EatInstr(117,29);EatInstr(115,41);EatInstr(114,40);EatInstr(112,39);EatInstr(109,24);EatInstr(108,38);EatInstr(105,37);EatInstr(104,21);EatInstr(100,36);EatInstr(99,35);EatInstr(97,34)]);
(392, [AAction2Instr(__a31,203)]);
(9, [EatInstr(119,30);EatInstr(117,29);EatInstr(116,28);EatInstr(115,27);EatInstr(114,26);EatInstr(112,25);EatInstr(109,24);EatInstr(108,23);EatInstr(105,22);EatInstr(104,21);EatInstr(103,20);EatInstr(102,19);EatInstr(101,18);EatInstr(100,17);EatInstr(99,16);EatInstr(97,15);AContInstr3(272,__g0,__binder2,32)]);
(393, [EatInstr(111,440)]);
(10, [EatInstr(45,42);AAction2Instr(__a1,43)]);
(11, [ALookaheadInstr(false,CfgLA (3,267),44)]);
(394, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,441)]);
(395, [EatInstr(115,442)]);
(12, [CompleteInstr(265)]);
(396, [EatInstr(97,443)]);
(13, [CompleteInstr(266)]);
(397, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,444)]);
(14, [CompleteInstr(267)]);
(398, [EatInstr(97,445)]);
(15, [EatInstr(116,47);EatInstr(114,46);EatInstr(100,45)]);
(399, [EatInstr(114,447);EatInstr(99,446)]);
(16, [EatInstr(111,49);EatInstr(108,48)]);
(400, [EatInstr(97,448)]);
(17, [EatInstr(111,51);EatInstr(101,50)]);
(401, [EatInstr(45,449)]);
(18, [EatInstr(120,52)]);
(402, [EatInstr(101,450)]);
(19, [EatInstr(117,53)]);
(403, [EatInstr(97,451)]);
(20, [EatInstr(101,54)]);
(404, [EatInstr(105,452)]);
(21, [EatInstr(97,55)]);
(405, [EatInstr(97,453)]);
(22, [EatInstr(110,56)]);
(406, [EatInstr(109,454)]);
(23, [EatInstr(114,60);EatInstr(111,59);EatInstr(105,58);EatInstr(101,57)]);
(407, [EatInstr(97,455)]);
(24, [EatInstr(105,61)]);
(408, [EatInstr(45,456)]);
(25, [EatInstr(114,63);EatInstr(97,62)]);
(409, [EatInstr(104,457)]);
(26, [EatInstr(102,65);EatInstr(101,64)]);
(410, [AAction2Instr(__a32,458)]);
(27, [EatInstr(117,68);EatInstr(116,67);EatInstr(111,66)]);
(411, [EatInstr(115,459)]);
(28, [EatInstr(114,69)]);
(412, [EatInstr(115,460)]);
(29, [EatInstr(110,70)]);
(413, [EatInstr(116,461)]);
(30, [EatInstr(114,71)]);
(414, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,462)]);
(31, [AAction2Instr(__a2,184)]);
(415, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,463)]);
(32, [AAction2Instr(__a3,72)]);
(416, [EatInstr(114,464)]);
(33, [CompleteInstr(269)]);
(417, [EatInstr(114,465)]);
(34, [EatInstr(116,47);EatInstr(114,46)]);
(418, [EatInstr(97,466)]);
(35, [EatInstr(111,77);EatInstr(108,48)]);
(419, [EatInstr(97,467)]);
(36, [EatInstr(101,78)]);
(420, [EatInstr(115,468)]);
(37, [EatInstr(110,79)]);
(421, [EatInstr(101,469)]);
(38, [EatInstr(105,58);EatInstr(101,57)]);
(422, [AAction2Instr(__a33,272)]);
(39, [EatInstr(114,80)]);
(423, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,470)]);
(40, [EatInstr(101,64)]);
(424, [EatInstr(121,471)]);
(41, [EatInstr(117,68)]);
(425, [EatInstr(105,472)]);
(42, [EatInstr(118,93);EatInstr(117,92);EatInstr(114,91);EatInstr(112,90);EatInstr(111,89);EatInstr(110,88);EatInstr(109,87);EatInstr(108,86);EatInstr(105,85);EatInstr(104,84);EatInstr(99,83);EatInstr(98,82);EatInstr(97,81)]);
(426, [AAction2Instr(__a35,72);AAction2Instr(__a34,473)]);
(43, [ACallInstr3(__default_call,7);ASimpleCont2Instr(271,__binder0,94)]);
(427, [EatInstr(97,474)]);
(44, [CompleteInstr(275)]);
(428, [EatInstr(101,475)]);
(45, [EatInstr(100,95)]);
(429, [EatInstr(108,476)]);
(46, [EatInstr(114,96)]);
(430, [EatInstr(103,477)]);
(47, [EatInstr(116,97)]);
(431, [EatInstr(45,478)]);
(48, [EatInstr(111,98)]);
(432, [EatInstr(104,479)]);
(49, [EatInstr(114,101);EatInstr(112,100);EatInstr(109,99)]);
(433, [EatInstr(101,480)]);
(50, [EatInstr(115,103);EatInstr(112,102)]);
(434, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,481)]);
(51, [EatInstr(116,104)]);
(435, [EatInstr(101,482)]);
(52, [EatInstr(116,106);EatInstr(101,105)]);
(436, [EatInstr(101,483)]);
(53, [EatInstr(115,107)]);
(437, [EatInstr(45,484)]);
(54, [EatInstr(116,108)]);
(438, [EatInstr(97,485)]);
(55, [EatInstr(115,109)]);
(439, [EatInstr(101,486)]);
(56, [EatInstr(108,111);EatInstr(102,110)]);
(440, [EatInstr(116,487)]);
(57, [EatInstr(120,112)]);
(441, [EatInstr(119,491);EatInstr(116,490);EatInstr(112,489);EatInstr(102,488)]);
(58, [EatInstr(102,113)]);
(442, [EatInstr(101,492)]);
(59, [EatInstr(111,114)]);
(443, [EatInstr(98,493)]);
(60, [EatInstr(49,115)]);
(444, [AAction2Instr(__a36,494)]);
(61, [EatInstr(110,116)]);
(445, [EatInstr(114,495)]);
(62, [EatInstr(114,117)]);
(446, [EatInstr(115,496)]);
(63, [EatInstr(105,119);EatInstr(101,118)]);
(447, [EatInstr(101,497)]);
(64, [EatInstr(112,120)]);
(448, [EatInstr(100,498)]);
(65, [EatInstr(99,121)]);
(449, [EatInstr(104,499)]);
(66, [EatInstr(114,122)]);
(450, [EatInstr(115,500)]);
(67, [EatInstr(114,123)]);
(451, [EatInstr(112,501)]);
(68, [EatInstr(98,124)]);
(452, [EatInstr(122,502)]);
(69, [EatInstr(97,125)]);
(453, [EatInstr(98,503)]);
(70, [EatInstr(114,126)]);
(454, [EatInstr(105,504)]);
(71, [EatInstr(97,127)]);
(455, [EatInstr(121,505)]);
(72, [CompleteInstr(273)]);
(456, [EatInstr(111,506)]);
(73, [ALookaheadInstr(false,CfgLA (1,265),74);ACallInstr3(__default_call,1);ASimpleCont2Instr(265,__binder0,73)]);
(457, [EatInstr(105,507)]);
(74, [CompleteInstr(270)]);
(458, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,508)]);
(75, [ALookaheadInstr(false,CfgLA (1,265),76);ACallInstr3(__default_call,1);ASimpleCont2Instr(265,__binder0,75)]);
(459, [EatInstr(116,509)]);
(76, [CompleteInstr(271)]);
(460, [EatInstr(116,510)]);
(77, [EatInstr(112,100)]);
(461, [EatInstr(45,511)]);
(78, [EatInstr(115,103)]);
(462, [AAction2Instr(__a37,203)]);
(79, [EatInstr(108,111);EatInstr(102,130)]);
(463, [AAction2Instr(__a38,203)]);
(80, [EatInstr(101,131)]);
(464, [EatInstr(45,512)]);
(81, [EatInstr(114,133);EatInstr(102,132)]);
(465, [EatInstr(115,513)]);
(82, [EatInstr(97,134)]);
(466, [EatInstr(99,514)]);
(83, [EatInstr(111,137);EatInstr(104,136);EatInstr(97,135)]);
(467, [EatInstr(116,515)]);
(84, [EatInstr(121,138)]);
(468, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,516)]);
(85, [EatInstr(110,139)]);
(469, [EatInstr(114,517)]);
(86, [EatInstr(111,140)]);
(470, [AAction2Instr(__a39,72)]);
(87, [EatInstr(101,141)]);
(471, [EatInstr(45,518)]);
(88, [EatInstr(111,142)]);
(472, [EatInstr(108,519)]);
(89, [EatInstr(110,143)]);
(473, [ACallInstr3(__default_call,6);ASimpleCont2Instr(270,__binder0,520)]);
(90, [EatInstr(114,144)]);
(474, [EatInstr(116,521)]);
(91, [EatInstr(111,145)]);
(475, [EatInstr(115,522)]);
(92, [EatInstr(115,147);EatInstr(110,146)]);
(476, [EatInstr(108,523)]);
(93, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,148)]);
(477, [EatInstr(117,524)]);
(94, [AAction2Instr(__a4,149)]);
(478, [EatInstr(97,525)]);
(95, [EatInstr(45,150)]);
(479, [EatInstr(101,526)]);
(96, [EatInstr(111,151)]);
(480, [EatInstr(45,528);ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,527)]);
(97, [EatInstr(114,152)]);
(481, [AAction2Instr(__a40,72)]);
(98, [EatInstr(115,153)]);
(482, [EatInstr(118,529)]);
(99, [EatInstr(112,154)]);
(483, [EatInstr(45,530)]);
(100, [EatInstr(121,155)]);
(484, [EatInstr(100,531)]);
(101, [EatInstr(111,156)]);
(485, [EatInstr(114,532)]);
(102, [EatInstr(101,157)]);
(486, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,527)]);
(103, [EatInstr(117,158)]);
(487, [EatInstr(97,533)]);
(104, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,159)]);
(488, [EatInstr(117,534)]);
(105, [EatInstr(99,160)]);
(489, [EatInstr(101,535)]);
(106, [EatInstr(114,161)]);
(490, [EatInstr(120,536)]);
(107, [EatInstr(101,162)]);
(491, [EatInstr(97,537)]);
(108, [EatInstr(45,163)]);
(492, [EatInstr(110,538)]);
(109, [EatInstr(104,164)]);
(493, [EatInstr(101,539)]);
(110, [EatInstr(111,166);EatInstr(101,165)]);
(494, [ACallInstr3(__default_call,2);ASimpleCont2Instr(266,__binder0,580)]);
(111, [EatInstr(105,167)]);
(495, [EatInstr(114,540)]);
(112, [EatInstr(101,168)]);
(496, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,541)]);
(113, [EatInstr(116,169)]);
(497, [EatInstr(103,542)]);
(114, [EatInstr(107,170)]);
(498, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,543)]);
(115, [EatInstr(45,171)]);
(499, [EatInstr(105,544)]);
(116, [EatInstr(117,172)]);
(500, [EatInstr(99,545)]);
(117, [EatInstr(115,173)]);
(501, [EatInstr(115,546)]);
(118, [EatInstr(99,174)]);
(502, [EatInstr(101,547)]);
(119, [EatInstr(110,175)]);
(503, [EatInstr(105,548)]);
(120, [EatInstr(108,176)]);
(504, [EatInstr(122,549)]);
(121, [AAction2Instr(__a5,177)]);
(505, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,550)]);
(122, [EatInstr(116,178)]);
(506, [EatInstr(112,551)]);
(123, [EatInstr(105,179)]);
(507, [EatInstr(115,552)]);
(124, [EatInstr(115,180)]);
(508, [AAction2Instr(__a41,203)]);
(125, [EatInstr(110,181)]);
(509, [EatInstr(111,553)]);
(126, [EatInstr(111,182)]);
(510, [EatInstr(97,554)]);
(127, [EatInstr(112,183)]);
(511, [EatInstr(115,555)]);
(128, [AAction2Instr(__a6,184)]);
(512, [EatInstr(115,556)]);
(129, [CompleteInstr(268)]);
(513, [EatInstr(101,557)]);
(130, [EatInstr(101,165)]);
(514, [EatInstr(116,558)]);
(131, [EatInstr(99,185)]);
(515, [EatInstr(105,559)]);
(132, [EatInstr(116,186)]);
(516, [AAction2Instr(__a42,272)]);
(133, [EatInstr(114,187)]);
(517, [EatInstr(45,560)]);
(134, [EatInstr(99,188)]);
(518, [EatInstr(103,561)]);
(135, [EatInstr(115,189)]);
(519, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,562)]);
(136, [EatInstr(101,190)]);
(520, [AAction2Instr(__a43,377)]);
(137, [EatInstr(117,191)]);
(521, [EatInstr(111,563)]);
(138, [EatInstr(98,192)]);
(522, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,564)]);
(139, [EatInstr(108,193)]);
(523, [EatInstr(97,565)]);
(140, [EatInstr(111,194)]);
(524, [EatInstr(108,566)]);
(141, [EatInstr(109,195)]);
(525, [EatInstr(110,567)]);
(142, [EatInstr(45,196)]);
(526, [EatInstr(97,568)]);
(143, [EatInstr(108,197)]);
(527, [AAction2Instr(__a44,272)]);
(144, [EatInstr(101,198)]);
(528, [EatInstr(97,569)]);
(145, [EatInstr(111,199)]);
(529, [EatInstr(97,570)]);
(146, [EatInstr(114,201);EatInstr(105,200)]);
(530, [EatInstr(97,571)]);
(147, [EatInstr(101,202)]);
(531, [EatInstr(121,572)]);
(148, [AAction2Instr(__a7,203)]);
(532, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,573)]);
(149, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,204)]);
(533, [EatInstr(116,574)]);
(150, [EatInstr(108,205)]);
(534, [EatInstr(110,575)]);
(151, [EatInstr(119,206)]);
(535, [EatInstr(103,576)]);
(152, [EatInstr(105,207)]);
(536, [AAction2Instr(__a45,698)]);
(153, [EatInstr(101,208)]);
(537, [EatInstr(100,577)]);
(154, [EatInstr(105,209)]);
(538, [EatInstr(115,578)]);
(155, [EatInstr(114,210)]);
(539, [EatInstr(108,579)]);
(156, [EatInstr(117,211)]);
(540, [EatInstr(111,582)]);
(157, [EatInstr(110,212)]);
(541, [AAction2Instr(__a46,203)]);
(158, [EatInstr(103,213)]);
(542, [EatInstr(117,583)]);
(159, [AAction2Instr(__a8,72)]);
(543, [AAction2Instr(__a47,203)]);
(160, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,214)]);
(544, [EatInstr(115,584)]);
(161, [EatInstr(97,215)]);
(545, [EatInstr(101,585)]);
(162, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,216)]);
(546, [EatInstr(101,586)]);
(163, [EatInstr(103,217)]);
(547, [EatInstr(45,587)]);
(164, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,218)]);
(548, [EatInstr(108,588)]);
(165, [EatInstr(114,219)]);
(549, [EatInstr(101,589)]);
(166, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,220)]);
(550, [AAction2Instr(__a48,203)]);
(167, [EatInstr(110,221)]);
(551, [EatInstr(116,590)]);
(168, [EatInstr(114,222)]);
(552, [EatInstr(116,591)]);
(169, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,223)]);
(553, [EatInstr(114,592)]);
(170, [EatInstr(97,224)]);
(554, [EatInstr(114,593)]);
(171, [EatInstr(108,225)]);
(555, [EatInstr(101,594)]);
(172, [EatInstr(115,226)]);
(556, [EatInstr(101,595)]);
(173, [EatInstr(101,227)]);
(557, [EatInstr(45,596)]);
(174, [EatInstr(101,228)]);
(558, [EatInstr(105,597)]);
(175, [EatInstr(116,229)]);
(559, [EatInstr(111,598)]);
(176, [EatInstr(97,230)]);
(560, [EatInstr(99,599)]);
(177, [ACallInstr3(__default_call,2);ASimpleCont2Instr(266,__binder0,284)]);
(561, [EatInstr(114,600)]);
(178, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,231)]);
(562, [AAction2Instr(__a49,272)]);
(179, [EatInstr(112,232)]);
(563, [EatInstr(114,601)]);
(180, [EatInstr(101,233)]);
(564, [AAction2Instr(__a50,272)]);
(181, [EatInstr(115,234)]);
(565, [EatInstr(98,602)]);
(182, [EatInstr(108,235)]);
(566, [EatInstr(97,603)]);
(183, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,236)]);
(567, [EatInstr(97,604)]);
(184, [ALookaheadInstr(false,CfgLA (3,267),129);ACallInstr3(__default_call,11);ACallInstr3(__g0,10);AContInstr3(274,__g0,__binder3,128);ASimpleCont2Instr(275,__binder0,129)]);
(568, [EatInstr(100,605)]);
(185, [EatInstr(101,237)]);
(569, [EatInstr(110,606)]);
(186, [EatInstr(101,238)]);
(570, [EatInstr(110,607)]);
(187, [EatInstr(111,239)]);
(571, [EatInstr(99,608)]);
(188, [EatInstr(107,240)]);
(572, [EatInstr(112,609)]);
(189, [EatInstr(101,241)]);
(573, [AAction2Instr(__a51,272)]);
(190, [EatInstr(99,242)]);
(574, [EatInstr(105,610)]);
(191, [EatInstr(110,243)]);
(575, [AAction2Instr(__a52,698)]);
(192, [EatInstr(114,244)]);
(576, [EatInstr(45,611);AAction2Instr(__a53,698)]);
(193, [EatInstr(105,245)]);
(577, [EatInstr(108,613)]);
(194, [EatInstr(107,246)]);
(578, [EatInstr(105,614)]);
(195, [EatInstr(111,247)]);
(579, [EatInstr(115,615)]);
(196, [EatInstr(115,253);EatInstr(114,252);EatInstr(111,251);EatInstr(110,250);EatInstr(109,249);EatInstr(99,248)]);
(580, [AAction2Instr(__a54,581);ACallInstr3(__default_call,2);ASimpleCont2Instr(266,__binder0,580)]);
(197, [EatInstr(121,254)]);
(581, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,616)]);
(198, [EatInstr(102,255)]);
(582, [EatInstr(119,617)]);
(199, [EatInstr(116,256)]);
(583, [EatInstr(108,618)]);
(200, [EatInstr(116,257)]);
(584, [EatInstr(116,619)]);
(201, [EatInstr(111,258)]);
(585, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,620)]);
(202, [EatInstr(45,259)]);
(586, [EatInstr(45,621)]);
(203, [CompleteInstr(274)]);
(587, [EatInstr(104,622)]);
(204, [AAction2Instr(__a9,203)]);
(588, [EatInstr(105,623)]);
(205, [EatInstr(97,260)]);
(589, [EatInstr(45,624)]);
(206, [EatInstr(45,261)]);
(590, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,625)]);
(207, [EatInstr(98,262)]);
(591, [EatInstr(111,626)]);
(208, [EatInstr(45,263)]);
(592, [EatInstr(121,627)]);
(209, [EatInstr(108,264)]);
(593, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,628)]);
(210, [EatInstr(117,265)]);
(594, [EatInstr(116,629)]);
(211, [EatInstr(116,266)]);
(595, [EatInstr(116,630)]);
(212, [EatInstr(100,267)]);
(596, [EatInstr(115,631)]);
(213, [EatInstr(97,268)]);
(597, [EatInstr(111,632)]);
(214, [AAction2Instr(__a10,269)]);
(598, [EatInstr(110,633)]);
(215, [EatInstr(99,270)]);
(599, [EatInstr(111,634)]);
(216, [AAction2Instr(__a11,72)]);
(600, [EatInstr(97,635)]);
(217, [EatInstr(101,271)]);
(601, [EatInstr(115,636)]);
(218, [AAction2Instr(__a12,272)]);
(602, [EatInstr(108,637)]);
(219, [EatInstr(45,273)]);
(603, [EatInstr(114,638)]);
(220, [AAction2Instr(__a13,72)]);
(604, [EatInstr(108,639)]);
(221, [EatInstr(101,274)]);
(605, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,640)]);
(222, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,275)]);
(606, [EatInstr(97,641)]);
(223, [AAction2Instr(__a14,272)]);
(607, [EatInstr(99,642)]);
(224, [EatInstr(104,276)]);
(608, [EatInstr(116,643)]);
(225, [EatInstr(111,277)]);
(609, [EatInstr(103,644)]);
(226, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,278)]);
(610, [EatInstr(111,645)]);
(227, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,279)]);
(611, [EatInstr(115,646)]);
(228, [EatInstr(100,280)]);
(612, [AAction2Instr(__a55,203)]);
(229, [EatInstr(45,282);ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,281)]);
(613, [EatInstr(101,647)]);
(230, [EatInstr(121,283)]);
(614, [EatInstr(116,648)]);
(231, [AAction2Instr(__a15,72)]);
(615, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,649)]);
(232, [EatInstr(45,286)]);
(616, [AAction2Instr(__a56,203)]);
(233, [EatInstr(116,287)]);
(617, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,650)]);
(234, [EatInstr(108,288)]);
(618, [EatInstr(97,651)]);
(235, [EatInstr(108,289)]);
(619, [EatInstr(111,652)]);
(236, [AAction2Instr(__a16,272)]);
(620, [AAction2Instr(__a57,203)]);
(237, [EatInstr(100,290)]);
(621, [EatInstr(99,653)]);
(238, [EatInstr(114,291)]);
(622, [EatInstr(105,654)]);
(239, [EatInstr(119,292)]);
(623, [EatInstr(116,655)]);
(240, [EatInstr(101,293)]);
(624, [EatInstr(112,656)]);
(241, [EatInstr(45,294)]);
(625, [AAction2Instr(__a58,203)]);
(242, [EatInstr(107,295)]);
(626, [EatInstr(114,657)]);
(243, [EatInstr(116,296)]);
(627, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,658)]);
(244, [EatInstr(105,297)]);
(628, [AAction2Instr(__a59,659)]);
(245, [EatInstr(110,298)]);
(629, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,660)]);
(246, [EatInstr(97,299)]);
(630, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,661)]);
(247, [EatInstr(105,300)]);
(631, [EatInstr(101,662)]);
(248, [EatInstr(111,301)]);
(632, [EatInstr(110,663)]);
(249, [EatInstr(101,302)]);
(633, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,664)]);
(250, [EatInstr(117,303)]);
(634, [EatInstr(114,665)]);
(251, [EatInstr(112,304)]);
(635, [EatInstr(112,666)]);
(252, [EatInstr(101,305)]);
(636, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,667)]);
(253, [EatInstr(107,306)]);
(637, [EatInstr(101,668)]);
(254, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,307)]);
(638, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,669)]);
(255, [EatInstr(105,308)]);
(639, [EatInstr(121,670)]);
(256, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,309)]);
(640, [AAction2Instr(__a60,72)]);
(257, [EatInstr(45,310)]);
(641, [EatInstr(108,671)]);
(258, [EatInstr(108,311)]);
(642, [EatInstr(101,672)]);
(259, [EatInstr(115,314);EatInstr(104,313);EatInstr(102,312)]);
(643, [EatInstr(105,673)]);
(260, [EatInstr(116,315)]);
(644, [EatInstr(101,674)]);
(261, [EatInstr(110,316)]);
(645, [EatInstr(110,675)]);
(262, [EatInstr(117,317)]);
(646, [EatInstr(116,676)]);
(263, [EatInstr(117,318)]);
(647, [EatInstr(114,677)]);
(264, [EatInstr(101,319)]);
(648, [EatInstr(105,678)]);
(265, [EatInstr(108,320)]);
(649, [AAction2Instr(__a61,203)]);
(266, [EatInstr(105,321)]);
(650, [AAction2Instr(__a62,203)]);
(267, [EatInstr(101,322)]);
(651, [EatInstr(114,679)]);
(268, [EatInstr(114,323)]);
(652, [EatInstr(114,680)]);
(269, [ACallInstr3(__default_call,6);ASimpleCont2Instr(270,__binder0,324)]);
(653, [EatInstr(97,681)]);
(270, [EatInstr(116,325)]);
(654, [EatInstr(115,682)]);
(271, [EatInstr(110,326)]);
(655, [EatInstr(121,683)]);
(272, [CompleteInstr(272)]);
(656, [EatInstr(97,684)]);
(273, [EatInstr(116,328)]);
(657, [EatInstr(121,685)]);
(274, [EatInstr(45,329)]);
(658, [AAction2Instr(__a63,203)]);
(275, [AAction2Instr(__a17,272)]);
(659, [ACallInstr3(__default_call,2);ASimpleCont2Instr(266,__binder0,707)]);
(276, [EatInstr(101,330)]);
(660, [AAction2Instr(__a64,203)]);
(277, [EatInstr(111,331)]);
(661, [AAction2Instr(__a65,203)]);
(278, [AAction2Instr(__a18,272)]);
(662, [EatInstr(116,686)]);
(279, [AAction2Instr(__a19,72)]);
(663, [EatInstr(115,687)]);
(280, [EatInstr(101,332)]);
(664, [AAction2Instr(__a66,272)]);
(281, [AAction2Instr(__a20,72)]);
(665, [EatInstr(101,688)]);
(282, [EatInstr(114,334);EatInstr(103,333)]);
(666, [EatInstr(104,689)]);
(283, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,335)]);
(667, [AAction2Instr(__a67,72)]);
(284, [AAction2Instr(__a21,285);ACallInstr3(__default_call,2);ASimpleCont2Instr(266,__binder0,284)]);
(668, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,690)]);
(285, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,336)]);
(669, [AAction2Instr(__a68,272)]);
(286, [EatInstr(108,337)]);
(670, [EatInstr(115,691)]);
(287, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,338)]);
(671, [EatInstr(121,692)]);
(288, [EatInstr(97,339)]);
(672, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,693)]);
(289, [EatInstr(45,340)]);
(673, [EatInstr(111,694)]);
(290, [EatInstr(101,341)]);
(674, [EatInstr(110,695)]);
(291, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,342)]);
(675, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,696)]);
(292, [EatInstr(45,343)]);
(676, [EatInstr(114,697)]);
(293, [EatInstr(110,344)]);
(677, [AAction2Instr(__a69,698)]);
(294, [EatInstr(105,345)]);
(678, [EatInstr(118,699)]);
(295, [EatInstr(45,346)]);
(679, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,700)]);
(296, [EatInstr(101,347)]);
(680, [EatInstr(121,701)]);
(297, [EatInstr(100,348)]);
(681, [EatInstr(108,702)]);
(298, [EatInstr(101,349)]);
(682, [EatInstr(116,703)]);
(299, [EatInstr(104,350)]);
(683, [EatInstr(45,704)]);
(300, [EatInstr(122,351)]);
(684, [EatInstr(109,705)]);
(301, [EatInstr(108,353);EatInstr(97,352)]);
(685, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,706)]);
(302, [EatInstr(109,354)]);
(686, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,709)]);
(303, [EatInstr(108,355)]);
(687, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,710)]);
(304, [EatInstr(116,356)]);
(688, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,711)]);
(305, [EatInstr(112,357)]);
(689, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,712)]);
(306, [EatInstr(105,358)]);
(690, [AAction2Instr(__a70,272)]);
(307, [AAction2Instr(__a22,203)]);
(691, [EatInstr(105,713)]);
(308, [EatInstr(120,359)]);
(692, [EatInstr(115,714)]);
(309, [AAction2Instr(__a23,360)]);
(693, [AAction2Instr(__a71,72)]);
(310, [EatInstr(104,361)]);
(694, [EatInstr(110,715)]);
(311, [EatInstr(108,362)]);
(695, [EatInstr(45,717);ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,716)]);
(312, [EatInstr(115,364);EatInstr(108,363)]);
(696, [AAction2Instr(__a72,203)]);
(313, [EatInstr(105,365)]);
(697, [EatInstr(105,718)]);
(314, [EatInstr(112,366)]);
(698, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,612)]);
(315, [EatInstr(101,367)]);
(699, [EatInstr(101,719)]);
(316, [EatInstr(111,368)]);
(700, [AAction2Instr(__a73,203)]);
(317, [EatInstr(116,369)]);
(701, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,720)]);
(318, [EatInstr(110,370)]);
(702, [EatInstr(108,721)]);
(319, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,371)]);
(703, [EatInstr(111,722)]);
(320, [EatInstr(101,372)]);
(704, [EatInstr(112,723)]);
(321, [EatInstr(110,373)]);
(705, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,724)]);
(322, [EatInstr(110,374)]);
(706, [AAction2Instr(__a74,203)]);
(323, [EatInstr(45,376);ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,375)]);
(707, [AAction2Instr(__a75,708);ACallInstr3(__default_call,2);ASimpleCont2Instr(266,__binder0,707)]);
(324, [AAction2Instr(__a24,377)]);
(708, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,725)]);
(325, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,378)]);
(709, [AAction2Instr(__a76,203)]);
(326, [EatInstr(101,379)]);
(710, [AAction2Instr(__a77,72)]);
(711, [AAction2Instr(__a78,272)]);
(328, [EatInstr(121,380)]);
(712, [AAction2Instr(__a79,72)]);
(329, [EatInstr(114,382);EatInstr(110,381)]);
(713, [EatInstr(115,726)]);
(330, [EatInstr(97,383)]);
(714, [EatInstr(105,727)]);
(331, [EatInstr(107,384)]);
(715, [EatInstr(115,728)]);
(332, [EatInstr(110,385)]);
(716, [AAction2Instr(__a80,72)]);
(333, [EatInstr(105,386)]);
(717, [EatInstr(115,729)]);
(334, [EatInstr(101,387)]);
(718, [EatInstr(99,730)]);
(335, [AAction2Instr(__a25,272)]);
(719, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,731)]);
(336, [AAction2Instr(__a26,72)]);
(720, [AAction2Instr(__a81,203)]);
(337, [EatInstr(97,388)]);
(721, [EatInstr(115,732)]);
(338, [AAction2Instr(__a27,272)]);
(722, [EatInstr(114,733)]);
(339, [EatInstr(116,389)]);
(723, [EatInstr(114,734)]);
(340, [EatInstr(115,390)]);
(724, [AAction2Instr(__a82,203)]);
(341, [EatInstr(110,391)]);
(725, [AAction2Instr(__a83,203)]);
(342, [AContInstr3(272,__g0,__binder4,392);ACallInstr3(__g0,8)]);
(726, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,735)]);
(343, [EatInstr(110,393)]);
(727, [EatInstr(115,736)]);
(344, [EatInstr(100,394)]);
(728, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,737)]);
(345, [EatInstr(110,395)]);
(729, [EatInstr(99,738)]);
(346, [EatInstr(108,396)]);
(730, [EatInstr(116,739)]);
(347, [EatInstr(114,397)]);
(731, [AAction2Instr(__a84,203)]);
(348, [EatInstr(45,398)]);
(732, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,740)]);
(349, [EatInstr(45,399)]);
(733, [EatInstr(121,741)]);
(350, [EatInstr(101,400)]);
(734, [EatInstr(101,742)]);
(351, [EatInstr(101,401)]);
(735, [AAction2Instr(__a85,72)]);
(352, [EatInstr(108,402)]);
(736, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,743)]);
(353, [EatInstr(108,403)]);
(737, [AAction2Instr(__a86,72)]);
(354, [EatInstr(111,404)]);
(738, [EatInstr(97,744)]);
(355, [EatInstr(108,405)]);
(739, [AAction2Instr(__a87,698)]);
(356, [EatInstr(105,406)]);
(740, [AAction2Instr(__a88,203)]);
(357, [EatInstr(108,407)]);
(741, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,745)]);
(358, [EatInstr(112,408)]);
(742, [EatInstr(100,746)]);
(359, [EatInstr(45,409)]);
(743, [AAction2Instr(__a89,72)]);
(360, [ACallInstr3(__default_call,6);ASimpleCont2Instr(270,__binder0,410)]);
(744, [EatInstr(110,747)]);
(361, [EatInstr(105,411)]);
(745, [AAction2Instr(__a90,203)]);
(362, [EatInstr(45,412)]);
(746, [EatInstr(115,748)]);
(363, [EatInstr(97,413)]);
(747, [EatInstr(110,749)]);
(364, [EatInstr(116,415);EatInstr(109,414)]);
(748, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,750)]);
(365, [EatInstr(101,416)]);
(749, [EatInstr(101,751)]);
(366, [EatInstr(97,417)]);
(750, [AAction2Instr(__a91,203)]);
(367, [EatInstr(45,418)]);
(751, [EatInstr(114,752)]);
(368, [EatInstr(116,419)]);
(752, [EatInstr(108,753)]);
(369, [EatInstr(101,420)]);
(753, [EatInstr(101,754)]);
(370, [EatInstr(100,421)]);
(754, [EatInstr(115,755)]);
(371, [AAction2Instr(__a28,72)]);
(755, [EatInstr(115,756)]);
(372, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,422)]);
(756, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,757)]);
(373, [EatInstr(101,423)]);
(757, [AAction2Instr(__a92,72)]);
(374, [EatInstr(99,424)]);
(375, [AAction2Instr(__a29,272)]);
(376, [EatInstr(103,425)]);
(377, [ACallInstr3(__default_call,5);ASimpleCont2Instr(269,__binder0,426)]);
(378, [AAction2Instr(__a30,72)]);
(379, [EatInstr(114,427)]);
(380, [EatInstr(112,428)]);
(381, [EatInstr(117,429)]);
(382, [EatInstr(101,430)]);
]

module Parse_engine = Yak.Engine

let start_symb = get_symb_action "cmd-line-args"

module P2__ = Parse_engine.Full_yakker (Parse_engine.Scannerless_term_lang)
                                     (struct type t = sv let cmp = sv_compare type idata = Yk_History.Root_id_set.t
  let create_idata () = Yk_History.Root_id_set.empty
  let inspect h s = Yk_History.add_id_set h#get_root s
  let summarize_inspection s = string_of_int (Yk_History.Root_id_set.cardinal s) end)

let _wfe_data_ = Yak.PamJIT.DNELR.mk_table Yak.PamJIT.Full_opt (Yak.Pam_internal.load_internal_program program)
  start_symb (get_symb_start start_symb) 264 num_symbols
  __default_call __default_ret

let parse = Yak.Pami.Wfe.mk_parse P2__.parse _wfe_data_ sv0 _replay_cmd_line_args
let visualize = parse
let visualize_file = Yak.Pami.Simple.parse_file visualize
let visualize_string = Yak.Pami.Simple.parse_string visualize

let parse_file = Yak.Pami.Simple.parse_file parse
let parse_string = Yak.Pami.Simple.parse_string parse
;;


let args_ykbuf = Yak.YkBuf.strings2buf Sys.argv 1
let what_arg = Yak.YkBuf.stringsposn2string Sys.argv 1
let process() =
    (try
      ignore(parse args_ykbuf); (!cmd, List.rev !files, List.rev !roots, !backend)
    with
      Yak.Pami.Parse_error("Error at byte.", i, _, _) ->
        let bad_arg = what_arg i in
        let bad = Sys.argv.(bad_arg) in
        if bad_arg = 1 then
          raise(Failure(Printf.sprintf "Unrecognized command '%s'" bad))
        else if String.length bad > 0 && String.get bad 0 = '-' then
          raise(Failure(Printf.sprintf "Unrecognized option '%s'" bad))
        else
          raise(Failure(Printf.sprintf "Bad argument '%s'" bad)))
