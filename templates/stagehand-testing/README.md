# Stagehand Browser Testing Template

This template provides a complete environment for AI-powered browser testing using Stagehand.

## Features

- **Stagehand** - AI-powered browser automation using natural language
- **Playwright** - Cross-browser testing framework
- **Jest** - Testing framework with watch mode
- **Node.js 20** - Latest LTS version
- **Pre-configured VS Code** - Extensions and settings for testing
- **1Password Integration** - Secure API key management
- **Docker Container** - Isolated, reproducible environment

## Quick Start

1. **Open in VS Code**
   ```bash
   code .
   ```

2. **Reopen in Container**
   - Click "Reopen in Container" when prompted
   - Or use Command Palette: "Dev Containers: Reopen in Container"

3. **Setup Stagehand**
   ```bash
   # Run the setup script
   ./scripts/setup-stagehand.sh

   # Or manually install
   npm install @browserbasehq/stagehand
   ```

4. **Configure API Key**
   ```bash
   # Add to .env file
   echo "ANTHROPIC_API_KEY=your_key_here" > .env
   ```

5. **Run Tests**
   ```bash
   npm run test:stagehand
   ```

## Pre-installed Tools

### Testing Frameworks
- Jest - Test runner and assertion library
- Playwright - Browser automation
- Stagehand - AI-powered testing

### Development Tools
- ESLint - Code linting
- Prettier - Code formatting
- TypeScript - Type checking
- Nodemon - Auto-restart on changes

### VS Code Extensions
- Jest Runner - Run tests from editor
- Playwright Test - Debug browser tests
- Claude Code - AI coding assistant
- Gemini Code Assist - Google's AI assistant

## Environment Variables

Create a `.env` file:
```env
# Required
ANTHROPIC_API_KEY=your_anthropic_api_key

# Optional - for cloud testing
BROWSERBASE_API_KEY=
BROWSERBASE_PROJECT_ID=

# Test Configuration
TEST_BASE_URL=http://localhost:3000
HEADLESS=true
TEST_TIMEOUT=120000
```

## Writing Tests

### Basic Test Structure
```javascript
const { Stagehand } = require('@browserbasehq/stagehand');

describe('My Application', () => {
  let stagehand;

  beforeAll(async () => {
    stagehand = new Stagehand({
      apiKey: process.env.ANTHROPIC_API_KEY,
      headless: true
    });
    await stagehand.init();
  });

  afterAll(async () => {
    await stagehand.close();
  });

  test('can perform user actions', async () => {
    await stagehand.page.goto('http://localhost:3000');

    // Use natural language to interact
    await stagehand.act({
      action: 'click',
      element: 'The login button'
    });

    // Observe page state
    const isLoggedIn = await stagehand.observe(
      'Is the user dashboard visible?'
    );
    expect(isLoggedIn).toBeTruthy();
  });
});
```

## Container Features

### Port Forwarding
- `3000` - Application server
- `3001` - Test server
- `8080` - Alternative server
- `9229` - Node.js debugger

### Mounted Volumes
- `~/.ssh` - SSH keys (read-only)
- `~/.secrets` - API keys (read-only)

### System Dependencies
All Playwright browser dependencies are pre-installed in the container.

## Debugging Tests

### Visual Debugging
```bash
# Run tests with visible browser
HEADLESS=false npm run test:stagehand
```

### VS Code Debugging
1. Set breakpoints in test files
2. Run "Debug: Jest Current File" from Command Palette
3. Use Debug Console for inspection

### Node Inspector
```bash
# Start tests with inspector
node --inspect-brk tests/stagehand/run-tests.js
```

## Best Practices

1. **Natural Language** - Write tests as a user would describe actions
2. **Resilient Selectors** - Use semantic descriptions, not CSS selectors
3. **Wait for State** - Use `observe()` to check page state before acting
4. **Structured Data** - Use `extract()` for complex data validation
5. **Error Handling** - Tests should gracefully handle missing elements

## Troubleshooting

### Browser Launch Issues
```bash
# Reinstall Playwright browsers
npx playwright install --force chromium
```

### API Key Issues
```bash
# Check environment variable
echo $ANTHROPIC_API_KEY

# Verify .env file
cat .env
```

### Container Performance
- Allocate at least 4GB RAM to Docker
- Use headless mode for better performance
- Close other applications to free resources

## Resources

- [Stagehand Documentation](https://github.com/browserbase/stagehand)
- [Playwright Docs](https://playwright.dev)
- [Jest Documentation](https://jestjs.io)
- [Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)