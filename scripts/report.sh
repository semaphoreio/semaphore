#!/bin/bash
set -euo pipefail

# File to title mapping
# Format: "file_path:title_or_env_var"
# If title starts with $, it's treated as an environment variable
declare -A FILE_TITLES=(
    ["docker-scan-junit.xml"]="Docker Security Scan"
    ["dependency-scan.xml"]="Dependency Scan"
    ["gosec-junit.xml"]="Gosec Security Scan"
    ["junit.xml"]="Tests"
    ["results.xml"]="Tests"
    ["out/results.xml"]="Tests"
    ["test-results.xml"]="Tests"
    ["junit-report.xml"]="Tests"
    ["assets/results.xml"]="Tests"
    ["out/lint-js-junit-report.xml"]="Tests"
    ["out/compile-ts-junit-report.xml"]="Tests"
    ["out/test-js-junit-report.xml"]="Tests"
    ["out/test-ex-junit-report.xml"]="Tests"
)

# Alternative: Using environment variables for titles
# Uncomment and modify as needed:
# declare -A FILE_TITLES=(
#     ["docker-scan-junit.xml"]='$DOCKER_SCAN_TITLE'
#     ["junit.xml"]='$UNIT_TEST_TITLE'
#     ["results.xml"]='$RESULTS_TITLE'
#     ["out/results.xml"]='$BUILD_RESULTS_TITLE'
#     ["test-results.xml"]='$INTEGRATION_TEST_TITLE'
#     ["junit-report.xml"]='$JUNIT_TITLE'
#     ["assets/results.xml"]='$ASSET_TEST_TITLE'
#     ["out/lint-js-junit-report.xml"]='$JS_LINT_TITLE'
#     ["out/compile-ts-junit-report.xml"]='$TS_COMPILE_TITLE'
#     ["out/test-js-junit-report.xml"]='$JS_TEST_TITLE'
#     ["out/test-ex-junit-report.xml"]='$EX_TEST_TITLE'
# )

# Resolve title (handle environment variables)
resolve_title() {
    local title="$1"

    # If title starts with $, treat it as environment variable
    if [[ "$title" =~ ^\$ ]]; then
        local var_name="${title#$}"  # Remove the $ prefix
        local resolved_value="${!var_name:-}"

        if [[ -z "$resolved_value" ]]; then
            echo "Warning: Environment variable '$var_name' is not set or empty" >&2
            echo "Untitled"
        else
            echo "$resolved_value"
        fi
    else
        echo "$title"
    fi
}

main() {
    local base_path="${1:-.}"  # Default to current directory if no argument
    local published=0
    local title
    local full_path

    echo "Publishing test results with titles..."
    echo "Base path: $base_path"
    echo

    # Check each file and publish if it exists
    for file in "${!FILE_TITLES[@]}"; do
        full_path="$base_path/$file"

        if [[ -f "$full_path" ]]; then
            title=$(resolve_title "${FILE_TITLES[$file]}")
            echo "Found: $full_path (Title: '$title')"

            if test-results publish --name "$title" --suite-prefix="$SEMAPHORE_BLOCK_NAME/$SEMAPHORE_JOB_NAME" "$full_path"; then
                echo "✓ Successfully published: $full_path"
                ((published++))
            else
                echo "✗ Failed to publish: $full_path"
            fi
            echo
        else
            echo "Not found: $full_path"
        fi
    done

    echo "Summary: Published $published test result files"

    if [[ $published -eq 0 ]]; then
        echo "No test result files were found to publish"
        exit 1
    fi
}

main "$@"
