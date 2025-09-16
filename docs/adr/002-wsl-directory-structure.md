# Architecture Decision Record: WSL Directory Structure for Docker Development

## Status
**Accepted** - 2025-01-15

## Context
The Docker Dev Environments project requires a decision on where to store project files when developing on Windows with WSL2. This affects performance, compatibility, and developer workflow efficiency.

### Current Setup
- All projects stored in WSL2 filesystem (`~/active-projects/`, `~/code/`, etc.)
- Docker Desktop integrated with WSL2
- VS Code with Remote-WSL and Dev Containers extensions
- Multi-agent orchestration using Docker Compose
- Heavy reliance on Unix tooling (Git, SSH, file permissions)

### Problem Statement
Should development projects remain in the WSL2 filesystem or be moved to Windows directories for better Windows integration?

## Decision Drivers
1. **Docker performance** - File I/O speed for container volumes
2. **Tool compatibility** - Support for development tools and AI assistants
3. **Developer experience** - Ease of use and workflow efficiency
4. **Cross-platform needs** - Requirements for Windows-native tools
5. **Security** - Proper handling of SSH keys and secrets

## Considered Options

### Option 1: Keep All Projects in WSL (Current Approach)
**Description**: Continue storing all projects within WSL2 filesystem

**Pros**:
- Native Linux filesystem performance (ext4)
- Direct Docker volume mounting without translation overhead
- Proper Unix permissions for SSH keys and secrets
- Git operations 5-10x faster than Windows drives
- Seamless integration with containerized workflows
- No line ending conversion issues (CRLF/LF)

**Cons**:
- Files less accessible from Windows Explorer
- Requires WSL for all operations
- Windows-native tools may have limited access

**Performance Impact**:
- File operations: **Native speed**
- Docker builds: **Optimal**
- Git operations: **5-10x faster**

### Option 2: Move Projects to Windows Filesystem
**Description**: Store projects in Windows directories (`C:\Projects` or similar)

**Pros**:
- Direct access from Windows Explorer
- Native Windows tool compatibility
- Easier backup with Windows backup tools
- Accessible when WSL is not running

**Cons**:
- **10-20x slower file operations** through 9P protocol
- Docker volume mount performance severely degraded
- Permission translation issues
- Line ending conflicts (CRLF vs LF)
- Case sensitivity problems
- SSH key permission warnings

**Performance Impact**:
- File operations: **10-20x slower**
- Docker builds: **Significantly degraded**
- Git operations: **5-10x slower**

### Option 3: Hybrid Approach
**Description**: Keep source in WSL, symlink specific outputs to Windows

**Implementation**:
```bash
# Source remains in WSL
~/active-projects/my-app/

# Symlink build outputs to Windows
ln -s /mnt/c/Users/Username/Desktop/builds ~/active-projects/my-app/dist
```

**Pros**:
- Performance for development operations
- Selected files accessible from Windows
- Best of both worlds for specific use cases

**Cons**:
- Complex setup and maintenance
- Potential symlink resolution issues
- Inconsistent file access patterns

### Option 4: Duplicate with Sync
**Description**: Maintain copies in both filesystems with automated sync

**Pros**:
- Full access from both environments
- Can choose optimal location per tool

**Cons**:
- Storage duplication
- Sync conflicts and delays
- Complex sync rules needed
- Potential for divergence

## Decision

**Selected Option: Option 1 - Keep All Projects in WSL**

## Rationale

The decision to maintain all projects within the WSL2 filesystem is driven by:

1. **Performance Requirements**: The 10-20x performance penalty for Docker operations on Windows filesystem is unacceptable for the multi-agent orchestration system that relies on rapid container creation and file operations.

2. **Tool Chain Optimization**: All primary tools (Docker, Git, Claude Code, Python, Node.js) are optimized for Unix-like environments and perform best with native Linux filesystem.

3. **Security Compliance**: Unix file permissions are required for proper SSH key management and the 1Password CLI integration expects standard Unix permission models.

4. **Workflow Consistency**: The entire development workflow from coding to testing to deployment assumes Unix conventions, making WSL the natural choice.

## Implementation

### Directory Structure
```
~/                          # WSL home directory
├── active-projects/        # Active development
├── code/                  # Infrastructure and tools
├── idp-projects/          # IDP framework
└── .mcp/                  # MCP configurations
```

### Access Patterns
- **Primary development**: WSL terminal + VS Code Remote-WSL
- **File management**: Use VS Code's explorer or WSL terminal
- **Windows access when needed**: Access via `\\wsl$\Ubuntu\home\username`
- **Backups**: Use WSL backup tools or mount in Windows backup software

### Best Practices
1. Clone repositories directly in WSL, not in Windows
2. Run all Docker commands from WSL terminal
3. Configure Git in WSL, not Windows Git
4. Store secrets and SSH keys in WSL filesystem only
5. Use VS Code Remote-WSL for editing

## Consequences

### Positive
- Maximum performance for containerized development
- Simplified permission management
- Consistent Unix-based workflow
- Optimal multi-agent orchestration performance
- Native speed for all development operations

### Negative
- Learning curve for Windows-centric developers
- Requires WSL2 to be properly configured and maintained
- Files less discoverable from Windows Explorer
- Requires understanding of WSL/Windows boundary

### Mitigation Strategies
1. Document WSL setup process thoroughly
2. Provide scripts for common Windows integration needs
3. Create Windows shortcuts to WSL directories where needed
4. Use VS Code as primary file browser (cross-platform)
5. Enable WSL backup in Windows backup tools

## Metrics for Success
- Docker build times remain under 30 seconds for typical services
- Git operations complete in < 1 second for common commands
- No permission-related errors for SSH or secret management
- Developer satisfaction scores > 4/5 for workflow efficiency

## Review Schedule
Review this decision in 6 months or if:
- Windows filesystem performance for WSL2 significantly improves
- Project requirements shift to Windows-native development
- Team composition changes to primarily Windows developers

## References
- [WSL2 Architecture Documentation](https://docs.microsoft.com/en/windows/wsl/compare-versions)
- [Docker Desktop WSL2 Backend](https://docs.docker.com/desktop/windows/wsl/)
- [VS Code Remote Development](https://code.visualstudio.com/docs/remote/wsl)
- [9P Protocol Performance Analysis](https://github.com/microsoft/WSL/issues/4197)

## Related Decisions
- ADR-001: Choice of Docker as container runtime
- ADR-003: Multi-agent orchestration architecture (future)

## Notes
This decision specifically applies to Windows machines using WSL2. Linux and macOS developers should use their native filesystems without any translation layer.