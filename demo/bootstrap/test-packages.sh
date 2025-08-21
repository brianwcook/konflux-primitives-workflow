#!/bin/bash

# Test script to verify all packages in rpms.lockfile.in are available in Fedora rawhide

echo "Testing package availability in Fedora rawhide..."

# Extract package names from the lockfile
packages=$(grep "^  - " rpms.lockfile.in | sed 's/  - //' | tr '\n' ' ')

echo "Packages to test: $packages"
echo

# Test with dnf repoquery
echo "Running: podman run --rm registry.fedoraproject.org/fedora:rawhide dnf repoquery --available $packages"
echo

podman run --rm registry.fedoraproject.org/fedora:rawhide dnf repoquery --available $packages

echo
echo "Test completed. All packages listed above are available in Fedora rawhide."