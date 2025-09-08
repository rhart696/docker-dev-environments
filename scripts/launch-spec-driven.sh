#!/bin/bash

# Launch Spec-Driven Development Workflow
# Integrates persistence service with multi-agent orchestration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.multi-agent.yml"
SPEC_DIR="./specs"
WORKSPACE_DIR="./workspace"

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}    Spec-Driven Development Workflow${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Function to create a new specification
create_spec() {
    local SPEC_NAME=$1
    local FEATURE_NAME=$2
    
    echo -e "${YELLOW}Creating specification: ${SPEC_NAME}${NC}"
    
    cat > "${SPEC_DIR}/${SPEC_NAME}.yaml" << EOF
feature:
  name: "${FEATURE_NAME}"
  type: "feature"
  description: "Auto-generated specification for ${FEATURE_NAME}"

outputs:
  - path: "tests/test_${SPEC_NAME}.py"
    type: "test"
    phase: "red"
    required_elements:
      - "def test_"
      
  - path: "src/${SPEC_NAME}.py"
    type: "implementation"
    phase: "green"
    required_elements:
      - "class"
      
validation:
  coverage_minimum: 80
  linting: "strict"
EOF
    
    echo -e "${GREEN}✅ Specification created: ${SPEC_DIR}/${SPEC_NAME}.yaml${NC}"
}

# Function to launch persistence service
launch_persistence() {
    echo -e "${YELLOW}Starting persistence service...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d persistence-service
    
    # Wait for service to be ready
    echo -e "${YELLOW}Waiting for persistence service to be ready...${NC}"
    for i in {1..30}; do
        if curl -s http://localhost:5001/status > /dev/null; then
            echo -e "${GREEN}✅ Persistence service is ready${NC}"
            break
        fi
        sleep 1
    done
}

# Function to launch agents with spec
launch_spec_agents() {
    local SPEC_NAME=$1
    
    echo -e "${YELLOW}Launching agents for spec: ${SPEC_NAME}${NC}"
    
    # Start core services
    docker-compose -f "$COMPOSE_FILE" up -d orchestrator redis persistence-service
    
    # Submit spec-driven task
    echo -e "${YELLOW}Submitting spec-driven development task...${NC}"
    
    curl -X POST http://localhost:8000/execute \
        -H "Content-Type: application/json" \
        -d "{
            \"task_type\": \"spec_driven_development\",
            \"execution_mode\": \"sequential\",
            \"agents\": [\"claude-architect\", \"gemini-developer\", \"claude-tester\"],
            \"payload\": {
                \"spec_name\": \"${SPEC_NAME}\",
                \"tdd_mode\": \"enforced\",
                \"persistence_url\": \"http://persistence-service:5000\"
            }
        }"
}

# Function to monitor TDD progress
monitor_tdd() {
    echo -e "${YELLOW}Monitoring TDD workflow progress...${NC}"
    
    while true; do
        # Check for test files (RED phase)
        if [ -f "${WORKSPACE_DIR}/tests/test_*.py" ]; then
            echo -e "${GREEN}✅ RED Phase: Tests created${NC}"
        fi
        
        # Check for implementation files (GREEN phase)
        if [ -f "${WORKSPACE_DIR}/src/*.py" ]; then
            echo -e "${GREEN}✅ GREEN Phase: Implementation created${NC}"
        fi
        
        # Check git commits for refactoring
        if cd "${WORKSPACE_DIR}" && git log --oneline | grep -q "refactor"; then
            echo -e "${GREEN}✅ REFACTOR Phase: Code improved${NC}"
            break
        fi
        
        sleep 5
    done
    
    echo -e "${BLUE}TDD Cycle Complete!${NC}"
}

# Function to validate against spec
validate_spec() {
    local SPEC_NAME=$1
    
    echo -e "${YELLOW}Validating outputs against specification...${NC}"
    
    # Call persistence service validation endpoint
    for file in $(find "${WORKSPACE_DIR}" -type f -name "*.py"); do
        filename=$(basename "$file")
        content=$(cat "$file")
        
        response=$(curl -s -X POST http://localhost:5001/validate \
            -H "Content-Type: application/json" \
            -d "{
                \"filename\": \"$filename\",
                \"content\": \"$content\",
                \"spec_name\": \"${SPEC_NAME}\"
            }")
        
        if echo "$response" | grep -q '"valid":true'; then
            echo -e "${GREEN}✅ Valid: $filename${NC}"
        else
            echo -e "${RED}❌ Invalid: $filename${NC}"
            echo "$response" | jq '.errors'
        fi
    done
}

# Main execution flow
case "$1" in
    "create-spec")
        print_header
        create_spec "$2" "$3"
        ;;
        
    "launch")
        print_header
        launch_persistence
        launch_spec_agents "$2"
        monitor_tdd
        validate_spec "$2"
        ;;
        
    "validate")
        print_header
        validate_spec "$2"
        ;;
        
    "status")
        print_header
        echo -e "${YELLOW}Checking service status...${NC}"
        curl -s http://localhost:5001/status | jq '.'
        ;;
        
    "demo")
        print_header
        echo -e "${BLUE}Running complete spec-driven demo...${NC}"
        
        # Create demo spec
        create_spec "demo_feature" "Demo Feature Implementation"
        
        # Launch services
        launch_persistence
        
        # Create demo files using persistence service
        echo -e "${YELLOW}Creating demo files via persistence service...${NC}"
        
        # Create test file (RED phase)
        curl -X POST http://localhost:5001/save \
            -H "Content-Type: application/json" \
            -d '{
                "filename": "tests/test_demo.py",
                "content": "import pytest\n\ndef test_demo_function():\n    assert True\n",
                "metadata": {
                    "agent": "demo",
                    "spec_name": "demo_feature",
                    "tdd_phase": "red"
                }
            }'
        
        # Create implementation (GREEN phase)
        curl -X POST http://localhost:5001/save \
            -H "Content-Type: application/json" \
            -d '{
                "filename": "src/demo.py",
                "content": "class DemoClass:\n    def demo_method(self):\n        return True\n",
                "metadata": {
                    "agent": "demo",
                    "spec_name": "demo_feature",
                    "tdd_phase": "green"
                }
            }'
        
        echo -e "${GREEN}✅ Demo complete! Check workspace/ for generated files${NC}"
        ;;
        
    *)
        print_header
        echo "Usage: $0 {create-spec|launch|validate|status|demo} [spec-name] [feature-name]"
        echo ""
        echo "Commands:"
        echo "  create-spec <name> <feature>  - Create a new specification"
        echo "  launch <spec-name>            - Launch spec-driven development"
        echo "  validate <spec-name>          - Validate outputs against spec"
        echo "  status                        - Check persistence service status"
        echo "  demo                          - Run a complete demo"
        exit 1
        ;;
esac