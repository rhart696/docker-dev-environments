#!/bin/bash

# Dev Container Quick Start Script
# Helps you set up a new project with dev containers

echo "🚀 Dev Container Quick Start"
echo "============================"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v code &> /dev/null; then
    echo "❌ VS Code CLI is not installed."
    exit 1
fi

if ! code --list-extensions | grep -q "ms-vscode-remote.remote-containers"; then
    echo "⚠️  Dev Containers extension not installed. Installing..."
    code --install-extension ms-vscode-remote.remote-containers
fi

echo "✅ Prerequisites met"
echo ""

# Select template
echo "📦 Select a template:"
echo "  1) Base (minimal with optional AI)"
echo "  2) Python AI Development"
echo "  3) Node.js AI Development"
echo "  4) Full-Stack AI Development"
echo ""

read -p "Enter choice (1-4): " TEMPLATE_CHOICE

case $TEMPLATE_CHOICE in
    1) TEMPLATE="base" ;;
    2) TEMPLATE="python-ai" ;;
    3) TEMPLATE="nodejs-ai" ;;
    4) TEMPLATE="fullstack-ai" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

# Get project details
read -p "Enter project name: " PROJECT_NAME
read -p "Enter project path (default: ~/projects/$PROJECT_NAME): " PROJECT_PATH

if [ -z "$PROJECT_PATH" ]; then
    PROJECT_PATH="$HOME/projects/$PROJECT_NAME"
fi

# Create project
echo ""
echo "🔨 Creating project at $PROJECT_PATH..."

mkdir -p "$PROJECT_PATH"
cp -r ~/dev-container-templates/$TEMPLATE/.devcontainer "$PROJECT_PATH/"

# Initialize git
cd "$PROJECT_PATH"
git init
echo "node_modules/" > .gitignore
echo ".env" >> .gitignore
echo "*.log" >> .gitignore

# Create README
cat > README.md << EOF
# $PROJECT_NAME

Development environment powered by VS Code Dev Containers.

## Getting Started

1. Open in VS Code: \`code .\`
2. When prompted, click "Reopen in Container"
3. Wait for container to build
4. Start developing!

## Features

- Isolated development environment
- AI coding assistants (Claude/Gemini)
- Project-specific extensions
- Consistent across team members

## Configuration

See \`.devcontainer/devcontainer.json\` for configuration.
EOF

echo "✅ Project created"
echo ""

# Offer to open in VS Code
read -p "Open in VS Code now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    code "$PROJECT_PATH"
    echo ""
    echo "💡 VS Code opened. Click 'Reopen in Container' when prompted."
else
    echo "💡 To open later: cd $PROJECT_PATH && code ."
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "📚 Next steps:"
echo "  1. Configure API keys for AI assistants (if needed)"
echo "  2. Customize .devcontainer/devcontainer.json"
echo "  3. Add project-specific VS Code extensions"
echo "  4. Commit .devcontainer to version control"
echo ""