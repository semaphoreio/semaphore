export MIX_ENV?=dev

include ../../Makefile

DOCKER_BUILD_PATH=..
EX_CATCH_WARRNINGS_FLAG=

APP_NAME=task_api_referent

IN_DOCKER?="true"
LOG_LEVEL?=info
GRPC_PORT?=50051

CONTAINER_ENV_VARS= \
  -e IN_DOCKER=$(IN_DOCKER) \
  -e CI=$(CI) \
  -e MIX_ENV=$(MIX_ENV) \
  -e LOG_LEVEL=$(LOG_LEVEL) \
  -e GRPC_PORT=$(GRPC_PORT)
