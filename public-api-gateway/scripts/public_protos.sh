#!/usr/bin/env sh

export PROTOC_VERSION=3.17.3
wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub
wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.33-r0/glibc-2.33-r0.apk
apk add glibc-2.33-r0.apk

apk update && apk add zip unzip

wget -O /tmp/protoc https://github.com/google/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip
unzip /tmp/protoc
mv bin/protoc /usr/local/bin/protoc

go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.4.0
go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@v2.21.0
go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@v2.21.0

mkdir -p /home/protoc

list='
secrets.v1beta
project_secrets.v1
notifications.v1alpha
dashboards.v1alpha
jobs.v1alpha
artifacts.v1
'

for element in $list;do
  echo "$element"

	protoc -I /home/protoc/source \
				 -I $GOPATH/src \
         --go-grpc_out=require_unimplemented_servers=false:/home/protoc/code/api \
         --go_out=/home/protoc/code/api \
				 /home/protoc/source/semaphore/$element.proto

	protoc -I /home/protoc/source \
				 -I $GOPATH/src \
				 --grpc-gateway_out=logtostderr=true,grpc_api_configuration=/home/protoc/source/semaphore/$element.yml:/home/protoc/code/api \
				 /home/protoc/source/semaphore/$element.proto
done
