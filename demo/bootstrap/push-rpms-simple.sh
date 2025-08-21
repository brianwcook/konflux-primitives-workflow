#!/bin/bash

# Push RPMs to quay.io with architecture-specific tags
# Since oras 1.2.3 doesn't support --platform, we'll use arch-specific tags

set -e

REPO_DIR="./prefetch/repo"
REGISTRY="quay.io/bcook/rpms"

echo "=== Pushing RPMs to $REGISTRY ==="
echo "Note: Using architecture-specific tags since OCI index not supported in oras 1.2.3"
echo

# Function to extract NVR from RPM filename
get_nvr() {
    local rpm_file="$1"
    # Remove .rpm extension and architecture
    local basename=$(basename "$rpm_file" .rpm)
    # Remove architecture (last dot-separated component)
    echo "$basename" | sed 's/\.[^.]*$//'
}

# Function to get architecture from RPM filename
get_arch() {
    local rpm_file="$1"
    local basename=$(basename "$rpm_file" .rpm)
    # Get last dot-separated component
    echo "$basename" | sed 's/.*\.//'
}

# Count total RPMs
total_rpms=$(ls "$REPO_DIR"/*.rpm | wc -l)
current=1

echo "Pushing $total_rpms RPMs..."
echo

# Push each RPM with architecture-specific tag
for rpm_file in "$REPO_DIR"/*.rpm; do
    if [[ -f "$rpm_file" ]]; then
        nvr=$(get_nvr "$rpm_file")
        arch=$(get_arch "$rpm_file")
        
        # Create tag with architecture
        if [[ "$arch" == "noarch" ]]; then
            tag="$nvr"  # noarch packages don't need arch suffix
        else
            tag="$nvr.$arch"  # arch-specific packages get arch suffix
        fi
        
        echo "[$current/$total_rpms] Pushing $(basename "$rpm_file")"
        echo "  -> $REGISTRY:$tag"
        
        # Push the RPM
        if oras push "$REGISTRY:$tag" "$rpm_file"; then
            echo "  ✓ Success"
        else
            echo "  ✗ Failed"
            exit 1
        fi
        
        echo
        ((current++))
    fi
done

echo "=== Push Complete ==="
echo "All $total_rpms RPMs pushed to $REGISTRY"
echo
echo "Example tags created:"
echo "  quay.io/bcook/rpms:bash-5.3.0-2.fc43.x86_64"
echo "  quay.io/bcook/rpms:bash-5.3.0-2.fc43.aarch64"
echo "  quay.io/bcook/rpms:crypto-policies-20250714-4.gitcd6043a.fc44  (noarch)"