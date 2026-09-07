include ../Makefile

APP_NAME=statsd
APP_ENV=prod

DOCKER_RUN_USER?=$(shell id -u):$(shell id -g)

# Tests run inside the image we actually ship, so they also prove that image can
# still start statsd. That image has no npm — it is stripped in the runner stage
# for CVE-2026-59873 — so drive the node test runner directly rather than through
# `npm test`. Keep this in sync with the `test` script in package.json, which is
# what you get when running the suite outside the runner image.
TEST_CMD=node --test --test-reporter=spec --test-reporter-destination=stdout --test-reporter=junit --test-reporter-destination=out/test-reports.xml test/*.test.js

test.js: build
	mkdir -p out
	docker run --rm -u $(DOCKER_RUN_USER) -v $(PWD)/test:/app/test -v $(PWD)/out:/app/out $(IMAGE):$(IMAGE_TAG) sh -c "$(TEST_CMD)"

test: test.js
