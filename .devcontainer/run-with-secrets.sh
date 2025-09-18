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
