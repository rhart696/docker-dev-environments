# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker Dev Environments system with multi-agent AI orchestration for isolated development environments and automated code workflows.

## Common Development Commands

### Setup and Dependencies
```bash
# Install Python dependencies for orchestrator
cd orchestrator && pip install -r requirements.txt && cd ..

# Install Python dependencies for persistence service
cd persistence && pip install -r requirements.txt && cd ..

# Install dependencies for resource manager
cd resource-manager && pip install -r requirements.txt && cd ..

# Verify Docker and Docker Compose are available
docker --version
docker-compose --version
```

### Running Tests
```bash
# Run orchestrator tests
cd orchestrator && python -m pytest tests/test_orchestrator.py -v --tb=short

# Run persistence service tests
python -m pytest tests/test_persistence_service.py -v --tb=short

# Run TDD enforcer tests
python -m pytest tests/test_tdd_enforcer.py -v

# Run ADR system tests  
python -m pytest tests/test_adr_system.py -v

# Run integration tests
./tests/test_integration.sh

# Run ADR bash tests
./tests/test_adr_bash.sh

# Run specific test
python -m pytest tests/test_orchestrator.py::TestTaskManager::test_submit_task_generates_unique_id -v
```

### Multi-Agent Orchestration
```bash
# Launch core orchestration services
./scripts/launch-multi-agent.sh core

# Run parallel code review with multiple agents
./scripts/launch-multi-agent.sh parallel-review

# Sequential feature development pipeline
./scripts/launch-multi-agent.sh sequential-feature [feature-name]

# Hybrid refactoring with agent swarm
./scripts/launch-multi-agent.sh hybrid-refactor

# Launch monitoring stack (Grafana, Prometheus)
./scripts/launch-multi-agent.sh monitoring

# Check system status
./scripts/launch-multi-agent.sh status

# View logs for specific service
./scripts/launch-multi-agent.sh logs [service-name]

# Stop all services
./scripts/launch-multi-agent.sh stop
```

### Dev Container Management
```bash
# Create new containerized project (interactive)
./scripts/dev-container-quickstart.sh

# Clean up global VS Code extensions
./scripts/vscode-extension-cleanup.sh

# Fix VS Code crashes from extension conflicts
./scripts/fix-vscode-crashes.sh

# Validate API keys
./scripts/validate-api-keys.sh

# Verify Claude/Gemini setup
./scripts/verify-claude-gemini.sh
```

### TDD Automation
```bash
# Run TDD automation scripts
./scripts/tdd-automation.sh

# Implement TDD hooks
./scripts/tdd-hook-implementation.sh

# Monitor TDD compliance
./scripts/tdd-monitoring.sh

# Validate TDD hooks
./scripts/validate-tdd-hooks.sh

# Run TDD tests
./run-tdd-tests.sh
```

### ADR (Architecture Decision Records)
```bash
# Create new ADR
./scripts/create-adr.sh "Decision Title"
```

### Spec-Driven Development
```bash
# Create new specification
./scripts/launch-spec-driven.sh create-spec feature-name "Feature Description"

# Launch spec-driven development with persistence
./scripts/launch-spec-driven.sh launch feature-name

# Validate outputs against specification
./scripts/launch-spec-driven.sh validate feature-name

# Run demo of spec-driven workflow
./scripts/launch-spec-driven.sh demo
```

### Docker Compose Operations
```bash
# Start specific profiles
docker-compose -f docker-compose.multi-agent.yml --profile architects up
docker-compose -f docker-compose.multi-agent.yml --profile monitoring up

# Scale specific agents
docker-compose -f docker-compose.multi-agent.yml up --scale gemini-developer=3
```

## High-Level Architecture

### Multi-Agent Orchestration System
The system coordinates AI agents through a central orchestrator that manages task distribution across three execution modes:

1. **Parallel Mode**: Concurrent execution for independent tasks (code reviews, multi-perspective testing)
2. **Sequential Mode**: Pipeline execution for dependent workflows (analyze → design → implement → test)
3. **Hybrid Mode**: Intelligent routing combining parallel and sequential based on task analysis

#### Core Services
- **Orchestrator** (`orchestrator/orchestrator/main.py`): FastAPI service on port 8000 managing task distribution via TaskManager class
- **Redis**: Message queue and state management on port 6379
- **Resource Manager** (`resource-manager/`): Monitors and allocates resources based on priorities
- **Persistence Service** (`persistence/persistence_service.py`): Flask service on port 5001 for saving agent outputs with spec validation and TDD enforcement
- **Monitoring Stack**: Grafana (3001), Prometheus (9090), cAdvisor (8080)

#### Agent Architecture
Agents are Docker containers with specific roles defined in `docker-compose.multi-agent.yml`:
- **claude-architect**: Architecture and design focus (2G RAM, 1.0 CPU)
- **gemini-developer**: Implementation and optimization (2G RAM, 1.0 CPU)  
- **claude-tester**: Testing and quality assurance (1G RAM, 0.5 CPU)
- **codeium-refactorer**: Code refactoring and cleanup (1G RAM, 0.5 CPU)

Each agent communicates through Redis pub/sub channels and receives tasks from the orchestrator's task queue.

### Dev Container System
Templates in `/templates/` provide isolated development environments:
- **base**: Minimal setup with optional AI assistants
- **python-ai**: Python 3.11 with data science libraries
- **nodejs-ai**: Node.js 20 with TypeScript
- **fullstack-ai**: Combined Python & Node.js with databases

### Task Flow Architecture
1. Tasks submitted to orchestrator API (`/execute` endpoint)
2. TaskManager validates and queues tasks in Redis
3. Execution mode determines agent coordination:
   - Parallel: Fan-out to multiple agents simultaneously
   - Sequential: Chain agents with output piping
   - Hybrid: Dynamic routing based on task analysis
4. Results aggregated and returned via API

### Spec-Driven Development Architecture
1. Specifications defined in YAML format (`/specs/*.yaml`)
2. Agents read specs to understand requirements and TDD phases
3. Persistence service validates all outputs against specifications
4. TDD enforcement ensures tests written before implementation
5. Automatic git commits track development progress
6. Validation reports compliance with spec requirements

## API Keys Setup

```bash
mkdir -p ~/.secrets
echo "your-claude-api-key" > ~/.secrets/claude_api_key
echo "your-gemini-api-key" > ~/.secrets/gemini_api_key
chmod 600 ~/.secrets/*_api_key
```

## Orchestrator API

### Endpoints
- `POST /execute` - Submit a task for execution
- `GET /tasks/{task_id}` - Check task status
- `GET /agents` - List available agents and their status
- `GET /health` - Health check endpoint

### Example API Calls
```bash
# Submit parallel code review
curl -X POST http://localhost:8000/execute \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "code_review",
    "execution_mode": "parallel",
    "agents": ["claude-architect", "gemini-developer", "claude-tester"],
    "payload": {"repository": "my-project"}
  }'

# Check task status
curl http://localhost:8000/tasks/{task_id}

# List available agents
curl http://localhost:8000/agents
```

## Persistence Service API

### Endpoints
- `POST /save` - Save files with spec validation and TDD enforcement
- `POST /validate` - Validate outputs against specifications
- `GET /specs` - List available specifications
- `GET /coverage` - Get test coverage report

### Example API Calls
```bash
# Save file with validation
curl -X POST http://localhost:5001/save \
  -H "Content-Type: application/json" \
  -d '{"filename": "feature.py", "content": "...", "spec_name": "auth-feature"}'
```

## Environment Configuration

Create `.env` file:
```bash
ORCHESTRATION_MODE=hybrid
MAX_PARALLEL_AGENTS=4
MAX_TOTAL_MEMORY=16G
MAX_TOTAL_CPU=8
```

## Monitoring Dashboards

- **Grafana**: http://localhost:3001 (admin/admin)
- **Prometheus**: http://localhost:9090
- **cAdvisor**: http://localhost:8080
- **Orchestrator API**: http://localhost:8000
- **Persistence Service**: http://localhost:5001

## Testing Approach

The project follows strict TDD (Test-Driven Development) with RED-GREEN-REFACTOR cycle:
1. **RED Phase**: Write failing tests first (tests in `*/tests/test_*.py`)
2. **GREEN Phase**: Implement minimal code to pass tests
3. **REFACTOR Phase**: Improve code while keeping tests green

### Test Coverage Requirements
- Minimum 80% code coverage enforced by persistence service
- TDD hooks prevent implementation without tests
- All tests use pytest framework with async support

## Debugging and Troubleshooting

```bash
# View Docker logs for specific service
docker-compose -f docker-compose.multi-agent.yml logs -f orchestrator
docker-compose -f docker-compose.multi-agent.yml logs -f redis

# Check container status
docker ps -a

# Enter container for debugging
docker exec -it docker-dev-environments_orchestrator_1 bash

# Check Redis connection
redis-cli ping

# Test orchestrator health
curl http://localhost:8000/health

# View Python package versions
pip list | grep -E "fastapi|redis|pytest"
```