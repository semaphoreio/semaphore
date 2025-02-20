include ../Makefile

APP_NAME=encryptor
APP_ENV=prod
INTERNAL_API_BRANCH ?= master
INTERNAL_API_MODULES = encryptor

#
# Protobuf compilation.
#

pb.gen:
	rm -rf /tmp/internal_api
	git clone git@github.com:renderedtext/internal_api.git /tmp/internal_api && (cd /tmp/internal_api && git checkout $(INTERNAL_API_BRANCH) && cd -)
	docker-compose run --rm app /app/scripts/protoc.sh $(INTERNAL_API_MODULES) $(INTERNAL_API_BRANCH)

#
# Tests
#

test.setup:
	docker-compose build
	docker-compose run app go get ./...

test:
	docker-compose run --rm app gotestsum --format short-verbose --junitfile results.xml --packages="./..." -- -p 1

tidy:
	docker-compose run --rm app go mod tidy

lint:
	docker-compose run --rm --no-deps app revive -formatter friendly -config lint.toml ./...
