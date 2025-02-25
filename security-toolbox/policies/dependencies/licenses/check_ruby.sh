#!/usr/bin/env bash

VALID_OSI_LICENSES=(
    "APACHE"
    "MIT"
    "BSD"
    "ISC"
    "MPL"
    "RUBY"
    "LGPL"
    "HIPPOCRATIC"
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
    license="$(echo "$license" | tr '[:lower:]' '[:upper:]')"
    for valid in "${VALID_OSI_LICENSES[@]}"; do
        if [[ "$license" =~ "$valid" ]]; then
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

# Ensure that dependencies are installed to be able to run bundle list
bundle config set without 'development test'
bundle install --quiet

# Run gem license check
INVALID_FOUND=0
echo "🔍 Checking Ruby gem licenses..."
echo "----------------------------------------------------"

while read -r line; do
    package=$(echo "$line" | cut -d' ' -f1)
    license=$(gem spec "$package" license 2>/dev/null | sed '/./,$!d' | tail -n 2 | tr -d '[:space:]-')

    if is_whitelisted "$package"; then
        echo "⚪ $package - Skipped (whitelisted)"
        continue
    fi

    if [[ -z "$license" ]]; then
        echo "⚠️  $package - License information not found"
        INVALID_FOUND=1
        continue
    fi

    if is_valid_license "$license"; then
        echo "✅ $package - Valid: $license"
    else
        echo "❌ $package - Potential issue: $license"
        INVALID_FOUND=1
    fi

done < <(bundle list | grep "*" |  cut -d" " -f4)

echo "----------------------------------------------------"

if [[ $INVALID_FOUND -eq 1 ]]; then
    echo "❌ Some dependencies have problematic licenses. Exiting with error."
    exit 1
else
    echo "✅ All dependencies have valid open-source licenses."
    exit 0
fi
