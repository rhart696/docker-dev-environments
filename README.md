# Docker Dev Environments with Multi-Agent Orchestration

A comprehensive system for creating isolated, Docker-based development environments with sophisticated multi-agent AI orchestration capabilities.

## 🎯 Project Overview

This project provides a complete solution for:
- **Dockerized development environments** for every project
- **Project-specific VS Code extensions** instead of global installations
- **Multi-agent AI orchestration** with parallel and sequential execution patterns
- **Resource management** and monitoring for AI agents
- **Template-based project initialization**
- **Optional GitHub integration** - Git-ize when you're ready, not before

### Philosophy: Progressive Git-ization

Not every project needs to be on GitHub immediately. Our approach:
- **Local-first development** - Start coding without friction
- **Git when ready** - Initialize version control when it adds value
- **GitHub when needed** - Push to remote when sharing or deploying
- **Privacy by default** - New repos are private unless you choose otherwise

This keeps you productive for experiments, learning, and client work without premature commitment to public repositories.

## 📁 Project Structure

```
docker-dev-environments/
├── docs/                              # Documentation
│   ├── docker-dev-environment-plan.md
│   └── docker-dev-multi-agent-orchestration.md
├── scripts/                           # Utility scripts
│   ├── vscode-extension-cleanup.sh   # Clean global VS Code extensions
│   ├── dev-container-quickstart.sh   # Create new dev container projects
│   └── launch-multi-agent.sh         # Launch multi-agent configurations
├── templates/                         # Dev container templates
│   ├── base/                         # Minimal template
│   ├── python-ai/                    # Python with AI assistants
│   ├── nodejs-ai/                    # Node.js with AI assistants
│   └── fullstack-ai/                 # Full-stack development
├── orchestrator/                      # Agent orchestration service
│   ├── Dockerfile
│   ├── requirements.txt
│   └── orchestrator/
│       └── main.py
├── monitoring/                        # Monitoring configurations
├── config/                           # Configuration files
├── examples/                         # Example projects
└── docker-compose.multi-agent.yml   # Multi-agent stack

```

## 🔄 Continuous GitHub Integration

### Auto-Commit System
Automatically commit and push changes to GitHub with intelligent batching:

```bash
# One-time setup
./scripts/auto-commit.sh setup

# Start auto-commit daemon
./scripts/auto-commit.sh daemon

# Check status
./scripts/auto-commit.sh status

# Stop daemon
./scripts/auto-commit.sh stop
```

### Features
- **Intelligent batching**: Groups related changes together
- **GitHub MCP integration**: Uses AI to generate meaningful commit messages
- **VS Code integration**: Auto-commits on file save
- **Git hooks**: Post-commit automation and validation
- **GitHub Actions**: Automated CI/CD pipeline

### Workflow Modes
1. **Manual mode**: Commit when you choose
2. **Auto mode**: Commit every 5 minutes (configurable)
3. **Continuous mode**: Commit on every save
4. **Daemon mode**: Background process for hands-free operation

### Environment Variables
```bash
export AUTO_PUSH=true           # Auto-push after commit
export COMMIT_INTERVAL=300      # Seconds between commits
export BATCH_SIZE=10            # Max files per commit
```

## 🚀 Quick Start

### 1. Clean Up VS Code Extensions

Reduce from 90+ global extensions to ~5 essential ones:

```bash
cd ~/active-projects/docker-dev-environments
./scripts/vscode-extension-cleanup.sh
```

### 2. Create Your First Containerized Project

```bash
./scripts/dev-container-quickstart.sh
# Follow the interactive prompts:
#   1. Select template (base/python/node/fullstack)
#   2. Choose GitHub integration (optional)
#   3. Open in VS Code (optional)
```

#### GitHub Integration (Optional)
Each project can optionally be:
- **Automatically created** on GitHub (public/private)
- **Linked** to your GitHub account
- **Configured** with CI/CD workflows
- **Protected** with branch rules
- **Auto-committed** with the continuous integration system

To add GitHub to an existing project later:
```bash
./scripts/github-integration.sh /path/to/project
```

### 3. Launch Multi-Agent System

```bash
# Start core orchestration
./scripts/launch-multi-agent.sh core

# Run parallel code review
./scripts/launch-multi-agent.sh parallel-review

# Sequential feature development
./scripts/launch-multi-agent.sh sequential-feature user-auth

# Check status
./scripts/launch-multi-agent.sh status
```

## 🤖 Agent Orchestration Patterns

### Parallel Execution
Best for independent tasks:
- Code reviews (multiple perspectives)
- Testing (unit, integration, E2E)
- Documentation generation
- Bug hunting

### Sequential Pipeline
Best for dependent workflows:
- Feature development (analyze → design → implement → test)
- Bug fixes (reproduce → isolate → fix → verify)
- Migrations (analyze → plan → execute → validate)

### Hybrid Mode
Intelligent routing based on task analysis:
- Parallel analysis phase
- Sequential implementation
- Parallel testing and review

## 🛠️ Available Templates

### Base Template
- Minimal setup with optional AI assistants
- Core development tools
- Security-focused configuration

### Python AI Template
- Python 3.11 environment
- Claude Code & Gemini CLI integration
- Data science libraries
- Testing frameworks

### Node.js AI Template
- Node.js 20 with TypeScript
- ESLint & Prettier configured
- AI assistants integrated
- Modern build tools

### Full-Stack Template
- Combined Python & Node.js
- Database tools (PostgreSQL, Redis)
- Docker-in-Docker support
- Complete AI assistant suite

## 📊 Monitoring & Management

### Grafana Dashboard
Access at `http://localhost:3001` (admin/admin)
- Agent performance metrics
- Resource utilization
- Task execution history

### Orchestrator API
Access at `http://localhost:8000`
- Submit tasks
- Check agent status
- View execution logs

### Resource Management
- Auto-scaling based on system load
- Priority-based resource allocation
- Automatic recovery from failures

## 🔧 Configuration

### 1Password CLI Integration

✅ **Full 1Password CLI integration is supported** for secure API key management:

#### Automatic Secret Retrieval
The system automatically retrieves API keys from 1Password when the CLI is available:
- **Claude API**: `op://Private/Anthropic/api_key`
- **Gemini API**: `op://Private/Gemini/api_key` or `op://Private/Google Gemini/credential`
- **GitHub Token**: `op://Private/GitHub/token`
- **OpenAI API**: `op://Private/OpenAI API Key/credential`
- **Codeium API**: `op://Private/Codeium/api_key`

#### Setup 1Password Integration
```bash
# Run the setup script to configure 1Password CLI integration
./scripts/setup-1password-integration.sh

# Validate API keys (now checks 1Password first)
./scripts/validate-api-keys.sh
```

#### Features
- **Automatic detection**: Scripts check for 1Password CLI and use it when available
- **Fallback support**: Falls back to file-based secrets if 1Password is unavailable
- **Docker integration**: Creates temporary key files for Docker containers
- **Session management**: Supports `op run` for injecting secrets into processes

### GitHub MCP Integration (VS Code)

✅ **GitHub MCP Server is configured globally in VS Code** with the following setup:
- Server configured at: `~/.vscode-server/data/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json`
- Uses `@modelcontextprotocol/server-github` npm package
- Requires `GITHUB_PERSONAL_ACCESS_TOKEN` environment variable for authentication
- Enables AI assistants to interact with GitHub repositories, issues, and pull requests

#### Verify Setup
```bash
npx -y @modelcontextprotocol/server-github --version
```

#### GitHub MCP Commands (via AI assistants)
When using Claude or other AI assistants with GitHub MCP:
- **Create issues**: "Create a GitHub issue for the bug in authentication"
- **List PRs**: "Show me all open pull requests"
- **Review code**: "Review the latest PR and suggest improvements"
- **Manage releases**: "Create a new release with the latest changes"
- **Search repos**: "Find all TODO comments in the repository"

#### Automated GitHub Operations
The auto-commit system leverages GitHub MCP for:
- Intelligent commit message generation based on code changes
- Automatic issue linking from commit messages
- PR creation with AI-generated descriptions
- Release notes generation from commit history

### API Keys Setup (Alternative Methods)

#### Option 1: Using 1Password CLI (Recommended)
```bash
# Install 1Password CLI if not already installed
curl -sS https://downloads.1password.com/linux/cli/stable/op_linux_amd64_v2.29.0.zip | unzip -j - op -d ~/bin/

# Sign in to 1Password
op signin

# Keys are automatically retrieved from 1Password vault
```

#### Option 2: Manual File-Based Setup
Create API key files:
```bash
mkdir -p ~/.secrets
echo "your-claude-api-key" > ~/.secrets/claude_api_key
echo "your-gemini-api-key" > ~/.secrets/gemini_api_key
echo "your-github-token" > ~/.secrets/github_token  # For GitHub MCP
chmod 600 ~/.secrets/*_api_key ~/.secrets/github_token
```

### Environment Variables

Set in `.env` file:
```bash
ORCHESTRATION_MODE=hybrid
MAX_PARALLEL_AGENTS=4
MAX_TOTAL_MEMORY=16G
MAX_TOTAL_CPU=8
```

## 📈 Performance Benefits

### Before (Global Extensions)
- 90+ VS Code extensions
- ~240MB RAM usage
- Slow VS Code startup
- Extension conflicts

### After (Containerized)
- 5-7 global extensions only
- ~80-100MB RAM usage
- Fast VS Code startup
- No conflicts, project-specific environments

## 🔒 Security Features

- **Isolated containers** for each project
- **Read-only SSH key mounts**
- **Network restrictions** via firewall rules
- **Resource limits** preventing resource exhaustion
- **Secret management** for API keys
- **1Password CLI integration** for secure credential storage
  - Never store API keys in plain text files
  - Automatic secret rotation support
  - Audit trail for secret access
  - Session-based authentication
  - Zero-knowledge architecture

## 📝 Usage Examples

### Create a Python Data Science Project
```bash
./scripts/dev-container-quickstart.sh
# Select: Python AI Development
# Open in VS Code → Reopen in Container
```

### Run Multi-Agent Code Review
```bash
# Start the orchestrator
./scripts/launch-multi-agent.sh core

# Submit a parallel review task
curl -X POST http://localhost:8000/execute \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "code_review",
    "execution_mode": "parallel",
    "agents": ["claude-architect", "gemini-developer", "claude-tester"],
    "payload": {"repository": "my-project"}
  }'
```

### Develop a Feature with Sequential Pipeline
```bash
./scripts/launch-multi-agent.sh sequential-feature authentication
# Agents will: Analyze → Design → Implement → Test → Review
```

## 🧰 Troubleshooting

### Extension Cleanup Issues
If cleanup script fails:
```bash
# Manual removal
code --list-extensions | grep -E "pattern" | xargs -L1 code --uninstall-extension
```

### Container Connection Issues
```bash
# Check Docker status
docker ps
docker-compose -f docker-compose.multi-agent.yml logs orchestrator
```

### API Key Problems
```bash
# Verify keys are readable
ls -la ~/.secrets/
# Test API access
curl -H "Authorization: Bearer $(cat ~/.secrets/claude_api_key)" \
  https://api.anthropic.com/v1/models
```

## 🤝 Contributing

1. Create feature branch
2. Add tests for new functionality
3. Update documentation
4. Submit pull request

## 📄 License

MIT License - See LICENSE file for details

## 🔗 Resources

- [VS Code Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Claude API Documentation](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)
- [Gemini API Documentation](https://ai.google.dev/api/rest)

## 📞 Support

For issues or questions:
- Check the [docs/](./docs) folder for detailed documentation
- Review [examples/](./examples) for sample configurations
- Open an issue on GitHub

---

**Built with ❤️ for efficient, isolated, AI-enhanced development environments**