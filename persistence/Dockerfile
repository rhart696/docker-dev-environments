FROM python:3.11-slim

WORKDIR /app

# Install git for version control integration
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY persistence_service.py .
COPY agent_client.js .

# Create directories for specs and outputs
RUN mkdir -p /workspace /specs /outputs

# Expose port
EXPOSE 5000

# Set environment variables
ENV FLASK_APP=persistence_service.py
ENV PYTHONUNBUFFERED=1

# Run the service
CMD ["python", "persistence_service.py"]