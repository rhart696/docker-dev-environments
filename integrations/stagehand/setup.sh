#!/bin/bash

# Stagehand Testing Framework Setup Script
# Integrates Stagehand with the Docker Dev Environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================${NC}"
echo -e "${BLUE}   Stagehand Framework Setup${NC}"
echo -e "${BLUE}==================================${NC}"
echo ""

# Function to check if running in container
check_environment() {
    if [ -f /.dockerenv ]; then
        echo -e "${GREEN}✅ Running in Docker container${NC}"
        IN_CONTAINER=true
    else
        echo -e "${YELLOW}⚠️  Not running in container${NC}"
        IN_CONTAINER=false
    fi
}

# Function to install Stagehand
install_stagehand() {
    echo -e "${YELLOW}Installing Stagehand...${NC}"
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js not found. Installing...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
    fi
    
    # Install Stagehand globally
    npm install -g @browserbasehq/stagehand
    
    # Install Playwright browsers
    npx playwright install
    npx playwright install-deps
    
    echo -e "${GREEN}✅ Stagehand installed${NC}"
}

# Function to create Stagehand configuration
create_stagehand_config() {
    echo -e "${YELLOW}Creating Stagehand configuration...${NC}"
    
    cat > stagehand.config.js << 'EOF'
const { StagehandConfig } = require('@browserbasehq/stagehand');

module.exports = {
  // Use Claude for natural language processing
  llm: {
    provider: 'anthropic',
    model: 'claude-3-opus-20240229',
    apiKey: process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY,
  },
  
  // Browser configuration
  browser: {
    headless: process.env.HEADLESS !== 'false',
    slowMo: parseInt(process.env.SLOW_MO || '0'),
    timeout: parseInt(process.env.TIMEOUT || '30000'),
  },
  
  // Test configuration
  test: {
    retries: parseInt(process.env.TEST_RETRIES || '2'),
    timeout: parseInt(process.env.TEST_TIMEOUT || '60000'),
    parallel: process.env.PARALLEL_TESTS === 'true',
  },
  
  // Browserbase integration (if API key is provided)
  browserbase: process.env.BROWSERBASE_API_KEY ? {
    apiKey: process.env.BROWSERBASE_API_KEY,
    projectId: process.env.BROWSERBASE_PROJECT_ID,
  } : undefined,
  
  // Custom selectors for common UI patterns
  selectors: {
    button: 'button, [role="button"], input[type="button"], input[type="submit"]',
    input: 'input, textarea, [contenteditable="true"]',
    link: 'a, [role="link"]',
    dropdown: 'select, [role="combobox"], [role="listbox"]',
  },
  
  // AI observation settings
  observation: {
    screenshotOnError: true,
    debugMode: process.env.DEBUG === 'true',
    logLevel: process.env.LOG_LEVEL || 'info',
  },
};
EOF
    
    echo -e "${GREEN}✅ Stagehand configuration created${NC}"
}

# Function to create example Stagehand test
create_example_test() {
    echo -e "${YELLOW}Creating example Stagehand test...${NC}"
    
    mkdir -p tests/stagehand
    
    cat > tests/stagehand/example.test.js << 'EOF'
const { Stagehand } = require('@browserbasehq/stagehand');
const { expect } = require('@playwright/test');

describe('Example Stagehand Test', () => {
  let stagehand;
  let page;
  
  beforeEach(async () => {
    stagehand = new Stagehand({
      env: process.env.NODE_ENV || 'test',
    });
    
    page = await stagehand.page();
  });
  
  afterEach(async () => {
    await stagehand.close();
  });
  
  test('should navigate and interact using natural language', async () => {
    // Navigate to the application
    await page.goto('http://localhost:3000');
    
    // Use Stagehand's observe function to "see" the page
    const pageContent = await page.observe('What is on this page?');
    console.log('Page observation:', pageContent);
    
    // Use natural language to interact
    await page.act('Click on the button that says "Get Started"');
    
    // Extract information using natural language
    const headerText = await page.extract('What is the main heading on this page?');
    expect(headerText).toBeTruthy();
    
    // More complex interaction
    await page.act('Fill in the email field with test@example.com');
    await page.act('Fill in the password field with SecurePass123');
    await page.act('Click the login button');
    
    // Verify the result
    const isLoggedIn = await page.observe('Is the user logged in?');
    expect(isLoggedIn).toContain('logged in');
  });
  
  test('should handle complex UI patterns', async () => {
    await page.goto('http://localhost:3000/color-mixer');
    
    // Interact with sliders using natural language
    await page.act('Set the red color slider to 50%');
    await page.act('Set the green color slider to 75%');
    await page.act('Set the blue color slider to 25%');
    
    // Verify the color output
    const colorValue = await page.extract('What is the current RGB color value displayed?');
    console.log('Color value:', colorValue);
    
    // Test color reset
    await page.act('Click the reset button');
    const isReset = await page.observe('Are all sliders set to zero?');
    expect(isReset).toContain('zero');
  });
});
EOF
    
    echo -e "${GREEN}✅ Example test created${NC}"
}

# Function to create TDD helper scripts
create_tdd_helpers() {
    echo -e "${YELLOW}Creating TDD helper scripts...${NC}"
    
    cat > tests/stagehand/tdd-cycle.sh << 'EOF'
#!/bin/bash

# TDD Cycle Runner for Stagehand Tests

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_FILE=${1:-"tests/stagehand/current.test.js"}

echo -e "${RED}=== RED PHASE ===${NC}"
echo "Writing/running failing test..."
npm test -- --testPathPattern="$TEST_FILE" --no-coverage

if [ $? -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Test passed but should fail in RED phase${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Test fails as expected${NC}"
echo ""

echo -e "${GREEN}=== GREEN PHASE ===${NC}"
echo "Implement code to make test pass..."
echo "Press Enter when implementation is ready..."
read

npm test -- --testPathPattern="$TEST_FILE" --no-coverage

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Test still failing${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Test passes!${NC}"
echo ""

echo -e "${BLUE}=== REFACTOR PHASE ===${NC}"
echo "Refactor code while keeping tests green..."
echo "Press Enter when refactoring is complete..."
read

npm test -- --testPathPattern="$TEST_FILE" --coverage

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Tests broken during refactoring${NC}"
    exit 1
fi

echo -e "${GREEN}✅ TDD cycle complete!${NC}"
EOF
    
    chmod +x tests/stagehand/tdd-cycle.sh
    
    echo -e "${GREEN}✅ TDD helper scripts created${NC}"
}

# Function to integrate with Docker Compose
update_docker_compose() {
    echo -e "${YELLOW}Updating Docker Compose configuration...${NC}"
    
    cat >> docker-compose.multi-agent.yml << 'EOF'

  # Stagehand Test Runner Service
  stagehand-runner:
    image: mcr.microsoft.com/playwright:v1.40.0-focal
    container_name: stagehand-runner
    environment:
      - ANTHROPIC_API_KEY_FILE=/run/secrets/claude_api_key
      - BROWSERBASE_API_KEY_FILE=/run/secrets/browserbase_api_key
      - HEADLESS=true
      - NODE_ENV=test
    volumes:
      - ./workspace:/workspace
      - ./tests:/tests
      - ./coverage:/coverage
    networks:
      - agent-network
    secrets:
      - claude_api_key
      - browserbase_api_key
    command: >
      sh -c "
        npm install -g @browserbasehq/stagehand &&
        npx playwright install &&
        tail -f /dev/null
      "
    profiles:
      - testing
EOF
    
    echo -e "${GREEN}✅ Docker Compose updated${NC}"
}

# Function to create VS Code tasks
create_vscode_tasks() {
    echo -e "${YELLOW}Creating VS Code tasks for TDD...${NC}"
    
    mkdir -p .vscode
    
    cat > .vscode/tasks.json << 'EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "TDD: Write Failing Test",
      "type": "shell",
      "command": "npm test -- --watch --testNamePattern='${input:testName}'",
      "group": "test",
      "presentation": {
        "reveal": "always",
        "panel": "dedicated"
      }
    },
    {
      "label": "TDD: Run Stagehand Tests",
      "type": "shell",
      "command": "npx stagehand test",
      "group": "test",
      "presentation": {
        "reveal": "always",
        "panel": "dedicated"
      }
    },
    {
      "label": "TDD: Coverage Report",
      "type": "shell",
      "command": "npm test -- --coverage",
      "group": "test",
      "presentation": {
        "reveal": "always",
        "panel": "dedicated"
      }
    },
    {
      "label": "TDD: Full Cycle",
      "type": "shell",
      "command": "./tests/stagehand/tdd-cycle.sh",
      "group": "test",
      "problemMatcher": []
    }
  ],
  "inputs": [
    {
      "id": "testName",
      "type": "promptString",
      "description": "Test name pattern"
    }
  ]
}
EOF
    
    echo -e "${GREEN}✅ VS Code tasks created${NC}"
}

# Main execution
main() {
    echo "Setting up Stagehand testing framework..."
    echo ""
    
    check_environment
    
    if [ "$1" == "--install" ]; then
        install_stagehand
    fi
    
    create_stagehand_config
    create_example_test
    create_tdd_helpers
    
    if [ "$IN_CONTAINER" == "false" ]; then
        update_docker_compose
        create_vscode_tasks
    fi
    
    echo ""
    echo -e "${GREEN}==================================${NC}"
    echo -e "${GREEN}   Setup Complete!${NC}"
    echo -e "${GREEN}==================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Set your API keys in .env:"
    echo "   ANTHROPIC_API_KEY=your_key_here"
    echo "   BROWSERBASE_API_KEY=your_key_here (optional)"
    echo ""
    echo "2. Run Stagehand tests:"
    echo "   npx stagehand test"
    echo ""
    echo "3. Use TDD cycle:"
    echo "   ./tests/stagehand/tdd-cycle.sh"
    echo ""
    echo "4. Start test runner service:"
    echo "   docker-compose --profile testing up stagehand-runner"
}

main "$@"