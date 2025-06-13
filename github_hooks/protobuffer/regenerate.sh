#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

TMP_REPO_DIR="/tmp/internal_api"
INTERNAL_API_BRANCH=${INTERNAL_API_BRANCH:-master}
PUBLIC_API_BRANCH=${PUBLIC_API_BRANCH:-master}


if [ -e protobuffer/generated ]; then
  echo "Deleting old files"
  rm -rf protobuffer/generated
fi

mkdir -p protobuffer/generated

rm -rf $TMP_REPO_DIR
git clone git@github.com:renderedtext/internal_api.git $TMP_REPO_DIR && (cd $TMP_REPO_DIR && git checkout $INTERNAL_API_BRANCH && cd -)

protos=(encryptor projecthub user plumber.pipeline plumber.admin google/protobuf/timestamp google/protobuf/empty google/rpc/google/protobuf/any google/rpc/code google/rpc/status repo_proxy repository_integrator internal_api/response_status server_farm.job server_farm.mq.job_state_exchange secrethub cache plumber_w_f.workflow internal_api/status repository rbac instance_config)

for i in ${protos[@]}; do
  echo "Generating $i"
  echo "bundle exec grpc_tools_ruby_protoc -I $TMP_REPO_DIR -I $TMP_REPO_DIR/include --ruby_out=protobuffer/generated --grpc_out=protobuffer/generated $i.proto" | sh
done

rm -rf $TMP_REPO_DIR

git status
