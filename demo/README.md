# OCI RPM Compose System - Demo

This directory demonstrates a complete working implementation of the OCI-based RPM compose system described in the architecture document.

## Directory Structure

```
demo/
├── bootstrap/          # RPM fetching and OCI artifact creation
├── lockfile/           # Lockfile transformation (file:/// → OCI)
├── compose/            # Compose file definitions
├── DEMO_RESULTS.md     # Multi-architecture RPM publishing results
├── ORAS_UPGRADE_RESULTS.md  # OCI Image Index implementation
├── LOCKFILE_DEMO.md    # Lockfile transformation results
└── README.md           # This file
```

## What This Demonstrates

### 1. Bootstrap Process (`bootstrap/`)
- **RPM Fetching**: Download RPMs from Fedora repositories for multiple architectures
- **Local Repository**: Create DNF repository with metadata using createrepo_c
- **OCI Publishing**: Push RPMs as OCI artifacts with both:
  - Architecture-specific tags: `quay.io/bcook/rpms:bash-5.3.0-2.fc43.x86_64`
  - OCI Image Indexes: `quay.io/bcook/rpms:bash-5.3.0-2.fc43` (auto-resolves)

### 2. Compose Management (`compose/`)
- **Package Mapping**: Define which packages map to which OCI artifacts
- **Version Control**: Track package versions and OCI references
- **Multi-Architecture**: Use OCI Image Indexes for automatic platform resolution

### 3. Lockfile Transformation (`lockfile/`)
- **File → OCI**: Transform traditional file:/// lockfiles to OCI references
- **Compose Integration**: Use compose files as source of truth for mappings
- **Hermeto Compatibility**: Generate lockfiles ready for hermetic builds

## End-to-End Workflow

```mermaid
graph LR
    A[Fedora Repos] --> B[Bootstrap: Fetch RPMs]
    B --> C[Bootstrap: Create OCI Artifacts]
    C --> D[Compose: Define Mappings]
    D --> E[Lockfile: Transform References]
    E --> F[Hermeto: Hermetic Builds]
```

## Demo Results

- **73 RPM artifacts** published to quay.io/bcook/rpms
- **31 OCI Image Indexes** created for multi-architecture packages
- **Complete lockfile transformation** from file:/// to OCI references
- **Functional hermetic build pipeline** ready for integration

## Key Achievements

✅ **True OCI Image Index support** with oras v1.3.0-beta.4  
✅ **Multi-architecture automatic resolution**  
✅ **Complete lockfile transformation workflow**  
✅ **Compose-driven package management**  
✅ **Incremental metadata updates** with createrepo cache  
✅ **End-to-end hermetic build compatibility**

## Architecture Integration

This demo validates all core components of the OCI RPM compose system architecture:

- **RPM → OCI transformation** (bootstrap)
- **Compose file management** (compose)  
- **Lockfile transformation** (lockfile)
- **Multi-architecture support** (OCI Image Indexes)
- **Hermetic build integration** (Hermeto compatibility)

See individual directory READMEs for detailed usage instructions.