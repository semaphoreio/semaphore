list='
artifacthub
cache
chmura
feature
gofer.dt
rbac
health
include/google/protobuf/timestamp
include/internal_api/response_status
loghub2
organization
projecthub
repo_proxy
repository
repository_integrator
secrethub
self_hosted
server_farm.job
server_farm.mq.job_state_exchange
task
usage'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/protos/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done
