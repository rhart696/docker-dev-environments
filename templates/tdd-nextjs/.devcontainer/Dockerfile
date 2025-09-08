FROM mcr.microsoft.com/devcontainers/javascript-node:20-bookworm

# Install Chrome for testing
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    chromium \
    chromium-driver \
    firefox-esr \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install global npm packages for TDD
RUN npm install -g \
    @browserbasehq/stagehand \
    @playwright/test \
    jest \
    vitest \
    c8 \
    nyc

# Install Playwright browsers
RUN npx playwright install chromium firefox webkit
RUN npx playwright install-deps

# Create directories for testing
RUN mkdir -p /workspace/tests /workspace/coverage /workspace/test-results

# Copy TDD configuration files
COPY .devcontainer/tdd-config/* /workspace/

# Set up Git hooks for TDD
RUN git config --global core.hooksPath /workspace/.githooks

WORKDIR /workspace

# Switch to node user
USER node

# Set environment variables for TDD
ENV NODE_ENV=test
ENV TDD_MODE=strict
ENV CI=false
ENV FORCE_COLOR=1

# Aliases for TDD commands
RUN echo 'alias tdd="npm run test:watch"' >> ~/.bashrc && \
    echo 'alias test="npm test"' >> ~/.bashrc && \
    echo 'alias coverage="npm run test:coverage"' >> ~/.bashrc && \
    echo 'alias e2e="npm run test:e2e"' >> ~/.bashrc && \
    echo 'alias stagehand="npx stagehand"' >> ~/.bashrc

CMD ["bash"]