#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Error: Please provide the app-design directory path as an argument"
    echo "Usage: $0 <app-design_dir>"
    exit 1
fi

APP_DESIGN_DIR="$1"
STARTER_TEMPLATES_DIR="$APP_DESIGN_DIR/starter_templates"
CE_NEW_DIR="workflow_templates/ce_new"
SAAS_NEW_DIR="workflow_templates/saas_new"

# Check if starter_templates directory exists
if [ ! -d "$STARTER_TEMPLATES_DIR" ]; then
    echo "Error: Starter templates directory '$STARTER_TEMPLATES_DIR' does not exist"
    exit 1
fi

# Check if both ce and saas directories exist
if [ ! -d "$STARTER_TEMPLATES_DIR/ce" ] || [ ! -d "$STARTER_TEMPLATES_DIR/saas" ]; then
    echo "Error: Both 'ce' and 'saas' directories must exist in $STARTER_TEMPLATES_DIR"
    exit 1
fi

rm -rf "$CE_NEW_DIR"
rm -rf "$SAAS_NEW_DIR"
# Create target directories if they don't exist
mkdir -p "$CE_NEW_DIR"
mkdir -p "$SAAS_NEW_DIR"

# Copy templates from ce and saas directories to their respective new locations
echo "Copying templates from $STARTER_TEMPLATES_DIR/ce to $CE_NEW_DIR..."
cp -R "$STARTER_TEMPLATES_DIR/ce/"* "$CE_NEW_DIR/"

echo "Copying templates from $STARTER_TEMPLATES_DIR/saas to $SAAS_NEW_DIR..."
cp -R "$STARTER_TEMPLATES_DIR/saas/"* "$SAAS_NEW_DIR/"

echo "Successfully copied workflow templates to their respective directories"
