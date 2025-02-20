#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Get the group of the 'nobody' user
NOBODY_GROUP=$(id -gn nobody)

# Change ownership of /var/repos
sudo chown -R nobody:$NOBODY_GROUP /var/repos

# Remove 'nobody' from the sudo group
sudo deluser nobody sudo || true

echo "Starting server..."
/app/build/repohub
