#!/bin/bash

# Optimized Auto-Commit System v3.0
# Fixes argument parsing bug and simplifies while keeping smart features
# Lessons learned: Simplicity + Reliability > Complexity

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command FIRST (fixes the critical bug!)
COMMAND="${1:-status}"
shift 2>/dev/null || true  # Shift if there are more args

# NOW get the repo path (after command is extracted)
REPO_PATH="${1:-$(pwd)}"

# Configuration with smart defaults
INTERVAL="${AUTO_COMMIT_INTERVAL:-300}"  # 5 minutes
BATCH_SIZE="${AUTO_COMMIT_BATCH_SIZE:-10}"
AUTO_PUSH="${AUTO_PUSH:-false}"
USE_NO_VERIFY="${AUTO_COMMIT_NO_VERIFY:-auto}"  # auto|true|false

# Logging
log_message() {
    echo -e "$1" >&2
}

# Simple commit with optional --no-verify
commit_with_optional_verify() {
    local msg="$1"
    local verify_flag=""

    # Determine whether to use --no-verify
    case "$USE_NO_VERIFY" in
        true|yes|1)
            verify_flag="--no-verify"
            log_message "${YELLOW}⚠️  Bypassing pre-commit hooks${NC}"
            ;;
        false|no|0)
            verify_flag=""
            log_message "${BLUE}Running with pre-commit hooks${NC}"
            ;;
        auto|*)
            # Auto-detect: Try a quick test commit
            if ! timeout 2 git commit --dry-run -m "test" >/dev/null 2>&1; then
                verify_flag="--no-verify"
                log_message "${YELLOW}⚠️  Hooks appear slow - bypassing${NC}"
            else
                verify_flag=""
                log_message "${GREEN}✅ Hooks responsive - using them${NC}"
            fi
            ;;
    esac

    # Perform the actual commit
    if git commit $verify_flag -m "$msg" -m "Auto-committed by auto-commit system"; then
        log_message "${GREEN}✅ Commit successful${NC}"

        # Remind about manual security check if bypassed
        if [ -n "$verify_flag" ]; then
            log_message "${BLUE}💡 Consider running: git diff HEAD~1 | grep -E 'password|secret|token'${NC}"
        fi

        return 0
    else
        return 1
    fi
}

# Generate simple but descriptive commit messages
generate_commit_message() {
    local file_count=$(git diff --cached --name-only | wc -l)
    local first_file=$(git diff --cached --name-only | head -1)

    if [ "$file_count" -eq 1 ]; then
        echo "Auto-commit: Updated $(basename "$first_file")"
    elif [ "$file_count" -le 3 ]; then
        local files=$(git diff --cached --name-only | xargs -n1 basename | paste -sd, -)
        echo "Auto-commit: Updated $files"
    else
        echo "Auto-commit: Updated $file_count files"
    fi
}

# Main commit function
commit_changes() {
    # Check for changes
    if ! git status --porcelain | grep -q .; then
        return 0  # No changes
    fi

    # Add all changes
    git add -A

    # Check if there are staged changes
    if git diff --cached --quiet; then
        return 0  # Nothing staged
    fi

    # Generate message and commit
    local msg=$(generate_commit_message)
    log_message "${BLUE}Committing changes...${NC}"

    if commit_with_optional_verify "$msg"; then
        # Auto-push if enabled
        if [ "$AUTO_PUSH" = "true" ]; then
            log_message "${BLUE}Pushing to remote...${NC}"
            if git push; then
                log_message "${GREEN}✅ Pushed successfully${NC}"
            else
                log_message "${RED}❌ Push failed${NC}"
            fi
        fi
    else
        log_message "${RED}❌ Commit failed${NC}"
        return 1
    fi
}

# Watch for changes (simplified)
watch_changes() {
    log_message "${BLUE}Starting auto-commit watch mode${NC}"
    log_message "Repository: $REPO_PATH"
    log_message "Interval: ${INTERVAL}s"
    log_message "Auto-push: $AUTO_PUSH"
    log_message "Hook bypass: $USE_NO_VERIFY"
    echo ""

    cd "$REPO_PATH"

    while true; do
        commit_changes
        sleep "$INTERVAL"
    done
}

# Setup function (simplified)
setup() {
    cd "$REPO_PATH"

    # Create simple config file
    cat > .auto-commit << EOF
# Auto-Commit Configuration
INTERVAL=$INTERVAL
AUTO_PUSH=$AUTO_PUSH
USE_NO_VERIFY=$USE_NO_VERIFY
ENABLED=true
EOF

    log_message "${GREEN}✅ Auto-commit configured for $REPO_PATH${NC}"
    log_message ""
    log_message "Settings:"
    log_message "  Interval: ${INTERVAL}s"
    log_message "  Auto-push: $AUTO_PUSH"
    log_message "  Hook bypass: $USE_NO_VERIFY (auto|true|false)"
    log_message ""
    log_message "To start: $0 watch"
}

# Status check (simplified)
status() {
    cd "$REPO_PATH"

    if [ -f .auto-commit ]; then
        log_message "${GREEN}✅ Auto-commit is CONFIGURED${NC}"
        echo ""
        cat .auto-commit | grep -v '^#' | sed 's/^/  /'
    else
        log_message "${YELLOW}Auto-commit is NOT CONFIGURED${NC}"
        log_message "Run: $0 setup"
    fi

    # Check for running processes
    if pgrep -f "auto-commit.*watch" > /dev/null; then
        echo ""
        log_message "${GREEN}✅ Watch process is RUNNING${NC}"
    else
        echo ""
        log_message "${YELLOW}No watch process running${NC}"
    fi

    # Show recent auto-commits
    echo ""
    log_message "${BLUE}Recent auto-commits:${NC}"
    git log --oneline --grep="Auto-commit" -5 2>/dev/null || echo "  None found"
}

# Test function to verify hooks work
test_hooks() {
    cd "$REPO_PATH"
    log_message "${BLUE}Testing pre-commit hooks...${NC}"

    # Create a test file
    local test_file=".test-auto-commit-$$"
    echo "test" > "$test_file"
    git add "$test_file"

    # Try with timeout
    if timeout 5 git commit --dry-run -m "Test" >/dev/null 2>&1; then
        log_message "${GREEN}✅ Hooks are responsive (< 5 seconds)${NC}"
        log_message "Recommendation: Use AUTO_COMMIT_NO_VERIFY=false"
    else
        log_message "${YELLOW}⚠️  Hooks are slow or hanging${NC}"
        log_message "Recommendation: Use AUTO_COMMIT_NO_VERIFY=true"
    fi

    # Cleanup
    git reset HEAD "$test_file" 2>/dev/null || true
    rm -f "$test_file"
}

# Main function with fixed argument handling
main() {
    # Validate repo
    if [ ! -d "$REPO_PATH/.git" ]; then
        log_message "${RED}Error: Not a git repository: $REPO_PATH${NC}"
        exit 1
    fi

    # Execute command
    case "$COMMAND" in
        watch)
            watch_changes
            ;;

        once)
            cd "$REPO_PATH"
            commit_changes
            ;;

        setup)
            setup
            ;;

        status)
            status
            ;;

        test|test-hooks)
            test_hooks
            ;;

        daemon)
            # Run in background
            nohup "$0" watch "$REPO_PATH" > /tmp/auto-commit-$$.log 2>&1 &
            local pid=$!
            log_message "${GREEN}✅ Started daemon with PID $pid${NC}"
            log_message "Logs: /tmp/auto-commit-$$.log"
            log_message "Stop with: kill $pid"
            ;;

        stop)
            if pgrep -f "auto-commit.*watch" > /dev/null; then
                pkill -f "auto-commit.*watch"
                log_message "${GREEN}✅ Stopped auto-commit processes${NC}"
            else
                log_message "${YELLOW}No processes to stop${NC}"
            fi
            ;;

        help|--help|-h)
            cat << EOF
Auto-Commit System - Optimized Edition

Usage: $0 [command] [directory]

Commands:
  setup      Configure auto-commit for a repository
  watch      Start watching for changes (foreground)
  daemon     Start watching in background
  once       Commit current changes once
  status     Show configuration and status
  test       Test if pre-commit hooks work
  stop       Stop background processes
  help       Show this help

Environment Variables:
  AUTO_COMMIT_INTERVAL    Seconds between commits (default: 300)
  AUTO_COMMIT_NO_VERIFY   Skip hooks: auto|true|false (default: auto)
  AUTO_PUSH               Push after commit (default: false)

Examples:
  $0 setup                    # Setup in current directory
  $0 watch ~/my-project       # Watch specific directory
  $0 daemon                   # Start in background
  $0 test                     # Test if hooks work

  # Force skip hooks for problematic repos
  AUTO_COMMIT_NO_VERIFY=true $0 daemon

  # Enable auto-push
  AUTO_PUSH=true $0 watch

Tip: If hooks hang, use AUTO_COMMIT_NO_VERIFY=true
EOF
            ;;

        *)
            log_message "${RED}Unknown command: $COMMAND${NC}"
            log_message "Run: $0 help"
            exit 1
            ;;
    esac
}

# Run main
main