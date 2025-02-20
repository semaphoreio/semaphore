export MIX_ENV?=dev

include ../../Makefile

DOCKER_BUILD_PATH=..
EX_CATCH_WARRNINGS_FLAG=

APP_NAME=job_matrix

IN_DOCKER?="true"
LOG_LEVEL?=info

CONTAINER_ENV_VARS= \
  -e IN_DOCKER=$(IN_DOCKER) \
  -e CI=$(CI) \
  -e MIX_ENV=$(MIX_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL)
