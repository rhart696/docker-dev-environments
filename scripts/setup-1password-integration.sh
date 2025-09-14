#!/bin/bash

# 1Password CLI Integration Script for Docker Dev Environments
# Sets up and configures 1Password CLI for seamless API key management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 1Password CLI Integration Setup ===${NC}"
echo ""

# Check if 1Password CLI is installed
check_op_installed() {
    if command -v op &> /dev/null; then
        OP_VERSION=$(op --version)
        echo -e "${GREEN}✅ 1Password CLI found: version $OP_VERSION${NC}"
        return 0
    else
        echo -e "${RED}❌ 1Password CLI not found${NC}"
        echo ""
        echo "Please install 1Password CLI first:"
        echo "  - Visit: https://developer.1password.com/docs/cli/get-started/"
        echo "  - Or run: curl -sS https://downloads.1password.com/linux/cli/stable/op_linux_amd64_v2.29.0.zip | unzip -j - op -d ~/bin/"
        return 1
    fi
}

# Check if user is signed in to 1Password
check_op_signin() {
    if op account get &> /dev/null; then
        ACCOUNT=$(op account get --format json | jq -r .email)
        echo -e "${GREEN}✅ Signed in to 1Password as: $ACCOUNT${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Not signed in to 1Password${NC}"
        echo ""
        echo "Please sign in to 1Password:"
        echo "  op signin"
        return 1
    fi
}

# Function to retrieve API key from 1Password
get_api_key_from_op() {
    local item_path=$1
    local api_key=""

    if [ -n "$item_path" ]; then
        api_key=$(op read "$item_path" 2>/dev/null || echo "")
    fi

    echo "$api_key"
}

# Function to create environment file with 1Password references
create_env_file() {
    local env_file="$1"

    echo -e "${YELLOW}Creating environment file with 1Password references...${NC}"

    cat > "$env_file" << 'EOF'
# Docker Dev Environments - 1Password Integration
# This file uses 1Password CLI to retrieve secrets

# Claude API Key
export CLAUDE_API_KEY=$(op read "op://Private/Anthropic/api_key" 2>/dev/null || echo "")

# Gemini API Key
export GEMINI_API_KEY=$(op read "op://Private/Gemini/api_key" 2>/dev/null || op read "op://Private/Google Gemini/credential" 2>/dev/null || echo "")

# GitHub Token
export GITHUB_TOKEN=$(op read "op://Private/GitHub/token" 2>/dev/null || echo "")
export GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN"

# OpenAI API Key (optional)
export OPENAI_API_KEY=$(op read "op://Private/OpenAI API Key/credential" 2>/dev/null || echo "")

# Codeium API Key (optional)
export CODEIUM_API_KEY=$(op read "op://Private/Codeium/api_key" 2>/dev/null || echo "")

# Function to reload secrets from 1Password
reload_secrets() {
    echo "Reloading secrets from 1Password..."
    source ~/.config/docker-dev-environments/1password.env
    echo "Secrets reloaded successfully"
}

# Alias for quick secret access
alias op-secrets='op item list --categories "API Credential" --format json | jq -r ".[] | .title"'
EOF

    chmod 600 "$env_file"
    echo -e "${GREEN}✅ Created environment file at: $env_file${NC}"
}

# Function to create wrapper script for Docker Compose
create_docker_wrapper() {
    local wrapper_path="$1"

    echo -e "${YELLOW}Creating Docker Compose wrapper with 1Password integration...${NC}"

    cat > "$wrapper_path" << 'EOF'
#!/bin/bash

# Docker Compose wrapper with 1Password CLI integration
# Automatically injects secrets from 1Password

# Source 1Password environment if available
if [ -f ~/.config/docker-dev-environments/1password.env ]; then
    source ~/.config/docker-dev-environments/1password.env
fi

# Run Docker Compose with environment variables
exec docker-compose "$@"
EOF

    chmod +x "$wrapper_path"
    echo -e "${GREEN}✅ Created Docker wrapper at: $wrapper_path${NC}"
}

# Function to test API key retrieval
test_api_keys() {
    echo ""
    echo -e "${BLUE}Testing API key retrieval from 1Password...${NC}"
    echo ""

    # Test Claude key
    echo -n "Claude API key: "
    if CLAUDE_KEY=$(op read "op://Private/Anthropic/api_key" 2>/dev/null); then
        echo -e "${GREEN}✅ Found (${#CLAUDE_KEY} characters)${NC}"
    else
        echo -e "${YELLOW}⚠️  Not found in 1Password${NC}"
    fi

    # Test Gemini key
    echo -n "Gemini API key: "
    if GEMINI_KEY=$(op read "op://Private/Gemini/api_key" 2>/dev/null || op read "op://Private/Google Gemini/credential" 2>/dev/null); then
        echo -e "${GREEN}✅ Found (${#GEMINI_KEY} characters)${NC}"
    else
        echo -e "${YELLOW}⚠️  Not found in 1Password${NC}"
    fi

    # Test GitHub token
    echo -n "GitHub token: "
    if GITHUB_KEY=$(op read "op://Private/GitHub/token" 2>/dev/null); then
        echo -e "${GREEN}✅ Found (${#GITHUB_KEY} characters)${NC}"
    else
        echo -e "${YELLOW}⚠️  Not found in 1Password${NC}"
    fi

    # Test OpenAI key
    echo -n "OpenAI API key: "
    if OPENAI_KEY=$(op read "op://Private/OpenAI API Key/credential" 2>/dev/null); then
        echo -e "${GREEN}✅ Found (${#OPENAI_KEY} characters)${NC}"
    else
        echo -e "${YELLOW}⚠️  Not found in 1Password${NC}"
    fi
}

# Function to setup bash integration
setup_bash_integration() {
    echo ""
    echo -e "${BLUE}Setting up bash integration...${NC}"

    # Add to bashrc if not already present
    if ! grep -q "docker-dev-environments/1password.env" ~/.bashrc; then
        cat >> ~/.bashrc << 'EOF'

# Docker Dev Environments - 1Password Integration
if [ -f ~/.config/docker-dev-environments/1password.env ]; then
    source ~/.config/docker-dev-environments/1password.env
fi
EOF
        echo -e "${GREEN}✅ Added 1Password integration to ~/.bashrc${NC}"
    else
        echo -e "${YELLOW}⚠️  1Password integration already in ~/.bashrc${NC}"
    fi
}

# Main execution
main() {
    # Check prerequisites
    check_op_installed || exit 1
    echo ""
    check_op_signin || exit 1
    echo ""

    # Create config directory
    CONFIG_DIR="$HOME/.config/docker-dev-environments"
    mkdir -p "$CONFIG_DIR"

    # Create environment file
    create_env_file "$CONFIG_DIR/1password.env"
    echo ""

    # Create Docker wrapper
    WRAPPER_DIR="$HOME/active-projects/docker-dev-environments/scripts"
    create_docker_wrapper "$WRAPPER_DIR/docker-compose-op"
    echo ""

    # Test API keys
    test_api_keys
    echo ""

    # Setup bash integration
    setup_bash_integration
    echo ""

    # Summary
    echo -e "${BLUE}=== Setup Complete ===${NC}"
    echo ""
    echo "1Password CLI integration is now configured for Docker Dev Environments."
    echo ""
    echo -e "${GREEN}Available commands:${NC}"
    echo "  - Source environment: source ~/.config/docker-dev-environments/1password.env"
    echo "  - List secrets: op-secrets"
    echo "  - Reload secrets: reload_secrets"
    echo "  - Docker with 1Password: ./scripts/docker-compose-op"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Restart your shell or run: source ~/.bashrc"
    echo "  2. Test with: ./scripts/validate-api-keys.sh"
    echo "  3. Use docker-compose-op instead of docker-compose for automatic secret injection"
}

# Run main function
main "$@"