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
ENV AGENT_TYPE=gemini
ENV MODEL=gemini-2.5-pro

# Labels for identification
LABEL agent.type="gemini"
LABEL agent.capabilities="implementation,optimization,algorithms,code-generation"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# Run agent
CMD ["python", "-m", "gemini_agent.main"]