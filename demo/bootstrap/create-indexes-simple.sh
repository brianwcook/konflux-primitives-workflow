#!/bin/bash

# Create OCI Image Indexes for packages with multiple architectures
# Simplified approach without associative arrays

set -e

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

# Get unique NVRs and check which ones have multiple architectures
echo "Analyzing packages for multi-architecture support..."
temp_file=$(mktemp)

for rpm in "$REPO_DIR"/*.rpm; do
    nvr=$(get_nvr_without_arch "$rpm")
    arch=$(get_arch "$rpm")
    echo "$nvr|$arch" >> "$temp_file"
done

# Find NVRs that appear with multiple architectures
multiarch_nvrs=$(sort "$temp_file" | cut -d'|' -f1 | uniq -c | awk '$1 > 1 {print $2}')

rm "$temp_file"

if [[ -z "$multiarch_nvrs" ]]; then
    echo "No multi-architecture packages found."
    exit 0
fi

echo "Multi-architecture packages found:"
echo "$multiarch_nvrs" | sed 's/^/  /'
echo

index_count=0

# Process each multi-arch package
for nvr in $multiarch_nvrs; do
    ((index_count++))
    echo "[$index_count] Creating OCI Image Index for: $nvr"
    
    # Find all architectures for this NVR
    archs=""
    for rpm in "$REPO_DIR"/*.rpm; do
        pkg_nvr=$(get_nvr_without_arch "$rpm")
        if [[ "$pkg_nvr" == "$nvr" ]]; then
            arch=$(get_arch "$rpm")
            if [[ "$arch" != "noarch" ]]; then  # Skip noarch for multi-arch indexes
                archs="$archs $arch"
            fi
        fi
    done
    
    # Remove duplicates and trim
    archs=$(echo $archs | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//')
    echo "  Architectures: $archs"
    
    # Build manifest list
    manifests=""
    first=true
    
    for arch in $archs; do
        arch_tag="$nvr.$arch"
        
        # Convert arch to platform
        case "$arch" in
            x86_64)   platform="amd64" ;;
            aarch64)  platform="arm64" ;;
            i686)     platform="386" ;;
            *)        platform="$arch" ;;
        esac
        
        echo "    Fetching manifest for $arch_tag (platform: linux/$platform)..."
        
        # Get manifest digest and size
        manifest_digest=$(oras manifest fetch "$REGISTRY:$arch_tag" --descriptor 2>/dev/null | jq -r '.digest')
        manifest_size=$(oras manifest fetch "$REGISTRY:$arch_tag" --descriptor 2>/dev/null | jq -r '.size')
        
        if [[ "$manifest_digest" == "null" || -z "$manifest_digest" ]]; then
            echo "    ⚠️  Warning: Could not fetch manifest for $arch_tag, skipping..."
            continue
        fi
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            manifests="$manifests,"
        fi
        
        manifests="$manifests
    {
      \"mediaType\": \"application/vnd.oci.image.manifest.v1+json\",
      \"digest\": \"$manifest_digest\",
      \"size\": $manifest_size,
      \"platform\": {
        \"architecture\": \"$platform\",
        \"os\": \"linux\"
      }
    }"
    done
    
    if [[ -z "$manifests" ]]; then
        echo "    ⚠️  No valid manifests found for $nvr, skipping..."
        continue
    fi
    
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
    
    echo "    Pushing OCI Image Index to $REGISTRY:$nvr..."
    if oras manifest push "$REGISTRY:$nvr" "$index_file"; then
        echo "    ✓ Success: $REGISTRY:$nvr"
    else
        echo "    ❌ Failed to push index for $nvr"
    fi
    
    # Clean up
    rm "$index_file"
    echo
done

echo "=== Multi-Architecture Index Creation Complete ==="
echo "Created $index_count OCI Image Indexes"
echo
echo "Examples of created indexes:"
echo "  quay.io/bcook/rpms:bash-5.3.0-2.fc43"
echo "  quay.io/bcook/rpms:gawk-5.3.2-2.fc43"
echo "  quay.io/bcook/rpms:util-linux-2.41.1-16.fc44"