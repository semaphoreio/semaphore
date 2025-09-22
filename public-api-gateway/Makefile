.PHONY: test api.checkout pb.gen

include ../Makefile

APP_NAME=public-api-gateway
APP_ENV=prod
SHELL=/bin/bash
TMP_REPO_DIR=/tmp/public_api

# Locally we want to bind volumes we're working on.
# On CI environment this is not necessary and would only slow us down. The data is already on the host.
ifeq ($(CI),)
	VOLUME_BIND?=--volume $(PWD):/app
	export BUILDKIT_INLINE_CACHE=0
endif

#
# Proto generation. Run: 'make pb.gen' to regenerate proto definitions.
#

pb.gen: api.checkout
	mkdir -p api/$(API)
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t golang:1.18-alpine sh -c /home/protoc/code/scripts/public_protos.sh

api.checkout:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:semaphoreci/api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(API_BRANCH) && cd -)

bin.build:
	docker compose run --remove-orphans --rm $(VOLUME_BIND) app sh -c "rm -rf build && CGO_ENABLED=0 go build -o build/server main.go"

test.e2e: bin.build
	docker compose run --remove-orphans --rm $(VOLUME_BIND) app bash ./test/test.sh

test:
	docker compose run --remove-orphans --rm $(VOLUME_BIND) app gotestsum --format short-verbose --junitfile out/test-reports.xml --packages="./..." -- -p 1

lint:
	docker compose run --remove-orphans --rm $(VOLUME_BIND) app revive -formatter friendly -config lint.toml ./...
