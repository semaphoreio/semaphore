#!/usr/bin/env sh
list='dashboardhub
audit
include/google/protobuf/timestamp
include/google/protobuf/empty
include/google/rpc/google/protobuf/any
include/google/rpc/status
include/google/rpc/code
repo_proxy
branch
include/internal_api/response_status
include/internal_api/status
periodic_scheduler
plumber.pipeline
plumber_w_f.workflow
user
projecthub
organization
guard
artifacthub
server_farm.job
task
gofer.dt
gofer.switch
groups
loghub
loghub2
repository
self_hosted
billing
repository_integrator
pre_flight_checks_hub
velocity
okta
rbac
permission_patrol
secrethub
feature
superjerry
instance_config
usage
scouter
license
service_account'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done
