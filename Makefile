.PHONY: build

TAG_NAME=$(shell git describe --exact-match --tags HEAD 2>/dev/null)

#
# If we are building on a tag, we use the branch name which contains the tag.
#
ifneq ($(TAG_NAME),)
	export BRANCH?=$(shell git branch --contains tags/$(TAG_NAME) | head -n 1 | sed '/HEAD/d' | sed 's/[^a-z]//g' | cut -c 1-40)
else ifneq ($(SEMAPHORE_GIT_PR_NUMBER),)
	export BRANCH?=pr$(SEMAPHORE_GIT_PR_NUMBER)
else
	export BRANCH?=$(shell git rev-parse --abbrev-ref HEAD | sed 's/[^a-z]//g' | cut -c 1-40)
endif

export REGISTRY_HOST?=local
export IMAGE?=$(APP_NAME)/$(BRANCH)
export MAIN_IMAGE?=$(APP_NAME)/main

APP_DIRECTORY=.
ifeq ($(CI),)
	APP_DIRECTORY=/app
endif

#
# If a MIX_ENV is available (this is only available for Elixir applications), we use it.
# If not, we use the APP_ENV variable.
#
BUILD_ENV?=$(MIX_ENV)
ifeq ($(BUILD_ENV),)
	BUILD_ENV=$(APP_ENV)
endif

IMAGE_TAG=$(BUILD_ENV)
ifneq ($(BUILD_ENV),prod)
	DOCKER_BUILD_TARGET?=dev
else
	DOCKER_BUILD_TARGET?=runner
endif

#
# Locally we want to bind volumes we're working on.
# On CI environment this is not necessary and would only slow us down. The data is already on the host.
#
DOCKER_COMPOSE_OPTS :=
ifeq ($(CI),)
	VOLUME_BIND?=--volume $(PWD):/app
	export BUILDKIT_INLINE_CACHE=0
endif

#
# Usually we want to expose service ports to the host.
#
DOCKER_COMPOSE_RUN_OPTS?=--service-ports

#
# We don't want to change files in CI, just check if they are formatted.
#
ifneq ($(CI),)
	FORMAT_ARGS?=--dry-run --check-formatted
endif

RELEASE_TAG?=$(shell git rev-list -1 HEAD -- .)
BUILDKIT_INLINE_CACHE=1

#
# Using tty progress output makes our job logs difficult to read
#
ifeq ($(CI),)
	DOCKER_BUILD_PROGRESS?=tty
else
	DOCKER_BUILD_PROGRESS?=plain
endif

DOCKER_BUILD_PATH=.
EX_CATCH_WARRNINGS_FLAG=--warnings-as-errors
CHECK_DEPS_EXTRA_OPTS?=-w feature_provider,grpc_health_check,tentacat,util,watchman,fun_registry,sentry_grpc,traceman,cacheman,log_tee,spec,proto,sys2app,looper,job_matrix,definition_validator,gofer_client,open_api_spex,when,uuid,esaml,openid_connect,block
ROOT_MAKEFILE_PATH := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
SCAN_RESULT_DIR?=out

#
# Security checks
#
# On CI environment - we're using sem-version to provide a ruby version.
# On local machines, we execute them inside of a Ruby Docker container.
#
SECURITY_TOOLBOX_TMP_DIR?=/tmp/security-toolbox
check.code:
ifeq ($(CI),)
	docker run -it \
		-v $$(pwd):/app \
		-v $(ROOT_MAKEFILE_PATH)/security-toolbox:$(SECURITY_TOOLBOX_TMP_DIR) \
		registry.semaphoreci.com/ruby:3 \
		bash -c 'cd $(APP_DIRECTORY) && $(SECURITY_TOOLBOX_TMP_DIR)/code --language $(LANGUAGE) -d $(CHECK_CODE_OPTS)'
else
	# ruby version is set in prologue
	cd $(APP_DIRECTORY) && $(ROOT_MAKEFILE_PATH)/security-toolbox/code --language $(LANGUAGE) $(CHECK_CODE_OPTS) -d
endif

check.ex.code:
	$(MAKE) check.code LANGUAGE=elixir

check.go.code:
	$(MAKE) check.code LANGUAGE=go

check.js.code:
	$(MAKE) check.code LANGUAGE=js

check.deps:
ifeq ($(CI),)
	docker run -it \
		-v $$(pwd):/app \
		-v $(ROOT_MAKEFILE_PATH)/security-toolbox:$(SECURITY_TOOLBOX_TMP_DIR) \
		registry.semaphoreci.com/ruby:3 \
		bash -c 'cd $(APP_DIRECTORY) && $(SECURITY_TOOLBOX_TMP_DIR)/dependencies --language $(LANGUAGE) -d --output-dir $(SCAN_RESULT_DIR) $(CHECK_DEPS_OPTS)'
else
	# ruby version is set in prologue
	cd $(APP_DIRECTORY) && $(ROOT_MAKEFILE_PATH)/security-toolbox/dependencies --language $(LANGUAGE) -d --output-dir $(SCAN_RESULT_DIR) $(CHECK_DEPS_OPTS)
endif

check.ex.deps:
	$(MAKE) check.deps LANGUAGE=elixir CHECK_DEPS_OPTS="-i hackney $(CHECK_DEPS_EXTRA_OPTS)"

check.go.deps:
	$(MAKE) check.deps LANGUAGE=go

check.js.deps:
	$(MAKE) check.deps LANGUAGE=js

check.docker:
ifeq ($(CI),)
	docker run -it \
		-v $$(pwd):/app \
		-v $(ROOT_MAKEFILE_PATH)/security-toolbox:$(SECURITY_TOOLBOX_TMP_DIR) \
		-v $(XDG_RUNTIME_DIR)/docker.sock:/var/run/docker.sock \
		registry.semaphoreci.com/ruby:3 \
		bash -c 'cd $(APP_DIRECTORY); $(SECURITY_TOOLBOX_TMP_DIR)/docker -d --image $(IMAGE):$(IMAGE_TAG) -s CRITICAL $(CHECK_DOCKER_OPTS)'
else
	# ruby version is set in prologue
	cd $(APP_DIRECTORY) && $(ROOT_MAKEFILE_PATH)/security-toolbox/docker -d --image $(IMAGE):$(IMAGE_TAG) -s CRITICAL $(CHECK_DOCKER_OPTS)
endif

check.generate-report:
ifeq ($(CI),)
	docker run -it \
		-v $$(pwd):/app \
		-v $(ROOT_MAKEFILE_PATH)/security-toolbox:$(SECURITY_TOOLBOX_TMP_DIR) \
		registry.semaphoreci.com/ruby:3 \
		bash -c 'cd $(APP_DIRECTORY) && $(SECURITY_TOOLBOX_TMP_DIR)/report --service-name "[$(CHECK_TYPE)] $(APP_NAME)"'
else
	cd $(APP_DIRECTORY) && $(ROOT_MAKEFILE_PATH)/security-toolbox/report --service-name "[$(CHECK_TYPE)] $(APP_NAME)"
endif

check.generate-global-report:
ifeq ($(CI),)
	docker run -it \
		-v $$(pwd):/app \
		-v $(ROOT_MAKEFILE_PATH)/security-toolbox:$(SECURITY_TOOLBOX_TMP_DIR) \
		registry.semaphoreci.com/ruby:3 \
		bash -c 'cd $(APP_DIRECTORY) && $(SECURITY_TOOLBOX_TMP_DIR)/global-report -i reports -o out'
else
	cd $(APP_DIRECTORY) && $(ROOT_MAKEFILE_PATH)/security-toolbox/global-report -i reports -o out
endif

#
# Operations for docker images during CI builds
#

push:
	docker tag $(IMAGE):$(IMAGE_TAG) $(REGISTRY_HOST)/$(IMAGE):$(IMAGE_TAG)
	-docker push $(REGISTRY_HOST)/$(IMAGE):$(IMAGE_TAG)

pull:
	-docker pull $(REGISTRY_HOST)/$(IMAGE):$(IMAGE_TAG)
	-docker pull $(REGISTRY_HOST)/$(MAIN_IMAGE):$(IMAGE_TAG)

tag:
	docker tag $(IMAGE):$(IMAGE_TAG) $(NEW_IMAGE):$(NEW_IMAGE_TAG)

#
# If MIX_ENV is set, we're dealing with an Elixir application,
# so we need to create the 'deps' and '_build' folders.
#
build:
ifneq ($(MIX_ENV),)
	mkdir -p deps _build
endif
ifeq ($(NO_BUILD_CACHE),true)
	docker build -f Dockerfile \
		--target $(DOCKER_BUILD_TARGET) \
		--progress $(DOCKER_BUILD_PROGRESS) \
		--build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) \
		--build-arg APP_NAME=$(APP_NAME) \
		--build-arg BUILD_ENV=$(BUILD_ENV) \
		-t $(IMAGE):$(IMAGE_TAG) \
		$(DOCKER_BUILD_PATH)
else
	$(MAKE) pull
	docker build -f Dockerfile \
		--target $(DOCKER_BUILD_TARGET) \
		--progress $(DOCKER_BUILD_PROGRESS) \
		--build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) \
		--build-arg APP_NAME=$(APP_NAME) \
		--build-arg BUILD_ENV=$(BUILD_ENV) \
		--cache-from=$(REGISTRY_HOST)/$(IMAGE):$(IMAGE_TAG) \
		--cache-from=$(REGISTRY_HOST)/$(MAIN_IMAGE):$(IMAGE_TAG) \
		-t $(IMAGE):$(IMAGE_TAG) \
		$(DOCKER_BUILD_PATH)
endif

build.skaffold: DOCKER_BUILD_PROGRESS=plain
build.skaffold: pull
ifneq ($(MIX_ENV),)
	mkdir -p deps _build
endif
	docker build -f Dockerfile \
		--target $(DOCKER_BUILD_TARGET) \
		--progress $(DOCKER_BUILD_PROGRESS) \
		--build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) \
		--build-arg APP_NAME=$(APP_NAME) \
		--build-arg BUILD_ENV=$(BUILD_ENV) \
		-t $(IMAGE) \
		$(DOCKER_BUILD_PATH)

#
# Development operations
#

format.ex: build
	docker run --rm $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do format $(FORMAT_ARGS), app.config $(EX_CATCH_WARRNINGS_FLAG)

lint.ex: build
	docker run --rm $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix credo --all

lint.ex.explain: build
	docker run --rm $(VOLUME_BIND) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix credo explain $(FILE)

console.ex:
	docker compose $(DOCKER_COMPOSE_OPTS) build --build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) --build-arg MIX_ENV=$(MIX_ENV) app
	docker compose $(DOCKER_COMPOSE_OPTS) run $(DOCKER_COMPOSE_RUN_OPTS) --rm app iex -S mix

console.bash:
	docker compose $(DOCKER_COMPOSE_OPTS) build --build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) --build-arg MIX_ENV=$(MIX_ENV) app
	docker compose $(DOCKER_COMPOSE_OPTS) run $(DOCKER_COMPOSE_RUN_OPTS) --rm app /bin/bash

console.sh:
	docker compose $(DOCKER_COMPOSE_OPTS) build --build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) --build-arg MIX_ENV=$(MIX_ENV) app
	docker compose $(DOCKER_COMPOSE_OPTS) run $(DOCKER_COMPOSE_RUN_OPTS) --rm app /bin/sh

#
# The default test.ex.setup target does nothing.
# Each application's Makefile should override it as it sees fit.
#
test.ex.setup:

#
# Locally we use database supplied by docker-compose.
# On CI we're relying on database supplied by sem-service
#
OUT_VOLUME?=$(PWD)/out:/app/out
test.ex: export MIX_ENV=test
test.ex:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) build --build-arg BUILDKIT_INLINE_CACHE=$(BUILDKIT_INLINE_CACHE) --build-arg BUILD_ENV=$(MIX_ENV) app
	$(MAKE) test.ex.setup
	-docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix test $(FILE) $(FLAGS) --warnings-as-errors
	docker compose $(DOCKER_COMPOSE_OPTS) down -v
else
	$(MAKE) test.ex.setup
ifeq ($(SEMAPHORE_JOB_INDEX),)
	docker run --network host -v $(OUT_VOLUME) $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix test $(TEST_FILE) $(TEST_FLAGS) $(EX_CATCH_WARRNINGS_FLAG)
else
	docker run --network host -v $(OUT_VOLUME) $(CONTAINER_ENV_VARS) -e MIX_TEST_PARTITION=$(SEMAPHORE_JOB_INDEX) $(IMAGE):$(IMAGE_TAG) mix test $(TEST_FILE) $(TEST_FLAGS) --partitions $(SEMAPHORE_JOB_COUNT) $(EX_CATCH_WARRNINGS_FLAG)
endif
endif

INTERNAL_API_BRANCH?=master
TMP_INTERNAL_REPO_DIR?=/tmp/internal_api
RELATIVE_INTERNAL_PB_OUTPUT_DIR=lib/internal_api

pb.clone:
	rm -rf $(TMP_INTERNAL_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_INTERNAL_REPO_DIR) && (cd $(TMP_INTERNAL_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)

#
# In CI, we run tests outside of docker compose,
# so we need to run the encryptor container as a docker container too
#
encryptor.run:
	cd ../encryptor && \
		$(MAKE) build IMAGE=encryptor/$(BRANCH) MAIN_IMAGE=encryptor/main BUILD_ENV=prod IMAGE_TAG=prod && \
		docker run --network host -e START_API=yes -e GRPC_API_PORT=50052 -e ENCRYPTOR_TYPE=no-op -d encryptor/$(BRANCH):prod && \
		cd -

#
# Operations for docker images on GCR
#
configure.sign:
	echo $${SEMAPHORE_OIDC_TOKEN} > /tmp/oidc_token && \
	gcloud iam workload-identity-pools create-cred-config projects/$$GCP_PROJECT_ID/locations/global/workloadIdentityPools/$$GCP_OIDC_POOL_ID/providers/$$GCP_OIDC_PROVIDER_ID \
		--service-account="ci-image-signer@$$GOOGLE_PROJECT_NAME.iam.gserviceaccount.com" \
		--service-account-token-lifetime-seconds=600 \
		--output-file=/home/semaphore/creds.json \
		--credential-source-file=/tmp/oidc_token \
		--credential-source-type="text" && \
	export GOOGLE_APPLICATION_CREDENTIALS=/home/semaphore/creds.json && \
	pip install packaging google-cloud-iam && \
	$(ROOT_MAKEFILE_PATH)/get_id_token.py $$GOOGLE_PROJECT_NAME ci-image-signer > /tmp/sigstore-token

registry.push:
	docker tag $(IMAGE):$(IMAGE_TAG) $(REGISTRY_HOST)/$(APP_NAME):$(RELEASE_TAG)
	docker push $(REGISTRY_HOST)/$(APP_NAME):$(RELEASE_TAG)

registry.sign: cosign.install
	cosign sign -y \
		--identity-token $$(cat /tmp/sigstore-token) \
		$(shell docker inspect --format='{{index .RepoDigests 0}}' $(REGISTRY_HOST)/$(APP_NAME):$(RELEASE_TAG))

registry.image:
	@echo $(REGISTRY_HOST)/$(APP_NAME):$(RELEASE_TAG)

registry.configure:
    @echo	"Configuring registry for user: $(GITHUB_USERNAME)"
	@printf "%s" "$(GITHUB_TOKEN)" | docker login ghcr.io -u "$(GITHUB_USERNAME)" --password-stdin

registry.helm.configure:
	@printf "%s" "$(GITHUB_TOKEN)" | helm registry login ghcr.io/semaphoreio --username "$(GITHUB_USERNAME)" --password-stdin

cosign.install:
	curl -O -L "https://github.com/sigstore/cosign/releases/download/v2.4.1/cosign-linux-amd64" && \
		sudo mv cosign-linux-amd64 /usr/local/bin/cosign && \
		sudo chmod +x /usr/local/bin/cosign
