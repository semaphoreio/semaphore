export MIX_ENV?=dev

include ../../Makefile

APP_NAME := $(shell grep 'app:' mix.exs | cut -d ':' -f3 | cut -d ',' -f1)
INTERNAL_API_BRANCH?=master
PROTOC_TAG=1.18.4-3.20.1-0.13.0
TMP_REPO_DIR?=/tmp/internal_api

CONTAINER_ENV_VARS = $(shell [ -f .env ] && sed 's/^/-e /' .env | tr '\n' ' ')

POSTGRES_VARS := POSTGRES_DB_NAME POSTGRES_DB_USER POSTGRES_DB_PASSWORD POSTGRES_DB_HOST POSTGRES_DB_POOL_SIZE MIX_ENV
CONTAINER_ENV_VARS = $(foreach var,$(POSTGRES_VARS),-e $(var)=$($(var)))

test.ex.setup: export MIX_ENV=test
test.ex.setup:
ifdef CI
	sem-service start postgres 9.6 --db=$(POSTGRES_DB_NAME) --user=$(POSTGRES_DB_USER) --password=$(POSTGRES_DB_PASSWORD)
endif

migration.gen:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make migration.gen NAME={migration_name}"; \
		exit 1; \
	fi
	docker compose run --rm app mix ecto.gen.migration $(NAME)

pb.gen:
	rm -rf $(TMP_REPO_DIR)
	git clone git@github.com:renderedtext/internal_api.git $(TMP_REPO_DIR) && (cd $(TMP_REPO_DIR) && git checkout $(INTERNAL_API_BRANCH) && cd -)
	rm -rf lib/internal_api && mkdir -p lib/internal_api
	docker run --rm -v $(PWD):/home/protoc/code -v $(TMP_REPO_DIR):/home/protoc/source -t renderedtext/protoc:$(PROTOC_TAG) sh -c /home/protoc/code/scripts/internal_protos.sh
	rm -rf $(TMP_REPO_DIR)
