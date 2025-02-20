export MIX_ENV?=dev

include ../../Makefile

APP_NAME := "pre-flight-checks-hub"
SEMAPHORE_WORKFLOW_ID ?= ""


RUN := docker exec -e MIX_ENV=$(MIX_ENV) -it $(APP)

#
# Environment variables required for app to run
#
AMQP_URL=amqp://127.0.0.1:5672
DB_HOSTNAME=127.0.0.1
DB_NAME=pre_flight_checks
DB_USERNAME=postgres
DB_PASSWORD=the-cake-is-a-lie
START_INTERNAL_API=true

CONTAINER_ENV_VARS= \
	-e DB_NAME=$(DB_NAME) \
	-e DB_USERNAME=$(DB_USERNAME) \
	-e DB_PASSWORD=$(DB_PASSWORD) \
	-e DB_HOSTNAME=$(DB_HOSTNAME) \
	-e START_INTERNAL_API=$(START_INTERNAL_API) \
	-e AMQP_URL=$(AMQP_URL) \
	-e CI=$(CI) \
	-e MIX_ENV=$(MIX_ENV)

test.ex.setup: export MIX_ENV=test
test.ex.setup: build
ifeq ($(CI),)
	docker compose run --rm app mix do ecto.create, ecto.migrate
else
	sem-service start rabbitmq 3.8
	sem-service start postgres 9.6 --db=$(DB_NAME) --user=$(DB_USERNAME) --password=$(POSTGRES_DB_PASSWORD)
	docker run --network host -v $(PWD)/out:/app/out $(CONTAINER_ENV_VARS) $(IMAGE):$(IMAGE_TAG) mix do ecto.create, ecto.migrate
endif

run: dev.setup
	$(RUN) iex -S mix run --no-halt

