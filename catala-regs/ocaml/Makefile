# All of these ML files are produced by the build
ML	= main.ml config.ml conversions.ml data.ml
CATALA	?= catala --language=en
JS	= _build/default/wrapper.bc.js
JSON	= ../../data/hawaii-regulations.json
SCRIPT	= ../scratch/mk_statutes.ml

all: $(JS)

.PRECIOUS: $(ML)

config.ml:
	echo "let base = \"$(shell pwd)\";;" > $@

data.ml: $(JSON)
	echo "let json = {|" > $@
	cat $(JSON) >> $@
	echo "|}" >> $@

../infractions.catala_en: $(JSON) $(SCRIPT)
	ocaml $(SCRIPT) -catala $< -o $@

conversions.ml: $(JSON) $(SCRIPT)
	ocaml $(SCRIPT) -ocaml $< -o $@

main.ml: $(wildcard ../*.catala_en)
	$(CATALA) OCaml ../main.catala_en -o $@

%.run: ../%.catala_en
	$(CATALA) -s $(SCOPE) Interpret -t $<

$(JS): $(ML) Wrapper.ml
	dune build --profile=release
