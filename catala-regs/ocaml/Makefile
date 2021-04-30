# Add here the set of statutes that are ready and working in Catala
# TODO: once all of them in the directory are done, replace with a wildcard
ML	= main.ml config.ml conversions.ml
CATALA	?= catala --language=en
JS	= _build/default/wrapper.bc.js
JSON	= ../../data/hawaii-regulations.json
SCRIPT	= ../scratch/mk_statutes.ml

all: $(JS)

.PRECIOUS: $(ML)

config.ml:
	echo "let base = \"$(shell pwd)\";;" > $@

../json.ml: $(JSON)
	echo -e "let data = {|\n" > $@
	cat $(JSON) >> $@
	echo "|}" >> $@

../infractions.catala_en: $(JSON) $(SCRIPT)
	ocamlfind ocaml $(SCRIPT) -catala $< -o $@

../conversions.ml: $(JSON) $(SCRIPT)
	ocamlfind ocaml $(SCRIPT) -ocaml $< -o $@

main.ml: $(wildcard ../*.catala_en)
	$(CATALA) OCaml ../main.catala_en -o $@

%.run: ../%.catala_en
	$(CATALA) -s $(SCOPE) Interpret -t $<

$(JS): $(ML) Wrapper.ml
	dune build --profile=release
