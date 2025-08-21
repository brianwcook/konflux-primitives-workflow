# Lockfile - File:/// to OCI Reference Transformation

This directory contains the lockfile transformation system that converts traditional file:/// RPM references to OCI artifact references.

## Files

### Input Files
- **`local-repo.lockfile.in`** - Input format for rpm-lockfile-prototype
  - Points to local file:/// repository created by bootstrap process
  - Lists packages for dependency resolution

### Mock/Example Files  
- **`example-lockfile.yaml`** - Mock output simulating rpm-lockfile-prototype
  - Shows what rpm-lockfile-prototype would generate with file:/// references
  - Used for testing the transformation process

### Transformation
- **`transform-lockfile.py`** - Core transformation script
  - Reads compose file to get package → OCI mappings
  - Converts file:/// references to OCI references
  - Preserves original references for debugging

### Output
- **`transformed-lockfile.yaml`** - Final OCI-enabled lockfile
  - Contains OCI references compatible with Hermeto
  - Ready for hermetic container builds

## Usage Flow

```bash
# 1. (In real usage) Generate lockfile from local repo
# rpm-lockfile-prototype --input local-repo.lockfile.in --output file-lockfile.yaml

# 2. Transform file:/// references to OCI references  
python3 transform-lockfile.py ../compose/fedora-base-compose.yaml example-lockfile.yaml transformed-lockfile.yaml

# 3. Use transformed lockfile with Hermeto for hermetic builds
# hermeto --lockfile transformed-lockfile.yaml
```

## Transformation Example

**Before (file:/// reference)**:
```yaml
- name: bash
  rpm_path: file:///workspace/prefetch/repo/bash-5.3.0-2.fc43.x86_64.rpm
```

**After (OCI reference)**:
```yaml
- name: bash
  rpm_path: oci://quay.io/bcook/rpms:bash-5.3.0-2.fc43
  oci_ref: oci://quay.io/bcook/rpms:bash-5.3.0-2.fc43
  original_rpm_path: file:///workspace/prefetch/repo/bash-5.3.0-2.fc43.x86_64.rpm
```

This enables hermetic builds using OCI artifacts while preserving the DNF dependency resolution workflow.