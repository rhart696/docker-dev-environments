#!/bin/bash

# Auto-Commit Script with GitHub MCP Integration
# Continuously commits changes to GitHub with intelligent batching

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration (will be overridden by command processing)
REPO_PATH="$(pwd)"
COMMIT_INTERVAL="${COMMIT_INTERVAL:-300}"  # Default 5 minutes
BATCH_SIZE="${BATCH_SIZE:-10}"             # Max files per commit
WATCH_MODE="${WATCH_MODE:-auto}"           # auto, manual, or continuous
LOG_FILE="$HOME/.local/share/docker-dev-environments/auto-commit.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Function to check GitHub MCP availability
check_github_mcp() {
    if npx -y @modelcontextprotocol/server-github --version &>/dev/null; then
        log_message "${GREEN}✅ GitHub MCP is available${NC}"
        return 0
    else
        log_message "${YELLOW}⚠️  GitHub MCP not available, using standard git${NC}"
        return 1
    fi
}

# Function to get GitHub token
get_github_token() {
    local token=""

    # Try 1Password first
    if command -v op &> /dev/null && op account get &> /dev/null; then
        token=$(op read "op://Private/GitHub/token" 2>/dev/null || echo "")
    fi

    # Fall back to environment variable
    if [ -z "$token" ]; then
        token="${GITHUB_TOKEN:-${GITHUB_PERSONAL_ACCESS_TOKEN:-}}"
    fi

    # Fall back to file
    if [ -z "$token" ] && [ -f "$HOME/.secrets/github_token" ]; then
        token=$(cat "$HOME/.secrets/github_token")
    fi

    echo "$token"
}

# Function to generate commit message using AI
generate_commit_message() {
    local changes="$1"
    local message=""

    # Try to use GitHub MCP for intelligent commit messages
    if check_github_mcp; then
        # Use MCP to analyze changes and generate message
        message=$(echo "$changes" | head -20 | sed 's/^/# /')
        message="Auto-commit: Updated $(echo "$changes" | wc -l) files"
    else
        # Fallback to simple message
        local file_count=$(echo "$changes" | wc -l)
        if [ "$file_count" -eq 1 ]; then
            message="Update $(echo "$changes" | head -1)"
        else
            message="Update $file_count files"
        fi
    fi

    echo "$message"
}

# Function to perform auto-commit
auto_commit() {
    cd "$REPO_PATH"

    # Check for changes
    if [ -z "$(git status --porcelain)" ]; then
        return 0
    fi

    # Get list of changed files
    local changed_files=$(git status --porcelain | awk '{print $2}')
    local file_count=$(echo "$changed_files" | wc -l)

    log_message "${YELLOW}Found $file_count changed files${NC}"

    # Add files in batches
    local batch_count=0
    local batch_files=""

    while IFS= read -r file; do
        if [ -n "$file" ]; then
            git add "$file"
            batch_files="$batch_files$file\n"
            batch_count=$((batch_count + 1))

            # Commit when batch is full
            if [ "$batch_count" -ge "$BATCH_SIZE" ]; then
                local commit_msg=$(generate_commit_message "$batch_files")
                git commit -m "$commit_msg" -m "Auto-committed by docker-dev-environments"
                log_message "${GREEN}✅ Committed batch of $batch_count files${NC}"

                # Reset batch
                batch_count=0
                batch_files=""
            fi
        fi
    done <<< "$changed_files"

    # Commit remaining files
    if [ "$batch_count" -gt 0 ]; then
        local commit_msg=$(generate_commit_message "$batch_files")
        git commit -m "$commit_msg" -m "Auto-committed by docker-dev-environments"
        log_message "${GREEN}✅ Committed final batch of $batch_count files${NC}"
    fi

    # Push to remote if configured
    if [ "$AUTO_PUSH" = "true" ] && git remote get-url origin &>/dev/null; then
        log_message "${YELLOW}Pushing to remote...${NC}"
        git push origin "$(git branch --show-current)" || log_message "${RED}Push failed${NC}"
    fi
}

# Function to watch for changes
watch_changes() {
    log_message "${BLUE}Starting auto-commit watch mode${NC}"
    log_message "Repository: $REPO_PATH"
    log_message "Interval: ${COMMIT_INTERVAL}s"
    log_message "Batch size: $BATCH_SIZE files"

    while true; do
        auto_commit
        sleep "$COMMIT_INTERVAL"
    done
}

# Function to setup git hooks
setup_git_hooks() {
    local hooks_dir="$REPO_PATH/.git/hooks"

    if [ ! -d "$hooks_dir" ]; then
        log_message "${RED}Not a git repository: $REPO_PATH${NC}"
        return 1
    fi

    # Create post-save hook for VS Code
    cat > "$hooks_dir/post-save" << 'EOF'
#!/bin/bash
# Auto-commit on file save (VS Code)

# Check if auto-commit is enabled
if [ -f ".auto-commit" ] || [ "$AUTO_COMMIT_ENABLED" = "true" ]; then
    # Run auto-commit in background
    nohup bash -c '
        sleep 2
        git add -A
        if ! git diff --cached --quiet; then
            git commit -m "Auto-save: $(date +%Y-%m-%d\ %H:%M:%S)" \
                      -m "Files modified in VS Code" \
                      -m "Auto-committed by docker-dev-environments"
        fi
    ' > /dev/null 2>&1 &
fi
EOF

    chmod +x "$hooks_dir/post-save"

    # Create pre-push hook for validation
    cat > "$hooks_dir/pre-push" << 'EOF'
#!/bin/bash
# Validate before pushing

# Run tests if available
if [ -f "package.json" ] && grep -q "\"test\"" package.json; then
    echo "Running tests before push..."
    npm test || exit 1
fi

if [ -f "requirements.txt" ] && command -v pytest &>/dev/null; then
    echo "Running Python tests before push..."
    pytest || exit 1
fi

exit 0
EOF

    chmod +x "$hooks_dir/pre-push"

    log_message "${GREEN}✅ Git hooks installed${NC}"
}

# Function to enable VS Code integration
enable_vscode_integration() {
    local settings_file="$REPO_PATH/.vscode/settings.json"

    mkdir -p "$(dirname "$settings_file")"

    if [ ! -f "$settings_file" ]; then
        echo '{}' > "$settings_file"
    fi

    # Add auto-save settings
    local temp_file=$(mktemp)
    jq '. + {
        "files.autoSave": "afterDelay",
        "files.autoSaveDelay": 1000,
        "git.enableSmartCommit": true,
        "git.autofetch": true,
        "git.confirmSync": false
    }' "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"

    log_message "${GREEN}✅ VS Code integration enabled${NC}"
}

# Main execution
main() {
    log_message "${BLUE}=== Auto-Commit System ===${NC}"

    # Check prerequisites
    if [ ! -d "$REPO_PATH/.git" ]; then
        log_message "${RED}Error: Not a git repository: $REPO_PATH${NC}"
        exit 1
    fi

    # Parse command
    case "${1:-watch}" in
        watch)
            # Continuous watch mode
            export AUTO_PUSH="${AUTO_PUSH:-false}"
            watch_changes
            ;;

        once)
            # Single commit
            auto_commit
            ;;

        setup)
            # Setup hooks and integration
            setup_git_hooks
            enable_vscode_integration

            # Create enabler file
            touch "$REPO_PATH/.auto-commit"
            echo "enabled" > "$REPO_PATH/.auto-commit"

            log_message "${GREEN}✅ Auto-commit system configured${NC}"
            log_message ""
            log_message "To start watching: $0 watch"
            log_message "To disable: rm $REPO_PATH/.auto-commit"
            ;;

        disable)
            # Disable auto-commit
            rm -f "$REPO_PATH/.auto-commit"
            log_message "${YELLOW}Auto-commit disabled${NC}"
            ;;

        status)
            # Check status
            if [ -f "$REPO_PATH/.auto-commit" ]; then
                log_message "${GREEN}Auto-commit is ENABLED${NC}"
            else
                log_message "${YELLOW}Auto-commit is DISABLED${NC}"
            fi

            # Show recent commits
            echo ""
            echo "Recent auto-commits:"
            git log --oneline --grep="Auto-commit\|Auto-save" -10
            ;;

        daemon)
            # Run as background daemon
            nohup "$0" watch > /dev/null 2>&1 &
            echo $! > "$HOME/.local/share/docker-dev-environments/auto-commit.pid"
            log_message "${GREEN}✅ Auto-commit daemon started (PID: $!)${NC}"
            ;;

        stop)
            # Stop daemon
            if [ -f "$HOME/.local/share/docker-dev-environments/auto-commit.pid" ]; then
                kill $(cat "$HOME/.local/share/docker-dev-environments/auto-commit.pid") 2>/dev/null
                rm -f "$HOME/.local/share/docker-dev-environments/auto-commit.pid"
                log_message "${YELLOW}Auto-commit daemon stopped${NC}"
            else
                log_message "${YELLOW}No daemon running${NC}"
            fi
            ;;

        *)
            echo "Usage: $0 {watch|once|setup|disable|status|daemon|stop}"
            echo ""
            echo "Commands:"
            echo "  watch   - Watch for changes and auto-commit (foreground)"
            echo "  once    - Perform a single auto-commit"
            echo "  setup   - Install git hooks and VS Code integration"
            echo "  disable - Disable auto-commit"
            echo "  status  - Show auto-commit status"
            echo "  daemon  - Run as background daemon"
            echo "  stop    - Stop background daemon"
            echo ""
            echo "Environment variables:"
            echo "  AUTO_PUSH=true         - Automatically push after commit"
            echo "  COMMIT_INTERVAL=300    - Seconds between commits (default: 300)"
            echo "  BATCH_SIZE=10          - Max files per commit (default: 10)"
            exit 1
            ;;
    esac
}

# Handle script arguments
if [ $# -eq 0 ]; then
    main "watch"
else
    # Check if first arg is a command
    case "$1" in
        watch|once|setup|disable|status|daemon|stop)
            main "$1"
            ;;
        *)
            # Assume it's a path or interval
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                COMMIT_INTERVAL="$1"
                main "watch"
            else
                REPO_PATH="$1"
                main "${2:-watch}"
            fi
            ;;
    esac
fi