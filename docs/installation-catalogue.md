# Installation Catalogue

This catalogue groups the repository's capabilities into discrete, opt-in installations. Each entry describes which objectives it satisfies, its dependencies, and where it competes with alternative installs. Use this as the source of truth when assembling project setup menus or automation manifests.

## Maintaining This Catalogue

When you add or change an installation, update the relevant entry in this file and include supporting links (scripts, compose services, docs). Run `rg` to confirm referenced paths exist, and append a `TODO` callout if any required assets are still in flight. For larger changes, tag the owning team in the PR description so they can verify objectives and adoption guidance.

## Objectives Reference

- **containerized-dev** – Provide reproducible development environments with project-scoped tooling.
- **brownfield-support** – Layer tooling onto an existing codebase without forcing containerization.
- **multi-agent-collab** – Enable parallel/sequential AI agent workflows for code, review, or testing.
- **resource-governance** – Monitor and enforce CPU/memory limits across running agents.
- **secrets-and-security** – Manage credentials via 1Password/Docker secrets and harden network access.
- **delivery-discipline** – Enforce TDD/spec adherence and automated persistence of agent output.
- **observability** – Surface metrics, logs, and dashboards for the agent fleet.
- **automation-ux** – Improve developer ergonomics for launching tasks, reviews, and tests.

## Installation Matrix

Each entry shows primary coverage, key dependencies, and recommended usage. Asterisks mark planned or partially implemented installs.

### Dev Environment Installations

#### `devcontainer-base`
- **Summary**: Minimal VS Code dev container template with optional compose add-ons.
- **Targets**: Containerized greenfield projects; can wrap existing repos with minimal changes.
- **Objectives**: containerized-dev.
- **Components**: `templates/base`, `scripts/dev-container-quickstart.sh` (prompts 1–3) from scripts/dev-container-quickstart.sh:1-200.
- **Dependencies**: Docker/`docker compose`; VS Code + Dev Containers extension.
- **Alternatives**: `host-cli-core` (brownfield); `devcontainer-python-ai` when AI tooling is required.
- **Adopt When**: Team wants isolated tooling but minimal AI footprint.
- **Avoid When**: Host lacks Docker or team needs language-specific stacks out of the box.

#### `devcontainer-python-ai`
- **Summary**: Python 3.11 dev container with Claude/Gemini integration and data tooling.
- **Targets**: Containerized greenfield or brownfield Python services.
- **Objectives**: containerized-dev, secrets-and-security (via Docker secrets), automation-ux (preinstalled assistants).
- **Components**: `templates/python-ai`, compose variants (README.md:188-207), quickstart options (scripts/dev-container-quickstart.sh:117-140).
- **Dependencies**: Docker, Python base image pulls, optional Redis/Postgres stacks.
- **Alternatives**: `devcontainer-node-ai`, `host-cli-core` (non-container), `devcontainer-fullstack-ai`.
- **Adopt When**: Python team needs AI pair programming, queue/services support.
- **Avoid When**: Infra disallows Docker-in-Docker or secrets injection.

#### `devcontainer-node-ai`
- **Summary**: Node.js 20 + TypeScript with AI assistants and linting.
- **Targets**: Containerized JS/TS projects.
- **Objectives**: containerized-dev, automation-ux.
- **Components**: `templates/nodejs-ai`, compose stacks (README.md:187-207).
- **Dependencies**: Docker, optional Postgres/Mongo.
- **Alternatives**: `devcontainer-base` (lighter), `devcontainer-fullstack-ai` (combined stack).
- **Adopt When**: Node teams want batteries-included dev container.
- **Avoid When**: Need direct host integration or extremely lightweight tooling.

#### `devcontainer-fullstack-ai`
- **Summary**: Combined Python + Node environment with optional messaging/search stacks.
- **Targets**: Containerized polyglot apps or monorepos.
- **Objectives**: containerized-dev, automation-ux, secrets-and-security (compose secrets), observability (if extended).
- **Components**: `templates/fullstack-ai`, quickstart branch (scripts/dev-container-quickstart.sh:141-150).
- **Dependencies**: Docker, significant host resources.
- **Alternatives**: Pair of single-language dev containers; bespoke compose stacks.
- **Adopt When**: Need unified environment for cross-stack squads.
- **Avoid When**: Resources limited or project scope is single language.

#### `stagehand-testing`
- **Summary**: Stagehand browser automation toolkit, toggled via `integrations/stagehand/setup.sh`.
- **Targets**: Containerized or host-based test harnesses; suits brownfield UI projects.
- **Objectives**: automation-ux, brownfield-support.
- **Components**: Stagehand setup script (integrations/stagehand/setup.sh:1-160).
- **Dependencies**: Node 20, Playwright browsers, Claude API key if using anthropic provider.
- **Alternatives**: Manual Playwright test harness; multi-agent testing via `orchestrator-core`.
- **Adopt When**: Need natural-language-driven browser tests without full agent stack.
- **Avoid When**: CI disallows browser dependencies or secrets injection.

### Orchestration & Agents

#### `orchestrator-core`
- **Summary**: FastAPI orchestration service with parallel/sequential/hybrid task routing (orchestrator/orchestrator/main.py:71-240).
- **Targets**: Containerized deployments with Docker socket access.
- **Objectives**: multi-agent-collab, automation-ux.
- **Components**: `orchestrator/`, Compose service `orchestrator` (docker-compose.multi-agent.yml:20-120).
- **Dependencies**: Redis, Docker Engine API, agent images (claude/gemini/codeium), secrets provisioning.
- **Alternatives**: `single-agent-cli` (lightweight); `stagehand-testing` for focused QA.
- **Adopt When**: Teams need orchestrated agent swarms for reviews/features.
- **Avoid When**: Security policy forbids Docker socket sharing or multi-container coordination.

#### `single-agent-cli`
- **Summary**: Local CLI assistants (Claude Code, Codex, Gemini) installed globally as per README.md:17-24.
- **Targets**: Host-based, brownfield environments without Docker.
- **Objectives**: brownfield-support, automation-ux (manual AI assistance).
- **Components**: Tools listed in README, accessible via CLI.
- **Dependencies**: Appropriate subscriptions/logins; optional 1Password CLI.
- **Alternatives**: `orchestrator-core`, dev containers with agents.
- **Adopt When**: You need AI coding support without container stack.
- **Avoid When**: Coordinated multi-agent workflows are required.

#### `agent-images-pack`
- **Summary**: Containerized agents under `agents/` (Claude, Gemini, Codeium, TDD specialist).
- **Targets**: Used alongside orchestrator.
- **Objectives**: multi-agent-collab (when paired), secrets-and-security (requires secret files), delivery-discipline (TDD agent).
- **Components**: `agents/claude`, `agents/gemini`, etc.
- **Dependencies**: Language runtimes inside images, API keys via secrets.
- **Alternatives**: Third-party hosted agents; CLI tools.
- **Adopt When**: Need self-hosted agent containers with custom behavior.
- **Avoid When**: Preferring SaaS agents or non-container environments.

### Operations & Governance

#### `resource-manager`
- **Summary**: FastAPI service enforcing resource allocation (resource-manager/resource_manager/main.py:1-320).
- **Targets**: Same Docker host as orchestrator; optional standalone.
- **Objectives**: resource-governance, observability (Prometheus metrics).
- **Components**: `resource-manager/`, Compose service `resource-manager` (docker-compose.multi-agent.yml:170-220).
- **Dependencies**: Docker socket, Redis, Prometheus scrape.
- **Alternatives**: Native Docker resource limits; Kubernetes-based autoscaling.
- **Adopt When**: Need dynamic throttling and metrics across agents.
- **Avoid When**: Running in managed environments with existing schedulers.

#### `monitoring-stack`
- **Summary**: Prometheus, Grafana, cAdvisor profile for fleet observability (docker-compose.multi-agent.yml:120-210).
- **Targets**: Containerized deployments.
- **Objectives**: observability.
- **Components**: `monitoring/`, Compose profiles `monitoring`.
- **Dependencies**: Docker metrics endpoints, storage volumes.
- **Alternatives**: External APM/SaaS monitoring; minimal logging only.
- **Adopt When**: Need dashboards for agent health and resource usage.
- **Avoid When**: Shared infrastructure already provides metrics stack.

#### `secrets-bridge`
- **Summary**: 1Password CLI integration plus Docker secrets workflow (README.md:240-340; scripts/launch-multi-agent.sh:30-120).
- **Targets**: Both host and containerized setups.
- **Objectives**: secrets-and-security.
- **Components**: Setup scripts (`scripts/setup-1password-integration.sh` referenced), secrets directory preparation.
- **Dependencies**: 1Password CLI v2, authenticated Development vault access.
- **Alternatives**: Manual `.env` management; cloud secret managers.
- **Adopt When**: Teams standardize on 1Password and need automated injection.
- **Avoid When**: Policy forbids CLI vault access on shared servers.

### Delivery & Workflow

#### `persistence-service`
- **Summary**: Flask service enforcing spec-driven file saving and Git commits (persistence/persistence_service.py:1-210).
- **Targets**: Containerized orchestrations; can mount existing repos.
- **Objectives**: delivery-discipline, secrets-and-security (when secrets drive specs), multi-agent-collab (artifacts exchange).
- **Components**: `persistence/`, Compose service `persistence-service` (docker-compose.multi-agent.yml:200-240).
- **Dependencies**: Git binary, YAML specs under `/specs`, writable `/workspace`.
- **Alternatives**: Manual git workflows; lightweight spec validators.
- **Adopt When**: Need agents to persist output with TDD enforcement.
- **Avoid When**: Working on repos with existing Git metadata (risk of conflicts) or lacking specs.

#### `auto-commit-daemon`*
- **Summary**: Documented continuous commit workflow (README.md:66-98) with baseline implementation in `scripts/auto-commit.sh`; still requires production hardening and MCP integration polish.
- **Targets**: Host or container.
- **Objectives**: delivery-discipline, automation-ux.
- **Components**: `scripts/auto-commit.sh`, optional experimental variants (`scripts/auto-commit-enhanced.sh`, `scripts/auto-commit-optimized.sh`).
- **Dependencies**: Git, GitHub token (via 1Password), MCP server.
- **Alternatives**: Manual Git practices; persistence-service automation.
- **Adopt When**: Desire automated commit cadence once tooling exists.
- **Avoid When**: Repository compliance requires manual review before commits.

#### `launch-cli`
- **Summary**: `scripts/launch-multi-agent.sh` orchestrates compose profiles and submits tasks (scripts/launch-multi-agent.sh:1-200).
- **Targets**: Host with Docker.
- **Objectives**: automation-ux, multi-agent-collab (via orchestrator), secrets-and-security (prompts for keys).
- **Components**: Bash script with core/parallel/sequential/hybrid commands.
- **Dependencies**: docker compose, curl, optional 1Password CLI.
- **Alternatives**: Direct `docker compose` invocation; custom wrappers.
- **Adopt When**: Need ergonomic entry point for orchestrator stacks.
- **Avoid When**: Automation pipelines require non-interactive commands (script currently prompts for secrets).

### Brownfield Tooling

#### `host-cli-core`
- **Summary**: Minimal host-based setup using VS Code cleanup plus CLI assistants (README.md:105-164; docs/docker-dev-environment-plan.md:1-80).
- **Targets**: Brownfield repos that can’t adopt containers.
- **Objectives**: brownfield-support, automation-ux, secrets-and-security (cleanup + 1Password guidance).
- **Components**: `scripts/vscode-extension-cleanup.sh`, manual instructions in docs.
- **Dependencies**: VS Code CLI, willingness to trim global extensions.
- **Alternatives**: Dev container migrations, single-agent CLI usage.
- **Adopt When**: Legacy project must stay host-native but wants curated tooling.
- **Avoid When**: Team already standardized on dev containers.

---

## Using the Catalogue

1. **Identify objectives** for the project (e.g., containerized-dev + multi-agent-collab).
2. **List candidate installations** whose objectives intersect the project goals.
3. **Resolve competitors** under each objective by comparing their "Adopt/Avoid" guidance.
4. **Validate dependencies/conflicts** before provisioning (e.g., Docker socket availability, secret vault access).
5. Capture selections in an `installations.yaml` (future step) so automation scripts can compose the chosen installs repeatably.

*Asterisked entries denote partially implemented items that need follow-up before general release.*
