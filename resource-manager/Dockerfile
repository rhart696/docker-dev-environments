FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    docker.io \
    redis-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy resource manager code
COPY . .

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV MAX_TOTAL_MEMORY=16G
ENV MAX_TOTAL_CPU=8
ENV CHECK_INTERVAL=30

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8001/health')" || exit 1

# Run resource manager
CMD ["python", "-m", "resource_manager.main"]