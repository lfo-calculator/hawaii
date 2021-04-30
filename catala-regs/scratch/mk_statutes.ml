(* This script takes a JSON list of statutes, and from it generates a Catala file declaring a
   corresponding type of violations.

   Note that this script makes one *KEY* hypothesis: if a JSON entry applies to multiple
   infractions, that is, its "applies" field is of the form "*" or "foo .. bar", then we assume that
   this statute is exclusively concerned with penalties, and does not constitute on its own an
   infraction. Examples of this include: 286-136, 607-4, and so on.
*)

#use "topfind"
#require "yojson"
#require "batteries"

let source = ref ""
let destination = ref ""
type lang = OCaml | Catala
let format = ref OCaml

let _ =
  let usage = Printf.sprintf "%s [-ocaml|-catala] <file>" Sys.argv.(1) in
  Arg.parse [
    "-o", Arg.Set_string destination, " Set output file";
    "-ocaml", Arg.Unit (fun () -> format := OCaml), " Output OCaml string_of_*";
    "-catala", Arg.Unit (fun () -> format := Catala), " Output Catala enumeration";
  ] (fun f -> if !source = "" then source := f else failwith "Only one input file thanks") usage

let print_prologue dst =
  match !format with
  | Catala ->
      Printf.fprintf dst {|## List of known statutes, auto-generated from %s

> Begin metadata

```catala
declaration enumeration Violation:
|} !source
  | OCaml ->
      Printf.fprintf dst "open Main\n\nlet string_of_statute = function\n"

let print_one dst as_string as_catala comment =
  match !format with
  | Catala ->
      Printf.fprintf dst "  -- Section%s	# %s\n" as_catala comment
  | OCaml ->
      Printf.fprintf dst "  | Section%s -> \"%s\" (* %s *)\n" as_catala as_string comment

let print_epilogue dst =
  match !format with
  | Catala ->
      Printf.fprintf dst "```\n"
  | OCaml ->
      ()

let _ =
  let regs = Yojson.Safe.from_channel (open_in !source) in
  let dst = open_out !destination in
  let assert_string = function `String s -> s | _ -> failwith "not a string" in
  print_prologue dst;
  let regs = match regs with `List regs -> regs | _ -> failwith "not a list" in
  List.iter (function
    | `Assoc l ->
        let reg = assert_string (List.assoc "regulation" l) in
        let sec = Filename.chop_suffix (assert_string (List.assoc "catala_url" l)) ".catala_en" in
        let is_generic =
          try
            let applies = assert_string (List.assoc "applies" l) in
            applies = "*" ||
            (ignore (BatString.find applies ".."); true)
          with Not_found ->
            false
        in
        if not is_generic then
          let constr = BatString.replace_chars (function '.' -> "_" | '-' -> "_" | x -> String.make 1 x) sec in
          print_one dst sec constr reg
    | _ ->
        failwith "not an assoc"
  ) regs;
  print_epilogue dst
