#!/bin/bash

# TDD Automation Script
# Orchestrates the complete TDD workflow with automatic verification

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="${1:-.}"
TEST_FRAMEWORK="${2:-stagehand}"
VERIFICATION_MODE="${3:-manual}"  # manual, automatic, or continuous
OUTPUT_STYLE="${4:-pragmatic_test_driven_developer}"

# Tracking variables
CURRENT_PHASE="RED"
TEST_RESULTS=""
COVERAGE_BASELINE=0
ITERATION_COUNT=0
MAX_ITERATIONS=10

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   TDD Automation System${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo "Project: $PROJECT_DIR"
echo "Framework: $TEST_FRAMEWORK"
echo "Verification: $VERIFICATION_MODE"
echo "Output Style: $OUTPUT_STYLE"
echo ""

# Function to run tests and capture results
run_tests() {
    local test_file="${1:-}"
    local expected_result="${2:-pass}"  # pass or fail
    
    echo -e "${CYAN}Running tests...${NC}"
    
    if [ "$TEST_FRAMEWORK" == "stagehand" ]; then
        TEST_OUTPUT=$(npx stagehand test $test_file 2>&1) || TEST_EXIT_CODE=$?
    elif [ "$TEST_FRAMEWORK" == "playwright" ]; then
        TEST_OUTPUT=$(npx playwright test $test_file 2>&1) || TEST_EXIT_CODE=$?
    elif [ "$TEST_FRAMEWORK" == "jest" ]; then
        TEST_OUTPUT=$(npm test -- $test_file 2>&1) || TEST_EXIT_CODE=$?
    else
        TEST_OUTPUT=$(npm test 2>&1) || TEST_EXIT_CODE=$?
    fi
    
    if [ "$expected_result" == "fail" ]; then
        if [ "${TEST_EXIT_CODE:-0}" -ne 0 ]; then
            echo -e "${GREEN}✅ Tests failing as expected (RED phase)${NC}"
            return 0
        else
            echo -e "${RED}❌ Tests passing but should fail (RED phase)${NC}"
            return 1
        fi
    else
        if [ "${TEST_EXIT_CODE:-0}" -eq 0 ]; then
            echo -e "${GREEN}✅ Tests passing (GREEN phase)${NC}"
            return 0
        else
            echo -e "${RED}❌ Tests failing but should pass (GREEN phase)${NC}"
            echo "$TEST_OUTPUT"
            return 1
        fi
    fi
}

# Function to check test coverage
check_coverage() {
    echo -e "${CYAN}Checking coverage...${NC}"
    
    COVERAGE_OUTPUT=$(npm run test:coverage 2>&1 | grep -E "Statements|Branches|Functions|Lines" | tail -1) || true
    
    # Extract coverage percentage (simplified)
    CURRENT_COVERAGE=$(echo "$COVERAGE_OUTPUT" | grep -oE "[0-9]+\.[0-9]+" | head -1)
    
    if [ -z "$CURRENT_COVERAGE" ]; then
        CURRENT_COVERAGE=0
    fi
    
    echo "Current coverage: ${CURRENT_COVERAGE}%"
    
    if (( $(echo "$CURRENT_COVERAGE < $COVERAGE_BASELINE" | bc -l) )); then
        echo -e "${YELLOW}⚠️  Coverage decreased from ${COVERAGE_BASELINE}% to ${CURRENT_COVERAGE}%${NC}"
        return 1
    else
        echo -e "${GREEN}✅ Coverage maintained or improved${NC}"
        COVERAGE_BASELINE=$CURRENT_COVERAGE
        return 0
    fi
}

# Function to call AI agent for implementation
call_agent() {
    local agent="${1}"
    local task="${2}"
    local context="${3:-}"
    
    echo -e "${MAGENTA}Calling $agent for $task...${NC}"
    
    # Call the orchestrator API
    RESPONSE=$(curl -s -X POST http://localhost:8000/execute \
        -H "Content-Type: application/json" \
        -d "{
            \"task_type\": \"$task\",
            \"execution_mode\": \"single\",
            \"agents\": [\"$agent\"],
            \"payload\": {
                \"phase\": \"$CURRENT_PHASE\",
                \"test_results\": \"$TEST_RESULTS\",
                \"context\": \"$context\",
                \"output_style\": \"$OUTPUT_STYLE\"
            },
            \"timeout\": 300
        }")
    
    TASK_ID=$(echo "$RESPONSE" | jq -r '.task_id')
    
    # Wait for completion
    sleep 5
    
    # Get results
    AGENT_OUTPUT=$(curl -s http://localhost:8000/tasks/$TASK_ID | jq -r '.results')
    
    echo "$AGENT_OUTPUT"
}

# RED Phase: Write failing test
red_phase() {
    echo ""
    echo -e "${RED}=== RED PHASE: Write Failing Test ===${NC}"
    echo ""
    
    if [ "$VERIFICATION_MODE" == "automatic" ]; then
        # Use AI to generate test
        call_agent "tdd-specialist" "generate_failing_test" "$1"
    else
        echo "Please write a failing test for: $1"
        echo "Press Enter when test is written..."
        read
    fi
    
    # Verify test fails
    if run_tests "" "fail"; then
        CURRENT_PHASE="GREEN"
        return 0
    else
        echo -e "${RED}Test must fail before proceeding to GREEN phase${NC}"
        return 1
    fi
}

# GREEN Phase: Make test pass
green_phase() {
    echo ""
    echo -e "${GREEN}=== GREEN PHASE: Make Test Pass ===${NC}"
    echo ""
    
    if [ "$VERIFICATION_MODE" == "automatic" ]; then
        # Use AI to implement minimal code
        call_agent "gemini-developer" "implement_minimal_code" "$TEST_RESULTS"
    else
        echo "Implement minimal code to make the test pass"
        echo "Press Enter when implementation is ready..."
        read
    fi
    
    # Verify test passes
    if run_tests "" "pass"; then
        CURRENT_PHASE="REFACTOR"
        return 0
    else
        echo -e "${RED}Test must pass before proceeding to REFACTOR phase${NC}"
        return 1
    fi
}

# REFACTOR Phase: Improve code
refactor_phase() {
    echo ""
    echo -e "${BLUE}=== REFACTOR PHASE: Improve Code ===${NC}"
    echo ""
    
    # Check current coverage before refactoring
    check_coverage
    
    if [ "$VERIFICATION_MODE" == "automatic" ]; then
        # Use AI to refactor
        call_agent "codeium-refactorer" "refactor_code" "$TEST_RESULTS"
    else
        echo "Refactor code while keeping tests green (optional)"
        echo "Press Enter when refactoring is complete (or skip)..."
        read
    fi
    
    # Verify tests still pass
    if ! run_tests "" "pass"; then
        echo -e "${RED}❌ Refactoring broke tests!${NC}"
        return 1
    fi
    
    # Verify coverage didn't drop
    if ! check_coverage; then
        echo -e "${YELLOW}⚠️  Coverage dropped during refactoring${NC}"
    fi
    
    CURRENT_PHASE="COMPLETE"
    return 0
}

# Continuous mode: Keep running TDD cycles
continuous_mode() {
    echo -e "${CYAN}Running in continuous TDD mode${NC}"
    echo "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        ((ITERATION_COUNT++))
        
        echo -e "${BLUE}--- Iteration $ITERATION_COUNT ---${NC}"
        
        # Get next feature to implement
        NEXT_FEATURE=$(call_agent "claude-architect" "get_next_feature" "")
        
        if [ -z "$NEXT_FEATURE" ] || [ "$NEXT_FEATURE" == "null" ]; then
            echo -e "${GREEN}All features implemented!${NC}"
            break
        fi
        
        echo "Next feature: $NEXT_FEATURE"
        
        # Run TDD cycle
        if red_phase "$NEXT_FEATURE" && green_phase && refactor_phase; then
            echo -e "${GREEN}✅ TDD cycle $ITERATION_COUNT complete${NC}"
        else
            echo -e "${RED}❌ TDD cycle $ITERATION_COUNT failed${NC}"
            
            if [ "$ITERATION_COUNT" -ge "$MAX_ITERATIONS" ]; then
                echo -e "${YELLOW}Maximum iterations reached${NC}"
                break
            fi
        fi
        
        echo ""
        sleep 2
    done
}

# Verification mode: Run with manual checkpoints
verification_mode() {
    echo -e "${CYAN}Running with verification checkpoints${NC}"
    echo ""
    
    # Phase 1: Design
    echo -e "${BLUE}PHASE 1: Design${NC}"
    call_agent "claude-architect" "design_feature" "$1"
    echo "Review the design. Press Enter to continue..."
    read
    
    # Phase 2: Test Specification
    echo -e "${BLUE}PHASE 2: Test Specification${NC}"
    call_agent "tdd-specialist" "write_test_spec" "$1"
    echo "Review the test spec. Press Enter to continue..."
    read
    
    # Phase 3: TDD Implementation
    echo -e "${BLUE}PHASE 3: TDD Implementation${NC}"
    red_phase "$1"
    green_phase
    refactor_phase
    
    # Phase 4: Verification
    echo -e "${BLUE}PHASE 4: Verification${NC}"
    run_tests
    check_coverage
    
    echo -e "${GREEN}✅ Feature implementation complete with verification${NC}"
}

# Main execution logic
main() {
    # Check if orchestrator is running
    if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "${YELLOW}Starting orchestrator...${NC}"
        ./scripts/launch-multi-agent.sh core
        sleep 10
    fi
    
    case "$VERIFICATION_MODE" in
        continuous)
            continuous_mode
            ;;
        automatic)
            echo "Running in automatic mode"
            red_phase "${5:-New feature}"
            green_phase
            refactor_phase
            ;;
        verification)
            verification_mode "${5:-New feature}"
            ;;
        *)  # manual mode
            echo "Running in manual mode"
            red_phase "${5:-New feature}"
            green_phase
            refactor_phase
            ;;
    esac
    
    # Final summary
    echo ""
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}   TDD Session Summary${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo "Iterations completed: $ITERATION_COUNT"
    echo "Final coverage: ${CURRENT_COVERAGE:-N/A}%"
    echo "Final phase: $CURRENT_PHASE"
    
    if [ "$CURRENT_PHASE" == "COMPLETE" ]; then
        echo -e "${GREEN}✅ TDD workflow completed successfully!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  TDD workflow incomplete${NC}"
        exit 1
    fi
}

# Handle interrupts gracefully
trap 'echo -e "\n${YELLOW}TDD session interrupted${NC}"; exit 130' INT TERM

# Run main function
main