SOURCES = $(wildcard sources/*.md)
OUTS = $(patsubst sources/%.md, out/%.pdf, $(SOURCES))

all: $(SOURCES)
	@mkdir -p "out"
	@make $(OUTS)

$(OUTS): out/%.pdf : sources/%.md
	pandoc $< -o $@

.PHONY: clean
clean:
	rm -f out/*
