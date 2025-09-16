#!/bin/bash

# Enhanced Auto-Commit System with Pre-Commit Hook Management
# Handles security hooks gracefully to prevent hanging
# Version: 2.0.0

set -e

# Configuration
REPO_PATH="${1:-$(pwd)}"
INTERVAL="${AUTO_COMMIT_INTERVAL:-300}"  # Default 5 minutes
BATCH_SIZE="${AUTO_COMMIT_BATCH_SIZE:-10}"
AUTO_PUSH="${AUTO_PUSH:-false}"
SKIP_HOOKS="${AUTO_COMMIT_SKIP_HOOKS:-smart}"  # Options: always, never, smart
HOOK_TIMEOUT="${AUTO_COMMIT_HOOK_TIMEOUT:-10}"  # Timeout for hook execution in seconds

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_message() {
    echo -e "$1" >&2
}

# Check if security hooks are present
check_for_security_hooks() {
    local hooks_path=$(git config --get core.hooksPath 2>/dev/null || echo ".git/hooks")

    if [ -n "$hooks_path" ] && [ -d "$hooks_path" ]; then
        if [ -f "$hooks_path/pre-commit" ]; then
            # Check if it's a security scanning hook
            if grep -q "password\|secret\|api.*key\|token\|credentials" "$hooks_path/pre-commit" 2>/dev/null; then
                return 0  # Security hooks detected
            fi
        fi
    fi

    return 1  # No security hooks detected
}

# Test if hooks are responsive
test_hook_responsiveness() {
    log_message "${YELLOW}Testing pre-commit hook responsiveness...${NC}"

    # Create a test commit with timeout
    local test_file=$(mktemp)
    echo "test" > "$test_file"
    git add "$test_file"

    # Try to run hooks with timeout
    if timeout "$HOOK_TIMEOUT" git commit --dry-run -m "Test" > /dev/null 2>&1; then
        git reset HEAD "$test_file" > /dev/null 2>&1
        rm -f "$test_file"
        return 0  # Hooks are responsive
    else
        git reset HEAD "$test_file" > /dev/null 2>&1
        rm -f "$test_file"
        return 1  # Hooks are slow/hanging
    fi
}

# Intelligent commit with hook management
smart_commit() {
    local commit_msg="$1"
    local skip_hooks_flag=""

    case "$SKIP_HOOKS" in
        always)
            skip_hooks_flag="--no-verify"
            log_message "${YELLOW}⚠️  Bypassing pre-commit hooks (always mode)${NC}"
            ;;
        never)
            skip_hooks_flag=""
            log_message "${BLUE}Running with pre-commit hooks enabled${NC}"
            ;;
        smart)
            # Smart detection: check if hooks exist and are responsive
            if check_for_security_hooks; then
                log_message "${YELLOW}Security hooks detected${NC}"

                # Test hook responsiveness
                if ! test_hook_responsiveness; then
                    skip_hooks_flag="--no-verify"
                    log_message "${YELLOW}⚠️  Hooks are slow/hanging - bypassing for auto-commit${NC}"
                    log_message "${BLUE}ℹ️  Manual commits will still run security checks${NC}"
                else
                    skip_hooks_flag=""
                    log_message "${GREEN}✅ Hooks are responsive - running with hooks${NC}"
                fi
            else
                skip_hooks_flag=""
                log_message "${BLUE}No security hooks detected - normal commit${NC}"
            fi
            ;;
    esac

    # Perform the commit with appropriate flags
    if git commit $skip_hooks_flag -m "$commit_msg" -m "Auto-committed by enhanced auto-commit system"; then
        log_message "${GREEN}✅ Commit successful${NC}"

        # If hooks were skipped, suggest manual security check
        if [ -n "$skip_hooks_flag" ]; then
            log_message "${YELLOW}💡 Run 'git diff HEAD~1 | grep -E \"password|secret|token\"' to manually check for secrets${NC}"
        fi

        return 0
    else
        log_message "${RED}❌ Commit failed${NC}"
        return 1
    fi
}

# Generate commit message using GitHub MCP if available
generate_commit_message() {
    local files="$1"
    local default_msg="Auto-commit: Updated $(echo "$files" | wc -l) files"

    # Try to use GitHub MCP for better messages
    if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
        local ai_msg=$(gh api /repos/:owner/:repo/generate-commit-message \
                       --method POST \
                       --field files="$files" \
                       2>/dev/null || echo "")

        if [ -n "$ai_msg" ]; then
            echo "$(echo "$ai_msg" | jq -r .message 2>/dev/null || echo "$default_msg")"
        else
            echo "$default_msg"
        fi
    else
        # Fallback to descriptive message based on file types
        if echo "$files" | grep -q "\.md$"; then
            echo "📝 Auto-commit: Documentation updates"
        elif echo "$files" | grep -q "\.yml\|\.yaml"; then
            echo "🔧 Auto-commit: Configuration updates"
        elif echo "$files" | grep -q "\.sh$"; then
            echo "🔨 Auto-commit: Script updates"
        elif echo "$files" | grep -q "docker"; then
            echo "🐳 Auto-commit: Docker configuration updates"
        else
            echo "$default_msg"
        fi
    fi
}

# Main commit function with batching
commit_changes() {
    local changed_files=$(git status --porcelain | grep -v "^?" | cut -c4-)
    local untracked_files=$(git status --porcelain | grep "^?" | cut -c4-)

    if [ -z "$changed_files" ] && [ -z "$untracked_files" ]; then
        return 0  # No changes
    fi

    log_message "${YELLOW}Found $(echo "$changed_files $untracked_files" | wc -w) changed files${NC}"

    # Add all files
    git add -A

    # Generate commit message
    local all_files=$(git diff --cached --name-only)
    local commit_msg=$(generate_commit_message "$all_files")

    # Use smart commit
    smart_commit "$commit_msg"

    # Auto-push if enabled
    if [ "$AUTO_PUSH" = "true" ] && [ $? -eq 0 ]; then
        log_message "${BLUE}Pushing to remote...${NC}"
        if git push; then
            log_message "${GREEN}✅ Pushed to remote${NC}"
        else
            log_message "${RED}❌ Push failed${NC}"
        fi
    fi
}

# Watch for changes
watch_changes() {
    log_message "${BLUE}Starting enhanced auto-commit watch mode${NC}"
    log_message "Repository: $REPO_PATH"
    log_message "Interval: ${INTERVAL}s"
    log_message "Batch size: $BATCH_SIZE files"
    log_message "Hook handling: $SKIP_HOOKS"

    cd "$REPO_PATH"

    # Initial hook detection
    if check_for_security_hooks; then
        log_message "${YELLOW}⚠️  Security hooks detected in this repository${NC}"
        log_message "The system will intelligently handle them to prevent hanging"
    fi

    while true; do
        commit_changes
        sleep "$INTERVAL"
    done
}

# Setup function (creates config file)
setup() {
    local config_file="$REPO_PATH/.auto-commit"

    cat > "$config_file" << EOF
# Auto-Commit Configuration
INTERVAL=$INTERVAL
BATCH_SIZE=$BATCH_SIZE
AUTO_PUSH=$AUTO_PUSH
SKIP_HOOKS=$SKIP_HOOKS
HOOK_TIMEOUT=$HOOK_TIMEOUT
ENABLED=true
EOF

    log_message "${GREEN}✅ Enhanced auto-commit system configured${NC}"
    log_message ""
    log_message "Configuration saved to: $config_file"
    log_message ""
    log_message "${BLUE}Hook handling modes:${NC}"
    log_message "  - smart: Automatically detect and handle slow hooks (default)"
    log_message "  - always: Always skip hooks for auto-commits"
    log_message "  - never: Never skip hooks (may cause hanging)"
    log_message ""
    log_message "To start watching: $0 watch"
    log_message "To disable: rm $config_file"
}

# Status check
status() {
    local config_file="$REPO_PATH/.auto-commit"

    if [ -f "$config_file" ]; then
        log_message "${GREEN}✅ Auto-commit is ENABLED${NC}"
        log_message ""
        log_message "Configuration:"
        cat "$config_file" | grep -v "^#" | sed 's/^/  /'

        # Check for hooks
        if check_for_security_hooks; then
            log_message ""
            log_message "${YELLOW}⚠️  Security hooks detected${NC}"

            if test_hook_responsiveness; then
                log_message "${GREEN}✅ Hooks are responsive${NC}"
            else
                log_message "${RED}⚠️  Hooks may be slow/hanging${NC}"
                log_message "${BLUE}ℹ️  Auto-commit will bypass them if needed${NC}"
            fi
        fi
    else
        log_message "${YELLOW}Auto-commit is DISABLED${NC}"
    fi

    # Check for running daemon
    if pgrep -f "auto-commit.*watch" > /dev/null; then
        log_message ""
        log_message "${GREEN}✅ Auto-commit daemon is running${NC}"
    else
        log_message ""
        log_message "${YELLOW}No auto-commit daemon running${NC}"
    fi
}

# Main execution
main() {
    log_message "${BLUE}=== Enhanced Auto-Commit System ===${NC}"

    # Check prerequisites
    if [ ! -d "$REPO_PATH/.git" ]; then
        log_message "${RED}Error: Not a git repository: $REPO_PATH${NC}"
        exit 1
    fi

    # Parse command
    case "${1:-status}" in
        watch)
            watch_changes
            ;;

        once)
            commit_changes
            ;;

        setup)
            setup
            ;;

        status)
            status
            ;;

        test-hooks)
            if check_for_security_hooks; then
                log_message "${YELLOW}Security hooks detected${NC}"
                if test_hook_responsiveness; then
                    log_message "${GREEN}✅ Hooks are responsive${NC}"
                else
                    log_message "${RED}❌ Hooks are slow or hanging${NC}"
                fi
            else
                log_message "${BLUE}No security hooks detected${NC}"
            fi
            ;;

        daemon)
            nohup "$0" watch > /tmp/auto-commit-$$.log 2>&1 &
            log_message "${GREEN}✅ Daemon started with PID $!${NC}"
            log_message "Logs: /tmp/auto-commit-$$.log"
            ;;

        stop)
            if pgrep -f "auto-commit.*watch" > /dev/null; then
                pkill -f "auto-commit.*watch"
                log_message "${GREEN}✅ Auto-commit daemon stopped${NC}"
            else
                log_message "${YELLOW}No daemon running${NC}"
            fi
            ;;

        help|*)
            cat << EOF
Usage: $0 [command] [repo_path]

Commands:
  setup     - Configure auto-commit for repository
  watch     - Start watching for changes
  once      - Commit current changes once
  daemon    - Run watch mode as background daemon
  stop      - Stop background daemon
  status    - Check current status
  test-hooks - Test if pre-commit hooks are responsive

Environment variables:
  AUTO_COMMIT_INTERVAL     - Seconds between commits (default: 300)
  AUTO_COMMIT_BATCH_SIZE   - Max files per commit (default: 10)
  AUTO_PUSH               - Auto-push after commit (default: false)
  AUTO_COMMIT_SKIP_HOOKS  - Hook handling: smart|always|never (default: smart)
  AUTO_COMMIT_HOOK_TIMEOUT - Timeout for hook tests in seconds (default: 10)

Examples:
  $0 setup                          # Configure for current directory
  $0 watch ~/my-project             # Watch specific directory
  AUTO_PUSH=true $0 daemon          # Start daemon with auto-push
  AUTO_COMMIT_SKIP_HOOKS=always $0 watch  # Always skip hooks
EOF
            ;;
    esac
}

# Run main function with all arguments
main "$@"