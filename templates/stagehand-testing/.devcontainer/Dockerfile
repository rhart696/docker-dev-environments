# Stagehand Testing Environment Dockerfile
FROM mcr.microsoft.com/devcontainers/javascript-node:20-bookworm

# Install additional system dependencies for Playwright
RUN apt-get update && apt-get install -y \
    wget \
    ca-certificates \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgbm1 \
    libgcc1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    lsb-release \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Install global npm packages
RUN npm install -g \
    npm@latest \
    jest \
    @playwright/test \
    typescript \
    ts-node \
    nodemon

# Create workspace directory
WORKDIR /workspace

# Switch to non-root user
USER node

# Pre-install Playwright browsers
RUN npx playwright install chromium

# Set environment variables
ENV NODE_ENV=development \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0 \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright

# Expose common ports
EXPOSE 3000 3001 8080 9229

# Default command
CMD ["bash"]