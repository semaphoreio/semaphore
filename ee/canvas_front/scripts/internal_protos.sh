#!/usr/bin/env sh
list='delivery
organization
repository_integrator
user
rbac
permission_patrol
feature
include/internal_api/response_status
include/internal_api/status
include/google/rpc/status
include/google/rpc/code
include/google/protobuf/timestamp'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done