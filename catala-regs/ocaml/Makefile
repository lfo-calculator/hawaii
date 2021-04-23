# Add here the set of statutes that are ready and working in Catala
# TODO: once all of them in the directory are done, replace with a wildcard
FILES	=  607-4 291-11-6 286-136
ML	= $(addsuffix .ml,$(FILES))
CATALA	?= catala --language=en
JS	= _build/default/wrapper.bc.js

all: $(JS)

%.ml: ../%.catala_en
	$(CATALA) OCaml $<

%.run: ../%.catala_en
	$(CATALA) -s $(SCOPE) Interpret -t $<

$(JS): $(ML) Wrapper.ml
	dune build --profile=release
