# Docker Dev Environments with Multi-Agent Orchestration

A comprehensive system for creating isolated, Docker-based development environments with sophisticated multi-agent AI orchestration capabilities.

## 🎯 Project Overview

This project provides a complete solution for:
- **Dockerized development environments** for every project
- **Project-specific VS Code extensions** instead of global installations
- **Multi-agent AI orchestration** with parallel and sequential execution patterns
- **Resource management** and monitoring for AI agents
- **Template-based project initialization**

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
# Follow the interactive prompts
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

### API Keys Setup

Create API key files:
```bash
mkdir -p ~/.secrets
echo "your-claude-api-key" > ~/.secrets/claude_api_key
echo "your-gemini-api-key" > ~/.secrets/gemini_api_key
chmod 600 ~/.secrets/*_api_key
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