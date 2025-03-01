export MIX_ENV?=dev

include ../../Makefile

DOCKER_BUILD_PATH=..
EX_CATCH_WARRNINGS_FLAG=

APP_NAME=definition_validator

CHECK_DEPS_EXTRA_OPTS=-w spec

IN_DOCKER?="true"
LOG_LEVEL?=info

CONTAINER_ENV_VARS= \
  -e IN_DOCKER=$(IN_DOCKER) \
  -e CI=$(CI) \
  -e MIX_ENV=$(MIX_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL)
