Master list of all the Hawaii regulations we cover (so far)
-----------------------------------------------------------

The JSON file in this directory contains a list of all the HRS (Hawaii Revised Statutes) regulations
we currently model and account for. The JSON file is partially auto-generated; see
[../catala-regs/scratch/SCRAPING.md].

Each entry contains at least:
- `regulation`: the name of the regulation,
- `reg_url`: a web-based readable version, and
- `catala_url`: the corresponding Catala source file, to be found in [../catala-regs].

Because we list *all* of the statutes we have modeled so far, this JSON file contains both:
- "regular" statutes, i.e. those that describe exactly one infraction; examples include 291-11.6
  mandatory use of seat belts;
- "meta" statutes, i.e. those that cover several infractions in one go; examples include 286-136,
  which covers everything between 286-85 and 286-135; or 607-4, which sets court fees and applies
  to every infraction.

To that end, each entry is decorated with an optional "applies" field, of the form:
- `*`, meaning the regulation is always relevant, e.g. 607-4;
- `X .. Y`, meaning the regulation covers section X (included) to section Y (included), e.g.
  286-136;
- `-`, meaning this does not have a corresponding Catala file, since the penalties for this
  particular section are specified in another section (e.g. 286-106 expired license, covered by
  286-136);
- finally, the absence of an `applies` field means that the regulation describes penalties for the
corresponding infraction, e.g. 291-11.6 mandatory use of seat belts.

From here on, meta-statutes have their `applies` field set to either `*` or `X .. Y`; and regular
statutes either have their `applies` field set to `-`, or do not have an `applies` field. We also
use "infraction" and "regular statute" interchangeably.

With those notions set, using the JSON file, we derive:
- the set of infractions (regular statutes) that can be recorded in the user interface;
- the Catala enumeration for all possible statutes (under version control in
  [../catala-regs/statutes.catala]
