# Start Here

Welcome to the Docker Dev Environments project. This guide orients new contributors and operators before diving into deeper documentation.

## 1. Understand the Landscape

- Skim the top-level [README](../README.md) for the project philosophy, tooling, and quick start commands.
- Use the [documentation index](README.md) to navigate detailed references, including the installation catalogue and architecture notes.
- Review the [Installation Catalogue](installation-catalogue.md) to see which stacks are available and the objectives they satisfy.

## 2. Set Up Your Environment

1. Run `./scripts/vscode-extension-cleanup.sh` if you want the minimal host tooling baseline.
2. Configure 1Password access with `./scripts/setup-1password-integration.sh`; it refreshes `.devcontainer/run-with-secrets.sh` and creates `.devcontainer/secrets.template` if missing (defaults to the `Development` vault—override via `OP_VAULT_NAME` or edit the template directly for multi-vault setups).
3. Use `./scripts/dev-container-quickstart.sh` to scaffold a containerized project (choose the template that matches your language stack).
4. Launch core agents with `./scripts/launch-multi-agent.sh core`; add profiles like `parallel-review` as needed.

### Customise the Secrets Template

- Edit `.devcontainer/secrets.template` to point at the vaults/items your team uses, then commit the file so everyone (and CI) shares the same mappings.
- Example with multiple vaults:

```
OPENAI_API_KEY=op://Backend-Services/OpenAI/api_key
GITHUB_TOKEN=op://Platform-CI/GitHub/token
STRIPE_API_KEY=op://Billing/Stripe/live_key
```

## 3. Key Operational Docs

- [docker-dev-multi-agent-orchestration.md](docker-dev-multi-agent-orchestration.md) explains the orchestrator, agent lifecycle, and compose profiles.
- [spec-driven-development-plan.md](spec-driven-development-plan.md) covers persistence, TDD enforcement, and spec workflows.
- [DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md) details service composition and profile management.
- [claude-integration-guide.md](claude-integration-guide.md) outlines AI assistant setup for Stagehand, Claude Code, and related tools.

## 4. Using Secrets in CI

- Ensure your pipeline authenticates the 1Password CLI before running project commands. For example:

```yaml
- name: Authenticate 1Password
  run: echo "$OP_SERVICE_ACCOUNT_TOKEN" | op signin --account my-team --raw

- name: Build with secrets
  run: ./.devcontainer/run-with-secrets.sh -- npm run build
```

- Commit updates to `.devcontainer/secrets.template` so local developers and CI runners share the same mappings.

## 5. Troubleshooting & Next Steps

- Quick fixes: run `eval "$(op signin)"` if prompted, set `OP_VAULT_NAME` (or edit the template) when vault access fails, and use `op item list --vault=<name>` to confirm item paths.
- Join `AGENTS.md` for coding standards, testing expectations, and security practices.
- Open issues or PRs with proposed changes; tag the owning team where relevant.
- Run application commands with secrets injected by executing `.devcontainer/run-with-secrets.sh -- <command>` once the setup script completes.
- As you add features or installations, update the [documentation index](README.md) and [Installation Catalogue](installation-catalogue.md) so future contributors can follow the same path.
