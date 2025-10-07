list='
include/internal_api/status
include/internal_api/response_status
include/google/rpc/status
include/google/rpc/code
repository_integrator
repository
user
projecthub
organization
health
encryptor
'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done
