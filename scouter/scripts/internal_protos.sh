list='
include/internal_api/status
include/internal_api/response_status
include/google/protobuf/timestamp
include/google/protobuf/empty
include/google/rpc/google/protobuf/any
include/google/rpc/status
include/google/rpc/code
scouter
health
'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source -I /home/protoc/source/include --elixir_out=plugins=grpc:/home/protoc/code/lib/internal_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/$element.proto
done
