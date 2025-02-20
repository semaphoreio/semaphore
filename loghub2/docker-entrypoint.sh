#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

echo "Starting server..."
/app/build/loghub2
