.PHONY: format test test.ui console.bash test.ui.docker

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
export PLATFORM ?= linux/arm64

ifeq (test.ui,$(MAKECMDGOALS))
    export START_WALLABY=true
endif

ifeq (test.ui.docker,$(MAKECMDGOALS))
    export START_WALLABY=true
endif

ifeq (console.bash,$(MAKECMDGOALS))
    export START_WALLABY=true
endif

gcloud.auth:
	gcloud config set project $(GOOGLE_PROJECT_NAME) --quiet && gcloud auth login --cred-file=$(GOOGLE_APPLICATION_CREDENTIALS)

console.ex: env.assert mix.prepare
	iex -S mix

# Start a bash shell in the Docker container
console.bash: env.assert
	docker compose run --rm \
		-e START_WALLABY=true \
		-e MIX_ENV=$(MIX_ENV) \
		-e BASE_DOMAIN=$(BASE_DOMAIN) \
		-e CLOUD_TEST_ENV_PREFIX=$(CLOUD_TEST_ENV_PREFIX) \
		-e GITHUB_ORGANIZATION=$(GITHUB_ORGANIZATION) \
		-e GITHUB_REPOSITORY=$(GITHUB_REPOSITORY) \
		-e GITHUB_BRANCH=$(GITHUB_BRANCH) \
		-e SEMAPHORE_ORGANIZATION=$(SEMAPHORE_ORGANIZATION) \
		-e SEMAPHORE_BASE_DOMAIN=$(SEMAPHORE_BASE_DOMAIN) \
		-e SEMAPHORE_USER_EMAIL=$(SEMAPHORE_USER_EMAIL) \
		-e SEMAPHORE_API_TOKEN=$(SEMAPHORE_API_TOKEN) \
		-e SEMAPHORE_USER_PASSWORD=$(SEMAPHORE_USER_PASSWORD) \
		e2e-tests sh

# Run UI tests in Docker
test.ui.docker: env.assert
	docker compose run --rm \
		-e START_WALLABY=true \
		-e MIX_ENV=$(MIX_ENV) \
		-e BASE_DOMAIN=$(BASE_DOMAIN) \
		-e CLOUD_TEST_ENV_PREFIX=$(CLOUD_TEST_ENV_PREFIX) \
		-e GITHUB_ORGANIZATION=$(GITHUB_ORGANIZATION) \
		-e GITHUB_REPOSITORY=$(GITHUB_REPOSITORY) \
		-e GITHUB_BRANCH=$(GITHUB_BRANCH) \
		-e SEMAPHORE_ORGANIZATION=$(SEMAPHORE_ORGANIZATION) \
		-e SEMAPHORE_BASE_DOMAIN=$(SEMAPHORE_BASE_DOMAIN) \
		-e SEMAPHORE_USER_EMAIL=$(SEMAPHORE_USER_EMAIL) \
		-e SEMAPHORE_API_TOKEN=$(SEMAPHORE_API_TOKEN) \
		-e SEMAPHORE_USER_PASSWORD=$(SEMAPHORE_USER_PASSWORD) \
		e2e-tests sh -c "chromedriver --port=9515 --whitelisted-ips='' --url-base=/wd/hub & mix test $(if $(TEST_FILE),$(TEST_FILE),test/e2e/ui)"

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
