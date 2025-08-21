#!/bin/bash

# Hermeto multi-architecture workflow - prefetch RPMs for both x86_64 and aarch64

set -e

LOCKFILE="rpms.lockfile.in"
OUTPUT_DIR="./prefetch"
REPO_DIR="$OUTPUT_DIR/repo"

echo "=== Hermeto Multi-Arch Prefetch Workflow ==="
echo "Lockfile: $LOCKFILE"
echo "Output directory: $OUTPUT_DIR"
echo

# Create output directories
mkdir -p "$REPO_DIR/x86_64" "$REPO_DIR/aarch64" "$OUTPUT_DIR/cache"

# Extract package list from lockfile (exclude architectures and context sections)
echo "Extracting package list from lockfile..."
packages=$(awk '/^packages:/,/^arches:/ {if(/^  - / && !/x86_64/ && !/aarch64/) print}' "$LOCKFILE" | sed 's/  - //' | tr '\n' ' ')
echo "Packages: $packages"
echo

# Download x86_64 RPMs
echo "=== Downloading x86_64 RPMs ==="
podman run --rm --platform linux/amd64 \
  -v "$PWD/$OUTPUT_DIR:/output:Z" \
  registry.fedoraproject.org/fedora:rawhide \
  bash -c "
    dnf install -y dnf-plugins-core
    dnf download --destdir /output/repo/x86_64 $packages
    echo 'Downloaded x86_64 RPMs:'
    ls -la /output/repo/x86_64/ | wc -l
  "

echo
echo "=== Downloading aarch64 RPMs ==="
podman run --rm --platform linux/arm64 \
  -v "$PWD/$OUTPUT_DIR:/output:Z" \
  registry.fedoraproject.org/fedora:rawhide \
  bash -c "
    dnf install -y dnf-plugins-core
    dnf download --destdir /output/repo/aarch64 $packages
    echo 'Downloaded aarch64 RPMs:'
    ls -la /output/repo/aarch64/ | wc -l
  "

echo
echo "=== Creating combined repository structure ==="
# Move all RPMs to the main repo directory
mv "$OUTPUT_DIR/repo/x86_64"/*.rpm "$OUTPUT_DIR/repo/" 2>/dev/null || true
mv "$OUTPUT_DIR/repo/aarch64"/*.rpm "$OUTPUT_DIR/repo/" 2>/dev/null || true

# Clean up architecture subdirectories
rmdir "$OUTPUT_DIR/repo/x86_64" "$OUTPUT_DIR/repo/aarch64" 2>/dev/null || true

echo
echo "Creating repository metadata with createrepo..."
podman run --rm \
  -v "$PWD/$OUTPUT_DIR:/output:Z" \
  registry.fedoraproject.org/fedora:rawhide \
  bash -c "
    dnf install -y createrepo_c
    createrepo_c --cachedir /output/cache /output/repo
    echo 'Repository metadata created:'
    ls -la /output/repo/repodata/
  "

echo
echo "=== Multi-Arch Prefetch Complete ==="
echo "Local repository available at: $REPO_DIR"
echo "Cache directory: $OUTPUT_DIR/cache"
echo
echo "RPM inventory:"
echo "  x86_64 RPMs: $(ls $REPO_DIR/*x86_64.rpm 2>/dev/null | wc -l)"
echo "  aarch64 RPMs: $(ls $REPO_DIR/*aarch64.rpm 2>/dev/null | wc -l)" 
echo "  noarch RPMs: $(ls $REPO_DIR/*noarch.rpm 2>/dev/null | wc -l)"
echo "  Total RPMs: $(ls $REPO_DIR/*.rpm 2>/dev/null | wc -l)"