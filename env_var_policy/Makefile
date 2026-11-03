.PHONY: test format

ELIXIR_IMAGE ?= elixir:1.11

# On CI the job provides Elixir (sem-version), so run directly.
ifneq ($(CI),)
RUN =
else
RUN = docker run --rm -v $(PWD):/app -w /app -e MIX_ENV=test $(ELIXIR_IMAGE)
endif

test:
	$(RUN) mix test

format:
	$(RUN) mix format --check-formatted
