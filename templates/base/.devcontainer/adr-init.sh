#!/bin/bash

# ADR Initialization for Dev Containers
# Automatically sets up ADR structure in new projects

set -e

ADR_DIR="docs/adr"

echo "📚 Initializing Architecture Decision Records..."

# Create ADR directory structure
mkdir -p "$ADR_DIR"

# Create initial ADR template
cat > "$ADR_DIR/template.md" << 'EOF'
# ADR-XXXX: [Short Title]

Date: YYYY-MM-DD
Status: [Proposed | Accepted | Deprecated | Superseded by ADR-YYYY]
Deciders: [List of people involved]
Tags: [tag1, tag2]

## Context

[What is the issue we're seeing that motivates this decision?]

## Decision

[What is the change that we're proposing/doing?]

## Consequences

### Positive
- [Positive consequence 1]
- [Positive consequence 2]

### Negative
- [Negative consequence 1]
- [Negative consequence 2]

## Alternatives Considered

1. **[Alternative 1]**
   - Pros: [...]
   - Cons: [...]

## Implementation

[How will this be implemented?]

## Validation

[How will we know if this decision was successful?]
EOF

# Create README for ADRs
cat > "$ADR_DIR/README.md" << 'EOF'
# Architecture Decision Records

This project uses Architecture Decision Records (ADRs) to document important architectural decisions.

## Quick Start

Create a new ADR:
```bash
./scripts/create-adr.sh "Title of Your Decision"
```

## Why ADRs?

- Document the context and consequences of decisions
- Help new team members understand the project's evolution
- Prevent repeating past mistakes
- Create a decision trail for auditing

## ADR Status

- **Proposed**: Under discussion
- **Accepted**: Decision made and implemented
- **Deprecated**: No longer relevant
- **Superseded**: Replaced by another ADR

## Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-0001](0001-initial-architecture.md) | Initial Architecture | Accepted | $(date +%Y-%m-%d) |
EOF

# Create first ADR for the project
cat > "$ADR_DIR/0001-initial-architecture.md" << EOF
# ADR-0001: Initial Architecture

Date: $(date +%Y-%m-%d)
Status: Accepted
Deciders: Development Team
Tags: architecture, setup

## Context

Setting up a new project with consistent development practices and containerized environment.

## Decision

We will use:
- Docker for development environment isolation
- Test-Driven Development (TDD) for quality assurance
- Architecture Decision Records (ADRs) for decision tracking
- Automated tooling for consistency

## Consequences

### Positive
- Consistent development environment across team
- High code quality through TDD
- Clear decision history
- Reduced onboarding time

### Negative
- Initial setup complexity
- Learning curve for new practices

## Implementation

1. Docker Dev Container configuration
2. TDD hooks and automation
3. ADR structure and tooling
4. CI/CD integration

## Validation

- All developers can start working within 30 minutes
- Test coverage > 80%
- All significant decisions documented
EOF

# Copy ADR creation script if it doesn't exist
if [ ! -f "scripts/create-adr.sh" ]; then
    mkdir -p scripts
    curl -sL https://raw.githubusercontent.com/docker-dev-environments/main/scripts/create-adr.sh \
        -o scripts/create-adr.sh || cat > scripts/create-adr.sh << 'SCRIPT'
#!/bin/bash
# Simple ADR creator
NUMBER=$(ls docs/adr/[0-9]*.md 2>/dev/null | wc -l | xargs)
NUMBER=$((NUMBER + 1))
FILENAME="docs/adr/$(printf "%04d" $NUMBER)-$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-').md"
cp docs/adr/template.md "$FILENAME"
echo "Created: $FILENAME"
SCRIPT
    chmod +x scripts/create-adr.sh
fi

# Add git alias for ADR commits
git config --local alias.adr '!f() { git add docs/adr && git commit -m "docs: ADR - $1"; }; f'

echo "✅ ADR structure initialized!"
echo ""
echo "Next steps:"
echo "  1. Review docs/adr/0001-initial-architecture.md"
echo "  2. Create new ADRs: ./scripts/create-adr.sh \"Your Decision Title\""
echo "  3. Commit ADRs: git adr \"Decision description\""