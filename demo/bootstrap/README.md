# Bootstrap - RPM to OCI Artifact Creation

This directory contains tools for the initial "bootstrap" process of converting RPMs into OCI artifacts.

## Files

### RPM Fetching
- **`rpms.lockfile.in`** - Input file defining which RPMs to fetch from Fedora repositories
- **`hermeto-prefetch.sh`** - Single-architecture RPM fetching (original demo)
- **`hermeto-multiarch-prefetch.sh`** - Multi-architecture RPM fetching for x86_64 and aarch64
- **`test-packages.sh`** - Validation script to test package availability

### OCI Artifact Publishing
- **`push-rpms-simple.sh`** - Push RPMs with architecture-specific tags (e.g., `bash-5.3.0-2.fc43.x86_64`)
- **`push-rpms-oci.sh`** - Complex OCI publishing (early version, not used)
- **`push-rpms-oci-simple.sh`** - Simplified OCI publishing (not used in final demo)

### OCI Image Index Creation
- **`create-indexes-simple.sh`** - Create OCI Image Indexes for multi-architecture packages
- **`create-multiarch-indexes.sh`** - Alternative implementation (not used)

### Generated Data
- **`prefetch/`** - Directory containing:
  - `repo/` - Downloaded RPM files and createrepo metadata
  - `cache/` - createrepo cache for incremental updates

## Usage Flow

1. **Fetch RPMs**: `./hermeto-multiarch-prefetch.sh`
2. **Push with arch tags**: `./push-rpms-simple.sh` 
3. **Create indexes**: `./create-indexes-simple.sh`

## Result

Creates both architecture-specific tags and OCI Image Indexes:
- Explicit: `quay.io/bcook/rpms:bash-5.3.0-2.fc43.x86_64`
- Automatic: `quay.io/bcook/rpms:bash-5.3.0-2.fc43` (resolves by platform)