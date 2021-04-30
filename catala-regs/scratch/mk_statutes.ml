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

let source = Sys.argv.(1)

let _ =
  let regs = Yojson.Safe.from_channel (open_in source) in
  let assert_string = function `String s -> s | _ -> failwith "not a string" in
  Printf.printf {|## List of known statutes, auto-generated from %s

> Begin metadata

```catala
declaration enumeration Violation:
|} source;
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
          let sec = BatString.replace_chars (function '.' -> "_" | '-' -> "_" | x -> String.make 1 x) sec in
          Printf.printf "  -- Section%s	# %s\n" sec reg
    | _ ->
        failwith "not an assoc"
  ) regs;
  Printf.printf "```\n"
