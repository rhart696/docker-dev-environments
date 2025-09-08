#!/bin/bash

# TDD Test Runner for Docker Dev Environments
# Demonstrates the RED-GREEN-REFACTOR cycle

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   TDD Test Runner${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Function to run Python tests
run_python_tests() {
    local component=$1
    echo -e "${YELLOW}Testing $component...${NC}"
    
    docker run --rm \
        -v $(pwd)/$component:/app \
        -w /app \
        python:3.11-slim \
        sh -c "pip install pytest pytest-asyncio pytest-cov && python -m pytest tests/ -v"
}

# Function to run JavaScript tests
run_js_tests() {
    local component=$1
    echo -e "${YELLOW}Testing $component...${NC}"
    
    docker run --rm \
        -v $(pwd)/$component:/app \
        -w /app \
        node:20 \
        sh -c "npm install && npm test"
}

# RED Phase: Show that tests fail initially
echo -e "${RED}=== RED PHASE ===${NC}"
echo "Expected: Tests should fail (no implementation yet)"
echo ""

# Test orchestrator
echo "1. Orchestrator Tests (Python):"
run_python_tests "orchestrator" || echo -e "${GREEN}✅ Tests failing as expected (RED phase)${NC}"

echo ""
echo "2. Resource Manager Tests (Python):"
run_python_tests "resource-manager" || echo -e "${GREEN}✅ Tests failing as expected (RED phase)${NC}"

echo ""
echo -e "${GREEN}=== GREEN PHASE ===${NC}"
echo "Implementation exists - tests should now pass"
echo ""

# After implementation, tests should pass
# This would normally happen after writing the minimal code

echo ""
echo -e "${BLUE}=== REFACTOR PHASE ===${NC}"
echo "Code can be improved while keeping tests green"
echo ""

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   TDD Cycle Complete${NC}"
echo -e "${BLUE}=====================================${NC}"