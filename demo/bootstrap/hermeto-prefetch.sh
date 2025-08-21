#!/bin/bash

# Hermeto workflow - prefetch RPMs and create local repository
# This performs the core Hermeto functionality using our rpms.lockfile.in

set -e

LOCKFILE="rpms.lockfile.in"
OUTPUT_DIR="./prefetch"
REPO_DIR="$OUTPUT_DIR/repo"

echo "=== Hermeto Prefetch Workflow ==="
echo "Lockfile: $LOCKFILE"
echo "Output directory: $OUTPUT_DIR"
echo

# Create output directories
mkdir -p "$REPO_DIR"

# Extract package list from lockfile (exclude architectures and context sections)
echo "Extracting package list from lockfile..."
packages=$(awk '/^packages:/,/^arches:/ {if(/^  - / && !/x86_64/ && !/aarch64/) print}' "$LOCKFILE" | sed 's/  - //' | tr '\n' ' ')
echo "Packages: $packages"
echo

# Use Fedora container to download RPMs
echo "Downloading RPMs using Fedora rawhide..."
podman run --rm \
  -v "$PWD/$OUTPUT_DIR:/output:Z" \
  registry.fedoraproject.org/fedora:rawhide \
  bash -c "
    dnf install -y dnf-plugins-core createrepo_c
    dnf download --destdir /output/repo $packages
    echo 'Downloaded \$(ls /output/repo/*.rpm | wc -l) RPM files'
    ls -la /output/repo/
  "

echo
echo "Creating local repository metadata with createrepo..."
podman run --rm \
  -v "$PWD/$OUTPUT_DIR:/output:Z" \
  registry.fedoraproject.org/fedora:rawhide \
  bash -c "
    dnf install -y createrepo_c
    createrepo_c /output/repo
    echo 'Repository metadata created:'
    ls -la /output/repo/repodata/
  "

echo
echo "=== Hermeto Prefetch Complete ==="
echo "Local repository available at: $REPO_DIR"
echo "You can now use this repository with DNF by pointing to file://$PWD/$REPO_DIR"
echo
echo "To test the repository:"
echo "podman run --rm -v $PWD/$OUTPUT_DIR:/repo:Z registry.fedoraproject.org/fedora:rawhide \\"
echo "  dnf --disablerepo='*' --enablerepo=local --repofrompath=local,/repo/repo repolist"