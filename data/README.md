Master list of all the Hawaii regulations we cover (so far)
-----------------------------------------------------------

The JSON file in this directory contains a list of all the HRS (Hawaii Revised
Statutes) regulations we have reviewed. The JSON file is partially
auto-generated; see [../catala-regs/scratch/SCRAPING.md]. It constitutes a
"central" reference for this project and should be edited with care.

Each entry contains at the following keys:
- `section`: the name of the section (i.e. the §), generally of the form `XX-YY[.ZZ]`
   -- if it exists, the corresponding Catala source file will be found in
   `../catala-regs/<section>.md`.
- `regulation`: human-readable title for the regulation,
- `reg_url`: a web-based readable version, and
- `applies`.

The `applies` field allows separating regulations into different categories,
depending on its value.
- `x` (strike-out): this is a "useless" regulation for our purposes and will be
  ignored both by the UI and the backend. Typically, the section is either
  repealed, or describes neither a violation or a penalty. Example: 286-108,
  "Examination of applicants", which merely describes how driving tests should
  be conducted.
- `0`: this is a "violation-only" regulation, and describes a violation without
  stating the penalties associated to it. Typically, the penalties for this
  particular violation are specified in another regulation. Example: 286-106,
  "expired license", is violation whose penalty is determined by by 286-136.
- `1` (self): this is a "self-contained" regulation, and describes both a
  violation and the accompanying penalty. Example: 291-11.6 "mandatory use of
  seat belts".
- `X..Y`: this is a "range" regulation, which describes no infraction, but
  establishes penalties for violation `X` (included) to violation `Y`
  (included). Example: 286-136, "Penalties", applies to `286-83..286-135`.
- `*`: this is a "wildcard" regulation, which describes no infraction, but
  establishes penalties for all violations. Example: 607-4, which sets court
  fees and applies to every violation.

Equipped with these distinctions, we maintain the following invariants:
- the [../catala-regs] directory contains Catala files for all regulations,
  except types `x` and `0`, which hold no computation content since neither of
  those establish penalties
- violations are defined to be regulations that have types `0` and `1`; these
  are chargeable offenses that appear in the user interface

Using the JSON file, we derive:
- the set of violations, for the user interface;
- the Catala enumeration for all possible violations, produced by the build as
  [../catala-regs/infractions.catala]
- the OCaml conversion function from a string (defined as `catala_url` stripped of its file
  extension) to the corresponding data type (as extracted by Catala), currently under version
  control in [../catala-regs/ocaml/conversions.ml]
