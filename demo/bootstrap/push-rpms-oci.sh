#!/bin/bash

# Push RPMs to quay.io using OCI index for multi-architecture support

set -e

# Ensure we're using bash for associative arrays
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

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

# Get all unique NVRs
declare -A nvr_map
for rpm_file in "$REPO_DIR"/*.rpm; do
    if [[ -f "$rpm_file" ]]; then
        nvr=$(get_nvr "$rpm_file")
        arch=$(get_arch "$rpm_file")
        
        if [[ -z "${nvr_map[$nvr]}" ]]; then
            nvr_map[$nvr]="$arch:$rpm_file"
        else
            nvr_map[$nvr]="${nvr_map[$nvr]},$arch:$rpm_file"
        fi
    fi
done

echo "Found $(echo "${!nvr_map[@]}" | wc -w) unique package NVRs"
echo

# Push each NVR with all its architectures
for nvr in "${!nvr_map[@]}"; do
    echo "Pushing $nvr..."
    
    # Parse architectures and files for this NVR
    IFS=',' read -ra arch_files <<< "${nvr_map[$nvr]}"
    
    # Check if we have multiple architectures for this package
    arch_count=$(echo "${nvr_map[$nvr]}" | tr ',' '\n' | wc -l)
    
    if [[ $arch_count -eq 1 ]]; then
        # Single architecture - simple push
        arch_file="${arch_files[0]}"
        arch=$(echo "$arch_file" | cut -d: -f1)
        file=$(echo "$arch_file" | cut -d: -f2)
        platform=$(rpm_arch_to_platform "$arch")
        
        echo "  Single arch ($arch) -> $REGISTRY:$nvr"
        oras push "$REGISTRY:$nvr" "$file" --platform "$platform"
        
    else
        # Multiple architectures - create multi-arch index
        echo "  Multi-arch ($(echo "${arch_files[@]}" | sed 's/:[^ ]*//g' | tr ' ' ',')) -> $REGISTRY:$nvr"
        
        # Push each architecture 
        for arch_file in "${arch_files[@]}"; do
            arch=$(echo "$arch_file" | cut -d: -f1)
            file=$(echo "$arch_file" | cut -d: -f2)
            platform=$(rpm_arch_to_platform "$arch")
            
            echo "    $arch ($platform)"
            oras push "$REGISTRY:$nvr" "$file" --platform "$platform"
        done
    fi
    
    echo "  ✓ Pushed $nvr"
    echo
done

echo "=== OCI Push Complete ==="
echo "All RPMs pushed to $REGISTRY with OCI index support"
echo "Multi-architecture packages will automatically resolve to the correct platform"