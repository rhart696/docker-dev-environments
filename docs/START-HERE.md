# Start Here

Welcome to the Docker Dev Environments project. This guide orients new contributors and operators before diving into deeper documentation.

## 1. Understand the Landscape

- Skim the top-level [README](../README.md) for the project philosophy, tooling, and quick start commands.
- Use the [documentation index](README.md) to navigate detailed references, including the installation catalogue and architecture notes.
- Review the [Installation Catalogue](installation-catalogue.md) to see which stacks are available and the objectives they satisfy.

## 2. Set Up Your Environment

1. Run `./scripts/vscode-extension-cleanup.sh` if you want the minimal host tooling baseline.
2. Use `./scripts/dev-container-quickstart.sh` to scaffold a containerized project (choose the template that matches your language stack).
3. Launch core agents with `./scripts/launch-multi-agent.sh core`; add profiles like `parallel-review` as needed.

## 3. Key Operational Docs

- [docker-dev-multi-agent-orchestration.md](docker-dev-multi-agent-orchestration.md) explains the orchestrator, agent lifecycle, and compose profiles.
- [spec-driven-development-plan.md](spec-driven-development-plan.md) covers persistence, TDD enforcement, and spec workflows.
- [DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md) details service composition and profile management.
- [claude-integration-guide.md](claude-integration-guide.md) outlines AI assistant setup for Stagehand, Claude Code, and related tools.

## 4. Next Steps

- Join `AGENTS.md` for coding standards, testing expectations, and security practices.
- Open issues or PRs with proposed changes; tag the owning team where relevant.
- As you add features or installations, update the [documentation index](README.md) and [Installation Catalogue](installation-catalogue.md) so future contributors can follow the same path.
