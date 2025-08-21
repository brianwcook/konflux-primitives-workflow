# Compose - Package to OCI Mapping Definitions

This directory contains compose files that define the mapping between package names and their OCI artifact locations.

## Files

### Compose Definitions
- **`fedora-base-compose.yaml`** - Base Fedora system compose
  - Maps 37 core system packages to OCI references
  - Uses OCI Image Index references for automatic architecture resolution
  - Serves as single source of truth for package-to-OCI mappings

## Compose File Format

```yaml
apiVersion: v1
kind: Compose
metadata:
  name: fedora-base
  version: "1.0.0"
  description: "Base Fedora system packages"
  
packages:
  bash:
    version: "5.3.0-2.fc43"
    oci_ref: "oci://quay.io/bcook/rpms:bash-5.3.0-2.fc43"
  # ... more packages

metadata:
  location: "oci://quay.io/bcook/metadata/fedora-base:v1.0.0"
  cache_location: "oci://quay.io/bcook/cache/fedora-base:v1.0.0"
```

## Usage

The compose file is used by:

1. **Lockfile transformation** - Maps package names to OCI references during transformation
2. **Renovate updates** - Automated PRs to update package versions
3. **Metadata generation** - Source of truth for creating DNF repository metadata
4. **Documentation** - Clear definition of what packages are in the compose

## Key Features

- **Multi-architecture support** - OCI Image Index references automatically resolve to correct architecture
- **Version tracking** - Explicit version information for each package  
- **Metadata references** - Points to DNF metadata and cache locations
- **Compose versioning** - Each compose has its own version for tracking changes

## Future Extensions

- Multiple compose files for different use cases (base, devel, server, etc.)
- Compose inheritance and composition
- Package conflict resolution between composes
- Integration with Konflux-ci build triggers