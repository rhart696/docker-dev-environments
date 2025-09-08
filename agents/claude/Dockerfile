FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy agent code
COPY . .

# Create directories
RUN mkdir -p /workspace /artifacts /logs

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV AGENT_TYPE=claude
ENV MODEL=claude-3-opus-20240229

# Labels for identification
LABEL agent.type="claude"
LABEL agent.capabilities="architecture,design,testing,review"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# Run agent
CMD ["python", "-m", "claude_agent.main"]