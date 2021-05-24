# hawaii

Data and related structures for processing Hawaii statutes for LFOs

# Building

- install OPAM
- `opam init && opam install catala`
- OSX: make sure you have `gdate` and `gsed` installed (`brew install coreutils
  gnu-sed`)
- `make` in `catala-regs/ocaml`
- follow instructions in `front-end`
- make sure you do `yarn upgrade hawaii-lfo` to pick up any changes
