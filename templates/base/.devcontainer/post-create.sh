#!/bin/bash

# Post-create script for dev container
# This runs after the container is created

echo "🚀 Setting up development environment..."

# Set up git (if not already configured via mount)
if [ ! -f ~/.gitconfig ]; then
    echo "📝 Configuring git..."
    git config --global user.name "${GIT_USER_NAME:-Developer}"
    git config --global user.email "${GIT_USER_EMAIL:-dev@localhost}"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
fi

# Fix SSH permissions if mounted
if [ -d ~/.ssh ]; then
    echo "🔐 Fixing SSH permissions..."
    # Create a writable copy since mounted as readonly
    cp -r ~/.ssh ~/.ssh-copy 2>/dev/null || true
    mv ~/.ssh-copy ~/.ssh 2>/dev/null || true
    chmod 700 ~/.ssh 2>/dev/null || true
    chmod 600 ~/.ssh/* 2>/dev/null || true
fi

# Install project dependencies if package.json exists
if [ -f "package.json" ]; then
    echo "📦 Installing Node.js dependencies..."
    if [ -f "pnpm-lock.yaml" ]; then
        pnpm install
    elif [ -f "yarn.lock" ]; then
        yarn install
    else
        npm install
    fi
fi

# Install Python dependencies if requirements.txt exists
if [ -f "requirements.txt" ]; then
    echo "🐍 Installing Python dependencies..."
    pip install --user -r requirements.txt
fi

# Install Python dependencies if pyproject.toml exists
if [ -f "pyproject.toml" ]; then
    echo "🐍 Installing Python project..."
    pip install --user -e .
fi

# Set up Claude CLI if API key is available
if [ -n "$CLAUDE_API_KEY" ] || [ -f ~/.config/claude/api_key ]; then
    echo "🤖 Claude CLI is available"
    # Optional: Run claude --version to verify
fi

# Set up Gemini CLI if API key is available  
if [ -n "$GEMINI_API_KEY" ] || [ -f ~/.config/gemini/api_key ]; then
    echo "🤖 Gemini CLI is available"
    # Optional: Run gemini --version to verify
fi

# Create useful project directories
mkdir -p .vscode
mkdir -p docs
mkdir -p tests

# Initialize ADR structure
if [ -f .devcontainer/adr-init.sh ]; then
    echo "📚 Setting up Architecture Decision Records..."
    bash .devcontainer/adr-init.sh
fi

echo ""
echo "✅ Development environment ready!"
echo ""
echo "📋 Quick tips:"
echo "  • Run 'code --list-extensions' to see installed VS Code extensions"
echo "  • Use 'claude' or 'gemini' CLI if configured with API keys"
echo "  • Git is configured and ready to use"
echo "  • Run 'alias' to see available shortcuts"
echo ""