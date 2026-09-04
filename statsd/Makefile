include ../Makefile

APP_NAME=statsd
APP_ENV=prod

DOCKER_RUN_USER?=$(shell id -u):$(shell id -g)

test.js: build
	mkdir -p out
	docker run --rm -u $(DOCKER_RUN_USER) -v $(PWD)/test:/app/test -v $(PWD)/out:/app/out $(IMAGE):$(IMAGE_TAG) sh -c "npm test"

test: test.js
