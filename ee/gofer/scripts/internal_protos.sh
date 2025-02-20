#!/usr/bin/env sh
list='include/google/protobuf/timestamp
include/google/protobuf/empty
include/google/rpc/google/protobuf/any
include/google/rpc/status
include/google/rpc/code
include/internal_api/response_status
include/internal_api/status
gofer.switch
plumber.pipeline
plumber_w_f.workflow
user
repository_integrator
repository
projecthub
gofer.dt
secrethub
rbac
health
'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done
