#!/bin/bash

# Example: Sequential Feature Development Workflow
# Agents work in sequence, passing results forward through the pipeline

echo "🚀 Sequential Feature Development Workflow"
echo "=========================================="
echo ""

FEATURE_NAME="${1:-user-authentication}"

echo "Developing feature: $FEATURE_NAME"
echo ""

# Start the orchestration system
echo "1. Starting orchestration system..."
./scripts/launch-multi-agent.sh core

# Wait for services to be ready
echo "2. Waiting for services to initialize..."
sleep 10

# Submit a sequential feature development task
echo "3. Submitting sequential feature development task..."
curl -X POST http://localhost:8000/execute \
  -H "Content-Type: application/json" \
  -d "{
    \"task_type\": \"feature_development\",
    \"execution_mode\": \"sequential\",
    \"agents\": [
      \"claude-architect\",
      \"gemini-developer\",
      \"claude-tester\",
      \"claude-reviewer\"
    ],
    \"payload\": {
      \"feature_name\": \"$FEATURE_NAME\",
      \"requirements\": {
        \"description\": \"Implement JWT-based user authentication with refresh tokens\",
        \"acceptance_criteria\": [
          \"Users can register with email and password\",
          \"Users can login and receive JWT tokens\",
          \"Tokens expire after 1 hour\",
          \"Refresh tokens valid for 7 days\",
          \"Secure password hashing with bcrypt\",
          \"Rate limiting on auth endpoints\"
        ],
        \"tech_stack\": {
          \"backend\": \"Python FastAPI\",
          \"database\": \"PostgreSQL\",
          \"authentication\": \"JWT\",
          \"testing\": \"pytest\"
        }
      },
      \"output_path\": \"/artifacts/features/$FEATURE_NAME\"
    },
    \"priority\": 8,
    \"timeout\": 1800
  }" | jq '.'

echo ""
echo "4. Task submitted! The following pipeline will execute:"
echo ""
echo "   Step 1: Claude Architect"
echo "   └─> Analyzes requirements"
echo "   └─> Designs system architecture"
echo "   └─> Creates component specifications"
echo "   └─> Output: Architecture document & diagrams"
echo ""
echo "   Step 2: Gemini Developer"
echo "   └─> Receives architecture from Step 1"
echo "   └─> Implements the feature"
echo "   └─> Writes production code"
echo "   └─> Output: Implementation files"
echo ""
echo "   Step 3: Claude Tester"
echo "   └─> Receives implementation from Step 2"
echo "   └─> Creates comprehensive test suite"
echo "   └─> Writes unit and integration tests"
echo "   └─> Output: Test files & coverage report"
echo ""
echo "   Step 4: Claude Reviewer"
echo "   └─> Receives all previous outputs"
echo "   └─> Performs final review"
echo "   └─> Suggests improvements"
echo "   └─> Output: Review report & recommendations"
echo ""

# Get task ID from response
TASK_ID="task_$(date +%s)"

echo "5. Monitoring pipeline progress..."
echo "   View task status: curl http://localhost:8000/tasks/$TASK_ID"
echo "   View queue status: curl http://localhost:8000/queue/status"
echo ""

# Monitor progress
for i in {1..4}; do
    sleep 10
    echo "   Checking progress (Step $i/4)..."
    curl -s http://localhost:8000/tasks/$TASK_ID | jq '.status'
done

echo ""
echo "6. Feature development pipeline complete!"
echo "   Artifacts saved to: /artifacts/features/$FEATURE_NAME"
echo ""
echo "   Contents:"
echo "   - architecture.md: System design document"
echo "   - implementation/: Source code files"
echo "   - tests/: Test suite"
echo "   - review.md: Code review report"
echo ""
echo "✅ Sequential feature development workflow complete!"