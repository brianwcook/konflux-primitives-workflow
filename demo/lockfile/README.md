# Lockfile Transformation Tools

This directory contains the core transformation system that converts standard DNF lockfiles to use OCI artifact references.

## Files

### Core Tool
- **`transform-lockfile.py`** - Production-ready lockfile transformer
  - Converts rpm-lockfile-prototype output to OCI references
  - Handles character sanitization for OCI compliance
  - Preserves all metadata and architecture information
  - Maps DNF package names to OCI-compliant tags

### Output Examples
- **`complete-oci-lockfile.yaml`** - Transformed lockfile using complete compose
  - Shows transformation of 427 packages to OCI references
  - Demonstrates character sanitization (`libstdc++` → `libstdc--`)
  - Ready for use with hermeto

## Core Tool Usage

### Basic Transformation
```bash
python3 transform-lockfile.py \
  ../compose/fedora-complete-compose.yaml \
  input-lockfile.yaml \
  output-oci-lockfile.yaml
```

### Command Line Options
```bash
python3 transform-lockfile.py --help
usage: transform-lockfile.py [-h] [--verbose] compose_file input_lockfile output_lockfile

Transform lockfile file:/// references to OCI references

positional arguments:
  compose_file     Path to compose file with OCI mappings
  input_lockfile   Input lockfile with file:/// references
  output_lockfile  Output lockfile with OCI references

optional arguments:
  -h, --help       show this help message and exit
  --verbose, -v    Verbose output
```

## Features

### 1. Character Sanitization
The transformer handles OCI-invalid characters in package names:

| Original Package | OCI Tag | Mapping |
|-----------------|---------|---------|
| `libstdc++` | `libstdc--15.2.1-1.fc43` | `+` → `-` |
| `python3` v`3.14.0~rc2` | `python3-3.14.0-rc2-1.fc44` | `~` → `-` |

### 2. Architecture Support
- Processes both aarch64 and x86_64 packages
- Handles noarch packages correctly
- Preserves architecture information in output

### 3. Metadata Preservation
- Maintains original URLs for reference
- Preserves checksums, sizes, and repo information
- Adds OCI references without breaking compatibility

## Transformation Process

### Input Format (rpm-lockfile-prototype output)
```yaml
lockfileVersion: 1
lockfileVendor: redhat
arches:
- arch: x86_64
  packages:
  - name: bash
    evr: 5.3.0-2.fc43
    url: https://dl.fedoraproject.org/pub/fedora/.../bash-5.3.0-2.fc43.x86_64.rpm
    size: 1234567
    checksum: sha256:abcdef...
```

### Output Format (OCI-enabled)
```yaml
lockfileVersion: 1
lockfileVendor: redhat
arches:
- arch: x86_64
  packages:
  - name: bash
    evr: 5.3.0-2.fc43
    url: oci://quay.io/bcook/rpms:bash-5.3.0-2.fc43.x86_64-x86_64
    original_url: https://dl.fedoraproject.org/pub/fedora/.../bash-5.3.0-2.fc43.x86_64.rpm
    oci_ref: oci://quay.io/bcook/rpms:bash-5.3.0-2.fc43.x86_64-x86_64
    size: 1234567
    checksum: sha256:abcdef...
```

## Integration Points

### With rpm-lockfile-prototype
```bash
# 1. Generate standard lockfile
rpm-lockfile-prototype my-packages.lockfile.in > deps.lockfile.yaml

# 2. Transform to OCI references  
python3 transform-lockfile.py \
  ../compose/my-compose.yaml \
  deps.lockfile.yaml \
  oci-deps.lockfile.yaml
```

### With hermeto
```bash
# 3. Use OCI lockfile for hermetic builds
hermeto build --lockfile oci-deps.lockfile.yaml
```

### With Compose Files
The transformer uses compose files to map package names to OCI locations:

```yaml
# compose file
packages:
  bash:
    location: oci://quay.io/bcook/rpms:bash-5.3.0-2.fc43
  libstdc++:  # Original name with +
    location: oci://quay.io/bcook/rpms:libstdc--15.2.1-1.fc43  # Sanitized OCI tag
```

## Error Handling

The transformer provides detailed reporting:
- **Packages transformed**: Count of successful transformations
- **Missing mappings**: Packages not found in compose file  
- **Verbose mode**: Detailed transformation logs

Example output:
```
Transformation complete:
  Packages transformed: 427
  Missing mappings: 0

Success: Transformed 427 packages
```

## Production Use

This tool is production-ready and handles:
- ✅ Large lockfiles (427+ packages tested)
- ✅ Multi-architecture support
- ✅ Character sanitization edge cases
- ✅ Error reporting and validation
- ✅ Backward compatibility with existing lockfile formats

The transformer is a critical component of the OCI-based RPM compose system and enables seamless integration between traditional DNF workflows and OCI-native hermetic builds.