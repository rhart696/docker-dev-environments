#!/bin/bash

# Stagehand Integration Script for Docker Dev Environments
# Adds AI-powered browser testing capabilities to any project
# Compatible with dev containers and local environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎭 Stagehand Browser Automation Setup${NC}"
echo "========================================"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Parse arguments
PROJECT_PATH="${1:-$(pwd)}"
TEMPLATE_TYPE="${2:-standalone}"  # standalone, nextjs, react, vue
SETUP_1PASSWORD="${3:-true}"

# Detect environment
detect_environment() {
    if [ -f /.dockerenv ]; then
        echo "docker"
    elif [ -n "$DEVCONTAINER" ] || [ -n "$REMOTE_CONTAINERS_IPC" ]; then
        echo "devcontainer"
    else
        echo "local"
    fi
}

ENV_TYPE=$(detect_environment)
print_info "Environment: $ENV_TYPE"
print_info "Project path: $PROJECT_PATH"
print_info "Template type: $TEMPLATE_TYPE"

# Navigate to project directory
cd "$PROJECT_PATH"

# Check for Node.js
check_node() {
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"

        if [ "$ENV_TYPE" = "docker" ] || [ "$ENV_TYPE" = "devcontainer" ]; then
            print_status "Installing Node.js 20 in container..."
            apt-get update && apt-get install -y curl
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
        else
            print_error "Please install Node.js 20+ first"
            echo "Visit: https://nodejs.org/"
            exit 1
        fi
    else
        NODE_VERSION=$(node -v)
        print_status "Node.js found: $NODE_VERSION"
    fi
}

# Initialize npm project if needed
init_npm() {
    if [ ! -f "package.json" ]; then
        print_status "Initializing npm project..."
        npm init -y

        # Update package.json with project info
        node -e "
const fs = require('fs');
const path = require('path');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.name = path.basename('$PROJECT_PATH');
pkg.description = 'Project with Stagehand browser automation testing';
pkg.private = true;
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"
    else
        print_info "package.json already exists"
    fi
}

# Install Stagehand and dependencies
install_stagehand() {
    print_status "Installing Stagehand and dependencies..."

    # Core dependencies
    npm install --save @browserbasehq/stagehand

    # Testing dependencies
    npm install --save-dev \
        jest \
        @playwright/test \
        dotenv \
        @types/jest \
        @types/node

    # Framework-specific dependencies
    case $TEMPLATE_TYPE in
        nextjs)
            npm install --save-dev @testing-library/react @testing-library/jest-dom
            ;;
        react)
            npm install --save-dev @testing-library/react @testing-library/user-event
            ;;
        vue)
            npm install --save-dev @vue/test-utils
            ;;
    esac

    print_status "Dependencies installed"
}

# Install Playwright browsers with Docker support
install_browsers() {
    print_status "Installing Playwright browsers..."

    if [ "$ENV_TYPE" = "docker" ] || [ "$ENV_TYPE" = "devcontainer" ]; then
        # Install system dependencies for containerized environments
        print_info "Installing system dependencies for browsers..."

        if [ -f /etc/debian_version ]; then
            apt-get update
            apt-get install -y \
                wget ca-certificates fonts-liberation \
                libappindicator3-1 libasound2 libatk-bridge2.0-0 \
                libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 \
                libexpat1 libfontconfig1 libgbm1 libgcc1 libglib2.0-0 \
                libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 \
                libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 \
                libxcb1 libxcomposite1 libxcursor1 libxdamage1 \
                libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 \
                libxss1 libxtst6 lsb-release xdg-utils
        fi
    fi

    # Install Chromium browser
    npx playwright install chromium

    if [ "$ENV_TYPE" = "local" ]; then
        npx playwright install-deps chromium
    fi

    print_status "Browsers installed"
}

# Setup environment variables
setup_environment() {
    print_status "Setting up environment configuration..."

    # Create .env.example
    cat > .env.example << 'EOF'
# Stagehand Configuration
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Optional: Browserbase for cloud testing
BROWSERBASE_API_KEY=
BROWSERBASE_PROJECT_ID=

# Test Configuration
NODE_ENV=test
TEST_TIMEOUT=120000
HEADLESS=true
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0

# Development Server (update port as needed)
TEST_BASE_URL=http://localhost:3000
EOF

    # Handle 1Password integration if available
    if [ "$SETUP_1PASSWORD" = "true" ] && command -v op &> /dev/null; then
        print_status "1Password CLI detected, fetching secrets..."

        # Check if signed in
        if op account list &> /dev/null; then
            # Try to fetch Claude API key
            if CLAUDE_KEY=$(op read "op://Development/Claude API/api_key" 2>/dev/null); then
                echo "ANTHROPIC_API_KEY=$CLAUDE_KEY" > .env
                print_status "Retrieved Anthropic API key from 1Password"
            else
                print_warning "Could not fetch Claude API key from 1Password"
                cp .env.example .env
            fi

            # Try to fetch Browserbase credentials
            if BB_KEY=$(op read "op://Development/Browserbase/api_key" 2>/dev/null); then
                echo "BROWSERBASE_API_KEY=$BB_KEY" >> .env
                if BB_PROJECT=$(op read "op://Development/Browserbase/project_id" 2>/dev/null); then
                    echo "BROWSERBASE_PROJECT_ID=$BB_PROJECT" >> .env
                    print_status "Retrieved Browserbase credentials from 1Password"
                fi
            fi
        else
            print_warning "1Password CLI not signed in, using template .env"
            cp .env.example .env
        fi
    elif [ ! -f .env ]; then
        cp .env.example .env
        print_warning "Created .env from template. Add your ANTHROPIC_API_KEY"
    else
        print_info ".env file already exists, skipping"
    fi

    # Add to .gitignore
    if [ -f .gitignore ]; then
        if ! grep -q "^\.env$" .gitignore; then
            echo ".env" >> .gitignore
        fi
    fi
}

# Create test structure
create_test_structure() {
    print_status "Creating test structure..."

    # Create directories
    mkdir -p tests/stagehand
    mkdir -p tests/fixtures

    # Create test runner
    cat > tests/stagehand/run-tests.js << 'EOF'
#!/usr/bin/env node

/**
 * Stagehand Test Runner
 * Orchestrates AI-powered browser tests
 */

const { execSync } = require('child_process');
const path = require('path');
require('dotenv').config();

// Validate environment
const validateEnv = () => {
  const required = ['ANTHROPIC_API_KEY'];
  const missing = required.filter(key => !process.env[key]);

  if (missing.length > 0) {
    console.error(`❌ Missing required environment variables: ${missing.join(', ')}`);
    console.error('   Please check your .env file');
    process.exit(1);
  }
};

// Main execution
const main = async () => {
  console.log('🎭 Stagehand Test Runner');
  console.log('========================\n');

  validateEnv();

  const args = process.argv.slice(2);
  const isHeaded = args.includes('--headed') || process.env.HEADLESS === 'false';

  if (isHeaded) {
    console.log('🖥️  Running in headed mode (browser visible)\n');
  }

  try {
    execSync(`npx jest --config jest.config.stagehand.js ${args.join(' ')}`, {
      stdio: 'inherit',
      env: {
        ...process.env,
        NODE_ENV: 'test',
        HEADLESS: isHeaded ? 'false' : 'true'
      }
    });

    console.log('\n✅ All tests passed!');
  } catch (error) {
    console.error('\n❌ Tests failed');
    process.exit(1);
  }
};

main();
EOF
    chmod +x tests/stagehand/run-tests.js

    # Create Jest configuration
    cat > jest.config.stagehand.js << 'EOF'
module.exports = {
  testMatch: ['**/tests/stagehand/**/*.test.js'],
  testTimeout: parseInt(process.env.TEST_TIMEOUT || '120000'),
  testEnvironment: 'node',
  verbose: true,
  setupFilesAfterEnv: ['<rootDir>/tests/stagehand/setup.js'],
  collectCoverageFrom: [
    'tests/stagehand/**/*.js',
    '!tests/stagehand/run-tests.js',
    '!tests/stagehand/setup.js'
  ]
};
EOF

    # Create test setup file
    cat > tests/stagehand/setup.js << 'EOF'
/**
 * Test Setup
 * Global configuration for all Stagehand tests
 */

require('dotenv').config();

// Extend test timeout for browser operations
jest.setTimeout(parseInt(process.env.TEST_TIMEOUT || '120000'));

// Global test helpers
global.testHelpers = {
  getBaseUrl: () => process.env.TEST_BASE_URL || 'http://localhost:3000',
  isHeadless: () => process.env.HEADLESS !== 'false',
  getTimeout: () => parseInt(process.env.TEST_TIMEOUT || '120000')
};

// Clean up on test failure
afterAll(async () => {
  // Cleanup code here
});
EOF

    # Create sample test based on template type
    create_sample_test

    print_status "Test structure created"
}

# Create template-specific sample test
create_sample_test() {
    local TEST_FILE="tests/stagehand/sample.test.js"

    case $TEMPLATE_TYPE in
        nextjs)
            cat > $TEST_FILE << 'EOF'
/**
 * Sample Stagehand Test for Next.js
 */

const { Stagehand } = require('@browserbasehq/stagehand');
const { expect } = require('@playwright/test');

describe('Next.js Application Tests', () => {
  let stagehand;
  let page;

  beforeAll(async () => {
    stagehand = new Stagehand({
      apiKey: process.env.ANTHROPIC_API_KEY,
      modelName: 'claude-3-5-sonnet-20241022',
      headless: global.testHelpers.isHeadless(),
    });

    await stagehand.init();
    page = stagehand.page;
  });

  afterAll(async () => {
    await stagehand.close();
  });

  test('Homepage loads successfully', async () => {
    await page.goto(global.testHelpers.getBaseUrl());

    const pageLoaded = await stagehand.observe(
      'Is this a Next.js application homepage with navigation and content?'
    );
    expect(pageLoaded).toBeTruthy();
  });

  test('Navigation works correctly', async () => {
    await stagehand.act({
      action: 'click',
      element: 'A navigation link to another page'
    });

    await page.waitForLoadState('networkidle');

    const navigated = await stagehand.observe(
      'Did the page navigate to a different route?'
    );
    expect(navigated).toBeTruthy();
  });
});
EOF
            ;;

        react)
            cat > $TEST_FILE << 'EOF'
/**
 * Sample Stagehand Test for React
 */

const { Stagehand } = require('@browserbasehq/stagehand');
const { expect } = require('@playwright/test');

describe('React Application Tests', () => {
  let stagehand;
  let page;

  beforeAll(async () => {
    stagehand = new Stagehand({
      apiKey: process.env.ANTHROPIC_API_KEY,
      modelName: 'claude-3-5-sonnet-20241022',
      headless: global.testHelpers.isHeadless(),
    });

    await stagehand.init();
    page = stagehand.page;
  });

  afterAll(async () => {
    await stagehand.close();
  });

  test('React app renders correctly', async () => {
    await page.goto(global.testHelpers.getBaseUrl());

    const appLoaded = await stagehand.observe(
      'Is this a React application with interactive components?'
    );
    expect(appLoaded).toBeTruthy();
  });

  test('Component interaction works', async () => {
    const initialState = await stagehand.extract({
      instruction: 'Find any counter or interactive element on the page',
      schema: {
        elementType: 'string',
        currentValue: 'string'
      }
    });

    await stagehand.act({
      action: 'click',
      element: 'An interactive button or clickable element'
    });

    const stateChanged = await stagehand.observe(
      'Did clicking the element cause a visible change on the page?'
    );
    expect(stateChanged).toBeTruthy();
  });
});
EOF
            ;;

        *)
            cat > $TEST_FILE << 'EOF'
/**
 * Sample Stagehand Test
 * Demonstrates core Stagehand functionality
 */

const { Stagehand } = require('@browserbasehq/stagehand');
const { expect } = require('@playwright/test');

describe('Stagehand Browser Automation Tests', () => {
  let stagehand;
  let page;

  beforeAll(async () => {
    stagehand = new Stagehand({
      apiKey: process.env.ANTHROPIC_API_KEY,
      modelName: 'claude-3-5-sonnet-20241022',
      headless: global.testHelpers.isHeadless(),
    });

    await stagehand.init();
    page = stagehand.page;
  });

  afterAll(async () => {
    await stagehand.close();
  });

  describe('Core Functionality', () => {
    test('Can navigate and observe content', async () => {
      await page.goto('https://example.com');

      const hasHeading = await stagehand.observe(
        'Is there a heading that says "Example Domain"?'
      );
      expect(hasHeading).toBeTruthy();
    });

    test('Can extract structured data', async () => {
      await page.goto('https://example.com');

      const pageInfo = await stagehand.extract({
        instruction: 'Extract information about this page',
        schema: {
          title: 'string',
          hasLinks: 'boolean',
          mainContent: 'string'
        }
      });

      expect(pageInfo.title).toBeTruthy();
      expect(typeof pageInfo.hasLinks).toBe('boolean');
    });

    test('Can interact with page elements', async () => {
      await page.goto('https://example.com');

      const linkData = await stagehand.extract({
        instruction: 'Find the "More information" link',
        schema: {
          linkText: 'string',
          linkExists: 'boolean'
        }
      });

      if (linkData.linkExists) {
        await stagehand.act({
          action: 'click',
          element: 'The "More information" link'
        });

        await page.waitForLoadState('networkidle');

        const navigated = await stagehand.observe(
          'Did the page navigate to IANA.org?'
        );
        expect(navigated).toBeTruthy();
      }
    });
  });

  describe('Error Handling', () => {
    test('Handles non-existent elements gracefully', async () => {
      await page.goto('https://example.com');

      const nonExistent = await stagehand.observe(
        'Is there a button that says "Buy Now"?'
      );
      expect(nonExistent).toBeFalsy();
    });
  });
});
EOF
            ;;
    esac
}

# Update package.json scripts
update_package_json() {
    print_status "Adding test scripts to package.json..."

    node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

// Initialize scripts if not present
if (!pkg.scripts) pkg.scripts = {};

// Add Stagehand test scripts
pkg.scripts['test:stagehand'] = 'node tests/stagehand/run-tests.js';
pkg.scripts['test:stagehand:headed'] = 'HEADLESS=false node tests/stagehand/run-tests.js';
pkg.scripts['test:stagehand:watch'] = 'npx jest --config jest.config.stagehand.js --watch';
pkg.scripts['test:stagehand:coverage'] = 'npx jest --config jest.config.stagehand.js --coverage';
pkg.scripts['test:stagehand:debug'] = 'node --inspect-brk tests/stagehand/run-tests.js';

// Add dev script if not present and it's a web project
if (!pkg.scripts.dev && ['nextjs', 'react', 'vue'].includes('$TEMPLATE_TYPE')) {
  pkg.scripts.dev = 'echo \"Please configure your dev server command\"';
}

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('✓ package.json updated with test scripts');
"
}

# Create documentation
create_documentation() {
    print_status "Creating documentation..."

    cat > STAGEHAND_GUIDE.md << 'EOF'
# Stagehand Browser Automation Guide

## Overview
This project is configured with Stagehand, an AI-powered browser automation framework that uses natural language to write resilient tests.

## Quick Start

### Running Tests
```bash
# Run all tests (headless)
npm run test:stagehand

# Run with visible browser
npm run test:stagehand:headed

# Watch mode for development
npm run test:stagehand:watch

# Generate coverage report
npm run test:stagehand:coverage

# Debug tests
npm run test:stagehand:debug
```

### Writing Tests

Stagehand provides three main methods for browser automation:

#### 1. Observe - Check if something exists
```javascript
const isVisible = await stagehand.observe('Is the login button visible?');
const hasError = await stagehand.observe('Is there an error message displayed?');
```

#### 2. Extract - Get structured data
```javascript
const productInfo = await stagehand.extract({
  instruction: 'Find the product details',
  schema: {
    name: 'string',
    price: 'number',
    inStock: 'boolean'
  }
});
```

#### 3. Act - Interact with the page
```javascript
await stagehand.act({
  action: 'click',
  element: 'The submit button'
});

await stagehand.act({
  action: 'fill',
  element: 'The email input field',
  value: 'test@example.com'
});
```

## Environment Variables

Configure in `.env`:
- `ANTHROPIC_API_KEY` - Required for AI features
- `BROWSERBASE_API_KEY` - Optional, for cloud testing
- `BROWSERBASE_PROJECT_ID` - Optional, for cloud testing
- `TEST_BASE_URL` - Base URL for your application
- `HEADLESS` - Set to 'false' to see browser
- `TEST_TIMEOUT` - Test timeout in milliseconds

## Project Structure
```
tests/
├── stagehand/
│   ├── run-tests.js       # Test runner
│   ├── setup.js           # Global test setup
│   └── *.test.js          # Test files
└── fixtures/              # Test data and fixtures
```

## Best Practices

### Writing Resilient Tests
1. **Use natural language** - Describe what a user would see, not technical details
2. **Be specific but flexible** - "The main navigation menu" not "#nav-id-123"
3. **Test user journeys** - Focus on workflows, not individual elements
4. **Handle dynamic content** - Use observe() to check state before acting

### Example Test Pattern
```javascript
describe('User Authentication Flow', () => {
  test('User can successfully log in', async () => {
    // Navigate
    await page.goto(global.testHelpers.getBaseUrl());

    // Observe initial state
    const loginVisible = await stagehand.observe('Is the login form visible?');
    expect(loginVisible).toBeTruthy();

    // Act - Fill form
    await stagehand.act({
      action: 'fill',
      element: 'The email input field',
      value: 'user@example.com'
    });

    await stagehand.act({
      action: 'fill',
      element: 'The password input field',
      value: 'password123'
    });

    // Submit
    await stagehand.act({
      action: 'click',
      element: 'The login submit button'
    });

    // Verify outcome
    await page.waitForLoadState('networkidle');
    const loggedIn = await stagehand.observe('Is the user dashboard visible?');
    expect(loggedIn).toBeTruthy();
  });
});
```

## Troubleshooting

### Common Issues

#### Missing API Key
- Ensure `ANTHROPIC_API_KEY` is set in `.env`
- Check 1Password integration: `op account list`

#### Browser Launch Failures
```bash
# Reinstall browsers
npx playwright install --force
npx playwright install-deps  # Linux only
```

#### Docker/Container Issues
- Ensure all system dependencies are installed
- Run tests in headless mode only
- Check container has sufficient memory (2GB+)

#### Test Timeouts
- Increase `TEST_TIMEOUT` in `.env`
- Check your application is running
- Verify `TEST_BASE_URL` is correct

## CI/CD Integration

### GitHub Actions
```yaml
name: Stagehand Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'

      - run: npm ci
      - run: npx playwright install --with-deps

      - name: Run Stagehand Tests
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: npm run test:stagehand
```

### Docker Support
Tests are fully compatible with Docker environments. The setup script automatically detects and configures for containerized environments.

## Advanced Usage

### Custom Model Configuration
```javascript
const stagehand = new Stagehand({
  apiKey: process.env.ANTHROPIC_API_KEY,
  modelName: 'claude-3-5-sonnet-20241022',  // or other available models
  modelClientOptions: {
    temperature: 0.1,  // Lower = more deterministic
    maxTokens: 4096
  }
});
```

### Debugging Tests
```javascript
// Enable verbose logging
stagehand = new Stagehand({
  apiKey: process.env.ANTHROPIC_API_KEY,
  headless: false,  // See browser
  debugDom: true,   // Log DOM observations
});

// Take screenshots on failure
afterEach(async () => {
  if (stagehand && stagehand.page) {
    await stagehand.page.screenshot({
      path: `screenshots/test-${Date.now()}.png`
    });
  }
});
```

## Resources

- [Stagehand Documentation](https://github.com/browserbase/stagehand)
- [Playwright Documentation](https://playwright.dev)
- [Jest Documentation](https://jestjs.io)
- [Anthropic API](https://docs.anthropic.com)

---
*Generated by Docker Dev Environments Stagehand Integration*
EOF

    print_status "Documentation created: STAGEHAND_GUIDE.md"
}

# Add to devcontainer if present
update_devcontainer() {
    if [ -f ".devcontainer/devcontainer.json" ]; then
        print_status "Updating devcontainer configuration..."

        # Add Stagehand post-create command
        node -e "
const fs = require('fs');
let content = fs.readFileSync('.devcontainer/devcontainer.json', 'utf8');

// Parse JSON (handling comments)
content = content.replace(/\\/\\/.*/g, '');
content = content.replace(/\\/\\*[\\s\\S]*?\\*\\//g, '');
const config = JSON.parse(content);

// Add post-create command
const stagehandSetup = 'npx playwright install chromium && npx playwright install-deps';
if (config.postCreateCommand) {
  if (!config.postCreateCommand.includes('playwright')) {
    config.postCreateCommand += ' && ' + stagehandSetup;
  }
} else {
  config.postCreateCommand = stagehandSetup;
}

// Add VS Code extensions
if (!config.customizations) config.customizations = {};
if (!config.customizations.vscode) config.customizations.vscode = {};
if (!config.customizations.vscode.extensions) config.customizations.vscode.extensions = [];

const extensions = [
  'dbaeumer.vscode-eslint',
  'esbenp.prettier-vscode',
  'orta.vscode-jest'
];

extensions.forEach(ext => {
  if (!config.customizations.vscode.extensions.includes(ext)) {
    config.customizations.vscode.extensions.push(ext);
  }
});

fs.writeFileSync('.devcontainer/devcontainer.json', JSON.stringify(config, null, 2));
console.log('✓ Updated devcontainer.json');
" 2>/dev/null || print_warning "Could not update devcontainer.json automatically"
    fi
}

# Main execution
main() {
    echo ""

    # Step 1: Check Node.js
    check_node

    # Step 2: Initialize npm if needed
    init_npm

    # Step 3: Install Stagehand
    install_stagehand

    # Step 4: Install browsers
    install_browsers

    # Step 5: Setup environment
    setup_environment

    # Step 6: Create test structure
    create_test_structure

    # Step 7: Update package.json
    update_package_json

    # Step 8: Create documentation
    create_documentation

    # Step 9: Update devcontainer if present
    update_devcontainer

    # Success message
    echo ""
    echo "========================================="
    echo -e "${GREEN}✅ Stagehand setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Add your ANTHROPIC_API_KEY to .env file"
    echo "2. Start your dev server (if applicable)"
    echo "3. Run tests: npm run test:stagehand"
    echo "4. See STAGEHAND_GUIDE.md for detailed usage"
    echo ""

    if [ "$ENV_TYPE" = "docker" ] || [ "$ENV_TYPE" = "devcontainer" ]; then
        print_info "Container environment detected - tests will run in headless mode"
    fi

    # Show available test commands
    echo "Available commands:"
    echo "  npm run test:stagehand         # Run all tests"
    echo "  npm run test:stagehand:headed  # Run with visible browser"
    echo "  npm run test:stagehand:watch   # Watch mode"
    echo "  npm run test:stagehand:coverage # Coverage report"
    echo ""
}

# Run main function
main