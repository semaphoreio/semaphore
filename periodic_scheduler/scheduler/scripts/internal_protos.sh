#!/usr/bin/env sh
list='
feature
health
organization
periodic_scheduler
plumber_w_f.workflow
projecthub
repository_integrator
repository
repo_proxy
include/internal_api/status
'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done