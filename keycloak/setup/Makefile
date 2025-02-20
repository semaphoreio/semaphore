include ../../Makefile

APP_NAME=keycloak-setup

validate: build
	docker run --rm --entrypoint "" -it $(IMAGE):$(IMAGE_TAG) terraform validate

fmt: build
	docker run --rm -v ${PWD}:/terraform --entrypoint "" -it $(IMAGE):$(IMAGE_TAG) terraform fmt

shell: build
	docker run --rm --entrypoint "" -it $(IMAGE):$(IMAGE_TAG) /bin/ash

lint: build
	docker run --rm --entrypoint "" -it $(IMAGE):$(IMAGE_TAG) terraform fmt -check
