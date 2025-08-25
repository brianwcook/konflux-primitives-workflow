# OCI-Based RPM Compose System Design

## Overview

This system enables on-demand creation of RPM "composes" - curated sets of RPM packages with DNF metadata - using OCI artifacts for storage and modern CI/CD practices for updates.

## Goals

- Enable incremental testing of individual RPM updates within compose contexts
- Support multiple conflicting package versions (e.g., different GCC toolchains)
- Provide hermetic, reproducible builds using DNF repositories
- Leverage OCI registries for artifact storage and distribution

## Architecture Components

### Core Components

**Compose Definition**: Text file mapping RPM names to OCI artifact locations and versions
**DNF Metadata**: Standard createrepo-generated metadata (repomd.xml, primary.xml.gz, etc.)
**Cache Artifacts**: createrepo cache directories stored as OCI artifacts for incremental updates
**Integration Pipeline**: CI system handling updates, testing, and promotion

### External Dependencies

- **Konflux-ci**: Builds and publishes RPMs as OCI artifacts
- **Renovate**: Monitors RPM versions and creates update PRs
- **rpm-lockfile-prototype**: Generates lockfiles for dependency resolution
- **Hermeto**: Fetches dependencies for hermetic builds
- **createrepo_c**: Generates DNF repository metadata

## System Flow

```mermaid
graph TD
    A[RPM Built in Konflux] --> B[Stored as OCI Artifact]
    B --> C[Renovate Detects New Version]
    C --> D[Creates PR to Update Compose File]
    D --> E[CI Pipeline Triggered]
    E --> F[Pull Previous Cache from OCI]
    F --> G[Run createrepo_c --update]
    G --> H[Generate New Metadata]
    H --> I[Run Integration Tests]
    I --> J{Tests Pass?}
    J -->|Yes| K[Publish RPM + Metadata + Cache to OCI]
    J -->|No| L[Fail Build]
    K --> M[Update Compose File]
    M --> N[Merge via Queue]
```

## Compose File Format

```yaml
apiVersion: v1
kind: Compose
metadata:
  name: rhel9-gcc13-latest
spec:
  packages:
    httpd:
      version: "2.4.57"
      oci_ref: "oci://quay.io/konflux/rpms/httpd:2.4.57"
    gcc:
      version: "13.2.0"
      oci_ref: "oci://quay.io/konflux/rpms/gcc:13.2.0"
  metadata:
    location: "oci://quay.io/konflux/metadata/rhel9-gcc13:v1.2.3"
    cache_location: "oci://quay.io/konflux/cache/rhel9-gcc13:v1.2.3"
```

## Metadata Generation Pipeline

### Initial Compose Creation
1. Start with empty cache directory
2. Run `createrepo_c --cachedir /tmp/cache /repo` (full generation)
3. Publish metadata and cache as OCI artifacts
4. Update compose file with artifact references

### Incremental Updates
1. Pull existing cache from OCI registry
2. Run `createrepo_c --update --cachedir /cache /repo`
3. Only processes changed/new RPMs (typically seconds vs minutes)
4. Test metadata with integration suite
5. Publish updated metadata and cache if tests pass

### Cache Management
- Each compose maintains separate cache (no sharing between composes)
- Cache size: ~3-10 MB for 1000 RPMs
- Cache artifacts versioned alongside metadata
- Merge queue prevents concurrent cache corruption

## Consumption Workflow

The consumption process consists of two distinct phases:

### Phase 1: Lockfile Generation (Development Time)

Performed by developers/maintainers and committed to source control:

```mermaid
graph LR
    A[Developer] --> B[Pull Compose Metadata from OCI]
    B --> C[Run rpm-lockfile-prototype]
    C --> D[Transform to OCI References]
    D --> E[Commit Lockfile to Git]
```

### Phase 2: Hermetic Build Execution (CI Pipeline)

Performed automatically during container builds:

```mermaid
graph LR
    A[CI Build Starts] --> B[Read Committed Lockfile]
    B --> C[Hermeto Fetches RPMs from OCI]
    C --> D[Hermeto Runs createrepo Locally]
    D --> E[DNF Installs from Local Repo]
    E --> F[Container Build Completes]
```

## Key Design Decisions

### Cache as Artifact
Store createrepo cache directories as OCI artifacts to enable:
- Reproducible incremental metadata generation
- Atomic promotion of RPM + metadata + cache
- Rollback capability to any previous state

### Merge Queue Sequencing
Process all compose updates sequentially to prevent:
- Cache corruption from concurrent modifications  
- Lost updates from parallel builds using stale cache
- Inconsistent metadata states

### No Cross-Compose Sharing
Each compose maintains independent cache and metadata to:
- Avoid complex dependency tracking between composes
- Enable independent testing and promotion
- Simplify rollback and debugging

## Storage Requirements

| Component | Size (1000 RPMs) | Transfer Time |
|-----------|------------------|---------------|
| Cache Directory | 3-10 MB | 1-3 seconds |
| DNF Metadata | 1-3 MB | <1 second |
| Individual RPM | 1-50 MB | 1-10 seconds |

## Error Handling

- **Cache corruption**: Fall back to full metadata rebuild
- **Integration test failure**: Block promotion, retain previous version
- **OCI artifact unavailable**: Fail build with clear error message
- **Concurrent builds**: Merge queue rejects conflicting updates

## OCI-DNF Integration Solution

### Dependency Resolution Process

The system bridges traditional DNF tooling with OCI artifact storage through a three-stage process:

1. **Metadata Expansion**: Pull DNF metadata from OCI registry and expand locally
2. **Dependency Resolution**: Use rpm-lockfile-prototype against local metadata 
3. **Reference Transformation**: Map resolved packages to OCI locations using compose file

### Implementation Flow

```mermaid
graph TD
    A[Pull Metadata from OCI] --> B[rpm-lockfile-prototype depsolve]
    B --> C[Generate lockfile with file refs]
    C --> D[Transform using compose file]
    D --> E[Final lockfile with OCI refs]
    
    F[Compose File] --> D
    F --> G[OCI package mappings]
    G --> D
```

### Transformation Logic

rpm-lockfile-prototype generates standard lockfiles with file references:

```yaml
# Initial lockfile output
packages:
  - name: httpd
    version: 2.4.57
    source: "file:///repo/httpd-2.4.57.rpm"
  - name: httpd-tools  
    version: 2.4.57
    source: "file:///repo/httpd-tools-2.4.57.rpm"
```

Post-processing transforms these to OCI references using the compose file:

```yaml
# Final lockfile with OCI references
packages:
  - name: httpd
    version: 2.4.57
    source: "oci://quay.io/konflux/rpms/httpd:2.4.57"
  - name: httpd-tools
    version: 2.4.57  
    source: "oci://quay.io/konflux/rpms/httpd-tools:2.4.57"
```

### Error Handling

This approach enables validation during transformation:
- **Missing packages**: Resolved dependency not found in compose file
- **Version mismatches**: Resolved version differs from compose version
- **Invalid OCI references**: Can verify OCI locations exist before generating final lockfile

### Future Enhancement

The transformation logic could be integrated directly into rpm-lockfile-prototype to:
- Accept compose file as additional input parameter
- Generate lockfiles with OCI references natively
- Eliminate need for separate post-processing step

### Open Questions

**Transitive dependency handling**: When DNF resolves dependencies not explicitly listed in the compose file, the system needs a strategy to map them to OCI locations. Options include:
- Requiring all transitive dependencies in compose (explicit but verbose)
- Using naming conventions to generate OCI references
- Maintaining separate base package registry for common dependencies

## Validated Implementation Details

### Working Depsolving Workflow

The following implementation has been validated end-to-end with functional testing:

#### Step 1: Download OCI Metadata and Cache

```bash
# Download metadata archive from OCI registry
oras pull quay.io/repo/rpms:compose-metadata-v1.0.0 -o workspace/

# Download cache archive for incremental updates
oras pull quay.io/repo/rpms:compose-cache-v1.0.0 -o workspace/

# Extract repository structure
cd workspace/
tar -xzf compose-metadata.tar.gz  # Creates repodata/
tar -xzf compose-cache.tar.gz     # Creates cache/
```

#### Step 2: Create DNF-compatible Repository Structure

```bash
# Repository structure for rpm-lockfile-prototype
workspace/
├── repodata/          # DNF metadata
│   ├── repomd.xml
│   ├── primary.xml.gz
│   └── ...
├── cache/             # createrepo cache
├── input.lockfile.in  # Package requirements
└── output.yaml        # Generated lockfile
```

#### Step 3: Dependency Resolution with rpm-lockfile-prototype

**Critical Command Structure**: The rpm-lockfile-prototype container has an entrypoint, so the correct invocation is:

```bash
# CORRECT: Tool name omitted (provided by entrypoint)
podman run --rm -it \
  -v workspace:/workspace \
  -w /workspace \
  localhost/rpm-lockfile-prototype:latest \
  --outfile resolved.lockfile.yaml \
  input.lockfile.in

# INCORRECT: Including tool name causes argument parsing errors
podman run ... rpm-lockfile-prototype --outfile ...  # ❌ FAILS
```

**Input File Format**: Container-relative paths must be used:

```yaml
# input.lockfile.in - Correct format
contentOrigin:
  repos:
    - repoid: local-oci-repo
      baseurl: file:///workspace/oci-repo  # Container path, not host path

packages:
  - bash
  - systemd
  - python3

arches:
  - x86_64

context:
  bare: true  # Context specified in file, not command line

allowerasing: true
installWeakDeps: true
```

#### Step 4: Transform Lockfile to OCI References

```bash
# Convert file:// URLs to oci:// URLs using compose file mapping
python3 transform-lockfile.py \
  compose-file.yaml \
  resolved.lockfile.yaml \
  final-oci.lockfile.yaml
```

### Character Sanitization Handling

The validated implementation correctly handles OCI tag naming constraints:

**DNF Metadata**: Preserves original names with special characters
```xml
<package type="rpm">
  <name>libstdc++</name>     <!-- Original name -->
  <name>python3</name>       <!-- Original name -->
  <version ver="3.14.0~rc2"/> <!-- Original version -->
</package>
```

**Compose File Mapping**: Maps original names to sanitized OCI tags
```yaml
packages:
  libstdc++:  # DNF metadata name (with +)
    location: "oci://quay.io/repo:libstdc--15.2.1-1.fc43"  # Sanitized OCI tag
  python3:    # DNF metadata name  
    location: "oci://quay.io/repo:python3-3.14.0-rc2-1.fc44"  # Sanitized version (~→-)
```

**Transformation Logic**: Correctly maps between the two naming schemes
```python
# Extract package name from DNF lockfile: "python3"
# Look up in compose file: finds location with sanitized tag
# Result: "oci://quay.io/repo:python3-3.14.0-rc2-1.fc44"
```

### Validated Results

**Test Scale**: 5 input packages → 129 resolved packages (complete dependency tree)
**Success Rate**: 100% package mapping, zero missing dependencies  
**Character Handling**: Correctly handled `+`, `~`, and other special characters
**Tool Integration**: Confirmed compatibility with rpm-lockfile-prototype v1.0

## Implementation Update: OCI Index Support

**oras Version Upgrade**: Upgraded from v1.2.3 to v1.3.0-beta.4

### New Capabilities ✅
- **`--artifact-platform` flag**: Enables creation of true OCI Image Indexes (multi-arch manifests)
- **Platform-aware publishing**: Can push same artifact to multiple architectures under single tag

### Updated Compose File Format
With OCI Index support, the original design is now achievable:

```yaml
# Clean single-tag approach (preferred)
packages:
  bash:
    version: "5.3.0-2.fc43"
    oci_ref: "oci://quay.io/bcook/rpms:bash-5.3.0-2.fc43"  # auto-resolves architecture
```

### Implementation Process
The OCI Image Index creation requires a multi-step process:

```bash
# Step 1: Push each architecture to temporary tags
oras push quay.io/bcook/rpms:bash-temp-amd64 bash.x86_64.rpm --artifact-type application/vnd.rpm
oras push quay.io/bcook/rpms:bash-temp-arm64 bash.aarch64.rpm --artifact-type application/vnd.rpm

# Step 2: Create OCI Image Index manifest
cat > index.json << EOF
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:...",
      "platform": {"architecture": "amd64", "os": "linux"}
    },
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json", 
      "digest": "sha256:...",
      "platform": {"architecture": "arm64", "os": "linux"}
    }
  ]
}
EOF

# Step 3: Push the index manifest to final tag
oras manifest push quay.io/bcook/rpms:bash-5.3.0-2.fc43 index.json
```

**Result**: Single tag `quay.io/bcook/rpms:bash-5.3.0-2.fc43` containing OCI Image Index that automatically resolves to correct architecture when pulled with `--platform linux/amd64` or `--platform linux/arm64`.

This approach removes the need for architecture-specific tag management in compose files and lockfile transformation logic.

## OCI Tag Naming Constraints and Character Sanitization

### Problem

RPM package names and versions can contain characters that are invalid in OCI tag names:

- Package names: `libstdc++`, `gcc-c++` (contain `+`)
- Versions: `3.14.0~rc2`, `2.1.0~beta1` (contain `~`)

The OCI Distribution Specification restricts tag names to: `[a-zA-Z0-9_][a-zA-Z0-9._-]{0,127}`

**Invalid characters in OCI tags**: `+`, `~`, `%`, spaces, and most special characters
**Valid characters**: letters, numbers, underscore (`_`), period (`.`), dash (`-`)

### Examples of the Problem

| Package | Version | Valid RPM Filename | Invalid OCI Tag | Valid OCI Tag |
|---------|---------|-------------------|-----------------|---------------|
| `libstdc++` | `15.2.1-1.fc43` | `libstdc++-15.2.1-1.fc43.x86_64.rpm` | `libstdc++-15.2.1-1.fc43-x86_64` ❌ | `libstdc--15.2.1-1.fc43-x86_64` ✅ |
| `python3` | `3.14.0~rc2-1.fc44` | `python3-3.14.0~rc2-1.fc44.x86_64.rpm` | `python3-3.14.0~rc2-1.fc44-x86_64` ❌ | `python3-3.14.0-rc2-1.fc44-x86_64` ✅ |

### Solution: Character Sanitization with Mapping

#### 1. Sanitization Rules

When uploading RPMs as OCI artifacts, apply these character substitutions:
- `+` → `-` (plus to dash)  
- `~` → `-` (tilde to dash)
- Any other invalid characters → `-`

#### 2. Repository Metadata Preservation

The DNF repository metadata preserves original package names and versions:
```xml
<package type="rpm">
  <name>libstdc++</name>  <!-- Original name with + -->
  <version epoch="0" ver="15.2.1" rel="1.fc43"/>
</package>
```

#### 3. Compose File Mapping

The compose file maps original package names to sanitized OCI references:
```yaml
packages:
  libstdc++:  # Original name (what DNF sees)
    location: "oci://quay.io/bcook/rpms:libstdc--15.2.1-1.fc43"  # Sanitized OCI tag
  python3:
    location: "oci://quay.io/bcook/rpms:python3-3.14.0-rc2-1.fc44"
```

#### 4. Lockfile Transformation

When transforming lockfiles, the process handles the mapping:

1. **Parse RPM filename**: `python3-3.14.0~rc2-1.fc44.x86_64.rpm`
2. **Extract package name**: `python3`
3. **Look up in compose file**: Find OCI location for `python3`
4. **Apply architecture suffix**: Add `-x86_64` to get final OCI reference
5. **Result**: `oci://quay.io/bcook/rpms:python3-3.14.0-rc2-1.fc44.x86_64-x86_64`

#### 5. Implementation Notes

- **DNF dependency resolution** uses original names/versions from metadata
- **OCI artifact storage** uses sanitized names for compliance
- **Compose file** bridges the gap between metadata and OCI storage
- **Transformation logic** must handle the character mapping correctly

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| URL Encoding (`%2B`, `%7E`) | Preserves exact characters | OCI spec forbids `%` character | ❌ Rejected |
| Base64 Encoding | Always valid | Unreadable, hard to debug | ❌ Rejected |
| Character Escape (\_plus\_) | Readable | Verbose, non-standard | ❌ Rejected |
| Simple Substitution (`+`→`-`) | Clean, readable, valid | Requires mapping layer | ✅ **Selected** |

This approach maintains compatibility with existing RPM tooling while ensuring OCI compliance and human-readable artifact names.