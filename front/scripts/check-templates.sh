#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if [ $# -lt 1 ]; then
  echo "Usage: $0 <root_directory>"
  exit 1
fi

root_dir="$1"
properties_dir="${root_dir}/properties"
setup_json="${root_dir}/setup.json"

# First check if setup.json exists and is valid
if [ ! -f "$setup_json" ]; then
  echo "❗️ Error: setup.json not found in root directory"
  exit 1
fi

# Validate setup.json
if ! jq empty "$setup_json" 2>/dev/null; then
  echo "❗️ Error: setup.json is not a valid JSON file"
  exit 1
else
  echo "✅ setup.json is valid"
fi

if [ ! -d "$properties_dir" ]; then
  echo "❗️ Error: Properties directory not found: $properties_dir"
  exit 1
fi

required_fields=(
  "title"
  "description"
  "short_description"
  "environment"
  "icon"
  "template_path"
)

exit_code=0
templates_checked=0

# Function to validate YAML block dependencies
validate_yaml_blocks() {
  local yaml_file="$1"
  local title="$2"
  
  # First check if the YAML is valid
  if ! yq eval '.' "$yaml_file" > /dev/null 2>&1; then
    echo "❌ Error: Invalid YAML in template for '${title}': ${yaml_file}"
    return 1
  fi
  
  # Get all block names
  local block_names
  block_names=$(yq eval '.blocks[].name' "$yaml_file")
  
  if [ -z "$block_names" ]; then
    echo "⚠️  Warning: No blocks found in template for '${title}': ${yaml_file}"
    return 0
  fi
  
  # Check blocks for valid dependencies (if present)
  local invalid_deps=0
  while IFS= read -r block; do
    local block_name
    block_name=$(yq eval '.blocks[] | select(.name == "'$block'") | .name' "$yaml_file")
    
    # Check if dependencies field exists (optional)
    local deps_field
    deps_field=$(yq eval '.blocks[] | select(.name == "'$block'") | has("dependencies")' "$yaml_file")
    
    # Only validate dependencies if the field exists
    if [ "$deps_field" = "true" ]; then
      # Check if dependencies field is an array
      local deps_type
      deps_type=$(yq eval '.blocks[] | select(.name == "'$block'") | .dependencies | type' "$yaml_file")
      
      if [ "$deps_type" != "!!seq" ]; then
        echo "❌ Error: Block '${block_name}' in '${title}' has dependencies field that is not an array"
        ((invalid_deps++))
      else
        # Validate each dependency in this block
        while IFS= read -r dep; do
          if [ ! -z "$dep" ] && ! echo "$block_names" | grep -Fxq "$dep"; then
            echo "❌ Error: Block '${block_name}' in '${title}' has undefined dependency: ${dep}"
            ((invalid_deps++))
          fi
        done < <(yq eval '.blocks[] | select(.name == "'$block'") | .dependencies[]' "$yaml_file")
      fi
    fi
  done < <(yq eval '.blocks[].name' "$yaml_file")
  
  if [ $invalid_deps -eq 0 ]; then
    echo "✅ Block dependencies valid in template for '${title}': ${yaml_file}"
  fi
  
  return $invalid_deps
}

for json_file in "$properties_dir"/*.properties.json; do
  if [ ! -f "$json_file" ]; then
    continue
  fi
  
  # Check if the JSON file is valid
  if ! jq empty "$json_file" 2>/dev/null; then
    echo "❌ Error: $(basename "$json_file") is not a valid JSON file"
    exit_code=1
    continue
  fi
  
  # Check required fields
  for field in "${required_fields[@]}"; do
    value=$(jq -r ".$field" "$json_file")
    if [ "$value" = "null" ] || [ -z "$value" ]; then
      echo "❗️ Error: Required field '$field' is missing in $(basename "$json_file")"
      exit_code=1
    fi
  done
  
  template_path=$(jq -r '.template_path' "$json_file")
  title=$(jq -r '.title' "$json_file")
  
  if [ "$template_path" = "null" ]; then
    echo "❗️ Warning: No template_path found in $json_file"
    continue
  fi
  
  full_template_path="${root_dir}/${template_path}"
  if [ ! -f "$full_template_path" ]; then
    echo "❌ Error: Template not found for '${title}', properties define template as: ${template_path}"
    exit_code=1
  else
    # Validate YAML block dependencies
    if ! validate_yaml_blocks "$full_template_path" "$title"; then
      exit_code=1
    fi
  fi
  templates_checked=$((templates_checked + 1))
done

if [ $exit_code -eq 0 ] && [ $templates_checked -gt 0 ]; then
  echo "✅ All templates in ${root_dir} are valid"
fi

exit $exit_code