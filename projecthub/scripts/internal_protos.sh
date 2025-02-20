#!/usr/bin/env sh

list='include/google/protobuf/timestamp
include/google/rpc/code
include/internal_api/response_status
projecthub
user
organization
cache
include/internal_api/status
periodic_scheduler
artifacthub
repository
repository_integrator
feature
health
rbac
'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done
