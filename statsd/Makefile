APP_ENV=prod

include ../Makefile

APP_NAME=statsd

DOCKER_RUN_USER?=$(shell id -u):$(shell id -g)

TEST_CMD=node --test --test-reporter=spec --test-reporter-destination=stdout --test-reporter=junit --test-reporter-destination=out/test-reports.xml test/*.test.js

test.js: build
	mkdir -p out
	docker run --rm -u $(DOCKER_RUN_USER) -v $(PWD)/test:/app/test -v $(PWD)/out:/app/out $(IMAGE):$(IMAGE_TAG) sh -c "$(TEST_CMD)"

test: test.js
