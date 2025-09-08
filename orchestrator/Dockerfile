FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    docker.io \
    redis-tools \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy orchestrator code
COPY . .

# Create directories for artifacts and logs
RUN mkdir -p /artifacts /logs /config

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV ORCHESTRATOR_MODE=hybrid
ENV LOG_LEVEL=INFO

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# Run orchestrator
CMD ["python", "-m", "orchestrator.main"]