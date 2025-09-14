#!/bin/bash

# Multi-Agent Launcher Script
# Provides easy commands to launch different agent configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.multi-agent.yml"
WORKSPACE_DIR="./workspace"
ARTIFACTS_DIR="./artifacts"
CONFIG_DIR="./config"
SECRETS_DIR="$HOME/.secrets"

# Functions
print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    Multi-Agent Orchestration System${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose is not installed${NC}"
        exit 1
    fi

    # Check directories
    mkdir -p "$WORKSPACE_DIR" "$ARTIFACTS_DIR" "$CONFIG_DIR" "$SECRETS_DIR"

    # Check for 1Password CLI and use it if available
    if command -v op &> /dev/null && op account get &> /dev/null; then
        echo -e "${GREEN}✅ Using 1Password CLI for secrets${NC}"

        # Export API keys from 1Password
        export CLAUDE_API_KEY=$(op read "op://Private/Anthropic/api_key" 2>/dev/null || echo "")
        export GEMINI_API_KEY=$(op read "op://Private/Gemini/api_key" 2>/dev/null || op read "op://Private/Google Gemini/credential" 2>/dev/null || echo "")
        export GITHUB_TOKEN=$(op read "op://Private/GitHub/token" 2>/dev/null || echo "")
        export CODEIUM_API_KEY=$(op read "op://Private/Codeium/api_key" 2>/dev/null || echo "")

        # Create temporary key files for Docker if keys exist in 1Password
        if [ -n "$CLAUDE_API_KEY" ]; then
            echo "$CLAUDE_API_KEY" > "$SECRETS_DIR/claude_api_key"
            chmod 600 "$SECRETS_DIR/claude_api_key"
        fi

        if [ -n "$GEMINI_API_KEY" ]; then
            echo "$GEMINI_API_KEY" > "$SECRETS_DIR/gemini_api_key"
            chmod 600 "$SECRETS_DIR/gemini_api_key"
        fi
    fi

    # Fall back to manual entry if keys not found
    if [ ! -f "$SECRETS_DIR/claude_api_key" ] && [ -z "$CLAUDE_API_KEY" ]; then
        echo -e "${YELLOW}⚠️  Claude API key not found${NC}"
        echo "  Try: op read \"op://Private/Anthropic/api_key\""
        read -p "Enter Claude API key (or press Enter to skip): " CLAUDE_KEY
        if [ -n "$CLAUDE_KEY" ]; then
            echo "$CLAUDE_KEY" > "$SECRETS_DIR/claude_api_key"
            chmod 600 "$SECRETS_DIR/claude_api_key"
        fi
    fi

    if [ ! -f "$SECRETS_DIR/gemini_api_key" ] && [ -z "$GEMINI_API_KEY" ]; then
        echo -e "${YELLOW}⚠️  Gemini API key not found${NC}"
        echo "  Try: op read \"op://Private/Gemini/api_key\""
        read -p "Enter Gemini API key (or press Enter to skip): " GEMINI_KEY
        if [ -n "$GEMINI_KEY" ]; then
            echo "$GEMINI_KEY" > "$SECRETS_DIR/gemini_api_key"
            chmod 600 "$SECRETS_DIR/gemini_api_key"
        fi
    fi

    echo -e "${GREEN}✅ Prerequisites checked${NC}"
    echo ""
}

launch_core() {
    echo -e "${YELLOW}Launching core services...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d orchestrator redis
    echo -e "${GREEN}✅ Core services started${NC}"
    echo "   Orchestrator: http://localhost:8000"
    echo "   Redis: localhost:6379"
}

launch_parallel_review() {
    echo -e "${YELLOW}Launching parallel code review agents...${NC}"
    docker-compose -f "$COMPOSE_FILE" \
        --profile architects \
        --profile developers \
        --profile testers \
        up -d
    
    echo -e "${GREEN}✅ Parallel review agents started${NC}"
    
    # Submit review task
    echo -e "${YELLOW}Submitting code review task...${NC}"
    curl -X POST http://localhost:8000/execute \
        -H "Content-Type: application/json" \
        -d '{
            "task_type": "code_review",
            "execution_mode": "parallel",
            "agents": ["claude-architect", "gemini-developer", "claude-tester"],
            "payload": {
                "pr_number": 123,
                "repository": "workspace"
            }
        }'
}

launch_sequential_feature() {
    echo -e "${YELLOW}Launching sequential feature development pipeline...${NC}"
    
    FEATURE_NAME="${1:-new-feature}"
    
    docker-compose -f "$COMPOSE_FILE" \
        --profile architects \
        --profile developers \
        --profile testers \
        up -d
    
    echo -e "${GREEN}✅ Sequential pipeline agents started${NC}"
    
    # Submit feature task
    echo -e "${YELLOW}Developing feature: $FEATURE_NAME${NC}"
    curl -X POST http://localhost:8000/execute \
        -H "Content-Type: application/json" \
        -d "{
            \"task_type\": \"feature_development\",
            \"execution_mode\": \"sequential\",
            \"agents\": [\"claude-architect\", \"gemini-developer\", \"claude-tester\"],
            \"payload\": {
                \"feature_name\": \"$FEATURE_NAME\",
                \"requirements\": \"User authentication with JWT\"
            }
        }"
}

launch_hybrid_refactor() {
    echo -e "${YELLOW}Launching hybrid refactoring swarm...${NC}"
    
    docker-compose -f "$COMPOSE_FILE" \
        --profile architects \
        --profile developers \
        --profile refactorers \
        --profile testers \
        up -d
    
    echo -e "${GREEN}✅ Hybrid refactoring agents started${NC}"
    
    # Submit refactor task
    curl -X POST http://localhost:8000/execute \
        -H "Content-Type: application/json" \
        -d '{
            "task_type": "refactoring",
            "execution_mode": "hybrid",
            "agents": ["claude-architect", "gemini-developer", "codeium-refactorer", "claude-tester"],
            "payload": {
                "target": "workspace",
                "focus": ["performance", "maintainability", "security"]
            }
        }'
}

launch_monitoring() {
    echo -e "${YELLOW}Launching monitoring stack...${NC}"
    docker-compose -f "$COMPOSE_FILE" --profile monitoring up -d
    echo -e "${GREEN}✅ Monitoring stack started${NC}"
    echo "   Prometheus: http://localhost:9090"
    echo "   Grafana: http://localhost:3001 (admin/admin)"
    echo "   cAdvisor: http://localhost:8080"
}

stop_all() {
    echo -e "${YELLOW}Stopping all agents...${NC}"
    docker-compose -f "$COMPOSE_FILE" down
    echo -e "${GREEN}✅ All services stopped${NC}"
}

view_logs() {
    SERVICE="${1:-orchestrator}"
    echo -e "${YELLOW}Viewing logs for $SERVICE...${NC}"
    docker-compose -f "$COMPOSE_FILE" logs -f "$SERVICE"
}

check_status() {
    echo -e "${YELLOW}Checking system status...${NC}"
    
    # Check running containers
    echo -e "\n${BLUE}Running Agents:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(agent-|claude-|gemini-|codeium-)" || echo "No agents running"
    
    # Check orchestrator health
    echo -e "\n${BLUE}Orchestrator Status:${NC}"
    curl -s http://localhost:8000/health 2>/dev/null | jq '.' || echo "Orchestrator not responding"
    
    # Check available agents
    echo -e "\n${BLUE}Available Agents:${NC}"
    curl -s http://localhost:8000/agents 2>/dev/null | jq '.agents[].name' || echo "Cannot retrieve agent list"
    
    # Check resource usage
    echo -e "\n${BLUE}Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep -E "(agent-|claude-|gemini-|codeium-)" || echo "No agents to monitor"
}

# Main menu
print_header
check_prerequisites

case "${1:-help}" in
    core)
        launch_core
        ;;
    parallel-review)
        launch_parallel_review
        ;;
    sequential-feature)
        launch_sequential_feature "${2}"
        ;;
    hybrid-refactor)
        launch_hybrid_refactor
        ;;
    monitoring)
        launch_monitoring
        ;;
    stop)
        stop_all
        ;;
    logs)
        view_logs "${2}"
        ;;
    status)
        check_status
        ;;
    all)
        launch_core
        sleep 5
        launch_monitoring
        echo -e "${GREEN}✅ Full system launched${NC}"
        ;;
    *)
        echo "Usage: $0 {command} [options]"
        echo ""
        echo "Commands:"
        echo "  core                    - Launch core orchestrator and Redis"
        echo "  parallel-review         - Launch parallel code review"
        echo "  sequential-feature NAME - Launch sequential feature development"
        echo "  hybrid-refactor        - Launch hybrid refactoring swarm"
        echo "  monitoring             - Launch monitoring stack"
        echo "  all                    - Launch everything"
        echo "  stop                   - Stop all services"
        echo "  logs [SERVICE]         - View logs for a service"
        echo "  status                 - Check system status"
        echo ""
        echo "Examples:"
        echo "  $0 core                           # Start orchestrator"
        echo "  $0 parallel-review                # Run code review"
        echo "  $0 sequential-feature auth-system # Develop auth feature"
        echo "  $0 status                         # Check what's running"
        ;;
esac