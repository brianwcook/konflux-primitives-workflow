# Background

## Konflux-ci - Secure Builds Made Easy

Konflux-ci (https://konflux-ci.dev/) is an open source, cloud-native software factory focused on software supply chain security. It provides a comprehensive platform for secure software development and deployment with the following key capabilities:

### Core Features:

**Build**: Build artifacts of all kinds from source code, enabling hermetic builds and producing accurate Software Bill of Materials (SBOMs).

**Securely Sign**: Generate secure and detailed provenance, creating an immutable record of what happened during each and every build step.

**Identify Vulnerabilities**: Catch critical vulnerabilities quickly with each pull request, providing early detection of security issues.

**Supply Chain Safeguards**: Verify container images against major secure software frameworks or your own custom rules to ensure compliance and security.

**SCM Integration**: Build in response to git events and post results of builds and tests back to your Pull or Merge requests for seamless development workflows.

**Integration Tests**: Execute integration tests for complex applications and see results directly in your source control management system.

Konflux-ci addresses the growing need for secure software supply chains by providing developers with tools to build, sign, and verify their software artifacts while maintaining transparency and security throughout the development lifecycle.

## createrepo - DNF Repository Creation Tool

The `createrepo` command is a utility used to create DNF/YUM package repositories from a directory of RPM packages. It generates the necessary repository metadata that allows package managers like DNF and YUM to understand and use the repository.

### Key Functions:

**Repository Metadata Generation**: Creates XML-based metadata files including primary.xml, filelists.xml, and other.xml that describe the packages in the repository.

**Package Indexing**: Scans a directory containing RPM packages and builds an index of all available packages, their dependencies, and file listings.

**Checksum Generation**: Generates checksums for packages and metadata to ensure repository integrity and security.

**Delta Support**: Can generate delta RPMs to reduce download sizes for package updates.

**Repository Updates**: Supports incremental updates to existing repositories, only processing new or changed packages.

The `createrepo` command is essential for creating custom RPM repositories, whether for internal distribution, testing purposes, or creating mirrors of existing repositories.

## Hermeto - Dependency Prefetching for Hermetic Builds

Hermeto (https://github.com/hermetoproject/hermeto) is a CLI tool that prefetches your project dependencies to aid in making your container build process hermetic. It ensures reproducible builds by downloading and caching all dependencies ahead of time.

### Core Capabilities:

**Multi-Language Support**: Supports various package managers including:
- **bundler** (Ruby) - Parses Gemfile.lock files
- **cargo** (Rust) - Fetches Rust dependencies via Cargo CLI
- **gomod** (Go) - Downloads Go modules using go.mod files  
- **npm** (JavaScript) - Processes package-lock.json files
- **pip** (Python) - Handles requirements.txt lockfiles
- **rpm** (RPM) - Parses rpms.lock.yaml files
- **yarn** (JavaScript) - Drives yarn CLI operations
- **generic** - Fetches arbitrary files via artifacts.lock.yaml

**SBOM Generation**: Produces detailed Software Bill of Materials (SBOM) containing information about all project components and packages, ensuring transparency in the supply chain.

**Hermetic Build Support**: Prefetches all dependencies to enable completely offline, reproducible builds that don't depend on external network resources during the build process.

**Dependency Validation**: Validates checksums and versions to ensure dependency integrity and prevent supply chain attacks.

**Configuration Modes**: Operates in strict or permissive modes, allowing flexibility in handling various project configurations and requirements.

Hermeto addresses the challenge of creating truly hermetic builds by ensuring all dependencies are available locally before the build process begins, eliminating network dependencies and improving build reproducibility and security.

## Renovate - Automated Dependency Updates

Renovate (https://renovatebot.com) is an automated dependency update tool developed by Mend.io that helps keep dependencies current across multiple platforms and languages without manual intervention. It automatically detects outdated dependencies and creates pull requests to update them.

### Core Features:

**Automated Pull Requests**: Automatically creates pull requests to update dependencies when newer versions are available, with relevant package files discovered automatically.

**Multi-Platform Support**: Works across major platforms including GitHub, GitLab, Bitbucket, Azure DevOps, AWS CodeCommit, Gitea, Forgejo, and Gerrit (experimental).

**Extensive Language Support**: Supports over 90 different package managers including npm, Java, Python, .NET, Scala, Ruby, Go, Docker, and many more.

**Smart Scheduling**: Reduces noise by allowing configuration of when Renovate creates PRs, fitting into your development workflow.

**Decision Support**: Provides useful information to help decide which updates to accept, including package age, adoption rates, pass rates, and merge confidence data.

**Highly Configurable**: Flexible configuration system that can be customized to fit repository standards and team preferences, with ESLint-like config presets for sharing configurations.

**Private Repository Support**: Connects with private repositories and package registries, supporting internal dependency management.

**Replacement Suggestions**: Provides replacement PRs to migrate from deprecated dependencies to community-suggested alternatives.

Renovate can be deployed as a cloud-hosted solution (free community plan available), self-hosted solution, or integrated into CI/CD pipelines through GitHub Actions, GitLab Runners, or custom implementations.

## rpm-lockfile-prototype - RPM Dependency Resolution for Hermetic Builds

The rpm-lockfile-prototype (https://github.com/konflux-ci/rpm-lockfile-prototype) is a proof-of-concept tool developed by the Konflux-ci project that implements lockfile generation for RPM-based dependencies to enable hermetic builds. It's designed to work with cachi2 to make container builds completely network-independent.

### Primary Purpose:

**Hermetic Build Enablement**: Resolves RPM transactions ahead of time so that build processes can run without network connections, with all dependencies pre-downloaded and available locally.

**cachi2 Integration**: Generates lockfiles in a format compatible with cachi2, which can download all resolved packages and provide a local repository for consumption during builds.

### Key Capabilities:

**RPM Transaction Resolution**: Given a list of packages, repository URLs, and installed packages, resolves all dependencies for the packages to create a complete dependency tree.

**Multiple Resolution Contexts**: Supports three different approaches for handling installed packages:
- **Local System Resolution**: Resolves against the current system (primarily for testing)
- **Bare/Empty Root Resolution**: Resolves from scratch for base images or OSTree deployments
- **Container Image Extraction**: Extracts installed packages from existing container images for layered builds

**Base Image Analysis**: Can extract and analyze the RPM database from container images to understand what packages are already installed, enabling accurate dependency resolution for layered container builds.

**Modular Support**: Handles RPM modularity, groups, and complex dependency scenarios including module streams, package groups, and architectural constraints.

**Configuration Flexibility**: Supports various configuration options including architecture specifications, repository management, and build context definitions through YAML configuration files.

**Multiple Implementation Approaches**: Has evolved through several iterations to handle the complexity of container-based dependency resolution, ultimately settling on extracting RPM databases from container images using tools like skopeo.

The tool addresses the challenge of creating reproducible, hermetic builds for RPM-based systems by ensuring all dependencies are resolved and available before the build process begins, eliminating the need for network access during container builds.