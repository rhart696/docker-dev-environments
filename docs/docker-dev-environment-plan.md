# Docker-Based Development Environment Implementation Plan

## Phase 1: Global VS Code Cleanup

### Extensions to Keep Globally (Minimal Core)
```
ms-vscode-remote.remote-wsl          # Essential for WSL
ms-azuretools.vscode-docker          # Docker management
ms-vscode-remote.remote-containers   # Dev Containers support
editorconfig.editorconfig            # Universal editor config
eamodio.gitlens                      # Git visualization
```

### Extensions to Remove/Disable Globally
#### AI Assistants (Move to Project-Specific)
- anthropic.claude-code
- google.geminicodeassist
- google.gemini-cli-vscode-ide-companion
- github.copilot
- github.copilot-chat
- codeium.codeium
- openai.chatgpt
- rooveterinaryinc.roo-cline
- kilocode.kilo-code
- saoudrizwan.claude-dev

#### Language-Specific (Move to Project Containers)
- Python extensions (ms-python.*)
- Go (golang.go)
- Java (redhat.java, vscjava.*)
- C++ (ms-vscode.cpptools*)
- .NET (ms-dotnettools.*)

#### Cloud/Platform Specific
- All Azure extensions (ms-azuretools.*)
- Firebase extensions
- Google Cloud extensions
- Kubernetes tools

## Phase 2: Dev Container Template Structure

### Base Template Repository Structure
```
project-templates/
├── base/
│   ├── .devcontainer/
│   │   ├── devcontainer.json
│   │   ├── Dockerfile
│   │   └── init-security.sh
│   └── .vscode/
│       └── extensions.json
├── python-ai/
├── nodejs-ai/
├── fullstack-ai/
└── data-science-ai/
```

### Core Dev Container Configuration
```json
// .devcontainer/devcontainer.json
{
  "name": "Project Dev Environment",
  "dockerFile": "Dockerfile",
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {},
    "ghcr.io/devcontainers/features/git:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        // Project-specific extensions here
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash"
      }
    }
  },
  "postCreateCommand": "bash .devcontainer/init-security.sh",
  "remoteUser": "vscode",
  "mounts": [
    "source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
  ]
}
```

## Phase 3: AI Assistant Integration

### Claude Code in Dev Container
```dockerfile
# Install Claude Code CLI
RUN npm install -g @anthropic/claude-cli

# Configure Claude with API key from host
ENV CLAUDE_API_KEY_FILE=/run/secrets/claude_api_key

# Enable safe mode by default
ENV CLAUDE_SAFE_MODE=true
```

### Gemini Code Assist in Dev Container
```dockerfile
# Install Gemini CLI
RUN curl -fsSL https://gemini.google.com/cli/install.sh | bash

# Configure Gemini
ENV GEMINI_API_KEY_FILE=/run/secrets/gemini_api_key
```

## Phase 4: Project Templates

### Python AI Project Template
```json
{
  "extensions": [
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-python.debugpy",
    "anthropic.claude-code",
    "google.geminicodeassist"
  ]
}
```

### Node.js/TypeScript Project Template
```json
{
  "extensions": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "anthropic.claude-code",
    "google.geminicodeassist"
  ]
}
```

### Full-Stack Project Template
```json
{
  "extensions": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "ms-python.python",
    "prisma.prisma",
    "anthropic.claude-code",
    "google.geminicodeassist"
  ]
}
```

## Phase 5: Security Configuration

### Network Isolation
```bash
#!/bin/bash
# init-security.sh
# Restrict network access to essential services only
iptables -P OUTPUT DROP
iptables -A OUTPUT -d 127.0.0.1 -j ACCEPT
iptables -A OUTPUT -d api.anthropic.com -j ACCEPT
iptables -A OUTPUT -d api.gemini.google.com -j ACCEPT
iptables -A OUTPUT -d github.com -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

### Secret Management
```yaml
# docker-compose.yml
version: '3.8'
services:
  dev:
    build: .
    secrets:
      - claude_api_key
      - gemini_api_key
secrets:
  claude_api_key:
    file: ~/.secrets/claude_api_key
  gemini_api_key:
    file: ~/.secrets/gemini_api_key
```

## Phase 6: Implementation Steps

1. **Backup Current Configuration**
   ```bash
   code --list-extensions > ~/vscode-extensions-backup.txt
   cp -r ~/.vscode-server ~/.vscode-server-backup
   ```

2. **Create Template Repository**
   ```bash
   mkdir -p ~/dev-container-templates
   cd ~/dev-container-templates
   git init
   ```

3. **Uninstall Global Extensions (Batch)**
   ```bash
   # Save this as cleanup-extensions.sh
   code --uninstall-extension anthropic.claude-code
   code --uninstall-extension google.geminicodeassist
   # ... continue for all non-essential extensions
   ```

4. **Install Dev Containers Extension**
   ```bash
   code --install-extension ms-vscode-remote.remote-containers
   ```

5. **Create First Project with Dev Container**
   ```bash
   mkdir ~/projects/test-project
   cd ~/projects/test-project
   cp -r ~/dev-container-templates/base/.devcontainer .
   code .
   # Then: F1 -> "Dev Containers: Reopen in Container"
   ```

## Performance Expectations

### Before (Current State)
- 90 global extensions
- ~240MB RAM for VS Code server
- Slow startup times
- Extension conflicts possible

### After Implementation
- 5-7 global extensions
- ~80-100MB RAM for VS Code server
- Fast VS Code startup
- No extension conflicts
- Project-specific optimized environments

## Rollback Plan

If issues arise:
```bash
# Restore extensions
cat ~/vscode-extensions-backup.txt | xargs -L 1 code --install-extension

# Or restore entire VS Code server
rm -rf ~/.vscode-server
mv ~/.vscode-server-backup ~/.vscode-server
```

## Best Practices

1. **One Container Per Project Type** - Don't over-customize
2. **Version Control Dev Containers** - Track .devcontainer/ in git
3. **Use Docker Compose** for multi-service projects
4. **Cache Dependencies** in Docker layers
5. **Mount SSH Keys Read-Only** for git operations
6. **Regular Container Updates** for security patches
7. **Use Claude/Gemini Sparingly** - They work best with focused contexts

## Migration Timeline

- **Week 1**: Backup, create templates, test with one project
- **Week 2**: Migrate 2-3 active projects
- **Week 3**: Clean global extensions
- **Week 4**: Refine templates based on experience