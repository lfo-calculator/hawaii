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
type penalties = penalty array
type section = string
type infraction = violation

(* N: none
 * V: violation
 * OP: offense + defendant + two priors in past five years *)
type computation =
  | N of (unit -> penalties)
  | V of (violation -> penalties)
  | VDP of (violation -> defendant -> bool -> penalties)

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
  "286-136", VDP (fun v d p ->
    let out = s_286_136 {
      violation_in = H.thunk v;
      defendant_in = H.thunk d;
      max_fine_in = H.no_input;
      min_fine_in = H.no_input;
      max_days_in = H.no_input;
      two_violations_past_five_years_in = H.thunk p;
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

type metadata = {
  title: string;
  url: string;
  violation: bool;
}

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
  string

(* TODO: rollout actual parsers *)
let section_leq s1 s2 =
  (* 291C-11.3 *)
  let parse_section s =
    let i = String.index s '-' in
    let l = String.sub s 0 i in
    let r = String.sub s (i + 1) (String.length s - i - 1) in
    let l1, l2 =
      let maybe_letter = String.get l (String.length l - 1) in
      if 'A' <= maybe_letter && maybe_letter <= 'Z' then
        int_of_string (String.sub l 0 (String.length l - 1)), maybe_letter
      else
        int_of_string l, '0'
    in
    let r1, r2 =
      try
        let i = String.index r '.' in
        int_of_string (String.sub r 0 i), int_of_string (String.sub r (i + 1) (String.length r - i - 1))
      with Not_found ->
        int_of_string r, 0
    in
    l1, l2, r1, r2
  in
  parse_section s1 <= parse_section s2


let string_of_applies = function
  | Self -> "self"
  | All -> "*"
  | Ranges rs ->
      String.concat "," (List.map (fun (lower, upper) -> Printf.sprintf "%s..%s" lower upper) rs)

let assert_string = function `String s -> s | _ -> failwith "not a string"
let assert_list = function `List s -> s | _ -> failwith "not a list"
let assert_assoc = function `Assoc s -> s | _ -> failwith "not an assoc"
let assert_bool = function `Bool s -> s | _ -> failwith "not an bool"

let find haystack needle =
  let r = Str.regexp (Str.quote needle) in
  Str.search_forward r haystack 0

let parse_need = assert_string

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
  let title = assert_string (List.assoc "regulation" r) in
  let url = assert_string (List.assoc "reg_url" r) in
  let violation = assert_bool (List.assoc "violation" r) in
  let metadata = { title; url; violation } in
  try
    let needs = match List.assoc_opt "needs" r with
      | Some needs -> parse_needs needs
      | None -> []
    in
    let applies = parse_applies (List.assoc "applies" r) in
    match applies with
    | None -> Some (section, None, metadata)
    | Some applies -> Some (section, Some { applies; needs; section }, metadata)
  with e ->
    debug "Cannot parse regulation %s: %s" section (Printexc.to_string e);
    None

let parse_json (json: Yojson.Safe.t) =
  let regs = json in
  let regs = assert_assoc regs in
  let regs = List.assoc "regulations" regs in
  let regs = assert_list regs in
  List.filter_map parse_regulation regs

(* This contains only regulations that have computational content, i.e. those
   for which [applies] is not "0". *)
let regulation_of_section: (string, regulation) Hashtbl.t =
  Hashtbl.create 41

let metadata_of_section: (string, metadata) Hashtbl.t =
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
        section_leq lower infraction && section_leq infraction upper
      in
      List.exists applies rs

let init (json: Yojson.Safe.t) =
  debug "[init] parsing JSON object";
  let json = parse_json json in
  (* Fill the section (e.g. "286-136") --> regulation (e.g. { applies = "..." }) mapping. *)
  debug "[init] initializing mapping from sections to regulation objects";
  List.iter (fun (s, r, _) ->
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
  debug "[init] initializing metadata";
  List.iter (fun (s, _, m) ->
    Hashtbl.add metadata_of_section s m
  ) json;
  (* Fill the violation (e.g. "286-135") --> sections (e.g. "286-136"; "607-4") mapping. *)
  debug "[init] initializing mapping from violations to relevant sections";
  List.iter (fun (violation, _, m) ->
    if m.violation then
      let relevant = Hashtbl.fold (fun section reg acc ->
        if applies reg violation then
          (* let _ = debug "%s (%s) applies to %s" section reg.section violation in *)
          section :: acc
        else
          (* let _ = debug "%s (%s, %s) DOES NOT apply to %s" section (string_of_applies reg.applies) reg.section violation in *)
          acc
      ) regulation_of_section [] in
      Hashtbl.add sections_of_violation violation relevant
  ) json

let lookup s =
  try
    Hashtbl.find regulation_of_section s
  with Not_found as e ->
    debug "Missing entry in the section --> regulation table: %s" s;
    raise e

let lookup_violation s =
  try
    Hashtbl.find sections_of_violation s
  with Not_found as e ->
    debug "Missing entry in the violation --> relevant sections table: %s" s;
    raise e

let lookup_metadata s =
  try
    Hashtbl.find metadata_of_section s
  with Not_found as e ->
    debug "Missing entry in the section --> metadata table: %s" s;
    raise e

(************************************
 * Computing required relevant info *
 ************************************)

module NS = Set.Make(struct
  type t = need
  let compare = compare
end)

let is_generic = function
  | "is_construction" -> true
  | "age" -> true
  | "two_priors_past_five_years" -> false
  | x ->
      debug "Unknown value for the `needs` field: %s" x;
      raise Not_found

(* [relevant v] returns:
 * - a set of /generic/ information required to compute the penalties associated
 *   to violation v; generic information is provided once and for all, e.g. the
 *   defendant's current age
 * - an associative list of /contextual/ information that only make sense in the
 *   context of violation [v], e.g. whether there were two identical violations
 *   in the past five years; such contextual annotations come annotated with
 *   their corresponding regulation *)
let relevant violation =
  let sections = lookup_violation violation in
  let generic_needs, specific_needs = List.fold_left (fun (generic, specific) section ->
    let regulation = lookup section in
    let g, s = List.partition is_generic regulation.needs in
    NS.union generic (NS.of_list g), (regulation, s) :: specific
  ) (NS.empty, []) sections in
  generic_needs, specific_needs

type relevant = {
  generic: NS.t;
  contextual: (section * breakdown) list;
}

and breakdown = (regulation * needs) list

let relevant_many violations: relevant =
  let generic, contextual = List.fold_left (fun (generic, contextual) violation ->
    let g, c = relevant violation in
    NS.union g generic, (violation, c) :: contextual
  ) (NS.empty, []) violations in
  { generic; contextual }


(***********************
 * Computing penalties *
 ***********************)

type need_ =
  | Age of int
  | TwoPriorsWithinPastFiveYears of bool
  | IsConstruction of bool

type needs_ =
  need_ list

(* We annotate each penalty with the regulation that justifies it. *)
type outcome = (violation * (section * penalties) list) list

let call f infraction generic_needs contextual_needs =
  let infraction = Conversions.statute_of_string infraction in
  match f with
  | N f -> f ()
  | V f -> f infraction
  | VDP f ->
      let age = List.find_map
        (function Age x -> Some x | _ -> None)
        generic_needs
      in
      let has_priors = List.find_map
        (function TwoPriorsWithinPastFiveYears x -> Some x | _ -> None)
        contextual_needs
      in
      let defendant = { age = integer_of_int (Option.get age) } in
      f infraction defendant (Option.get has_priors)

(* After the data has been converted from JS types to Catala representations,
   [compute] captures the main logic: for each infraction, find the set of
   regulations that apply, feed the data into Catala, then collect the results.

   TODO: bool option = has_priors -- introduce a data structure for generic and
   contextual information? with labels?
   *)
let compute (infractions: (string * needs_) list) (generic: needs_): outcome =
  List.map (fun (infraction, contextual_needs) ->
    Conversions.statute_of_string infraction, List.filter_map (fun (regulation, f) ->
      if applies (lookup regulation) infraction then begin
        debug "%s applies to %s" regulation infraction;
        let p = call f infraction generic contextual_needs in
        Some (regulation, p)
      end else
        None
    ) computation_of_reg
  ) infractions

(*******************
 * Interop with JS *
 *******************)

let get_assoc (o: _ Js.t) =
  let ks = Array.to_list (Js.to_array (Js.object_keys o)) in
  List.map (fun k -> Js.to_string k, Js.Opt.to_option (Js.Unsafe.get o k)) ks

let mk_assoc (kvs: (string * 'a option) list): _ Js.t =
  let o = object%js end in
  let o = Js.Unsafe.coerce o in
  List.iter (fun (k, v) -> Js.Unsafe.set o k (Js.Opt.option v)) kvs;
  o

let default = function
  | "age" -> Obj.magic 18
  | "is_construction"
  | "two_priors_past_five_years" -> Js.bool false
  | _ -> failwith "unknown need"

let mk_needs ns: _ Js.t =
  mk_assoc (List.map (fun n -> n, Some (default n)) ns)

(* Step 1: compute relevant information needed for a given set of violations *)
let mk_relevant (relevant: relevant): _ Js.t =
  object%js
    val contextual =
      (* { "286-135": { *)
      mk_assoc (List.map (fun (v, reg_and_needs) ->
        let m = lookup_metadata v in
        v, Some (object%js
          (* "title": "Renting motor vehicle to another" *)
          val title = Js.string m.title;
          val url = Js.string m.url;
          (* "relevant": { *)
          val relevant = mk_assoc (List.map (fun (r, needs) ->
            let m = lookup_metadata r.section in
            (* "286-135": { *)
            r.section, Some (object%js
              (* "title": "Penalties" *)
              val title = Js.string m.title;
              val url = Js.string m.url;
              (* "needs": "two_priors_past_five_years" *)
              val needs = mk_needs needs
            end)
            (* } *)
          ) reg_and_needs)
          (* } *)
        end)
      ) relevant.contextual)
      (* }} *)

    val needs =
      mk_needs (List.of_seq (NS.to_seq relevant.generic))
  end

(* Step 2: extract enough relevant information from the object above, now with
   null fields filled out. *)
let get_need (kv: string * _ Js.t) =
  let s, n = kv in
  match s with
  | "age" -> Age (Obj.magic n)
  | "two_priors_past_five_years" -> TwoPriorsWithinPastFiveYears (Js.to_bool n)
  | "is_construction" -> IsConstruction (Js.to_bool n)
  | _ -> debug "Unknown need field from JS: %s" s; raise Not_found

let get_needs o =
  List.map get_need
    (List.filter_map (fun (k, v) ->
      match v with Some v -> Some (k, v) | None -> None
    ) (get_assoc o##.needs))

let get_input (o: _ Js.t) =
  let generic_needs = get_needs o in
  let sections = get_assoc o##.contextual in
  let sections = List.map (fun (v, o) ->
    let o = Option.get o in
    let relevant = get_assoc o##.relevant in
    (* In the object sent from OCaml to JS after the first phase, requirements
       are grouped by regulation. We discard this grouping here. *)
    let relevant = List.flatten (List.map (fun (_, o) -> get_needs (Option.get o)) relevant) in
    v, relevant
  ) sections in
  sections, generic_needs

(* The [mk_*] functions go in the other direction and embed the result of
   [compute] into suitable JS types *)
let mk_duration (d: duration) =
  let years, months, days = duration_to_days_months_years d in object%js
    val days = days
    val months = months
    val years = years
  end

let mk_imprisonment (i: imprisonment) = object%js
  val min = mk_duration i.min_days
  val max = mk_duration i.max_days
end

let mk_fine (i: fine) = object%js
  val min = i.min_fine
  val max = i.max_fine
end

let mk_fee (i: fee) = object%js
  val min = i.min_fee
  val max = i.max_fee
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

let mk_annotated_penalty (r: string) (ps: penalties) =
  let m = lookup_metadata r in
  object%js
    val regulation = Js.string r
    val title = Js.string m.title
    val url = Js.string m.url
    val penalties = Js.array (Array.map mk_penalty ps)
  end

let mk_one_outcome (v: violation) (ps: (section * penalties) list) =
  let v = Conversions.string_of_statute v in
  let m = lookup_metadata v in
  object%js
    val violation = Js.string v
    val title = Js.string m.title
    val url = Js.string m.url
    val penalties =
      Js.array (Array.of_list (List.map (fun (r, p) ->
        mk_annotated_penalty r p
      ) ps))
  end

let mk_outcome (o: outcome) =
  Js.array (Array.of_list (List.map (fun (v, ps) -> mk_one_outcome v ps) o))

let _ =
  Js.export_all (object%js
    method computePenalties (input: _ Js.t): _ Js.t =
      debug "[Wrapper.ml] computing penalties";
      let contextual, generic = get_input input in
      debug "[Wrapper.ml] input translated";
      let outcome = compute contextual generic in
      mk_outcome outcome

    method relevant (input: Js.js_string Js.t Js.js_array Js.t): _ Js.t =
      let input = List.map Js.to_string (Array.to_list (Js.to_array input)) in
      mk_relevant (relevant_many input)
  end)

let _ =
  init (Yojson.Safe.from_string Data.json);
  print_endline "[Wrapper.ml] loaded"
