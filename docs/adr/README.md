# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the Docker Dev Environments project.

## What is an ADR?

An Architecture Decision Record captures an important architectural decision made along with its context and consequences.

## ADR Format

We use a lightweight format:

```markdown
# ADR-XXXX: Title

Date: YYYY-MM-DD
Status: [Proposed | Accepted | Deprecated | Superseded by ADR-YYYY]
Deciders: [List of people involved]
Tags: [tag1, tag2]

## Context
What is the issue we're seeing that motivates this decision?

## Decision
What is the change that we're proposing/doing?

## Consequences
What becomes easier or harder because of this change?

## Alternatives Considered
What other options were evaluated?
```

## Index of ADRs

| ADR | Title | Status | Date | Tags |
|-----|-------|--------|------|------|
| [ADR-0001](0001-use-docker-for-dev-environments.md) | Use Docker for Development Environments | Accepted | 2024-01-15 | docker, architecture |
| [ADR-0002](0002-multi-agent-orchestration.md) | Multi-Agent Orchestration Pattern | Accepted | 2024-01-15 | agents, orchestration |
| [ADR-0003](0003-adopt-tdd-workflow.md) | Adopt Test-Driven Development Workflow | Accepted | 2024-01-15 | testing, tdd, quality |
| [ADR-0004](0004-stagehand-for-testing.md) | Use Stagehand for Natural Language Testing | Accepted | 2024-01-15 | testing, ai, stagehand |
| [ADR-0005](0005-claude-hooks-enforcement.md) | Claude Hooks for TDD Enforcement | Accepted | 2024-01-15 | hooks, tdd, automation |
| [ADR-0006](0006-resource-management-strategy.md) | Container Resource Management Strategy | Accepted | 2024-01-15 | resources, scaling |
| [ADR-0007](0007-monitoring-with-prometheus.md) | Monitoring with Prometheus and Grafana | Accepted | 2024-01-15 | monitoring, observability |

## Creating New ADRs

Use the provided script:
```bash
./scripts/create-adr.sh "Title of Decision"
```

Or manually:
1. Copy template from `template.md`
2. Number it sequentially (e.g., `0008-your-decision.md`)
3. Update this README index
4. Commit with message: `docs: ADR-0008 Your Decision`

## ADR Lifecycle

1. **Proposed** - Under discussion
2. **Accepted** - Decision made and being implemented
3. **Deprecated** - No longer relevant but kept for history
4. **Superseded** - Replaced by another ADR (reference it)

## Review Process

1. Create ADR as "Proposed"
2. Discuss in PR/meeting
3. Update status to "Accepted" when consensus reached
4. Implementation begins

## Automation

ADRs are automatically:
- Generated when significant changes are made
- Linked in commit messages
- Validated by CI/CD
- Included in project documentation