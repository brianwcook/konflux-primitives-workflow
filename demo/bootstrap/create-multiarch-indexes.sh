#!/bin/bash

# Create OCI Image Indexes for packages with multiple architectures

set -e

# Ensure we're using bash for associative arrays
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

REPO_DIR="./prefetch/repo"
REGISTRY="quay.io/bcook/rpms"

echo "=== Creating OCI Image Indexes for Multi-Architecture Packages ==="
echo

# Function to extract NVR from RPM filename (without architecture)
get_nvr_without_arch() {
    local rpm_file="$1"
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
arch_to_platform() {
    case "$1" in
        x86_64)   echo "linux/amd64" ;;
        aarch64)  echo "linux/arm64" ;;
        i686)     echo "linux/386" ;;
        noarch)   echo "linux/amd64" ;;  # Default platform for noarch
        *)        echo "linux/$1" ;;
    esac
}

# Get list of unique NVRs and their architectures
echo "Analyzing packages for multi-architecture support..."
temp_file=$(mktemp)

for rpm in "$REPO_DIR"/*.rpm; do
    nvr=$(get_nvr_without_arch "$rpm")
    arch=$(get_arch "$rpm")
    echo "$nvr|$arch|$(basename $rpm)" >> "$temp_file"
done

# Group by NVR and identify multi-arch packages
declare -A nvr_archs
declare -A nvr_files

while IFS='|' read -r nvr arch filename; do
    if [[ -z "${nvr_archs[$nvr]}" ]]; then
        nvr_archs[$nvr]="$arch"
        nvr_files[$nvr]="$filename"
    else
        nvr_archs[$nvr]="${nvr_archs[$nvr]} $arch"
        nvr_files[$nvr]="${nvr_files[$nvr]} $filename"
    fi
done < "$temp_file"

rm "$temp_file"

# Create indexes for multi-arch packages
index_count=0
total_packages=${#nvr_archs[@]}

echo "Found $total_packages unique packages"
echo

for nvr in "${!nvr_archs[@]}"; do
    archs_array=(${nvr_archs[$nvr]})
    files_array=(${nvr_files[$nvr]})
    
    # Skip single-architecture packages and noarch-only packages
    if [[ ${#archs_array[@]} -le 1 ]]; then
        continue
    fi
    
    # Skip if only noarch
    if [[ ${#archs_array[@]} -eq 1 && "${archs_array[0]}" == "noarch" ]]; then
        continue
    fi
    
    ((index_count++))
    echo "[$index_count] Creating OCI Image Index for: $nvr"
    echo "  Architectures: ${nvr_archs[$nvr]}"
    
    # Fetch manifest digests for each architecture
    manifests=""
    for i in "${!archs_array[@]}"; do
        arch="${archs_array[$i]}"
        filename="${files_array[$i]}"
        
        # Skip noarch in multi-arch packages (we'll use amd64 as default)
        if [[ "$arch" == "noarch" ]]; then
            continue
        fi
        
        arch_tag="$nvr.$arch"
        platform=$(arch_to_platform "$arch")
        
        echo "    Fetching manifest for $arch_tag..."
        manifest_info=$(oras manifest fetch "$REGISTRY:$arch_tag" 2>/dev/null | jq -c '{mediaType, config, layers, annotations}')
        manifest_digest=$(oras manifest fetch "$REGISTRY:$arch_tag" --descriptor 2>/dev/null | jq -r '.digest')
        manifest_size=$(oras manifest fetch "$REGISTRY:$arch_tag" --descriptor 2>/dev/null | jq -r '.size')
        
        if [[ -n "$manifests" ]]; then
            manifests="$manifests,"
        fi
        
        manifests="$manifests
    {
      \"mediaType\": \"application/vnd.oci.image.manifest.v1+json\",
      \"digest\": \"$manifest_digest\",
      \"size\": $manifest_size,
      \"platform\": {
        \"architecture\": \"$(echo $platform | cut -d'/' -f2)\",
        \"os\": \"linux\"
      }
    }"
    done
    
    # Create OCI Image Index manifest
    index_file="index-$nvr.json"
    cat > "$index_file" << EOF
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [$manifests
  ]
}
EOF
    
    echo "    Pushing OCI Image Index to $REGISTRY:$nvr"
    oras manifest push "$REGISTRY:$nvr" "$index_file"
    
    # Clean up
    rm "$index_file"
    
    echo "    ✓ Success"
    echo
done

echo "=== Multi-Architecture Index Creation Complete ==="
echo "Created $index_count OCI Image Indexes"
echo
echo "Examples of created indexes:"
echo "  quay.io/bcook/rpms:bash-5.3.0-2.fc43       (amd64, arm64)"
echo "  quay.io/bcook/rpms:util-linux-2.41.1-16.fc44  (amd64, arm64, 386)"
echo "  quay.io/bcook/rpms:glibc-2.42.9000-1.fc44    (amd64, arm64, 386)"