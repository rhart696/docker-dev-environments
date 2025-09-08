#!/bin/bash

# Example: Parallel Code Review Workflow
# Multiple agents review code simultaneously from different perspectives

echo "🔍 Parallel Code Review Workflow Example"
echo "========================================"
echo ""

# Start the orchestration system
echo "1. Starting orchestration system..."
./scripts/launch-multi-agent.sh core

# Wait for services to be ready
echo "2. Waiting for services to initialize..."
sleep 10

# Submit a parallel code review task
echo "3. Submitting parallel code review task..."
curl -X POST http://localhost:8000/execute \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "code_review",
    "execution_mode": "parallel",
    "agents": ["claude-architect", "gemini-developer", "claude-tester"],
    "payload": {
      "repository": "/workspace/my-project",
      "pr_number": 123,
      "files": [
        "src/api/handlers.py",
        "src/models/user.py",
        "src/services/auth.py"
      ],
      "review_criteria": {
        "security": true,
        "performance": true,
        "best_practices": true,
        "test_coverage": true
      }
    },
    "priority": 7,
    "timeout": 600
  }' | jq '.'

echo ""
echo "4. Task submitted! The following will happen in parallel:"
echo "   - Claude Architect: Reviews architecture and design patterns"
echo "   - Gemini Developer: Reviews implementation and optimization"
echo "   - Claude Tester: Reviews test coverage and quality"
echo ""

# Get task ID from response (in real usage, parse the JSON response)
TASK_ID="task_$(date +%s)"

echo "5. Monitoring task progress..."
echo "   View task status: curl http://localhost:8000/tasks/$TASK_ID"
echo "   View metrics: http://localhost:3001 (Grafana)"
echo "   View logs: docker-compose -f docker-compose.multi-agent.yml logs -f"
echo ""

# Check task status
sleep 5
echo "6. Checking task status..."
curl -s http://localhost:8000/tasks/$TASK_ID | jq '.'

echo ""
echo "✅ Parallel review workflow initiated!"
echo ""
echo "The agents are now working simultaneously to review your code."
echo "Each agent provides unique insights based on their specialization."