.PHONY: publish console test

ELIXIR_DOCKER_IMAGE=elixir:1.14

PREFIX=priv
YMLs=$(wildcard $(PREFIX)/*.yml)
SCHEMAs=$(notdir $(basename $(YMLs)))

PUBLISH_DIR=publish


publish: mkdir $(SCHEMAs)

mkdir:
	mkdir -p $(PUBLISH_DIR)/

$(SCHEMAs): %: $(PREFIX)/%.yml
	echo $< $@
	ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load(ARGF))' < $< > $(PUBLISH_DIR)/schema-$@
	cp $< $(PUBLISH_DIR)/schema-$@-yaml


USER=dev
HOME_DIR=/home/dev
WORKDIR=$(HOME_DIR)/pipelines
INTERACTIVE_SESSION=\
          -v $$PWD/home_dir:$(HOME_DIR) \
          -v $$PWD/..:$(WORKDIR) \
          -e HOME=$(HOME_DIR) \
          -e MIX_ENV=test \
          --workdir=$(WORKDIR)/spec \
          -it $(ELIXIR_DOCKER_IMAGE) \

console:
	docker run $(INTERACTIVE_SESSION) /bin/bash

test:
	docker run --user=$(USER) $(INTERACTIVE_SESSION) \
          mix do local.hex --force, local.rebar --force, deps.get, test
