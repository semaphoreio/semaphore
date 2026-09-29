#!/usr/bin/env sh

list='include/internal_api/response_status
auth
feature
rbac
repository_integrator
organization'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done
