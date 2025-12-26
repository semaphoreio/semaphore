#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || -z ${1:-} ]]; then
  echo "Usage: $0 <module[,module...]> [branch] [internal_api_dir]" >&2
  exit 1
fi

MODULE_LIST=$1
INTERNAL_API_BRANCH=${2:-master}
INTERNAL_API_SOURCE=${3:-/tmp/internal_api}

IFS=',' read -r -a RAW_MODULES <<< "${MODULE_LIST}"

RESPONSE_STATUS_MODULE="include/internal_api/response_status"

declare -A SEEN
MODULES=()

canon_module() {
  local value="$1"
  case "$value" in
    "" ) return 1 ;;
    "response_status"|"internal_api/response_status")
      echo "$RESPONSE_STATUS_MODULE"
      ;;
    *)
      echo "$value"
      ;;
  esac
}

add_module() {
  local module
  module=$(canon_module "$1") || return 0
  if [[ -z ${SEEN[$module]:-} ]]; then
    SEEN[$module]=1
    MODULES+=("$module")
  fi
}

for raw in "${RAW_MODULES[@]}"; do
  add_module "$raw"
done

if [[ -z ${SEEN[$RESPONSE_STATUS_MODULE]:-} ]]; then
  MODULES+=("$RESPONSE_STATUS_MODULE")
fi

if [[ ${#MODULES[@]} -eq 0 ]]; then
  echo "No internal_api modules provided." >&2
  exit 1
fi

export PATH="$PATH:$(go env GOPATH)/bin"

INTERNAL_API_OUT=/app/pkg/internal_api
MODULE_PREFIX=github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cp -R "$INTERNAL_API_SOURCE"/. "$WORK_DIR" >/dev/null

sanitize_package() {
  local module="$1"
  if [[ "$module" == include/internal_api/* ]]; then
    echo "${module#include/internal_api/}"
  elif [[ "$module" == include/* ]]; then
    echo "${module#include/}"
  else
    echo "$module"
  fi
}

proto_file_for() {
  local module="$1"
  local base
  base=$(basename "$module")

  local candidates=(
    "${WORK_DIR}/${module}.proto"
  )

  case "$module" in
    include/*)
      candidates+=(
        "${WORK_DIR}/include/${module#include/}.proto"
        "${WORK_DIR}/include/${module#include/}/${base}.proto"
      )
      ;;
    *)
      candidates+=(
        "${WORK_DIR}/${module}/${base}.proto"
      )
      ;;
  esac

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  echo "Proto file not found. Checked: ${candidates[*]}" >&2
  exit 1
}

update_go_package() {
  local module="$1"
  local package
  package=$(sanitize_package "$module")
  local proto_file
  proto_file=$(proto_file_for "$module")

  sed --in-place '/go_package/d' "$proto_file"
  if [[ $(tail -c1 "$proto_file") != $'\n' ]]; then
    printf '\n' >> "$proto_file"
  fi
  printf 'option go_package = "%s/%s";\n' "$MODULE_PREFIX" "$package" >> "$proto_file"
}

generate_proto_definition() {
  local module="$1"
  local package
  package=$(sanitize_package "$module")
  local proto_file
  proto_file=$(proto_file_for "$module")
  local out_dir="$INTERNAL_API_OUT/$package"
  local mapping="M${proto_file}=internal_api/${package}"

  mkdir -p "$out_dir"

  protoc \
    --proto_path "$WORK_DIR" \
    --proto_path "$WORK_DIR/include" \
    --proto_path "$WORK_DIR/include/internal_api" \
    --go_out="$out_dir" \
    --go_opt=paths=source_relative \
    --go_opt="${mapping}" \
    --go_opt=Mgoogle/protobuf/timestamp.proto=google.golang.org/protobuf/types/known/timestamppb \
    --go_opt=Mgoogle/protobuf/empty.proto=google.golang.org/protobuf/types/known/emptypb \
    --go_opt=Mgoogle/protobuf/duration.proto=google.golang.org/protobuf/types/known/durationpb \
    --go_opt=Mgoogle/protobuf/any.proto=google.golang.org/protobuf/types/known/anypb \
    --go_opt=Mgoogle/rpc/status.proto=google.golang.org/genproto/googleapis/rpc/status \
    --go_opt=Mgoogle/rpc/code.proto=google.golang.org/genproto/googleapis/rpc/code \
    --go_opt=Mgoogle/rpc/errdetails.proto=google.golang.org/genproto/googleapis/rpc/errdetails \
    --go-grpc_out="$out_dir" \
    --go-grpc_opt=paths=source_relative \
    --go-grpc_opt=require_unimplemented_servers=false \
    "$proto_file"

  if [[ "$module" == include/* ]]; then
    local base
    base=$(basename "$module")
    local nested="$out_dir/include/${module#include/}.pb.go"
    if [[ -f "$nested" ]]; then
      mv "$nested" "$out_dir/${base}.pb.go"
      rm -rf "$out_dir/include"
    fi
  fi
}

rm -rf "$INTERNAL_API_OUT"

for module in "${MODULES[@]}"; do
  update_go_package "$module"
done

for module in "${MODULES[@]}"; do
  generate_proto_definition "$module"
done

echo "Generated $((${#MODULES[@]})) module(s) into $INTERNAL_API_OUT"
