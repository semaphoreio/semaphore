.PHONY: docs test cover

# If docker is installed, run the command in a docker container, otherwise run it directly
define maybe_call_in_docker
	$(if $(shell command -v docker 2> /dev/null), docker compose run --rm app $1, $1)
endef

test: MIX_ENV=test
test:
	$(call maybe_call_in_docker, $$(echo "mix do deps.get, test"))

docs: MIX_ENV=test
docs:
	$(call maybe_call_in_docker, $$(echo "mix docs"))

cover: MIX_ENV=test
cover:
	$(call maybe_call_in_docker, $$(echo "mix coveralls.lcov"))
