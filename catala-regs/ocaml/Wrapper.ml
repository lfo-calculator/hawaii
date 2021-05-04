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
  let thunk x = fun () -> x

  let catala_date_of_js_date (d: Js.date Js.t) =
    date_of_numbers d##getFullYear d##getMonth d##getDay
end

module H = Helpers

let has_debug = true

let debug fmt =
  if has_debug then
    Printf.printf (fmt ^^ format_of_string "\n")
  else
    Printf.ifprintf stdout fmt


(**********************
 * All known statutes *
 **********************)

(* Here, we build a table that maps string representations (consistent with
   Catala file names) of regulations to their corresponding Catala function. *)
type priors = offense array
type penalties = penalty array
type regulation = string
type infraction = violation

(* N: none
 * V: violation
 * OP: offense + defendant (priors + age) *)
type catala_regulation =
  | N of (unit -> penalties)
  | V of (violation -> penalties)
  | OD of (offense -> defendant -> penalties)

let all_regulations: (regulation * catala_regulation) list = [
  "291-11.6", N (fun () ->
    let out = s_291_11_6 {
      penalties_in = H.no_input
    } in
    out.penalties_out);
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
    out.penalties_out);
  "607-4", V (fun v ->
    let out = s_607_4 {
      violation_in = H.thunk v;
      category_in = H.no_input;
      penalties_in = H.no_input
    } in
    out.penalties_out);
]

let find haystack needle =
  let r = Str.regexp (Str.quote needle) in
  Str.search_forward r haystack 0

(* [applies r1 r2] determines whether regulation [r1] applies to the infraction [r2] *)
let applies: string -> string -> bool =
  let t = Hashtbl.create 41 in
  let regs = Yojson.Safe.from_string Data.json in
  let assert_string = function `String s -> s | _ -> failwith "not a string" in
  let regs = match regs with `List regs -> regs | _ -> failwith "not a list" in
  List.iter (function
    | `Assoc l ->
        let sec = assert_string (List.assoc "section" l) in
        begin try
          Hashtbl.add t sec (assert_string (List.assoc "applies" l))
        with Not_found ->
          ()
        end
    | _ ->
        failwith "not an assoc"
  ) regs;
  fun reg infraction ->
    match Hashtbl.find t reg with
    | "0" ->
        false
    | "1" ->
        (* See ../../data/README.md: we assume the penalty for the infraction is in the
           relevant section *)
        reg = infraction
    | "*" ->
        true
    | s ->
        let i = find s ".." in
        let lower = String.sub s 0 i in
        let upper = String.sub s (i + 2) (String.length s - i - 2) in
        (* Lexicographic comparison; TODO this is bad, do better... *)
        lower <= infraction && infraction <= upper


(***********************
 * Computing penalties *
 ***********************)

(* We annotate each penalty with the regulation that justifies it. *)
type outcome = (violation * (regulation * penalties) list) list

let call f infraction date age priors =
  let must = function
    | Some x -> x
    | None -> failwith (Printf.sprintf "For %s -- got an empty option" infraction)
  in
  let infraction = Conversions.statute_of_string infraction in
  match f with
  | N f -> f ()
  | V f -> f infraction
  | OD f ->
      let offense = { violation = infraction; date_of = must date } in
      let defendant = { age = integer_of_int (must age); priors = must priors } in
      f offense defendant

(* After the data has been converted from JS types to Catala representations,
   [compute] captures the main logic: for each infraction, find the set of
   regulations that apply, feed the data into Catala, then collect the results.
   *)
let compute (infractions: (string * date option) list) (age: int option) (priors: priors option): outcome =
  List.map (fun (infraction, date) ->
    Conversions.statute_of_string infraction, List.filter_map (fun (regulation, f) ->
      if applies regulation infraction then begin
        debug "%s applies to %s" regulation infraction;
        let p = call f infraction date age priors in
        Some (regulation, p)
      end else
        None
    ) all_regulations
  ) infractions

(*******************
 * Interop with JS *
 *******************)

(* The [get_*] functions convert JS types to option-based types suitable for
   [compute], above *)
class type js_offense = object
  method dateOf: Js.date Js.t Js.optdef Js.readonly_prop
  method violation: Js.js_string Js.t Js.readonly_prop
end

let get_offense (o: js_offense Js.t) =
  Js.to_string o##.violation,
  Option.map H.catala_date_of_js_date (Js.Optdef.to_option o##.dateOf)

class type js_input = object
  method violations: js_offense Js.t Js.js_array Js.t Js.readonly_prop
  method priors: js_offense Js.t Js.js_array Js.t Js.optdef Js.readonly_prop
  method age: int Js.optdef Js.readonly_prop
end

let get_input (o: js_input Js.t) =
  List.map get_offense (Array.to_list (Js.to_array o##.violations)),
  Option.map (fun priors ->
    Array.map (fun p ->
      let v, d = get_offense p in
      if d = None then
        failwith (Printf.sprintf "For prior violation %s, no date provided!" v);
      { violation = Conversions.statute_of_string v; date_of = Option.get d }
    ) (Js.to_array priors)
  ) (Js.Optdef.to_option o##.priors),
  Js.Optdef.to_option o##.age

(* The [mk_*] functions go in the other direction and embed the result of
   [compute] into suitable JS types *)
let mk_duration (d: duration) =
  let days, months, years = duration_to_days_months_years d in object%js
    val days = days
    val months = months
    val years = years
  end

let mk_imprisonment (i: imprisonment) = object%js
  val min_days = mk_duration i.min_days
  val max_days = mk_duration i.max_days
end

let mk_fine (i: fine) = object%js
  val min_fine = i.min_fine
  val max_fine = i.max_fine
end

let mk_fee (i: fee) = object%js
  val min_fee = i.min_fee
  val max_fee = i.max_fee
end

let rec mk_penalty (p: penalty) = object%js
  val kind = Js.string (match p with
    | Either _ -> "either"
    | One (Imprisonment _) -> "imprisonment"
    | One (Fine _) -> "fine"
    | One (Fee _) -> "fee"
    | One (LoseRightToDriveUntil18 _) -> "lose_right_to_drive_until_18")

  val fine =
    match p with
    | One (Fine f) -> Js.Optdef.return (mk_fine f)
    | _ -> Js.undefined

  val fee =
    match p with
    | One (Fee f) -> Js.Optdef.return (mk_fee f)
    | _ -> Js.undefined

  val imprisonment =
    match p with
    | One (Imprisonment f) -> Js.Optdef.return (mk_imprisonment f)
    | _ -> Js.undefined

  val either =
    match p with
    | Either ps -> Js.Optdef.return (Js.array (Array.map (fun p -> mk_penalty (One p)) ps))
    | _ -> Js.undefined
end

let mk_annotated_penalty (r: string) (ps: penalties) = object%js
  val regulation = Js.string r
  val penalties = Js.array (Array.map mk_penalty ps)
end

let mk_one_outcome (v: violation) (ps: (regulation * penalties) list) = object%js
  val violation = Js.string (Conversions.string_of_statute v)
  val penalties =
    Js.array (Array.of_list (List.map (fun (r, p) ->
      mk_annotated_penalty r p
    ) ps))
end

let mk_outcome (o: outcome) =
  Js.array (Array.of_list (List.map (fun (v, ps) -> mk_one_outcome v ps) o))

let _ =
  Js.export_all (object%js
    method computePenalties (input: js_input Js.t): _ Js.t =
      debug "[Wrapper.ml] computing penalties";
      let violations, priors, age = get_input input in
      debug "[Wrapper.ml] input translated";
      let outcome = compute violations age priors in
      mk_outcome outcome
  end)

let _ =
  print_endline "[Wrapper.ml] loaded"
