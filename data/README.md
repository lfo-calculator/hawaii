Master list of all the Hawaii regulations we cover (so far)
-----------------------------------------------------------

The JSON file in this directory contains a list of all the HRS (Hawaii Revised
Statutes) regulations we currently model and account for. The JSON file is
partially auto-generated; see [../catala-regs/scratch/SCRAPING.md].

Each entry contains at least the following keys:
- `regulation`: the name of the regulation,
- `reg_url`: a web-based readable version, and
- `catala_url`: the corresponding Catala source file, to be found in [../catala-regs].

Because we list *all* of the regulations we have modeled so far, this JSON file contains both:
- "normal" regulations, i.e. those that describe exactly one infraction;
  examples include 291-11.6 mandatory use of seat belts;
- "meta" regulations, i.e. those that cover several infractions in one go;
  examples include 286-136, which covers everything between 286-85 and 286-135;
  or 607-4, which sets court fees and applies to every infraction.

We thus distinguish between a *regulation* and an *infraction*. Every infraction
has a corresponding regulation, but not every regulation describes an
infraction.

To that end, each entry is decorated with an optional "applies" field, of the form:
- `*`, meaning the regulation applies to *any* infraction, e.g. 607-4;
- `X..Y`, meaning the regulation covers infraction X (included) to infraction Y (included), e.g.
  286-136, applies to `286-83..286-135`;
- `-`, meaning the regulation describes an infraction without specifying the
  penalties; this means that there is no corresponding Catala file, and that the
  penalties for this particular infraction are specified in another regulation
  (e.g. 286-106 "expired license", is covered by 286-136);
- finally, the absence of an `applies` field means that the regulation describes
  penalties for the corresponding infraction, e.g. 291-11.6 "mandatory use of
  seat belts", i.e. a one-to-one correspondence between infraction and
  regulation

We can now precisely characterise our earlier notions: "meta" regulations have
their `applies` field set to either `*` or `X..Y`; "normal" regulations either
have their `applies` field set to `-`, or do not have an `applies` field.
Therefore, a "normal" regulation is also an infraction (and vice-versa); we use
the two terms interchangeably.

With those notions set, using the JSON file, we derive:
- the set of infractions that can be recorded in the user interface;
- the Catala enumeration for all possible infractions, currently under version control in
  [../catala-regs/statutes.catala]
- the OCaml conversion function from a string (defined as `catala_url` stripped of its file
  extension) to the corresponding data type (as extracted by Catala), currently under version
  control in [../catala-regs/conversions.ml]
