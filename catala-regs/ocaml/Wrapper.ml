(* Hawaii LFO regulations.
   Copyright (C) 2021 Microsoft, Jonathan Protzenko <protz@microsoft.com>

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

(* Some terminology:
  - section: string representation (e.g. "286-136")
  - computation: an OCaml function extracted from Catala
  - regulation: internal representation built from the JSON data
*)

(* Here, we build a table that maps sections to their corresponding Catala
   function. *)
type priors = offense array
type penalties = penalty array
type section = string
type infraction = violation

(* N: none
 * V: violation
 * OP: offense + defendant (priors + age) *)
type computation =
  | N of (unit -> penalties)
  | V of (violation -> penalties)
  | OD of (offense -> defendant -> penalties)

(* Associative list that, given a section (whose [applies] field is not [0]),
   returns the corresponding computation. *)
let computation_of_reg: (section * computation) list = [
  "291-10", N (fun () ->
    let out = s_291_10 {
      penalties_in = H.no_input
    } in
    out.penalties_out);
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

(* Our structured representation of a regulation. *)
type regulation = {
  applies: applies;
  needs: needs;
  section: string;
}

and applies =
  | Self
  | All
  | Ranges of range list

and range =
  section * section

and needs =
  need list

and need =
  | Age
  | Priors
  | IsConstruction

let assert_string = function `String s -> s | _ -> failwith "not a string"
let assert_list = function `List s -> s | _ -> failwith "not a list"
let assert_assoc = function `Assoc s -> s | _ -> failwith "not an assoc"

let find haystack needle =
  let r = Str.regexp (Str.quote needle) in
  Str.search_forward r haystack 0

let parse_need (need: Yojson.Safe.t) =
  let need = assert_string need in
  match need with
  | "age" -> Age
  | "priors" -> Priors
  | "is_construction" -> IsConstruction
  | _ -> failwith ("Unknown value in the need field: " ^ need)

let parse_needs (needs: Yojson.Safe.t) =
  let needs = assert_list needs in
  List.map parse_need needs

let parse_applies (applies: Yojson.Safe.t) =
  let applies = assert_string applies in
  match applies with
  | "0" -> None
  | "self" -> Some Self
  | "*" -> Some All
  | applies ->
      (* TODO: fixme here for a list and possibly singleton ranges *)
      let i = find applies ".." in
      let lower = String.sub applies 0 i in
      let upper = String.sub applies (i + 2) (String.length applies - i - 2) in
      Some (Ranges [ lower, upper ])

let parse_regulation (r: Yojson.Safe.t) =
  let r = assert_assoc r in
  let section = assert_string (List.assoc "section" r) in
  let needs = parse_needs (List.assoc "needs" r) in
  let applies = parse_applies (List.assoc "applies" r) in
  match applies with
  | None -> section, None
  | Some applies -> section, Some { applies; needs; section }

let parse_json (json: Yojson.Safe.t) =
  let regs = Yojson.Safe.from_string Data.json in
  let regs = assert_assoc regs in
  let regs = List.assoc "regulations" regs in
  let regs = assert_list regs in
  List.map parse_regulation regs

(* This contains only regulations that have computational content, i.e. those
   for which [applies] is not "0". *)
let regulation_of_section: (string, regulation) Hashtbl.t =
  Hashtbl.create 41

let sections_of_violation =
  Hashtbl.create 41


(* [applies s1 s2] determines whether regulation [s1] applies to the infraction [s2] *)
let applies reg infraction =
  match reg.applies with
  | Self ->
      (* See ../../data/README.md: we assume the penalty for the infraction is in the
         relevant section *)
      reg.section = infraction
  | All ->
      true
  | Ranges rs ->
      let applies (lower, upper) =
        (* Lexicographic comparison; TODO this is bad, do better... *)
        lower <= infraction && infraction <= upper
      in
      List.exists applies rs

let init (json: Yojson.Safe.t) =
  let json = parse_json json in
  (* Fill the section (e.g. "286-136") --> regulation (e.g. { applies = "..." }) mapping. *)
  List.iter (fun (s, r) ->
    match r with
    | Some r ->
        Hashtbl.add regulation_of_section s r;
        begin match List.assoc_opt s computation_of_reg with
        | None ->
            debug "[init] %s has no entry in the Catala computation table" s
        | Some _ -> ()
        end
    | None ->
        ()
  ) json;
  (* Fill the violation (e.g. "286-135") --> sections (e.g. "286-136"; "607-4") mapping. *)
  List.iter (fun (violation, r) ->
    match r with
    | None ->
        let relevant = Hashtbl.fold (fun section reg acc ->
          if applies reg violation then
            section :: acc
          else
            acc
        ) regulation_of_section [] in
        Hashtbl.add sections_of_violation violation relevant
    | Some _ -> ()
  ) json

let lookup =
  Hashtbl.find regulation_of_section

module NS = Set.Make(struct
  type t = need
  let compare = compare
end)

(* [relevant r1] returns the set of regulations [rs], such that for each [r] in
   [rs], we have [applies r r1] *)
let relevant violation =
  let sections = Hashtbl.find sections_of_violation violation in
  let needs = List.fold_left (fun acc section ->
    NS.union acc (NS.of_list (lookup section).needs)
  ) NS.empty sections in
  sections, (List.of_seq (NS.to_seq needs))


(***********************
 * Computing penalties *
 ***********************)

(* We annotate each penalty with the regulation that justifies it. *)
type outcome = (violation * (section * penalties) list) list

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
      if applies (lookup regulation) infraction then begin
        debug "%s applies to %s" regulation infraction;
        let p = call f infraction date age priors in
        Some (regulation, p)
      end else
        None
    ) computation_of_reg
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

let mk_one_outcome (v: violation) (ps: (section * penalties) list) = object%js
  val violation = Js.string (Conversions.string_of_statute v)
  val penalties =
    Js.array (Array.of_list (List.map (fun (r, p) ->
      mk_annotated_penalty r p
    ) ps))
end

let mk_outcome (o: outcome) =
  Js.array (Array.of_list (List.map (fun (v, ps) -> mk_one_outcome v ps) o))

let mk_need n =
  Js.string (match n with
  | Age -> "age"
  | Priors -> "priors"
  | IsConstruction -> "is_construction"
  )

let mk_relevant (r: string list * needs) =
  object%js
    val sections = Js.array (Array.of_list (List.map Js.string (fst r)))
    val needs = Js.array (Array.of_list (List.map mk_need (snd r)))
  end

let _ =
  Js.export_all (object%js
    method computePenalties (input: js_input Js.t): _ Js.t =
      debug "[Wrapper.ml] computing penalties";
      let violations, priors, age = get_input input in
      debug "[Wrapper.ml] input translated";
      let outcome = compute violations age priors in
      mk_outcome outcome

    method relevant (input: Js.js_string Js.t): _ Js.t =
      mk_relevant (relevant (Js.to_string input))
  end)

let _ =
  print_endline "[Wrapper.ml] loaded"
