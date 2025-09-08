# Claude Integration Guide for Spec-Driven Development

## Overview

This guide shows how to integrate Claude (or any AI assistant) with our spec-driven persistence service to prevent losing generated code and enforce TDD practices.

## Quick Start

### 1. Start the Persistence Service

```bash
# Using Docker Compose
docker-compose -f docker-compose.multi-agent.yml up -d persistence-service

# Or using the launch script
./scripts/launch-spec-driven.sh demo
```

### 2. Provide Claude with the Save Function

Copy and paste this entire block to Claude at the start of your conversation:

```javascript
// Persistence Service Integration
// This allows me to save files directly to your local machine

const PERSISTENCE_URL = 'http://localhost:5001';
const AGENT_NAME = 'claude';
let currentSpec = null;
let tddPhase = 'red';  // Start with tests

async function saveFile(filename, content, options = {}) {
    const metadata = {
        agent: AGENT_NAME,
        spec_name: currentSpec || options.specName,
        tdd_phase: tddPhase || options.phase,
        timestamp: new Date().toISOString()
    };

    try {
        const response = await fetch(`${PERSISTENCE_URL}/save`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                filename,
                content,
                metadata
            })
        });

        const result = await response.json();
        
        if (response.ok) {
            console.log(`✅ Saved: ${filename} (${result.status})`);
            
            // Auto-advance TDD phase
            if (tddPhase === 'red' && filename.includes('test')) {
                tddPhase = 'green';
                console.log('📝 TDD Phase: GREEN - Write implementation');
            } else if (tddPhase === 'green' && !filename.includes('test')) {
                tddPhase = 'refactor';
                console.log('🔧 TDD Phase: REFACTOR - Improve code');
            }
        } else {
            console.error(`❌ Failed to save ${filename}:`, result);
        }
        
        return result;
    } catch (error) {
        console.error(`Error saving ${filename}:`, error);
        return { success: false, error: error.message };
    }
}

// Helper functions for TDD workflow
async function saveTest(filename, content) {
    tddPhase = 'red';
    return saveFile(filename, content);
}

async function saveImplementation(filename, content) {
    tddPhase = 'green';
    return saveFile(filename, content);
}

async function saveRefactored(filename, content) {
    tddPhase = 'refactor';
    return saveFile(filename, content);
}

// Set the current specification
function setSpec(specName) {
    currentSpec = specName;
    console.log(`📋 Working with spec: ${specName}`);
}

console.log('✅ Persistence service connected!');
console.log('📝 TDD Mode: Enforced');
console.log('🚀 Ready to save files locally with spec validation');

// Instructions for Claude:
// 1. ALWAYS create test files first (TDD red phase)
// 2. Then create implementation files (TDD green phase)
// 3. Finally refactor if needed (TDD refactor phase)
// 4. Use saveFile(filename, content) for all file creation
// 5. Files will be validated against specifications automatically
```

### 3. Request Feature Development

Now you can ask Claude to develop features with automatic file saving:

```
Please create a user authentication system following TDD principles.
Use setSpec('auth-system') first, then:
1. Write comprehensive tests first
2. Implement the code to pass the tests
3. Refactor for quality

Save all files using the saveFile function.
```

## Advanced Usage

### Working with Specifications

1. **Create a specification first:**

```bash
./scripts/launch-spec-driven.sh create-spec auth-system "User Authentication"
```

2. **Tell Claude about the spec:**

```javascript
setSpec('auth-system');
// Now all saved files will be validated against the auth-system spec
```

3. **Claude will automatically:**
   - Save test files first (enforced by TDD mode)
   - Validate outputs against your specification
   - Commit changes to git with meaningful messages
   - Track the TDD cycle progress

### Integration with Multi-Agent System

For multi-agent workflows, each agent can use the persistence service:

```javascript
// Agent-specific configuration
const agentClient = {
    claude: { name: 'claude-architect', role: 'design' },
    gemini: { name: 'gemini-developer', role: 'implement' },
    codeium: { name: 'codeium-refactorer', role: 'refactor' }
};

// Each agent saves with its identity
async function agentSaveFile(filename, content, agentType) {
    return saveFile(filename, content, {
        metadata: { agent: agentClient[agentType].name }
    });
}
```

## Benefits

1. **Never Lose Work**: All generated code is saved immediately
2. **TDD Enforcement**: System ensures tests are written first
3. **Spec Validation**: All outputs validated against specifications
4. **Version Control**: Automatic git commits with context
5. **Multi-Agent Ready**: Supports concurrent agents saving files

## Troubleshooting

### Service Not Responding

```bash
# Check if persistence service is running
docker ps | grep persistence

# Check service logs
docker logs agent-persistence

# Test the service
curl http://localhost:5001/status
```

### Validation Failures

If files fail validation:
1. Check the specification file in `specs/`
2. Ensure required elements are present
3. Verify TDD phase order (tests before implementation)

### CORS Issues

The persistence service includes CORS support. If you still have issues:
1. Ensure you're using localhost:5001
2. Check browser console for specific errors
3. Try using the service from a local HTML file instead of a web app

## Example Conversation with Claude

```
You: I've provided you with a saveFile function. Please use it to create a simple calculator with TDD.

Claude: I'll create a calculator following TDD principles. Let me start by setting up the specification and writing tests first.

[Claude uses setSpec('calculator')]
[Claude calls saveTest('tests/test_calculator.py', ...)]
[Claude calls saveImplementation('src/calculator.py', ...)]
[Claude calls saveRefactored('src/calculator.py', ...)]

You can now find all the files in your workspace/ directory, properly versioned and validated!
```

## Security Notes

- The persistence service only accepts connections from localhost
- Files are saved within the designated workspace directory
- API keys are never saved or logged
- Git commits don't include sensitive information

## Next Steps

1. Explore creating custom specifications for your projects
2. Integrate with CI/CD pipelines using the git history
3. Use the monitoring dashboard to track agent productivity
4. Extend the validation rules for your specific needs