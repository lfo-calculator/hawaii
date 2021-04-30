(* This file is part of the French law library, a collection of functions for computing French taxes
   and benefits derived from Catala programs. Copyright (C) 2021 Microsoft,
   Jonathan Protzenko <protz@microsoft.com>

   Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
   in compliance with the License. You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software distributed under the License
   is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
   or implied. See the License for the specific language governing permissions and limitations under
   the License. *)

open Runtime
open Main
open Js_of_ocaml

(* TODO: move into a separate library *)
module Helpers = struct
  let no_input () = raise EmptyError
  let catala_date_of_js_date (d: Js.date Js.t) =
    date_of_numbers d##getFullYear d##getMonth d##getDay
  let thunk x = fun () -> x
end

module H = Helpers

(**********************
 * All known statutes *
 **********************)
type priors = offense array
type penalties = penalties array

(* N: none
 * V: violation
 * OP: offense + defendant (priors + age) *)
type statute_typ =
  | N of unit -> penalties
  | V of violation -> penalties
  | OD of offense -> defendant -> penalties

let all_statutes = [
  "291-11.6", N (fun () ->
    let out = s_291_11_6 {
      penalties_in = H.no_input
    } in
    out.penalties_out ());
  "286-136", OD (fun o d ->
    let out = s_286_136 {
      offense_in = H.thunk o;
      defendant_in = H.thunk d;
      max_fine_in = H.no_input;
      min_fine_in = H.no_input;
      max_days_in = H.no_input;
      priors_same_offense_in = H.no_input;
      paragraph_b_applies_in = H.no_input;
      paragraph_c_applies_in = H.no_input;
      penalties_in = H.no_input
    } in
    out.penalties_out ());
  "607-4", O (fun v ->
    let out = s_607_4 {
      violation_in = H.thunk v;
      category_in = H.no_input;
      penalty_in = H.no_input
    } in
    out.penalties_out ());
]

let applies: string -> string -> bool =
  let t = Hashtbl.create 41 in
  let statutes = Yojson.from_string Json.data in
  let assert_string = function `String s -> s | _ -> failwith "not a string" in
  let regs = match regs with `List regs -> regs | _ -> failwith "not a list" in
  List.iter (function
    | `Assoc l ->
        let reg = assert_string (List.assoc "regulation" l) in
        let sec = Filename.chop_suffix (assert_string (List.assoc "catala_url" l)) ".catala_en" in
        try
          Hashtbl.add t sec (assert_string (List.assoc "applies" l))
        with Not_found ->
          ()
    | _ ->
        failwith "not an assoc"
  ) regs;
  fun reg infraction ->
    match Hashtbl.find_opt t reg with
    | None ->
        (* See README.md: we assume the penalty for the infraction is in the
           relevant section *)
        reg = infraction
    | Some "-" ->
        false
    | Some "*" ->
        true
    | Some s ->
        let i = BatString.find s ".." in
        let lower = String.sub s 0 i in
        let upper = String.sub s (i + 2) (String.length s) in
        (* Lexicographic comparison *)
        lower <= infraction && infraction <= upper

(***********************
 * Computing penalties *
 ***********************)
let outcome = (penalty * violation) list
let table =
  let (/) = Filename.concat in
  Yojson.from_channel (Config.base / ".." / ".." / "data" / "hawaii-regulations.json")


(* Most likely coming in from JS *)
type statute = string

let applies (s: statute) (v: violation) =


let compute (offenses: offense list) (defendant: defendant): outcome =
  _

(* Describing input types that the JavaScript API is expected to provide *)
type js_violation = Js.js_string

let catala_violation_of_js (v: js_violation Js.t): Title17.violation_83_135 =
  match Js.to_string v with
  | "Section286_102" -> Section286_102 ()
  | "Section286_122" -> Section286_122 ()
  | "Section286_130" -> Section286_130 ()
  | "Section286_131" -> Section286_131 ()
  | "Section286_132" -> Section286_132 ()
  | "Section286_133" -> Section286_133 ()
  | "Section286_134" -> Section286_134 ()
  | "Section286_83_135" -> Section286_83_135 ()
  | "Section291_2" -> Section291_2 ()
  | "Section291_3_1" -> Section291_3_1 ()
  | "Section291_3_2" -> Section291_3_2 ()
  | "Section291_3_3" -> Section291_3_3 ()
  | "Section291_4_6" -> Section291_4_6 ()
  | "Section291_8" -> Section291_8 ()
  | "Section291_9" -> Section291_9 ()
  | "Section291_11_5" -> Section291_11_5 ()
  | "Section291_11_6" -> Section291_11_6 ()
  | "Section291_11" -> Section291_11 ()
  | "Section291_12" -> Section291_12 ()
  | "Section291_13" -> Section291_13 ()
  | "Section291_14" -> Section291_14 ()
  | v -> failwith (v ^ " is not a valid violation")

class type js_offense = object
  method dateOf: Js.date Js.t Js.readonly_prop
  method violation: js_violation Js.t Js.readonly_prop
end

let catala_offense_of_js (o: js_offense Js.t): Title17.offense = {
  date_of = H.catala_date_of_js_date o##.dateOf;
  violation = catala_violation_of_js o##.violation
}

class type js_defendant = object
  method priors: js_offense Js.t Js.js_array Js.t Js.readonly_prop
  method age: int Js.readonly_prop
end

let catala_defendant_of_js (o: js_defendant Js.t): Title17.defendant = {
  priors = Array.map catala_offense_of_js (Js.to_array o##.priors);
  age = integer_of_int o##.age
}

(* We receive a list of offenses, as well as the defendent's history *)
class type js_input = object
  method offense: js_offense Js.t Js.js_array Js.t Js.readonly_prop
  method defendant: js_defendant Js.t Js.readonly_prop
end

let catala_input_of_js (i: js_input Js.t): Title17.penalty286_83_135_in = {
  offense_in = (fun () -> catala_offense_of_js i##.offense);
  defendant_in = (fun () -> catala_defendant_of_js i##.defendant);
  max_fine_in = H.no_input;
  min_fine_in = H.no_input;
  max_days_in = H.no_input;
  priors_same_offense_in = H.no_input;
  paragraph_b_applies_in = H.no_input;
  paragraph_c_applies_in = H.no_input;
  penalty_in = H.no_input
}

(* What we return to the JavaScript code, using inheritance to encode tagged
   unions. *)
(* class type js_penalty = object *)
(* end *)

(* class type js_time_and_days = object *)
(*   inherit js_penalty *)
(*   method minFine: float Js.t Js.readonly_prop *)
(*   method maxFine: float Js.t Js.readonly_prop *)
(*   method maxDays: int Js.t Js.readonly_prop *)
(* end *)

let js_time_and_days_of_catala (p: Title17.penalty_time_and_days):
  (* js_time_and_days Js.t *)
  _ Js.t
=
  object%js
    method minFine = money_to_float p.Title17.min_fine
    method maxFine = money_to_float p.Title17.max_fine
    method maxDays = p.Title17.max_days
  end

(* class type js_fine500_or_lose_right_to_drive_until18 = object *)
(*   inherit js_penalty *)
(* end *)

(* let js_fine500_or_lose_right_to_drive_until18_of_catala (): *)
(*   js_fine500_or_lose_right_to_drive_until18 Js.t *)
(* = *)
(*   object *)
(*   end *)

let _ =
  Js.export_all (object%js
    method computePenalties (input: js_input Js.t): _ Js.t =
      match Title17.((penalty286_83_135 (catala_input_of_js input)).penalty_out) with
      | Title17.TimeAndDays td ->
          let o = js_time_and_days_of_catala td in
          let o = Js.Unsafe.coerce o in
          o##.kind := Js.string "TimeAndDays";
          o
      | Title17.Fine500OrLoseRightToDriveUntil18 () ->
          let o = object%js end in
          let o = Js.Unsafe.coerce o in
          o##.kind := Js.string "Fine500OrLoseRightToDriveUntil18";
          o
  end)

let _ =
  print_endline "[Wrapper.ml] loaded"
