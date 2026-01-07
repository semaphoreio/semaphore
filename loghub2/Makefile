include ../Makefile

APP_NAME=loghub2
APP_ENV=prod

test.setup:
	docker-compose build
	docker-compose run app go get ./...

lint:
	docker-compose run --rm --no-deps app revive -formatter friendly -config lint.toml ./...

test: build
	docker-compose run --rm app gotestsum --format short-verbose --junitfile out/test-reports.xml --packages="./..." -- -p 1

test.watch: build
	docker-compose run --rm app gotestsum --watch --format short-verbose --junitfile out/test-reports.xml --packages="./..." -- -p 1

test.bench: build
	docker-compose run --rm app go test -v ./pkg/publicapi -bench=. -benchmem -run Benchmark__PullJSONLogsFromRedis -memprofile memprofile.out

#
# Protobuf compilation
#

INTERNAL_API_BRANCH ?= master
INTERNAL_API_MODULES ?= include/internal_api/response_status,loghub2,server_farm.mq.job_state_exchange,server_farm.job
pb.gen:
	rm -rf /tmp/internal_api
	git clone git@github.com:renderedtext/internal_api.git /tmp/internal_api && (cd /tmp/internal_api && git checkout $(INTERNAL_API_BRANCH) && cd -)
	docker-compose run --rm --no-deps app /app/scripts/protoc.sh $(INTERNAL_API_MODULES) $(INTERNAL_API_BRANCH)
