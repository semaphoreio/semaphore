# Helper to check required variables using shell environment
check_defined = \
    $(if $(shell printenv $(1)),,$(error $(1) env variable must be explicitly set))

$(eval $(call check_defined,CLOUD_TEST_ENV_PREFIX))

ROOT_PATH := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))

auth:
	$(error "Target 'auth' not implemented. Each terraform environment should implement/override this target.")

terraform.prepare:
	$(eval $(call check_defined,CLOUD_TEST_ENVIRONMENT_TYPE))
	$(ROOT_PATH)/scripts/terraform-prepare.sh

terraform.plan:
	$(error "Target 'terraform.plan' not implemented. Each terraform environment should implement/override this target.")

terraform.apply:
	$(error "Target 'terraform.apply' not implemented. Each terraform environment should implement/override this target.")

terraform.destroy:
	$(error "Target 'terraform.destroy' not implemented. Each terraform environment should implement/override this target.")

helm.install:
	$(eval $(call check_defined,CLOUD_TEST_ENVIRONMENT_TYPE))
	cd $(ROOT_PATH)/scripts && ./install.sh

dns.update:
	cd $(ROOT_PATH)/scripts && ./update-dns.sh