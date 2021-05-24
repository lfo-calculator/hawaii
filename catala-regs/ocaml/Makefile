# All of these ML files are produced by the build
SHELL	= /bin/bash
ML	= main.ml config.ml conversions.ml data.ml
CATALA	?= catala --language=en
JS	= _build/default/wrapper.bc.js
JSON	= ../../data/hawaii-regulations.json
SCRIPT	= ../scratch/mk_statutes.ml
SED	= $(shell which gsed &>/dev/null && echo "gsed" || echo "sed")
DATE	= $(shell which gdate &>/dev/null && echo "gdate" || echo "date")

all: $(JS)
	$(SED) -i "s/.*version.*$$/  \"version\": \"0.0.$(shell $(DATE) +'%4Y%m%d%H%M')\",/g" package.json

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

main.ml: $(wildcard ../*.catala_en) ../infractions.catala_en
	$(CATALA) OCaml ../main.catala_en -o $@

%.run: ../%.catala_en
	$(CATALA) -s $(SCOPE) Interpret -t $<

$(JS): $(ML) Wrapper.ml
	dune build --profile=release
