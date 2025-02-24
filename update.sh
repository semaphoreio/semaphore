#!/usr/bin/env bash

update_util() {
  local dir=$1
  if [[ -f "$dir/mix.exs" ]]; then
    echo "Updating fun_registry in $dir"
    (cd "$dir" && mix deps.update fun_registry)
  fi
}

# Iterate over all directories in the current directory
for dir in */; do
  update_util "$dir"
done

# Iterate over subdirectories inside ee/
if [[ -d "ee" ]]; then
  for dir in ee/*/; do
    update_util "$dir"
  done
fi
