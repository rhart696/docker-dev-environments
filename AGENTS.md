# Repository Guidelines

## Project Structure & Module Organization
Core orchestration code lives in `orchestrator/` (FastAPI service) and `resource-manager/` (runtime limits and quota logic). Each agent container keeps its build assets under `agents/<agent-name>/`. Shared runtime configuration and compose profiles sit in the repo root (`docker-compose.multi-agent.yml`) and in `config/`. Automation scripts belong in `scripts/`; make new helpers executable and bash-compatible. Documentation lives in `docs/`, while scaffolds and golden examples are under `templates/`, `examples/`, and `workspace/`.

## Build, Test, and Development Commands
Run local stacks with `docker compose -f docker-compose.multi-agent.yml up --build orchestrator redis` to bring up the orchestrator and Redis. Use `./scripts/launch-multi-agent.sh core` for the default multi-agent bundle; add profiles such as `parallel-review` or `sequential-feature <topic>` as required. Scaffold new dev containers via `./scripts/dev-container-quickstart.sh`.

## Coding Style & Naming Conventions
Python modules follow PEP 8 with Black formatting (`black orchestrator resource-manager`). Lint Python changes with `flake8` before opening a PR. Prefer descriptive module and package names aligned with agent roles (for example, `orchestrator/tasks` rather than `misc`). Shell scripts should be POSIX-friendly Bash, start with `#!/bin/bash` and `set -euo pipefail`, and move shared helpers into `scripts/lib/` when they grow. YAML and Compose files use two-space indentation; secrets should reference Docker secrets, never inline keys.

## Testing Guidelines
Unit tests use `pytest`; run `python -m pytest orchestrator/tests -q` (or the equivalent path) before publishing changes. Integration checks live in top-level shell harnesses such as `tests/test_integration.sh`; run them from the repo root so relative paths resolve. Name tests `test_<feature>.py` or `test_<scenario>.sh` to match existing patterns. Strive for coverage on new endpoints and agent workflows, and document intentional gaps in the PR.

## Commit & Pull Request Guidelines
Follow the existing Conventional Commit style (`feat:`, `fix:`, `docs:`) for human-authored messages. Auto-commit tooling may add `Auto-commit:` prefixes; leave them untouched unless incorrect. Each PR should include a concise summary, linked tracking issue (if any), reproduction or validation steps, and screenshots or log links for orchestrator changes.

## Security & Configuration Tips
Place secrets in Docker secrets or local `.env` files listed in `.gitignore`. Avoid committing per-user workspace data; use `artifacts/` for transient agent output that needs review. When adding new services, ensure network aliases stay within `agent-network` and document required environment variables in `docs/` or `config/README.md`.
