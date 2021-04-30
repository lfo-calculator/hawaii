# Add here the set of statutes that are ready and working in Catala
# TODO: once all of them in the directory are done, replace with a wildcard
ML	= main.ml config.ml conversions.ml
CATALA	?= catala --language=en
JS	= _build/default/wrapper.bc.js

all: $(JS)

.PRECIOUS: $(ML)

config.ml:
	echo "let base = \"$(shell pwd)\";;" > $@

../statutes.catala_en: ../../data/hawaii-regulations.json ../scratch/mk_statutes.ml
	ocaml ../scratch/mk_statutes.ml -catala $< -o $@

../conversions.ml: ../../data/hawaii-regulations.json ../scratch/mk_statutes.ml
	ocaml ../scratch/mk_statutes.ml -ocaml $< -o $@

main.ml: $(wildcard ../*.catala_en)
	$(CATALA) OCaml ../main.catala_en -o $@

%.run: ../%.catala_en
	$(CATALA) -s $(SCOPE) Interpret -t $<

$(JS): $(ML) Wrapper.ml
	dune build --profile=release
