# Stagehand Browser Testing Integration

## Overview

Stagehand is an AI-powered browser automation framework that enables natural language testing. This integration provides seamless setup for project-by-project Stagehand installation within Docker Dev Environments.

## Features

### 🎭 AI-Powered Testing
- **Natural language commands** - Write tests in plain English
- **Visual understanding** - AI comprehends page content semantically
- **Resilient selectors** - Tests don't break with UI changes
- **Smart waiting** - Automatic detection of page readiness

### 🔧 Project Integration
- **One-command setup** - `./scripts/setup-stagehand.sh`
- **Template support** - Pre-configured dev container template
- **1Password integration** - Secure API key management
- **Framework agnostic** - Works with Next.js, React, Vue, vanilla JS

### 🐳 Container Optimization
- **Pre-installed dependencies** - All browser deps in container
- **Headless mode** - Optimized for container environments
- **Resource efficient** - Minimal overhead for testing
- **VS Code integration** - Debug tests directly in editor

## Installation Methods

### Method 1: During Project Creation

When creating a new project with `dev-container-quickstart.sh`:

```bash
./scripts/dev-container-quickstart.sh

# Select option 5: Stagehand Browser Testing
# Or select Node.js/Full-Stack and answer "yes" to Stagehand setup
```

### Method 2: Add to Existing Project

For any existing project:

```bash
# Navigate to your project
cd /path/to/your/project

# Run setup script
~/active-projects/docker-dev-environments/scripts/setup-stagehand.sh

# Optional: specify template type
~/active-projects/docker-dev-environments/scripts/setup-stagehand.sh . nextjs
```

### Method 3: Manual Template Copy

```bash
# Copy the Stagehand template
cp -r ~/active-projects/docker-dev-environments/templates/stagehand-testing/.devcontainer ./

# Install dependencies
npm install @browserbasehq/stagehand jest @playwright/test dotenv

# Install browsers
npx playwright install chromium
```

## Configuration

### API Key Setup

#### Using 1Password CLI (Recommended)
```bash
# Store in 1Password Development vault
op item create --category=login \
  --title="Claude API" \
  --vault="Development" \
  api_key="your-anthropic-api-key"

# Auto-fetch during setup
./scripts/setup-stagehand.sh  # Automatically retrieves from 1Password
```

#### Manual Configuration
```bash
# Create .env file
cat > .env << EOF
ANTHROPIC_API_KEY=your_api_key_here
TEST_BASE_URL=http://localhost:3000
HEADLESS=true
TEST_TIMEOUT=120000
EOF
```

### Dev Container Settings

The Stagehand template includes optimized devcontainer.json:

```json
{
  "name": "Stagehand Browser Testing",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:20-bookworm",
  "features": {
    "ghcr.io/devcontainers-contrib/features/playwright:1": {
      "version": "latest"
    }
  },
  "postCreateCommand": "npm install && npx playwright install chromium",
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-playwright.playwright",
        "orta.vscode-jest",
        "anthropic.claude-code"
      ]
    }
  }
}
```

## Usage Examples

### Basic Test Structure

```javascript
const { Stagehand } = require('@browserbasehq/stagehand');

describe('E2E User Journey', () => {
  let stagehand;
  let page;

  beforeAll(async () => {
    stagehand = new Stagehand({
      apiKey: process.env.ANTHROPIC_API_KEY,
      modelName: 'claude-3-5-sonnet-20241022',
      headless: process.env.HEADLESS !== 'false'
    });

    await stagehand.init();
    page = stagehand.page;
  });

  afterAll(async () => {
    await stagehand.close();
  });

  test('User can complete checkout flow', async () => {
    await page.goto('http://localhost:3000');

    // Natural language navigation
    await stagehand.act({
      action: 'click',
      element: 'The shop navigation link'
    });

    // Extract product information
    const product = await stagehand.extract({
      instruction: 'Find the first product listing',
      schema: {
        name: 'string',
        price: 'string',
        available: 'boolean'
      }
    });

    expect(product.available).toBeTruthy();

    // Add to cart
    await stagehand.act({
      action: 'click',
      element: `The add to cart button for ${product.name}`
    });

    // Verify cart updated
    const cartUpdated = await stagehand.observe(
      'Is there a cart icon showing 1 item?'
    );
    expect(cartUpdated).toBeTruthy();
  });
});
```

### Framework-Specific Examples

#### Next.js App Router
```javascript
test('Next.js RSC navigation works', async () => {
  await page.goto(global.testHelpers.getBaseUrl());

  // Test server component rendering
  const serverContent = await stagehand.observe(
    'Is there content that says "Rendered on server"?'
  );
  expect(serverContent).toBeTruthy();

  // Test client navigation
  await stagehand.act({
    action: 'click',
    element: 'A link to the about page'
  });

  // Verify soft navigation (no full reload)
  const softNavigated = await stagehand.observe(
    'Did the page change without a full reload?'
  );
  expect(softNavigated).toBeTruthy();
});
```

#### React SPA
```javascript
test('React form validation', async () => {
  await page.goto('http://localhost:3000/contact');

  // Submit empty form
  await stagehand.act({
    action: 'click',
    element: 'The submit button'
  });

  // Check for validation errors
  const errors = await stagehand.extract({
    instruction: 'Find all form validation error messages',
    schema: {
      emailError: 'string',
      nameError: 'string',
      hasErrors: 'boolean'
    }
  });

  expect(errors.hasErrors).toBeTruthy();
  expect(errors.emailError).toContain('required');
});
```

## Running Tests

### Command Line Options

```bash
# Run all Stagehand tests
npm run test:stagehand

# Run with visible browser (debugging)
npm run test:stagehand:headed

# Run specific test file
npx jest tests/stagehand/checkout.test.js

# Run in watch mode
npm run test:stagehand:watch

# Generate coverage report
npm run test:stagehand:coverage
```

### CI/CD Integration

#### GitHub Actions
```yaml
name: Stagehand E2E Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.40.0-focal

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run Stagehand tests
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          HEADLESS: true
        run: npm run test:stagehand

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results/
```

#### Docker Compose
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"

  stagehand-tests:
    build:
      context: .
      dockerfile: .devcontainer/Dockerfile
    depends_on:
      - app
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - TEST_BASE_URL=http://app:3000
      - HEADLESS=true
    command: npm run test:stagehand
    volumes:
      - ./tests:/workspace/tests
      - ./test-results:/workspace/test-results
```

## Advanced Configuration

### Custom Stagehand Options

```javascript
// tests/stagehand/setup.js
const { Stagehand } = require('@browserbasehq/stagehand');

// Global Stagehand configuration
global.createStagehand = async (options = {}) => {
  const stagehand = new Stagehand({
    apiKey: process.env.ANTHROPIC_API_KEY,
    modelName: 'claude-3-5-sonnet-20241022',
    headless: process.env.HEADLESS !== 'false',
    logger: console,  // Enable logging
    debugDom: process.env.DEBUG === 'true',  // DOM debugging
    ...options
  });

  await stagehand.init();
  return stagehand;
};

// Shared test helpers
global.testHelpers = {
  getBaseUrl: () => process.env.TEST_BASE_URL || 'http://localhost:3000',

  waitForApp: async (page) => {
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);  // Additional settling time
  },

  takeScreenshot: async (page, name) => {
    if (process.env.SCREENSHOTS === 'true') {
      await page.screenshot({
        path: `screenshots/${name}-${Date.now()}.png`,
        fullPage: true
      });
    }
  }
};
```

### Parallel Test Execution

```javascript
// jest.config.stagehand.js
module.exports = {
  testMatch: ['**/tests/stagehand/**/*.test.js'],
  maxWorkers: process.env.CI ? 2 : 4,  // Parallel execution
  testTimeout: 120000,
  testEnvironment: 'node',
  setupFilesAfterEnv: ['<rootDir>/tests/stagehand/setup.js'],
  globalSetup: '<rootDir>/tests/stagehand/global-setup.js',
  globalTeardown: '<rootDir>/tests/stagehand/global-teardown.js'
};
```

### Browser Context Reuse

```javascript
// tests/stagehand/global-setup.js
const { Stagehand } = require('@browserbasehq/stagehand');

module.exports = async () => {
  // Create shared browser instance
  global.__STAGEHAND__ = new Stagehand({
    apiKey: process.env.ANTHROPIC_API_KEY,
    headless: true
  });

  await global.__STAGEHAND__.init();
};

// tests/stagehand/global-teardown.js
module.exports = async () => {
  if (global.__STAGEHAND__) {
    await global.__STAGEHAND__.close();
  }
};
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Missing ANTHROPIC_API_KEY"
```bash
# Solution 1: Check .env file
cat .env | grep ANTHROPIC_API_KEY

# Solution 2: Use 1Password
op read "op://Development/Claude API/api_key"

# Solution 3: Export directly
export ANTHROPIC_API_KEY="your-key-here"
```

#### Issue: "Browser launch failed"
```bash
# Solution 1: Reinstall Playwright
npx playwright install --force chromium

# Solution 2: Install system deps (Linux)
sudo npx playwright install-deps

# Solution 3: Check Docker memory
docker system df
docker system prune -a  # Clean up
```

#### Issue: "Tests timeout"
```javascript
// Solution 1: Increase timeout in jest.config.stagehand.js
module.exports = {
  testTimeout: 240000  // 4 minutes
};

// Solution 2: Add explicit waits
await page.waitForLoadState('networkidle');
await page.waitForTimeout(2000);

// Solution 3: Check app is running
await page.goto(TEST_BASE_URL, { timeout: 60000 });
```

#### Issue: "Container performance"
```yaml
# Solution: Increase resources in docker-compose.yml
services:
  test:
    mem_limit: 4g
    cpus: '2.0'
    shm_size: '2gb'  # Shared memory for browser
```

### Debug Mode

Enable detailed debugging:

```bash
# Set debug environment variables
export DEBUG=pw:api
export HEADLESS=false
export SCREENSHOTS=true

# Run with Node inspector
node --inspect-brk tests/stagehand/run-tests.js

# Use VS Code debugger
# Set breakpoints and run "Debug: Jest Current File"
```

## Best Practices

### 1. Write Semantic Tests
```javascript
// ❌ Bad: Technical selectors
await page.click('#btn-123');
await page.fill('input[name="email"]', 'test@test.com');

// ✅ Good: Natural language
await stagehand.act({
  action: 'click',
  element: 'The submit button'
});
await stagehand.act({
  action: 'fill',
  element: 'The email address field',
  value: 'test@test.com'
});
```

### 2. Use Observation Before Action
```javascript
// Always verify state before interacting
const formVisible = await stagehand.observe('Is the login form visible?');
if (formVisible) {
  await stagehand.act({
    action: 'fill',
    element: 'The username field',
    value: 'testuser'
  });
}
```

### 3. Structure Data Extraction
```javascript
// Extract multiple related values at once
const pageData = await stagehand.extract({
  instruction: 'Get all product information from the page',
  schema: {
    products: [{
      name: 'string',
      price: 'number',
      inStock: 'boolean'
    }],
    totalCount: 'number',
    hasMorePages: 'boolean'
  }
});
```

### 4. Handle Dynamic Content
```javascript
// Wait for dynamic content to load
await page.goto(url);
await page.waitForLoadState('networkidle');

// Retry on dynamic elements
let retries = 3;
let success = false;

while (retries > 0 && !success) {
  success = await stagehand.observe('Is the dynamic content loaded?');
  if (!success) {
    await page.waitForTimeout(1000);
    retries--;
  }
}
```

### 5. Organize Test Files
```
tests/
└── stagehand/
    ├── setup.js              # Global configuration
    ├── helpers/
    │   ├── auth.js          # Authentication helpers
    │   └── navigation.js    # Navigation helpers
    ├── smoke/               # Quick smoke tests
    │   └── health.test.js
    ├── features/            # Feature-specific tests
    │   ├── auth.test.js
    │   ├── checkout.test.js
    │   └── search.test.js
    └── e2e/                 # Full user journeys
        └── purchase-flow.test.js
```

## Performance Optimization

### Container Optimization
```dockerfile
# Use slim base image
FROM mcr.microsoft.com/devcontainers/javascript-node:20-bookworm-slim

# Pre-install browser binaries
RUN npx playwright install chromium --with-deps

# Cache node_modules
COPY package*.json ./
RUN npm ci --only=production

# Set memory limits
ENV NODE_OPTIONS="--max-old-space-size=2048"
```

### Test Optimization
```javascript
// Reuse browser context
let context;

beforeAll(async () => {
  context = await stagehand.browser.newContext({
    viewport: { width: 1280, height: 720 },
    userAgent: 'Stagehand Test Runner'
  });
});

beforeEach(async () => {
  page = await context.newPage();
});

afterEach(async () => {
  await page.close();
});

afterAll(async () => {
  await context.close();
});
```

## Integration with Docker Dev Environments

### Multi-Agent Testing
Combine Stagehand with the multi-agent orchestration system:

```bash
# Launch orchestrator with Stagehand agent
./scripts/launch-multi-agent.sh stagehand-testing

# Submit test task
curl -X POST http://localhost:8000/execute \
  -H "Content-Type: application/json" \
  -d '{
    "task_type": "browser_test",
    "execution_mode": "parallel",
    "agents": ["stagehand-tester"],
    "payload": {
      "test_suite": "e2e",
      "headless": true
    }
  }'
```

### Spec-Driven Testing
Integrate with spec-driven development:

```yaml
# specs/checkout-flow.yaml
name: checkout-flow
description: E2E checkout process testing
requirements:
  - User can browse products
  - User can add items to cart
  - User can complete checkout
test_scenarios:
  - Browse and select product
  - Add multiple items
  - Apply discount code
  - Complete payment
```

## Resources

- [Stagehand GitHub Repository](https://github.com/browserbase/stagehand)
- [Playwright Documentation](https://playwright.dev)
- [Jest Testing Framework](https://jestjs.io)
- [Anthropic Claude API](https://docs.anthropic.com)
- [Docker Dev Environments Guide](../README.md)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review [example tests](../templates/stagehand-testing/tests/)
3. Consult the [Stagehand documentation](https://github.com/browserbase/stagehand)
4. Open an issue in this repository

---
*Stagehand Integration for Docker Dev Environments - AI-powered browser testing made simple*