# Tebako Packaging Architecture

This document describes the architecture and design decisions for packaging Fig as platform-specific executables using Tebako.

## Overview

The packaging workflow creates standalone executables for Linux, macOS, and Windows platforms. While based on Tebako's reference implementation, our approach is streamlined for Fig's specific needs as a Tebako consumer rather than a Tebako developer.

## Key Differences from Tebako Reference

1. **Simplified Matrix Strategy**
   - We use a simpler build matrix focused on end-user platforms
   - No development environment testing (handled by Tebako upstream)
   - Focused on distribution rather than Tebako development

2. **Container Usage**
   - Linux: Uses Tebako's container for consistent builds
   - macOS/Windows: Direct runner execution (no containers needed)

## Platform-Specific Details

### Linux (AMD64)
- **Environment**: GitHub-hosted Ubuntu runner + Tebako container
- **Container**: `ghcr.io/tamatebako/tebako-ci-container:latest`
  - Versioning: Track latest stable release
  - Contains all build dependencies
  - Provides consistent build environment across CI/CD
- **Dependencies**: All handled by container
- **Assumptions**: 
  - Docker available on runner
  - Container provides complete build environment
  - Container's Ruby version matches workflow configuration

### macOS (AMD64 + ARM64)
- **Environment**: GitHub-hosted macOS-14 runner
- **Dependencies**:
  - Ruby installed via ruby/setup-ruby action
  - Tebako installed via setup-tebako action
  - Xcode 15.2 or later (for ARM64 support)
- **Build Configuration**:
  - Uses universal binary flags when possible
  - Separate builds for architecture-specific optimizations
  - SDK requirements: macOS 14.0 or later
- **Assumptions**:
  - macOS-14 runner supports both architectures
  - No additional system packages needed
  - Xcode command line tools installed

### Windows (AMD64)
- **Environment**: GitHub-hosted Windows runner + MSYS2
- **MSYS2 Configuration**:
  - System: UCRT64 (preferred) or MINGW64
  - PATH_TYPE: minimal (avoid conflicts)
  - Shell: msys2 {0} for all commands
- **Dependencies**:
  - MSYS2 base environment
  - Required packages:
    - Development tools: git, tar, bison, flex
    - Build tools: cmake, ninja, autotools, make
    - Libraries: boost, libevent, fmt, glog, dlfcn
    - Ruby environment: ruby, openssl, libyaml, libxslt
- **Windows-Specific Requirements**:
  - Windows SDK 10.0.20348.0 or later
  - Visual Studio Build Tools (optional)
- **Assumptions**:
  - Long filename support enabled in git
  - MSYS2 shell available for commands
  - No antivirus interference with build process

## Smoke Testing

Each platform includes basic validation with platform-specific considerations:

### Common Tests
```bash
# Version check
./fig-{platform} --version

# Help command
./fig-{platform} --help

# Basic functionality
cd $(mktemp -d)
./fig-{platform} init
test -d fig && test -f fig/config.yml
```

### Platform-Specific Tests

#### Unix (Linux/macOS)
```bash
# Permissions
test -x ./fig-{platform}

# Dynamic library dependencies
ldd ./fig-{platform}  # Linux
otool -L ./fig-{platform}  # macOS
```

#### Windows
```batch
# File type verification
file fig-windows-amd64.exe

# DLL dependency check
dumpbin /dependents fig-windows-amd64.exe
```

### Test Environment Isolation
- Each test runs in a clean directory
- No shared state between test runs
- Platform-specific temporary directories
- Cleanup after test completion

## Release Integration

Executables are:
1. Built during the workflow
2. Uploaded as workflow artifacts
3. Attached to GitHub releases when tags are pushed
4. Named consistently per platform:
   - Linux: `fig-linux-amd64`
   - macOS: `fig-macos-{arch}` (amd64/arm64)
   - Windows: `fig-windows-amd64.exe`

## Build Artifacts and Security

### Artifact Management
- **Retention Policy**:
  - Workflow artifacts: 30 days
  - Release artifacts: permanent
  - Debug symbols: optional, 90 days

### Security Considerations
- **Build Environment**:
  - Isolated build containers
  - Clean runner state
  - No credential persistence

- **Artifact Verification**:
  - SHA256 checksums
  - Optional code signing
  - Reproducible builds when possible

### Error Handling and Debugging
- **Common Issues**:
  - Container pull failures
  - MSYS2 package conflicts
  - macOS SDK version mismatches

- **Debug Artifacts**:
  - Build logs
  - System information
  - Dependency trees

- **Recovery Steps**:
  - Documented per failure mode
  - Platform-specific troubleshooting
  - Contact points for support

## CI/CD Integration

### Workflow Triggers
- Tags: Full release build
- Pull Requests: Smoke tests only
- Manual: Full test matrix

### External Services
- GitHub Releases
- Package Registries
- Status Badges

## Future Considerations

1. **Platform Expansion**
   - Additional Linux distributions
   - Windows ARM64 (when GitHub runners available)
   - Additional macOS versions

2. **Build Optimization**
   - Parallel builds for multiple architectures
   - Caching strategies for dependencies
   - Build time improvements

3. **Testing Enhancements**
   - Platform-specific test cases
   - Cross-platform compatibility validation
   - Installation testing

## Maintenance Notes

1. **Version Dependencies**
   - Ruby version specified in workflow
   - Tebako version in setup-tebako action
   - MSYS2 package versions (Windows)

2. **Workflow Updates**
   - GitHub Actions versions
   - Runner image updates
   - Container image updates

3. **Monitoring**
   - Build times per platform
   - Artifact sizes
   - Test coverage across platforms

## Common Tasks

### Adding Support for a New Ruby Version

1. **Update Workflow Configuration**:
   ```yaml
   strategy:
     matrix:
       include:
         - ruby-version: '3.3.4'  # Add new version here
   ```

2. **Test Container Compatibility**:
   - Verify Tebako container supports the new Ruby version
   - Test on Linux first (simplest environment)
   - Document any version-specific dependencies

3. **Platform-Specific Checks**:
   - macOS: Verify Xcode compatibility
   - Windows: Check MSYS2 Ruby package availability
   - Update setup-ruby action version if needed

4. **Update Documentation**:
   - Add version to supported versions list
   - Note any special requirements
   - Update troubleshooting guide if needed

### Removing Support for an Old Ruby Version

1. **Announce Deprecation**:
   - Create deprecation issue/PR
   - Document timeline in release notes
   - Update minimum version requirements

2. **Remove Configuration**:
   - Remove version from matrix
   - Update minimum version checks
   - Remove version-specific workarounds

### Adding a New Platform or OS Version

1. **Initial Assessment**:
   ```markdown
   - [ ] GitHub runner availability
   - [ ] Tebako support for platform
   - [ ] Required system dependencies
   - [ ] Build tools availability
   - [ ] Test environment requirements
   ```

2. **Workflow Updates**:
   ```yaml
   matrix:
     include:
       - os: new-platform-latest
         platform: new-platform
         artifact: fig-new-platform-amd64
   ```

3. **Platform-Specific Setup**:
   - Create platform-specific setup steps
   - Document required dependencies
   - Add platform-specific tests

4. **Testing and Validation**:
   - Start with smoke tests
   - Add platform-specific test cases
   - Verify artifact naming/packaging

5. **Documentation**:
   - Add platform to supported list
   - Document known limitations
   - Update troubleshooting guide

### Troubleshooting Build Failures

1. **Common Issues by Platform**:
   ```markdown
   Linux:
   - Container pull failures -> Check container registry status
   - Missing dependencies -> Verify container version
   
   macOS:
   - SDK version mismatch -> Update Xcode version
   - ARM64 build issues -> Check universal binary flags
   
   Windows:
   - MSYS2 package conflicts -> Clean package cache
   - Path length issues -> Verify git config
   ```

2. **Build Log Analysis**:
   - Location of logs by platform
   - Common error patterns
   - Required debugging information

3. **Recovery Steps**:
   - How to clean build environment
   - Rebuilding specific components
   - Skipping problematic tests
