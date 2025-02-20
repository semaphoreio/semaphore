list='secrets.v1beta
project_secrets.v1'

for element in $list;do
  echo "$element"
  protoc -I /home/protoc/source --elixir_out=plugins=grpc:/home/protoc/code/lib/public_api --plugin=/root/.mix/escripts/protoc-gen-elixir /home/protoc/source/semaphore/$element.proto
done
