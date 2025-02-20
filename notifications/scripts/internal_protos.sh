#!/usr/bin/env sh

list='
include/internal_api/response_status
include/internal_api/status
include/google/protobuf/timestamp
include/google/rpc/code
rbac
plumber.pipeline
plumber_w_f.workflow
projecthub
notifications
repo_proxy
organization
repository_integrator
user
secrethub
'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done
