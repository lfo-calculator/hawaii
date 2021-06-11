# All of these ML files are produced by the build
SHELL	= /bin/bash
ML	= main.ml conversions.ml data.ml
CATALA	?= catala --language=en
JS	= _build/default/wrapper.bc.js
JSON	= ../../data/hawaii-regulations.json
SCRIPT	= ../scratch/mk_statutes.ml

all: $(JS)
	sed -i.bak "s/.*version.*$$/  \"version\": \"0.0.$(shell date +'%Y%m%d%H%M')\",/g" package.json

.PRECIOUS: $(ML)

data.ml: $(JSON)
	echo "let json = {|" > $@
	cat $(JSON) >> $@
	echo "|}" >> $@

../infractions.catala_en: $(JSON) $(SCRIPT)
	ocaml $(SCRIPT) -catala $< -o $@

conversions.ml: $(JSON) $(SCRIPT)
	ocaml $(SCRIPT) -ocaml $< -o $@

main.ml: $(wildcard ../*.catala_en) ../infractions.catala_en
	$(CATALA) OCaml ../main.catala_en -o $@

%.run: ../%.catala_en
	$(CATALA) -s $(SCOPE) Interpret -t $<

$(JS): $(ML) Wrapper.ml
	dune build --profile=release

clean:
	rm -rf _build $(ML)
