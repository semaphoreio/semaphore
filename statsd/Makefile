# MUST be set before the include. ../Makefile resolves DOCKER_BUILD_TARGET from
# BUILD_ENV (which defaults to APP_ENV) inside an `ifneq`, and make evaluates
# conditionals while the file is being read — so an APP_ENV assigned after the
# include is too late and the target silently falls back to `dev`. Because
# IMAGE_TAG is a deferred assignment it still expands to `prod`, so the dev
# image gets built and tagged `:prod`, and `make check.docker` then scans the
# dev stage (npm, and its bundled node-tar) instead of the runner we ship.
APP_ENV=prod

include ../Makefile

APP_NAME=statsd

DOCKER_RUN_USER?=$(shell id -u):$(shell id -g)

# Tests run inside the image we actually ship, so they also prove that image can
# still start statsd. That image has no npm — the runner stage is plain Alpine
# plus the `nodejs` apk — so drive the node test runner directly rather than
# through `npm test`. Keep this in sync with the `test` script in package.json,
# which is what you get when running the suite outside the runner image.
TEST_CMD=node --test --test-reporter=spec --test-reporter-destination=stdout --test-reporter=junit --test-reporter-destination=out/test-reports.xml test/*.test.js

test.js: build
	mkdir -p out
	docker run --rm -u $(DOCKER_RUN_USER) -v $(PWD)/test:/app/test -v $(PWD)/out:/app/out $(IMAGE):$(IMAGE_TAG) sh -c "$(TEST_CMD)"

test: test.js
