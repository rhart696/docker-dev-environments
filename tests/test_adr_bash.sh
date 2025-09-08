#!/bin/bash

# Test Suite for ADR Bash Scripts
# These tests SHOULD have been written BEFORE the implementation
# This is a TDD violation that our hooks should have caught!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
test_start() {
    echo -e "${YELLOW}TEST: $1${NC}"
}

test_pass() {
    echo -e "${GREEN}  ✅ PASS${NC}"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}  ❌ FAIL: $1${NC}"
    ((TESTS_FAILED++))
}

# Setup test environment
setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    mkdir -p docs/adr scripts
    cp /home/ichardart/active-projects/docker-dev-environments/scripts/create-adr.sh scripts/
    chmod +x scripts/create-adr.sh
}

# Cleanup
cleanup() {
    cd /
    rm -rf "$TEST_DIR"
}

# RED Test 1: Script should create ADR file
test_creates_adr_file() {
    test_start "Should create ADR file with correct name"
    
    # Act
    ./scripts/create-adr.sh "Test Decision" 2>/dev/null
    
    # Assert
    if [ -f "docs/adr/0001-test-decision.md" ]; then
        test_pass
    else
        test_fail "ADR file not created"
    fi
}

# RED Test 2: Should use sequential numbering
test_sequential_numbering() {
    test_start "Should use sequential numbering"
    
    # Create first ADR
    ./scripts/create-adr.sh "First Decision" 2>/dev/null
    ./scripts/create-adr.sh "Second Decision" 2>/dev/null
    
    # Assert
    if [ -f "docs/adr/0001-first-decision.md" ] && [ -f "docs/adr/0002-second-decision.md" ]; then
        test_pass
    else
        test_fail "Sequential numbering failed"
    fi
}

# RED Test 3: Should include required sections
test_includes_required_sections() {
    test_start "Should include all required sections"
    
    # Create ADR
    ./scripts/create-adr.sh "Complete ADR" 2>/dev/null
    
    # Check for required sections
    content=$(cat docs/adr/0001-complete-adr.md)
    
    if [[ "$content" == *"## Context"* ]] && \
       [[ "$content" == *"## Decision"* ]] && \
       [[ "$content" == *"## Consequences"* ]] && \
       [[ "$content" == *"## Alternatives Considered"* ]]; then
        test_pass
    else
        test_fail "Missing required sections"
    fi
}

# RED Test 4: Should update README index
test_updates_readme_index() {
    test_start "Should update README index"
    
    # Create README
    cat > docs/adr/README.md << 'EOF'
# ADRs

## Index

| ADR | Title | Status | Date | Tags |
|-----|-------|--------|------|------|

## Creating New ADRs
EOF
    
    # Create ADR
    ./scripts/create-adr.sh "Indexed Decision" 2>/dev/null
    
    # Check if README was updated
    if grep -q "ADR-0001.*Indexed Decision" docs/adr/README.md; then
        test_pass
    else
        test_fail "README index not updated"
    fi
}

# RED Test 5: Should handle spaces in title
test_handles_spaces_in_title() {
    test_start "Should handle spaces and special characters in title"
    
    # Create ADR with complex title
    ./scripts/create-adr.sh "Complex Title With Spaces & Special Chars!" 2>/dev/null
    
    # Check if file created with sanitized name
    if ls docs/adr/0001-complex-title-with-spaces--special-chars.md 2>/dev/null; then
        test_pass
    else
        test_fail "Failed to handle special characters"
    fi
}

# RED Test 6: Should set correct date
test_sets_current_date() {
    test_start "Should set current date in ADR"
    
    # Create ADR
    ./scripts/create-adr.sh "Dated Decision" 2>/dev/null
    
    # Check for today's date
    today=$(date +%Y-%m-%d)
    if grep -q "Date: $today" docs/adr/0001-dated-decision.md; then
        test_pass
    else
        test_fail "Incorrect date in ADR"
    fi
}

# RED Test 7: Should accept status parameter
test_accepts_status_parameter() {
    test_start "Should accept status parameter"
    
    # Create ADR with status
    ./scripts/create-adr.sh "Status Test" "Accepted" 2>/dev/null
    
    # Check status
    if grep -q "Status: Accepted" docs/adr/0001-status-test.md; then
        test_pass
    else
        test_fail "Status parameter not applied"
    fi
}

# RED Test 8: Should accept tags parameter
test_accepts_tags_parameter() {
    test_start "Should accept tags parameter"
    
    # Create ADR with tags
    ./scripts/create-adr.sh "Tagged Decision" "Proposed" "testing,architecture" 2>/dev/null
    
    # Check tags
    if grep -q "Tags: testing,architecture" docs/adr/0001-tagged-decision.md; then
        test_pass
    else
        test_fail "Tags parameter not applied"
    fi
}

# Main test runner
main() {
    echo -e "${YELLOW}================================${NC}"
    echo -e "${YELLOW}   ADR Bash Script Tests${NC}"
    echo -e "${YELLOW}================================${NC}"
    echo ""
    echo -e "${RED}⚠️  These tests violate TDD - they were written AFTER implementation!${NC}"
    echo ""
    
    # Run tests
    trap cleanup EXIT
    
    setup
    test_creates_adr_file
    
    setup
    test_sequential_numbering
    
    setup
    test_includes_required_sections
    
    setup
    test_updates_readme_index
    
    setup
    test_handles_spaces_in_title
    
    setup
    test_sets_current_date
    
    setup
    test_accepts_status_parameter
    
    setup
    test_accepts_tags_parameter
    
    # Summary
    echo ""
    echo -e "${YELLOW}================================${NC}"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed${NC}"
        echo -e "${YELLOW}BUT: This violates TDD - tests should have been written first!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

main