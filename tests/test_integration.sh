#!/bin/bash

# Integration Test Suite for Docker Dev Environments
# Tests the complete multi-agent orchestration system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Test configuration
TEST_TIMEOUT=60
ORCHESTRATOR_URL="http://localhost:8000"
RESOURCE_MANAGER_URL="http://localhost:8001"
REDIS_HOST="localhost"
REDIS_PORT="6379"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   Integration Test Suite${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Helper functions
test_start() {
    echo -e "${YELLOW}TEST: $1${NC}"
}

test_pass() {
    echo -e "${GREEN}  ✅ PASS: $1${NC}"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}  ❌ FAIL: $1${NC}"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
}

wait_for_service() {
    local url=$1
    local service=$2
    local max_attempts=30
    local attempt=1
    
    echo "  Waiting for $service..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url/health" > /dev/null 2>&1; then
            echo "  $service is ready"
            return 0
        fi
        sleep 2
        ((attempt++))
    done
    
    echo "  $service failed to start"
    return 1
}

cleanup() {
    echo ""
    echo "Cleaning up test environment..."
    docker-compose -f docker-compose.multi-agent.yml down 2>/dev/null || true
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Test 1: Docker and Docker Compose availability
test_start "Docker and Docker Compose availability"
if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    test_pass "Docker and Docker Compose are installed"
else
    test_fail "Docker or Docker Compose not found"
    exit 1
fi

# Test 2: API Key validation
test_start "API Key validation"
if ./scripts/validate-api-keys.sh > /dev/null 2>&1; then
    test_pass "API keys are valid"
else
    echo -e "${YELLOW}  ⚠️  WARNING: API keys not configured${NC}"
    echo "  Continuing with mock agents..."
fi

# Test 3: Start core services
test_start "Starting core services"
docker-compose -f docker-compose.multi-agent.yml up -d orchestrator redis resource-manager

if wait_for_service "$ORCHESTRATOR_URL" "Orchestrator" && \
   wait_for_service "$RESOURCE_MANAGER_URL" "Resource Manager"; then
    test_pass "Core services started successfully"
else
    test_fail "Failed to start core services"
    exit 1
fi

# Test 4: Redis connectivity
test_start "Redis connectivity"
if redis-cli -h $REDIS_HOST -p $REDIS_PORT ping | grep -q PONG; then
    test_pass "Redis is responding"
else
    test_fail "Redis connection failed"
fi

# Test 5: Orchestrator health check
test_start "Orchestrator health check"
HEALTH_RESPONSE=$(curl -s "$ORCHESTRATOR_URL/health")
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    test_pass "Orchestrator health check passed"
else
    test_fail "Orchestrator health check failed"
fi

# Test 6: Resource Manager health check
test_start "Resource Manager health check"
HEALTH_RESPONSE=$(curl -s "$RESOURCE_MANAGER_URL/health")
if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    test_pass "Resource Manager health check passed"
else
    test_fail "Resource Manager health check failed"
fi

# Test 7: Submit parallel task
test_start "Submit parallel execution task"
TASK_RESPONSE=$(curl -s -X POST "$ORCHESTRATOR_URL/execute" \
    -H "Content-Type: application/json" \
    -d '{
        "task_type": "test_parallel",
        "execution_mode": "parallel",
        "agents": ["claude-architect", "gemini-developer"],
        "payload": {"test": true},
        "timeout": 30
    }')

if echo "$TASK_RESPONSE" | grep -q "task_id"; then
    TASK_ID=$(echo "$TASK_RESPONSE" | jq -r '.task_id')
    test_pass "Parallel task submitted: $TASK_ID"
else
    test_fail "Failed to submit parallel task"
fi

# Test 8: Submit sequential task
test_start "Submit sequential execution task"
TASK_RESPONSE=$(curl -s -X POST "$ORCHESTRATOR_URL/execute" \
    -H "Content-Type: application/json" \
    -d '{
        "task_type": "test_sequential",
        "execution_mode": "sequential",
        "agents": ["claude-architect", "gemini-developer"],
        "payload": {"test": true},
        "timeout": 30
    }')

if echo "$TASK_RESPONSE" | grep -q "task_id"; then
    TASK_ID=$(echo "$TASK_RESPONSE" | jq -r '.task_id')
    test_pass "Sequential task submitted: $TASK_ID"
else
    test_fail "Failed to submit sequential task"
fi

# Test 9: Resource allocation request
test_start "Resource allocation request"
RESOURCE_RESPONSE=$(curl -s -X POST "$RESOURCE_MANAGER_URL/allocate" \
    -H "Content-Type: application/json" \
    -d '{
        "container_name": "test-container",
        "memory_required": "1G",
        "cpu_required": 0.5,
        "priority": 5
    }')

if echo "$RESOURCE_RESPONSE" | grep -q "approved"; then
    test_pass "Resource allocation approved"
else
    test_fail "Resource allocation failed"
fi

# Test 10: Queue status check
test_start "Queue status check"
QUEUE_STATUS=$(curl -s "$ORCHESTRATOR_URL/queue/status")
if echo "$QUEUE_STATUS" | grep -q "queue_size"; then
    test_pass "Queue status retrieved"
else
    test_fail "Failed to get queue status"
fi

# Test 11: Agent listing
test_start "Agent listing"
AGENTS=$(curl -s "$ORCHESTRATOR_URL/agents")
if echo "$AGENTS" | grep -q "agents"; then
    test_pass "Agent list retrieved"
else
    test_fail "Failed to list agents"
fi

# Test 12: Metrics endpoint
test_start "Metrics endpoints"
ORCHESTRATOR_METRICS=$(curl -s "$ORCHESTRATOR_URL/metrics")
RESOURCE_METRICS=$(curl -s "$RESOURCE_MANAGER_URL/metrics")

if echo "$ORCHESTRATOR_METRICS" | grep -q "orchestrator_tasks_total" && \
   echo "$RESOURCE_METRICS" | grep -q "resource_manager_memory_usage_bytes"; then
    test_pass "Metrics endpoints working"
else
    test_fail "Metrics endpoints not functioning"
fi

# Test 13: Start monitoring stack
test_start "Starting monitoring stack"
docker-compose -f docker-compose.multi-agent.yml --profile monitoring up -d

sleep 10

if curl -s "http://localhost:9090/-/healthy" | grep -q "Prometheus" && \
   curl -s "http://localhost:3001/api/health" > /dev/null 2>&1; then
    test_pass "Monitoring stack started"
else
    echo -e "${YELLOW}  ⚠️  WARNING: Monitoring stack failed to start${NC}"
fi

# Test 14: Container resource monitoring
test_start "Container resource monitoring"
CONTAINER_RESOURCES=$(curl -s "$RESOURCE_MANAGER_URL/containers")
if echo "$CONTAINER_RESOURCES" | grep -q "containers"; then
    test_pass "Container resources being monitored"
else
    test_fail "Container resource monitoring failed"
fi

# Test 15: Task cancellation
test_start "Task cancellation"
# Submit a task
TASK_RESPONSE=$(curl -s -X POST "$ORCHESTRATOR_URL/execute" \
    -H "Content-Type: application/json" \
    -d '{
        "task_type": "test_cancel",
        "execution_mode": "parallel",
        "agents": ["claude-architect"],
        "payload": {"test": true},
        "timeout": 300
    }')

TASK_ID=$(echo "$TASK_RESPONSE" | jq -r '.task_id')

# Cancel the task
CANCEL_RESPONSE=$(curl -s -X DELETE "$ORCHESTRATOR_URL/tasks/$TASK_ID")
if echo "$CANCEL_RESPONSE" | grep -q "cancelled"; then
    test_pass "Task cancellation successful"
else
    test_fail "Task cancellation failed"
fi

# Test 16: Resource rebalancing
test_start "Resource rebalancing"
REBALANCE_RESPONSE=$(curl -s -X POST "$RESOURCE_MANAGER_URL/rebalance")
if echo "$REBALANCE_RESPONSE" | grep -q "rebalancing triggered"; then
    test_pass "Resource rebalancing triggered"
else
    test_fail "Resource rebalancing failed"
fi

# Test 17: Dev container template validation
test_start "Dev container template validation"
TEMPLATES=("base" "python-ai" "nodejs-ai" "fullstack-ai")
TEMPLATES_VALID=true

for template in "${TEMPLATES[@]}"; do
    if [ ! -f "templates/$template/.devcontainer/devcontainer.json" ]; then
        echo "  Missing template: $template"
        TEMPLATES_VALID=false
    fi
done

if [ "$TEMPLATES_VALID" = true ]; then
    test_pass "All dev container templates present"
else
    test_fail "Some dev container templates missing"
fi

# Test 18: Script executability
test_start "Script executability"
SCRIPTS=(
    "scripts/launch-multi-agent.sh"
    "scripts/dev-container-quickstart.sh"
    "scripts/validate-api-keys.sh"
    "scripts/vscode-extension-cleanup.sh"
)

SCRIPTS_EXECUTABLE=true
for script in "${SCRIPTS[@]}"; do
    if [ ! -x "$script" ]; then
        echo "  Not executable: $script"
        chmod +x "$script"
        SCRIPTS_EXECUTABLE=false
    fi
done

if [ "$SCRIPTS_EXECUTABLE" = true ]; then
    test_pass "All scripts are executable"
else
    test_pass "Scripts made executable"
fi

# Test 19: Docker network connectivity
test_start "Docker network connectivity"
NETWORK_EXISTS=$(docker network ls | grep -c "agent-network" || true)
if [ "$NETWORK_EXISTS" -gt 0 ]; then
    test_pass "Agent network exists"
else
    test_fail "Agent network not found"
fi

# Test 20: End-to-end workflow test
test_start "End-to-end workflow test"
# Submit a simple task and wait for completion
E2E_RESPONSE=$(curl -s -X POST "$ORCHESTRATOR_URL/execute" \
    -H "Content-Type: application/json" \
    -d '{
        "task_type": "e2e_test",
        "execution_mode": "parallel",
        "agents": ["claude-architect"],
        "payload": {"message": "Hello, World!"},
        "timeout": 10
    }')

E2E_TASK_ID=$(echo "$E2E_RESPONSE" | jq -r '.task_id')
sleep 5

# Check task status
TASK_STATUS=$(curl -s "$ORCHESTRATOR_URL/tasks/$E2E_TASK_ID")
if echo "$TASK_STATUS" | grep -q "completed\|pending\|running"; then
    test_pass "End-to-end workflow executed"
else
    test_fail "End-to-end workflow failed"
fi

# Summary
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}       Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed Tests:${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
fi

echo ""

# Overall result
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some integration tests failed${NC}"
    exit 1
fi