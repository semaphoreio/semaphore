include ../Makefile

APP_NAME=bootstrapper
APP_ENV=prod
INTERNAL_API_BRANCH ?= master
INTERNAL_API_TMP_DIR ?= /tmp/internal_api

lint:
	docker-compose run --rm --no-deps app revive -formatter friendly -config lint.toml ./...

test:
	docker compose build
	docker compose run --rm app gotestsum --format short-verbose --junitfile junit-report.xml --packages="./..." -- -p 1

test.watch:
	docker compose run --rm app gotestsum --watch --format short-verbose --junitfile junit-report.xml --packages="./..." -- -p 1

tidy:
	docker compose run --rm app go mod tidy

#
# Protobuf compilation
#

INTERNAL_API_MODULES ?= include/internal_api/response_status,repository_integrator,self_hosted,organization,user,rbac,instance_config
pb.gen:
	rm -rf $(INTERNAL_API_TMP_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(INTERNAL_API_TMP_DIR) && (cd $(INTERNAL_API_TMP_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	docker-compose run --rm --no-deps --build app /app/scripts/protoc.sh $(INTERNAL_API_MODULES) $(INTERNAL_API_BRANCH) $(INTERNAL_API_TMP_DIR)
	rm -rf $(INTERNAL_API_TMP_DIR)
