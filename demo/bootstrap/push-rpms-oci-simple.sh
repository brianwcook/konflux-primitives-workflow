#!/bin/bash

# Push RPMs to quay.io using OCI index for multi-architecture support

set -e

REPO_DIR="./prefetch/repo"
REGISTRY="quay.io/bcook/rpms"

echo "=== Pushing RPMs to $REGISTRY with OCI Index ==="
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

# Function to convert RPM arch to OCI platform
rpm_arch_to_platform() {
    case "$1" in
        x86_64)   echo "linux/amd64" ;;
        aarch64)  echo "linux/arm64" ;;
        noarch)   echo "linux/amd64,linux/arm64" ;; # noarch works on both
        i686)     echo "linux/386" ;;
        *)        echo "linux/amd64" ;; # default
    esac
}

# Create temporary files to track NVRs and their RPMs
nvr_list=$(mktemp)
rpm_list=$(mktemp)

# Build list of all NVRs and their corresponding RPMs
for rpm_file in "$REPO_DIR"/*.rpm; do
    if [[ -f "$rpm_file" ]]; then
        nvr=$(get_nvr "$rpm_file")
        arch=$(get_arch "$rpm_file")
        echo "$nvr|$arch|$rpm_file" >> "$rpm_list"
    fi
done

# Get unique NVRs
cut -d'|' -f1 "$rpm_list" | sort -u > "$nvr_list"

echo "Found $(wc -l < "$nvr_list") unique package NVRs"
echo

# Process each unique NVR
while read -r nvr; do
    echo "Pushing $nvr..."
    
    # Get all RPMs for this NVR
    nvr_rpms=$(grep "^$nvr|" "$rpm_list")
    rpm_count=$(echo "$nvr_rpms" | wc -l)
    
    if [[ $rpm_count -eq 1 ]]; then
        # Single architecture
        arch=$(echo "$nvr_rpms" | cut -d'|' -f2)
        file=$(echo "$nvr_rpms" | cut -d'|' -f3)
        platform=$(rpm_arch_to_platform "$arch")
        
        echo "  Single arch ($arch) -> $REGISTRY:$nvr"
        oras push "$REGISTRY:$nvr" "$file" --platform "$platform"
        
    else
        # Multiple architectures - push each one to build OCI index
        echo "  Multi-arch -> $REGISTRY:$nvr"
        
        echo "$nvr_rpms" | while IFS='|' read -r n arch file; do
            platform=$(rpm_arch_to_platform "$arch")
            echo "    $arch ($platform)"
            oras push "$REGISTRY:$nvr" "$file" --platform "$platform"
        done
    fi
    
    echo "  ✓ Pushed $nvr"
    echo
done < "$nvr_list"

# Cleanup
rm -f "$nvr_list" "$rpm_list"

echo "=== OCI Push Complete ==="
echo "All RPMs pushed to $REGISTRY with OCI index support"
echo "Multi-architecture packages will automatically resolve to the correct platform"