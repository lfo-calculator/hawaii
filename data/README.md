# Hawaii Regulation Coverage (so far)

The JSON file in this directory contains a list of all the HRS (Hawaii Revised
Statutes) regulations reviewed to date. The JSON file is partially
auto-generated; see [../catala-regs/scratch/SCRAPING.md]. It constitutes a
"central" reference for this project and should be edited with care.

Each entry contains at the following keys:

- `section`: the name of the section (i.e. the §), generally of the form `XX-YY[.ZZ]`
   -- if it exists, the corresponding Catala source file will be found in
   `../catala-regs/<section>.md`.
- `regulation`: human-readable title for the regulation,
- `reg_url`: a web-based readable version,
- `applies`, and
- `violation`.

The `applies` field allows separating regulations into different categories.
Intuitively, it answer the question "which violations does this regulation apply
to".

- `0`: this regulation doesn't contain any penalties
- `self`: this regulation contains within itself the associated penalty
- `(X..Y)`: this is a "range" regulation but establishes penalties for violation
  `X` (included) to violation `Y` (included).
- `*`: this is a "wildcard" regulation, which describes no infraction, but
  establishes penalties for all violations *within* a specific statute.

The `violation` field is a boolean that indicates whether the regulation
describes an enforceable violation; a regulation appears in the user interface
if and only if it is also a violation.

Some examples:
- 286-108, "Examination of applicants", merely describes how driving tests should
  be conducted. It does not contain penalties (`applies = "0"`); and it does not
  describe an infraction either (`violation = false`). It will therefore be
  ignored both by the frontend and the backend. This is an irrelevant regulation
  for our purposes, but we keep it in the JSON file to indicate we have
  suitably reviewed it. Repealed regulations behave the same way.
- 291-11.6, "Mandatory use of seat belts", is a chargeable offense, therefore
  `violation = true`. Furthermore, the regulation also contains the
  corresponding fines and fees for the violation, therefore `applies = "self"`.
- 286-136, "Penalties", describes the penalties for violations 286-83 to
  286-135. Therefore, `applies = "(286-83..286-135)"`. However, regulation
  286-136 is not a violation in itself; in other words, someone cannot be
  charged for having violated 286-136. Therefore, `violation = false`.
- 607-4, which sets court fees, applies to every violation. Therefore, `applies
  = "*"`; but here, too, 607-4 is not an infraction in itself, so `violation =
  false`.

The [../catala-regs] directory therefore contains Catala files for all
regulations, except those for which `applies = "0"`, which contain no semantic
content.

Using the JSON file, we derive:

- the set of violations for the user interface to present to the user,
  i.e. those for which `violation = true`
- the Catala enumeration for all possible violations, produced by the build as
  [../catala-regs/infractions.catala]
- the OCaml conversion function from a string (the `section` field) to the
  corresponding data type (as extracted by Catala), currently under version
  control in [../catala-regs/ocaml/conversions.ml]
