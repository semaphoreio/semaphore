export MIX_ENV ?= dev

include ../../Makefile

DOCKER_BUILD_PATH=../..
OUT_VOLUME=$(PWD)/out:/app/scheduler/out
SHELL := /bin/bash

APP_NAME := periodic-scheduler

INTERNAL_API_TMP_DIR ?= /tmp/internal_api
INTERNAL_API_BRANCH ?= master
PROTOC_IMAGE_TAG ?= 1.12.1-3.20.3-0.11.0

CHECK_DEPS_EXTRA_OPTS=-w feature_provider,definition_validator

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
SSH_AUTH_SOCK_I=$(SSH_AUTH_SOCK)
endif
ifeq ($(UNAME_S),Darwin)
SSH_AUTH_SOCK_I=/run/host-services/ssh-auth.sock
endif

IN_DOCKER?="true"
DB_HOSTNAME?= "0.0.0.0"
DB_USERNAME?= postgres
DB_PASSWORD?= postgres
DB_NAME?= periodics_test
FRONT_DB_NAME?= front_test
RABBITMQ_URL?= "amqp://0.0.0.0:5672"
LOG_LEVEL?=info

CONTAINER_ENV_VARS= \
  -e IN_DOCKER=$(IN_DOCKER) \
  -e CI=$(CI) \
  -e MIX_ENV=$(MIX_ENV) \
  -e RABBITMQ_URL=$(RABBITMQ_URL) \
  -e LOG_LEVEL=$(LOG_LEVEL) \
  -e DB_HOSTNAME=$(DB_HOSTNAME) \
  -e DB_USERNAME=$(DB_USERNAME) \
  -e DB_PASSWORD=$(DB_PASSWORD)

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifeq ($(CI),)
	docker compose $(DOCKER_COMPOSE_OPTS) run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start postgres 9.6 --db=$(DB_NAME) --user=$(DB_USERNAME) --password=$(DB_PASSWORD)
	sem-service start rabbitmq 3.8
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

# Protobuf files

pb.gen: pb.gen.internal format

pb.gen.internal:
	rm -rf $(INTERNAL_API_TMP_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(INTERNAL_API_TMP_DIR) \
		&& (cd $(INTERNAL_API_TMP_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	scripts/vagrant_sudo rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(INTERNAL_API_TMP_DIR):/home/protoc/source \
		-t renderedtext/protoc:$(PROTOC_IMAGE_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	scripts/vagrant_sudo chown -R $$(id -u $${USER}):$$(id -g $${USER}) lib/internal_api
	rm -rf $(INTERNAL_API_TMP_DIR)