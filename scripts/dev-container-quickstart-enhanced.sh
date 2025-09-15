#!/bin/bash

# Enhanced Dev Container Quick Start Script with Docker Compose Support
# Helps you set up a new project with dev containers and optional multi-service stacks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"

echo -e "${BLUE}🚀 Enhanced Dev Container Quick Start${NC}"
echo -e "${BLUE}=====================================/${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed.${NC}"
    exit 1
fi

if ! command -v code &> /dev/null; then
    echo -e "${RED}❌ VS Code CLI is not installed.${NC}"
    exit 1
fi

if ! code --list-extensions | grep -q "ms-vscode-remote.remote-containers"; then
    echo -e "${YELLOW}⚠️  Dev Containers extension not installed. Installing...${NC}"
    code --install-extension ms-vscode-remote.remote-containers
fi

echo -e "${GREEN}✅ Prerequisites met${NC}"
echo ""

# Select template
echo -e "${CYAN}📦 Select a template:${NC}"
echo "  1) Base (minimal with optional AI)"
echo "  2) Python AI Development"
echo "  3) Node.js AI Development"
echo "  4) Full-Stack AI Development"
echo "  5) Stagehand Browser Testing"
echo ""

read -p "Enter choice (1-5): " TEMPLATE_CHOICE

case $TEMPLATE_CHOICE in
    1) TEMPLATE="base" ;;
    2) TEMPLATE="python-ai" ;;
    3) TEMPLATE="nodejs-ai" ;;
    4) TEMPLATE="fullstack-ai" ;;
    5) TEMPLATE="stagehand-testing" ;;
    *) echo -e "${RED}Invalid choice${NC}"; exit 1 ;;
esac

# Get project details
read -p "Enter project name: " PROJECT_NAME
read -p "Enter project path (default: ~/projects/$PROJECT_NAME): " PROJECT_PATH

if [ -z "$PROJECT_PATH" ]; then
    PROJECT_PATH="$HOME/projects/$PROJECT_NAME"
fi

# Ask about Docker Compose
echo ""
echo -e "${CYAN}🐳 Docker Compose Configuration${NC}"
echo "Would you like to add Docker Compose for multi-service setup?"
echo "(Recommended for apps needing databases, Redis, message queues, etc.)"
echo ""

USE_COMPOSE=false
COMPOSE_SERVICES=""

if [[ "$TEMPLATE" == "stagehand-testing" ]]; then
    echo -e "${YELLOW}ℹ️  Stagehand template doesn't typically need Docker Compose${NC}"
    read -p "Add Docker Compose anyway? (y/N): " -n 1 -r
else
    read -p "Add Docker Compose? (Y/n): " -n 1 -r
    if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
        REPLY="y"
    fi
fi
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    USE_COMPOSE=true

    echo -e "${CYAN}Select services to include:${NC}"

    case $TEMPLATE in
        "base")
            echo "  1) Basic (just the app container)"
            echo "  2) With PostgreSQL"
            echo "  3) With PostgreSQL + Redis"
            read -p "Enter choice (1-3): " SERVICE_CHOICE
            case $SERVICE_CHOICE in
                1) COMPOSE_SERVICES="basic" ;;
                2) COMPOSE_SERVICES="with-db" ;;
                3) COMPOSE_SERVICES="with-db,with-cache" ;;
                *) COMPOSE_SERVICES="basic" ;;
            esac
            ;;
        "python-ai")
            echo "  1) Python + PostgreSQL + Redis"
            echo "  2) Python + PostgreSQL + Redis + Celery"
            echo "  3) Python + MongoDB + Redis"
            read -p "Enter choice (1-3): " SERVICE_CHOICE
            case $SERVICE_CHOICE in
                1) COMPOSE_SERVICES="standard" ;;
                2) COMPOSE_SERVICES="with-celery" ;;
                3) COMPOSE_SERVICES="with-mongo" ;;
                *) COMPOSE_SERVICES="standard" ;;
            esac
            ;;
        "nodejs-ai")
            echo "  1) Node.js + PostgreSQL + Redis"
            echo "  2) Node.js + MongoDB + Redis"
            echo "  3) Node.js + PostgreSQL + MongoDB + Redis (full stack)"
            read -p "Enter choice (1-3): " SERVICE_CHOICE
            case $SERVICE_CHOICE in
                1) COMPOSE_SERVICES="postgres-stack" ;;
                2) COMPOSE_SERVICES="mongo-stack" ;;
                3) COMPOSE_SERVICES="full-stack" ;;
                *) COMPOSE_SERVICES="postgres-stack" ;;
            esac
            ;;
        "fullstack-ai")
            echo "  1) Standard (PostgreSQL + MongoDB + Redis)"
            echo "  2) With messaging (+ RabbitMQ)"
            echo "  3) Full platform (+ Elasticsearch + MinIO + RabbitMQ)"
            read -p "Enter choice (1-3): " SERVICE_CHOICE
            case $SERVICE_CHOICE in
                1) COMPOSE_SERVICES="standard" ;;
                2) COMPOSE_SERVICES="with-messaging" ;;
                3) COMPOSE_SERVICES="full-platform" ;;
                *) COMPOSE_SERVICES="standard" ;;
            esac
            ;;
    esac
fi

# Create project
echo ""
echo -e "${YELLOW}🔨 Creating project at $PROJECT_PATH...${NC}"

mkdir -p "$PROJECT_PATH"

# Setup based on compose choice
if [ "$USE_COMPOSE" = true ]; then
    echo -e "${CYAN}📦 Setting up Docker Compose environment...${NC}"

    # Create .devcontainer directory
    mkdir -p "$PROJECT_PATH/.devcontainer"

    # Copy appropriate Docker Compose file
    case $TEMPLATE in
        "base")
            cp "$TEMPLATES_DIR/compose/base-stack.yml" "$PROJECT_PATH/docker-compose.yml"
            ;;
        "python-ai")
            cp "$TEMPLATES_DIR/compose/python-stack.yml" "$PROJECT_PATH/docker-compose.yml"
            cp "$TEMPLATES_DIR/compose/Dockerfile.python" "$PROJECT_PATH/.devcontainer/Dockerfile"
            ;;
        "nodejs-ai")
            cp "$TEMPLATES_DIR/compose/nodejs-stack.yml" "$PROJECT_PATH/docker-compose.yml"
            cp "$TEMPLATES_DIR/compose/Dockerfile.nodejs" "$PROJECT_PATH/.devcontainer/Dockerfile"
            ;;
        "fullstack-ai")
            cp "$TEMPLATES_DIR/compose/fullstack-stack.yml" "$PROJECT_PATH/docker-compose.yml"
            if [ -f "$TEMPLATES_DIR/$TEMPLATE/.devcontainer/Dockerfile" ]; then
                cp "$TEMPLATES_DIR/$TEMPLATE/.devcontainer/Dockerfile" "$PROJECT_PATH/.devcontainer/Dockerfile"
            else
                # Create a combined Dockerfile for fullstack
                cat > "$PROJECT_PATH/.devcontainer/Dockerfile" << 'EOF'
FROM mcr.microsoft.com/devcontainers/python:3.11-bookworm

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install Python packages
RUN pip install --no-cache-dir \
    black flake8 pytest ipython \
    pandas numpy requests python-dotenv \
    psycopg2-binary redis sqlalchemy alembic \
    fastapi uvicorn celery

# Install Node.js packages globally
RUN npm install -g typescript tsx nodemon pm2 pnpm

# Install database clients
RUN apt-get update && apt-get install -y \
    postgresql-client \
    mongodb-clients \
    redis-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
EOF
            fi
            ;;
    esac

    # Create compose-enabled devcontainer.json
    cat > "$PROJECT_PATH/.devcontainer/devcontainer.json" << EOF
{
  "name": "$PROJECT_NAME",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",

  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {},
    "ghcr.io/devcontainers/features/git:1": {}
  },

  "customizations": {
    "vscode": {
      "extensions": [
        "ms-vscode-remote.remote-containers",
        "ms-azuretools.vscode-docker",
        "editorconfig.editorconfig",
        "eamodio.gitlens"
EOF

    # Add template-specific extensions
    case $TEMPLATE in
        "python-ai")
            cat >> "$PROJECT_PATH/.devcontainer/devcontainer.json" << 'EOF',
        "ms-python.python",
        "ms-python.vscode-pylance",
        "ms-python.debugpy"
EOF
            ;;
        "nodejs-ai")
            cat >> "$PROJECT_PATH/.devcontainer/devcontainer.json" << 'EOF',
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "prisma.prisma"
EOF
            ;;
        "fullstack-ai")
            cat >> "$PROJECT_PATH/.devcontainer/devcontainer.json" << 'EOF',
        "ms-python.python",
        "ms-python.vscode-pylance",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "prisma.prisma"
EOF
            ;;
    esac

    # Complete devcontainer.json
    cat >> "$PROJECT_PATH/.devcontainer/devcontainer.json" << 'EOF'
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "bash",
        "editor.formatOnSave": true
      }
    }
  },

  "forwardPorts": [3000, 5000, 5432, 6379, 8000, 8080],

  "postCreateCommand": "echo 'Container ready!'",

  "remoteUser": "vscode"
}
EOF

    # Create .env file template
    cat > "$PROJECT_PATH/.env.example" << EOF
# Database
DATABASE_URL=postgresql://devuser:devpass@postgres:5432/devdb

# Redis
REDIS_URL=redis://redis:6379

# Node environment
NODE_ENV=development

# Python environment
PYTHONDONTWRITEBYTECODE=1
PYTHONUNBUFFERED=1
EOF

    # Create docker-compose override for development
    cat > "$PROJECT_PATH/docker-compose.override.yml" << EOF
# Local development overrides
# This file is automatically loaded by docker-compose
version: '3.8'

services:
  app:
    volumes:
      # Add any additional local mounts here
      - ~/.config/claude:/home/vscode/.config/claude:ro
EOF

else
    # Standard non-compose setup
    echo -e "${CYAN}📦 Setting up standard Dev Container...${NC}"
    cp -r "$TEMPLATES_DIR/$TEMPLATE/.devcontainer" "$PROJECT_PATH/"
fi

# Initialize git
cd "$PROJECT_PATH"
git init

# Create comprehensive .gitignore
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
*.pyc
__pycache__/
.venv/
venv/
env/
.Python

# Environment
.env
.env.local
.env.*.local
!.env.example

# IDE
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# Testing
coverage/
.coverage
htmlcov/
.pytest_cache/
.tox/

# Build
dist/
build/
*.egg-info/
.cache/

# Docker
docker-compose.override.yml
!docker-compose.override.yml.example
EOF

# Create README
if [ "$USE_COMPOSE" = true ]; then
    cat > README.md << EOF
# $PROJECT_NAME

Development environment powered by VS Code Dev Containers with Docker Compose.

## Architecture

This project uses Docker Compose to orchestrate multiple services:
- **app**: Main development container
EOF

    # Add service descriptions based on template
    case $COMPOSE_SERVICES in
        *db*|*postgres*|standard|full*)
            echo "- **postgres**: PostgreSQL database" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *mongo*)
            echo "- **mongodb**: MongoDB NoSQL database" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *cache*|*redis*|standard|full*)
            echo "- **redis**: Redis cache and message broker" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *rabbit*|*messaging*)
            echo "- **rabbitmq**: Message queue service" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *elastic*|full-platform)
            echo "- **elasticsearch**: Full-text search engine" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *minio*|full-platform)
            echo "- **minio**: S3-compatible object storage" >> README.md
            ;;
    esac

    cat >> README.md << 'EOF'

## Getting Started

1. Clone this repository
2. Copy `.env.example` to `.env` and configure
3. Open in VS Code: `code .`
4. When prompted, click "Reopen in Container"
5. Wait for all services to start
6. Start developing!

## Docker Compose Commands

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f [service-name]

# Stop all services
docker-compose down

# Stop and remove volumes (fresh start)
docker-compose down -v

# Run with specific profiles (e.g., tools)
docker-compose --profile tools up -d

# Execute commands in app container
docker-compose exec app bash
```

## Service URLs

- Application: http://localhost:3000 (frontend) / http://localhost:8000 (backend)
EOF

    # Add service URLs based on what's included
    case $COMPOSE_SERVICES in
        *db*|*postgres*|standard|full*)
            echo "- PostgreSQL: localhost:5432 (user: devuser, pass: devpass)" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *mongo*)
            echo "- MongoDB: localhost:27017" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *cache*|*redis*|standard|full*)
            echo "- Redis: localhost:6379" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *rabbit*|*messaging*)
            echo "- RabbitMQ Management: http://localhost:15672 (guest/guest)" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *elastic*|full-platform)
            echo "- Elasticsearch: http://localhost:9200" >> README.md
            echo "- Kibana: http://localhost:5601 (with --profile tools)" >> README.md
            ;;
    esac
    case $COMPOSE_SERVICES in
        *minio*|full-platform)
            echo "- MinIO Console: http://localhost:9001 (minioadmin/minioadmin)" >> README.md
            ;;
    esac

    cat >> README.md << 'EOF'

## Features

- Multi-service orchestration with Docker Compose
- Isolated development environment
- AI coding assistants (Claude/Gemini)
- Project-specific VS Code extensions
- Consistent environment across team members
- Hot reloading for development
- Persistent data volumes

## Configuration

- Docker Compose: `docker-compose.yml`
- Dev Container: `.devcontainer/devcontainer.json`
- Environment variables: `.env` (copy from `.env.example`)
- Local overrides: `docker-compose.override.yml`
EOF

else
    # Standard README for non-compose setup
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
fi

echo -e "${GREEN}✅ Project created${NC}"
echo ""

# Create initial project structure based on template
if [ "$USE_COMPOSE" = true ]; then
    case $TEMPLATE in
        "python-ai")
            mkdir -p "$PROJECT_PATH"/{app,tests,scripts}
            cat > "$PROJECT_PATH/app/__init__.py" << 'EOF'
"""Main application package."""
__version__ = "0.1.0"
EOF
            cat > "$PROJECT_PATH/requirements.txt" << 'EOF'
# Core dependencies
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
pydantic>=2.0.0
python-dotenv>=1.0.0

# Database
sqlalchemy>=2.0.0
psycopg2-binary>=2.9.0
alembic>=1.12.0

# Redis
redis>=5.0.0
celery>=5.3.0

# Testing
pytest>=7.4.0
pytest-cov>=4.1.0
pytest-asyncio>=0.21.0

# Development
black>=23.0.0
flake8>=6.0.0
ipython>=8.0.0
EOF
            ;;
        "nodejs-ai")
            mkdir -p "$PROJECT_PATH"/{src,tests,scripts}
            cat > "$PROJECT_PATH/package.json" << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Node.js application with Docker Compose",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "lint": "eslint src/",
    "format": "prettier --write ."
  },
  "dependencies": {
    "express": "^4.18.0",
    "dotenv": "^16.0.0",
    "pg": "^8.11.0",
    "redis": "^4.6.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.0",
    "jest": "^29.0.0",
    "eslint": "^8.0.0",
    "prettier": "^3.0.0"
  }
}
EOF
            cat > "$PROJECT_PATH/src/index.js" << 'EOF'
const express = require('express');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({ message: 'Hello from Docker Compose!' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
EOF
            ;;
        "fullstack-ai")
            mkdir -p "$PROJECT_PATH"/{backend,frontend,shared,tests}
            echo "# Backend API" > "$PROJECT_PATH/backend/README.md"
            echo "# Frontend Application" > "$PROJECT_PATH/frontend/README.md"
            ;;
    esac
fi

# Offer Stagehand setup for applicable templates
if [[ "$TEMPLATE" == "nodejs-ai" || "$TEMPLATE" == "fullstack-ai" || "$TEMPLATE" == "stagehand-testing" ]]; then
    read -p "Setup Stagehand browser testing? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🎭 Setting up Stagehand...${NC}"
        "$SCRIPT_DIR/setup-stagehand.sh" "$PROJECT_PATH"
        echo ""
    fi
fi

# Offer GitHub integration
read -p "Setup GitHub repository? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}🔗 Setting up GitHub integration...${NC}"
    "$SCRIPT_DIR/github-integration.sh" "$PROJECT_PATH"
    echo ""
fi

# Offer to open in VS Code
read -p "Open in VS Code now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    code "$PROJECT_PATH"
    echo ""
    if [ "$USE_COMPOSE" = true ]; then
        echo -e "${GREEN}💡 VS Code opened. Click 'Reopen in Container' when prompted.${NC}"
        echo -e "${CYAN}   The Dev Container will automatically start all Docker Compose services.${NC}"
    else
        echo -e "${GREEN}💡 VS Code opened. Click 'Reopen in Container' when prompted.${NC}"
    fi
else
    echo -e "${CYAN}💡 To open later: cd $PROJECT_PATH && code .${NC}"
fi

echo ""
echo -e "${GREEN}✨ Setup complete!${NC}"
echo ""
echo -e "${CYAN}📚 Next steps:${NC}"

if [ "$USE_COMPOSE" = true ]; then
    echo "  1. Copy .env.example to .env and configure"
    echo "  2. Open in VS Code and reopen in container"
    echo "  3. Services will start automatically"
    echo "  4. Check service health: docker-compose ps"

    # Add template-specific instructions
    case $TEMPLATE in
        "python-ai")
            echo "  5. Install Python dependencies: pip install -r requirements.txt"
            echo "  6. Run database migrations: alembic upgrade head"
            ;;
        "nodejs-ai")
            echo "  5. Install Node dependencies: npm install"
            echo "  6. Start development server: npm run dev"
            ;;
        "fullstack-ai")
            echo "  5. Install dependencies in both backend/ and frontend/"
            echo "  6. Start both servers (check README for commands)"
            ;;
    esac
else
    echo "  1. Configure API keys for AI assistants (if needed)"
    if [[ "$TEMPLATE" == "stagehand-testing" ]] || [[ -f "$PROJECT_PATH/tests/stagehand/run-tests.js" ]]; then
        echo "  2. Add ANTHROPIC_API_KEY to .env file"
        echo "  3. Run tests: npm run test:stagehand"
        echo "  4. See STAGEHAND_GUIDE.md for usage details"
    else
        echo "  2. Customize .devcontainer/devcontainer.json"
        echo "  3. Add project-specific VS Code extensions"
        echo "  4. Commit .devcontainer to version control"
    fi
fi

echo ""
echo -e "${BLUE}🐳 Docker Compose Tips:${NC}"
echo "  • View logs: docker-compose logs -f [service]"
echo "  • Restart service: docker-compose restart [service]"
echo "  • Fresh start: docker-compose down -v && docker-compose up -d"
echo "  • Shell access: docker-compose exec app bash"
echo ""