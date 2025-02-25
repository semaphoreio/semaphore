#!/usr/bin/env bash

VALID_OSI_LICENSES=(
    "Apache 2.0"
    "MIT"
    "BSD"
    "BSD-3-Clause"
    "BSD 2-Clause"
    "ISC"
    "MPL-2.0"
    "MPL2.0"
    "CC0-1.0"
)

WHITELIST=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --whitelist-licenses-for-packages)
            IFS=',' read -ra WHITELIST <<< "$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

is_valid_license() {
    local license="$1"
    for valid in "${VALID_OSI_LICENSES[@]}"; do
        if [[ "$license" == *"$valid"* ]]; then
            return 0
        fi
    done
    return 1
}

is_whitelisted() {
    local package="$1"
    for whitelisted in "${WHITELIST[@]}"; do
        if [[ "$package" == "$whitelisted" ]]; then
            return 0
        fi
    done
    return 1
}

# Ensure that dependencies are installed to be able to run mix licenses
mix deps.get

# Run mix licenses command and capture output
MIX_OUTPUT=$(mix licenses --top-level-only --csv)

# Track if any invalid license is found
INVALID_FOUND=0

echo "🔍 Checking dependencies and their licenses..."
echo "----------------------------------------------------"

# Use process substitution to avoid subshell issues
while IFS=, read -r package version license; do
    original_license="$license"

    if is_whitelisted "$package"; then
        echo "⚪ $package - Skipped (whitelisted)"
        continue
    fi

    # Normalize "Unsure" results by extracting known valid licenses
    if [[ "$license" == *"Unsure"* ]]; then
        for valid in "${VALID_OSI_LICENSES[@]}"; do
            if [[ "$license" == *"$valid"* ]]; then
                license="$valid"
                break
            fi
        done
    fi

    # Display all licenses
    if is_valid_license "$license"; then
        echo "✅ $package - Valid: $license"
    else
        echo "❌ $package - Potential issue: $original_license"
        INVALID_FOUND=1  # This now correctly updates the variable
    fi

done < <(echo "$MIX_OUTPUT" | tail -n +2)

echo "----------------------------------------------------"

# If any invalid licenses were found, exit with an error
if [[ $INVALID_FOUND -eq 1 ]]; then
    echo "❌ Some dependencies have problematic licenses. Exiting with error."
    exit 1
else
    echo "✅ All dependencies have valid open-source licenses."
    exit 0
fi
