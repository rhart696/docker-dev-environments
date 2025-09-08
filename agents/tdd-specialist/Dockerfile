FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for testing frameworks
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    chromium \
    chromium-driver \
    firefox-esr \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js for JavaScript testing frameworks
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install JavaScript testing tools globally
RUN npm install -g playwright @browserbasehq/stagehand

# Copy agent code
COPY . .

# Create directories
RUN mkdir -p /workspace /artifacts /tests /coverage

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV AGENT_TYPE=tdd-specialist
ENV AGENT_ROLE=tester
ENV TDD_MODE=strict

# Labels for identification
LABEL agent.type="tdd-specialist"
LABEL agent.capabilities="test-generation,test-execution,coverage-analysis,tdd-workflow"
LABEL agent.frameworks="playwright,stagehand,pytest,jest,vitest"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# Run agent
CMD ["python", "-m", "tdd_agent.main"]