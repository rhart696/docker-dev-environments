#!/bin/bash

# GitHub Integration Script for Docker Dev Environments
# Handles GitHub repository creation and linking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_PATH="${1:-$(pwd)}"
GITHUB_USERNAME="${GITHUB_USERNAME:-$(git config --global user.name)}"
GITHUB_ORG="${GITHUB_ORG:-}"  # Optional: organization name

# Function to check prerequisites
check_prerequisites() {
    # Check for gh CLI
    if ! command -v gh &> /dev/null; then
        echo -e "${YELLOW}GitHub CLI (gh) not found. Installing...${NC}"
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update && sudo apt install gh -y
    fi

    # Check gh auth status
    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}Not authenticated with GitHub. Running gh auth login...${NC}"

        # Try to use token from 1Password or environment
        if command -v op &> /dev/null && op account get &> /dev/null; then
            TOKEN=$(op read "op://Private/GitHub/token" 2>/dev/null || echo "")
            if [ -n "$TOKEN" ]; then
                echo "$TOKEN" | gh auth login --with-token
            else
                gh auth login
            fi
        else
            gh auth login
        fi
    fi

    echo -e "${GREEN}✅ GitHub CLI authenticated${NC}"
}

# Function to create GitHub repository
create_github_repo() {
    local repo_name="$1"
    local description="$2"
    local visibility="$3"
    local auto_init="$4"

    echo -e "${YELLOW}Creating GitHub repository: $repo_name${NC}"

    # Build gh command
    local gh_cmd="gh repo create"

    if [ -n "$GITHUB_ORG" ]; then
        gh_cmd="$gh_cmd $GITHUB_ORG/$repo_name"
    else
        gh_cmd="$gh_cmd $repo_name"
    fi

    # Add options
    gh_cmd="$gh_cmd --$visibility"

    if [ -n "$description" ]; then
        gh_cmd="$gh_cmd --description \"$description\""
    fi

    if [ "$auto_init" != "true" ]; then
        gh_cmd="$gh_cmd --source=. --remote=origin"
    else
        gh_cmd="$gh_cmd --clone"
    fi

    # Execute command
    eval $gh_cmd

    echo -e "${GREEN}✅ Repository created successfully${NC}"
}

# Function to link existing project to GitHub
link_to_github() {
    local project_path="$1"
    local repo_name="$2"

    cd "$project_path"

    # Check if already has remote
    if git remote get-url origin &> /dev/null; then
        echo -e "${YELLOW}Repository already has origin remote:${NC}"
        git remote get-url origin
        read -p "Replace with new GitHub repository? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
        git remote remove origin
    fi

    # Create repository on GitHub
    create_github_repo "$repo_name" "" "private" "false"

    # Push to GitHub
    echo -e "${YELLOW}Pushing to GitHub...${NC}"
    git add -A
    git commit -m "Initial commit" -m "Created with Docker Dev Environments" || true
    git branch -M main
    git push -u origin main

    echo -e "${GREEN}✅ Project linked to GitHub${NC}"
}

# Function to setup GitHub Actions
setup_github_actions() {
    local project_path="$1"

    echo -e "${YELLOW}Setting up GitHub Actions...${NC}"

    mkdir -p "$project_path/.github/workflows"

    # Detect project type and create appropriate workflow
    if [ -f "$project_path/package.json" ]; then
        create_node_workflow "$project_path"
    elif [ -f "$project_path/requirements.txt" ]; then
        create_python_workflow "$project_path"
    else
        create_generic_workflow "$project_path"
    fi

    echo -e "${GREEN}✅ GitHub Actions configured${NC}"
}

# Function to create Node.js workflow
create_node_workflow() {
    cat > "$1/.github/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18.x, 20.x]

    steps:
    - uses: actions/checkout@v3
    - name: Use Node.js ${{ matrix.node-version }}
      uses: actions/setup-node@v3
      with:
        node-version: ${{ matrix.node-version }}
    - run: npm ci
    - run: npm test
    - run: npm run build --if-present
EOF
}

# Function to create Python workflow
create_python_workflow() {
    cat > "$1/.github/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        python-version: ["3.9", "3.10", "3.11"]

    steps:
    - uses: actions/checkout@v3
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        pip install pytest pytest-cov
    - name: Run tests
      run: |
        pytest --cov=./ --cov-report=xml
EOF
}

# Function to create generic workflow
create_generic_workflow() {
    cat > "$1/.github/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3
    - name: Build Docker image
      run: docker build -t app .
    - name: Run tests
      run: docker run --rm app test
EOF
}

# Function to configure branch protection
setup_branch_protection() {
    local repo_name="$1"

    echo -e "${YELLOW}Setting up branch protection rules...${NC}"

    # Protect main branch
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        "/repos/${GITHUB_USERNAME}/${repo_name}/branches/main/protection" \
        -f required_status_checks='{"strict":true,"contexts":["continuous-integration"]}' \
        -f enforce_admins=false \
        -f required_pull_request_reviews='{"required_approving_review_count":1}' \
        -f restrictions=null \
        2>/dev/null || echo "Branch protection requires admin rights"

    echo -e "${GREEN}✅ Branch protection configured${NC}"
}

# Interactive setup
interactive_setup() {
    echo -e "${BLUE}=== GitHub Integration Setup ===${NC}"
    echo ""

    # Get project details
    cd "$PROJECT_PATH"
    PROJECT_NAME=$(basename "$PROJECT_PATH")

    echo "Project: $PROJECT_NAME"
    echo "Path: $PROJECT_PATH"
    echo ""

    # Check if git repo exists
    if [ ! -d ".git" ]; then
        echo -e "${YELLOW}Initializing git repository...${NC}"
        git init
        git add -A
        git commit -m "Initial commit" || true
    fi

    # Ask for GitHub integration
    read -p "Create/link GitHub repository? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Repository name (default: $PROJECT_NAME): " REPO_NAME
        REPO_NAME="${REPO_NAME:-$PROJECT_NAME}"

        read -p "Repository visibility (public/private) [private]: " VISIBILITY
        VISIBILITY="${VISIBILITY:-private}"

        read -p "Repository description: " DESCRIPTION

        # Check prerequisites
        check_prerequisites

        # Create and link repository
        link_to_github "$PROJECT_PATH" "$REPO_NAME"

        # Setup GitHub Actions
        read -p "Setup GitHub Actions CI/CD? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_github_actions "$PROJECT_PATH"
        fi

        # Setup branch protection
        read -p "Setup branch protection rules? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_branch_protection "$REPO_NAME"
        fi

        # Enable auto-commit
        read -p "Enable auto-commit system? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            "$HOME/active-projects/docker-dev-environments/scripts/auto-commit.sh" setup
        fi

        echo ""
        echo -e "${GREEN}✅ GitHub integration complete!${NC}"
        echo ""
        echo "Repository URL: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
        echo ""
        echo "Next steps:"
        echo "  1. Visit your repository: gh repo view --web"
        echo "  2. Add collaborators: gh repo edit --add-collaborator USERNAME"
        echo "  3. Create issues: gh issue create"
        echo "  4. View Actions: gh workflow view"
    else
        echo -e "${YELLOW}Skipping GitHub integration${NC}"
        echo "You can run this script again later to add GitHub integration."
    fi
}

# Main execution
case "${1:-interactive}" in
    create)
        check_prerequisites
        create_github_repo "$2" "$3" "${4:-private}" "${5:-false}"
        ;;
    link)
        check_prerequisites
        link_to_github "${2:-$(pwd)}" "$3"
        ;;
    actions)
        setup_github_actions "${2:-$(pwd)}"
        ;;
    protect)
        setup_branch_protection "$2"
        ;;
    interactive|*)
        interactive_setup
        ;;
esac