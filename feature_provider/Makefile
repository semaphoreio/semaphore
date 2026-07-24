.PHONY: docs test cover

# On CI the job provides the Erlang/Elixir under test (sem-version), so run
# commands directly. Locally, run in a docker container when docker is
# available, otherwise run directly.
ifneq ($(CI),)
define maybe_call_in_docker
	$1
endef
else
define maybe_call_in_docker
	$(if $(shell command -v docker 2> /dev/null), docker compose run --rm app $1, $1)
endef
endif

test: export MIX_ENV=test
test:
	$(call maybe_call_in_docker, $$(echo "mix do deps.get, test"))

docs: export MIX_ENV=test
docs:
	$(call maybe_call_in_docker, $$(echo "mix docs"))

cover: export MIX_ENV=test
cover:
	$(call maybe_call_in_docker, $$(echo "mix coveralls.lcov"))
