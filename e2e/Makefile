.PHONY: format test test.ui

SHELL := /bin/bash
export MIX_ENV ?= test
export BASE_DOMAIN ?= test.sonprem.com
export CLOUD_TEST_ENV_PREFIX ?= master
export CHROMEDRIVER_DIR ?= /usr/local/bin/chromedriver
export GITHUB_ORGANIZATION ?= rt-on-prem-tester-org
export GITHUB_REPOSITORY ?= e2e-tests
export GITHUB_BRANCH ?= refs/heads/main
export SEMAPHORE_ORGANIZATION ?= semaphore
export SEMAPHORE_BASE_DOMAIN ?= $(CLOUD_TEST_ENV_PREFIX).$(BASE_DOMAIN)
export SEMAPHORE_USER_EMAIL ?= root@example.com
export GOOGLE_APPLICATION_CREDENTIALS ?= /home/semaphore/creds.json

ifeq (test.ui,$(MAKECMDGOALS))
    export START_WALLABY=true
endif

gcloud.auth:
	gcloud config set project $(GOOGLE_PROJECT_NAME) --quiet && gcloud auth login --cred-file=$(GOOGLE_APPLICATION_CREDENTIALS)

console.ex: env.assert mix.prepare
	iex -S mix

format:
	SEMAPHORE_API_TOKEN="" \
	SEMAPHORE_USER_PASSWORD="" \
	mix format $(if $(CI), --check-formatted)

test: env.assert mix.prepare
	mix test $(if $(TEST_FILE),$(TEST_FILE),test/e2e/api)

test.ui: env.assert mix.prepare
	mix test $(if $(TEST_FILE),$(TEST_FILE),test/e2e/ui)

env.assert:
	[ -n "$$SEMAPHORE_API_TOKEN" ] || exit 1
	[ -n "$$SEMAPHORE_USER_PASSWORD" ] || exit 1

mix.prepare:
	mix local.hex --force --if-missing
	mix local.rebar --force --if-missing
	mix deps.get
