#!/bin/bash

# Example: Hybrid Refactoring Workflow
# Intelligent routing - parallel analysis, sequential implementation, parallel testing

echo "🔧 Hybrid Refactoring Workflow"
echo "=============================="
echo ""

TARGET_DIR="${1:-/workspace}"

echo "Target directory: $TARGET_DIR"
echo ""

# Start the orchestration system with monitoring
echo "1. Starting orchestration system with monitoring..."
./scripts/launch-multi-agent.sh all

# Wait for services to be ready
echo "2. Waiting for services to initialize..."
sleep 15

# Submit a hybrid refactoring task
echo "3. Submitting hybrid refactoring task..."
curl -X POST http://localhost:8000/execute \
  -H "Content-Type: application/json" \
  -d "{
    \"task_type\": \"refactoring\",
    \"execution_mode\": \"hybrid\",
    \"agents\": [
      \"claude-architect\",
      \"gemini-developer\",
      \"codeium-refactorer\",
      \"claude-tester\"
    ],
    \"payload\": {
      \"target_directory\": \"$TARGET_DIR\",
      \"refactoring_goals\": [
        \"Improve code maintainability\",
        \"Optimize performance bottlenecks\",
        \"Reduce technical debt\",
        \"Enhance security posture\",
        \"Standardize coding patterns\"
      ],
      \"analysis_config\": {
        \"metrics_to_track\": [
          \"cyclomatic_complexity\",
          \"code_duplication\",
          \"dependency_coupling\",
          \"test_coverage\"
        ],
        \"performance_targets\": {
          \"response_time_p95\": \"200ms\",
          \"memory_usage\": \"512MB\",
          \"cpu_usage\": \"50%\"
        }
      },
      \"constraints\": {
        \"preserve_api_compatibility\": true,
        \"maintain_test_coverage\": true,
        \"incremental_changes\": true
      }
    },
    \"priority\": 6,
    \"timeout\": 2400
  }" | jq '.'

echo ""
echo "4. Hybrid workflow initiated with intelligent routing:"
echo ""
echo "   PHASE 1: Parallel Analysis (All agents simultaneously)"
echo "   ├─ Claude Architect: Analyzes architecture & patterns"
echo "   ├─ Gemini Developer: Identifies optimization opportunities"
echo "   ├─ Codeium Refactorer: Detects code smells & duplications"
echo "   └─ Claude Tester: Assesses current test coverage"
echo ""
echo "   PHASE 2: Sequential Refactoring (Based on analysis)"
echo "   ├─ Step 1: Architecture improvements (Claude)"
echo "   ├─ Step 2: Code refactoring (Codeium)"
echo "   └─ Step 3: Performance optimization (Gemini)"
echo ""
echo "   PHASE 3: Parallel Validation"
echo "   ├─ Claude Tester: Runs regression tests"
echo "   ├─ Gemini Developer: Performance benchmarks"
echo "   └─ Claude Architect: Architecture validation"
echo ""

TASK_ID="task_$(date +%s)"

# Monitor phases
echo "5. Monitoring hybrid workflow phases..."
echo ""

# Phase 1: Analysis
echo "   📊 Phase 1: Parallel Analysis"
sleep 10
curl -s http://localhost:8000/tasks/$TASK_ID | jq '.results.analysis'

# Phase 2: Implementation
echo ""
echo "   🔨 Phase 2: Sequential Refactoring"
sleep 15
curl -s http://localhost:8000/tasks/$TASK_ID | jq '.results.refactoring'

# Phase 3: Validation
echo ""
echo "   ✅ Phase 3: Parallel Validation"
sleep 10
curl -s http://localhost:8000/tasks/$TASK_ID | jq '.results.validation'

# Resource usage
echo ""
echo "6. Checking resource utilization..."
curl -s http://localhost:8001/summary | jq '.'

# Metrics
echo ""
echo "7. Performance metrics:"
echo "   - Grafana Dashboard: http://localhost:3001"
echo "   - Prometheus Metrics: http://localhost:9090"
echo "   - Resource Manager: http://localhost:8001/summary"
echo ""

echo "✅ Hybrid refactoring workflow complete!"
echo ""
echo "Results:"
echo "- Analysis reports: /artifacts/refactoring/analysis/"
echo "- Refactored code: /artifacts/refactoring/code/"
echo "- Test results: /artifacts/refactoring/tests/"
echo "- Performance benchmarks: /artifacts/refactoring/benchmarks/"