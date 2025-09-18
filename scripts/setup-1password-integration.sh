#!/bin/bash

# 1Password CLI integration bootstrapper for Docker Dev Environments.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEVCONTAINER_DIR="$REPO_ROOT/.devcontainer"
RUNNER_PATH="$DEVCONTAINER_DIR/run-with-secrets.sh"
TEMPLATE_PATH="$DEVCONTAINER_DIR/secrets.template"

DEFAULT_VAULT="${OP_VAULT_NAME:-Development}"
OPENAI_PATH="${OP_OPENAI_PATH:-OpenAI/api_key}"
GEMINI_PATH="${OP_GEMINI_PATH:-Gemini API/api_key}"
ANTHROPIC_PATH="${OP_ANTHROPIC_PATH:-Claude API/api_key}"

usage() {
    cat <<'EOF'
Usage: setup-1password-integration.sh [--help]

Environment overrides (only used when bootstrapping a missing template):
  OP_VAULT_NAME      Default vault name (default: Development)
  OP_OPENAI_PATH     OpenAI item/field path (default: OpenAI/api_key)
  OP_GEMINI_PATH     Gemini item/field path (default: "Gemini API"/api_key)
  OP_ANTHROPIC_PATH  Claude item/field path (default: "Claude API"/api_key)

The script rewrites .devcontainer/run-with-secrets.sh and creates
.devcontainer/secrets.template if it is absent.
EOF
}

log() {
    printf '%b\n' "$1"
}

check_op_installed() {
    if ! command -v op >/dev/null 2>&1; then
        log "${RED}❌ 1Password CLI (op) not found on PATH${NC}"
        log "Install instructions: https://developer.1password.com/docs/cli/get-started/"
        return 1
    fi
    log "${GREEN}✅ 1Password CLI detected: $(op --version)${NC}"
}

check_op_signed_in() {
    if ! op account get >/dev/null 2>&1; then
        log "${YELLOW}⚠️  Not signed in to 1Password${NC}"
        log 'Run: eval "$(op signin)"'
        return 1
    fi
    local account
    account=$(op whoami 2>/dev/null | head -n1 || echo "1Password account")
    log "${GREEN}✅ Signed in: $account${NC}"
}

check_vault_access() {
    if ! op vault get "$DEFAULT_VAULT" >/dev/null 2>&1; then
        log "${RED}❌ Cannot access vault: $DEFAULT_VAULT${NC}"
        log 'Set OP_VAULT_NAME to a vault you can access, then rerun.'
        return 1
    fi
}

write_runner() {
    mkdir -p "$DEVCONTAINER_DIR"
    cat >"$RUNNER_PATH" <<'EOF'
#!/usr/bin/env bash
# Execute a command with environment variables sourced from 1Password.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/secrets.template"

usage() {
    cat <<'USAGE'
Usage: run-with-secrets.sh [--template PATH] -- <command> [args...]

Loads environment variables from a 1Password template via `op run` and executes
the command.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --template)
            shift
            [[ $# -gt 0 ]] || { echo "Missing value for --template" >&2; exit 1; }
            TEMPLATE="$1"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -eq 0 ]]; then
    usage >&2
    exit 1
fi

if ! command -v op >/dev/null 2>&1; then
    echo "1Password CLI (op) is not installed or not on PATH" >&2
    exit 1
fi

if ! op account get >/dev/null 2>&1; then
    echo 'Not signed in to 1Password. Run: eval "$(op signin)"' >&2
    exit 1
fi

if [[ ! -f "$TEMPLATE" ]]; then
    echo "Template file not found: $TEMPLATE" >&2
    exit 1
fi

op run --env-file="$TEMPLATE" -- "$@"
status=$?
if [[ $status -ne 0 ]]; then
    echo "Command exited with status $status. Confirm your 1Password session is active and the template paths are correct." >&2
fi
exit $status
EOF
    chmod +x "$RUNNER_PATH"
    log "${GREEN}✅ Updated helper: $RUNNER_PATH${NC}"
}

bootstrap_template() {
    if [[ -f "$TEMPLATE_PATH" ]]; then
        log "${YELLOW}⚠️  Existing template preserved: $TEMPLATE_PATH${NC}"
        log '   Edit this file manually if your secret mappings change.'
        return
    fi

    cat >"$TEMPLATE_PATH" <<EOF
# Map environment variables to 1Password vault references.
# Edit and commit this file so the team and CI share the same mappings.
OPENAI_API_KEY=op://$DEFAULT_VAULT/$OPENAI_PATH
GEMINI_API_KEY=op://$DEFAULT_VAULT/$GEMINI_PATH
ANTHROPIC_API_KEY=op://$DEFAULT_VAULT/$ANTHROPIC_PATH
EOF
    log "${GREEN}✅ Created template: $TEMPLATE_PATH${NC}"
    log '   Update it now if your secrets live in other vaults or items.'
}

verify_template() {
    log "${BLUE}Checking template references...${NC}"

    if [[ ! -f "$TEMPLATE_PATH" ]]; then
        log "${RED}❌ Template not found: $TEMPLATE_PATH${NC}"
        log 'Populate the template before running commands.'
        return 1
    fi

    local missing=0

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        if [[ -z "$key" || $key =~ ^[[:space:]]*# ]]; then
            continue
        fi

        local ref="${value#${value%%[![:space:]]*}}"
        ref="${ref%${ref##*[![:space:]]}}"

        if [[ ${ref:0:1} == '"' && ${ref: -1} == '"' ]]; then
            ref="${ref:1:-1}"
        fi

        if [[ ${ref:0:1} == "'" && ${ref: -1} == "'" ]]; then
            ref="${ref:1:-1}"
        fi

        if [[ -z "$ref" ]]; then
            log "${YELLOW}⚠️  $key has no op:// reference; skipping.${NC}"
            continue
        fi

        if op read "$ref" >/dev/null 2>&1; then
            log "${GREEN}✅ $key available${NC}"
        else
            log "${RED}❌ Unable to retrieve $key (check the template entry and vault access)${NC}"
            missing=1
        fi
    done <"$TEMPLATE_PATH"

    if [[ $missing -eq 1 ]]; then
        log "${RED}Secret verification failed. Ensure you're signed in and the template paths are correct.${NC}"
        return 1
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                return 0
                ;;
            *)
                usage >&2
                return 1
                ;;
        esac
    done

    log "${BLUE}=== 1Password CLI Integration Setup ===${NC}"
    log ""

    check_op_installed
    check_op_signed_in
    check_vault_access

    write_runner
    bootstrap_template
    verify_template

    log ""
    log "${BLUE}=== Setup Complete ===${NC}"
    log ""
    log "1Password CLI integration is configured for Docker Dev Environments."
    log ""
    log "${GREEN}Available commands:${NC}"
    log "  - Run commands with secrets: .devcontainer/run-with-secrets.sh -- <command>"
    log ""
    log "${YELLOW}Next steps:${NC}"
    log "  1. Review and customise $TEMPLATE_PATH if your secrets live in other vaults."
    log "  2. Commit template updates so the team and CI share the same mappings."
    log "  3. Run project commands through the secrets wrapper as needed."
}

main "$@"
