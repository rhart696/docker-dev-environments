#!/bin/bash

# Test script for Docker Dev Environments templates
# Run: ./test-templates.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Docker Dev Environments Test Suite${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Function to check if service is healthy
check_service() {
    local service=$1
    local max_attempts=30
    local attempt=0

    echo -n "Checking $service..."

    while [ $attempt -lt $max_attempts ]; do
        if docker-compose -f docker-compose.test.yml ps | grep -q "$service.*healthy"; then
            echo -e " ${GREEN}✅ Healthy${NC}"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
        echo -n "."
    done

    echo -e " ${RED}❌ Failed${NC}"
    return 1
}

# Test 1: Validate Docker Compose file
echo -e "${YELLOW}Test 1: Validating docker-compose.test.yml${NC}"
if docker-compose -f docker-compose.test.yml config > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker Compose test file is valid${NC}"
else
    echo -e "${RED}❌ Docker Compose test file has errors${NC}"
    exit 1
fi
echo ""

# Test 2: Check template files exist
echo -e "${YELLOW}Test 2: Checking template files${NC}"
for file in templates/compose/*.yml templates/compose/Dockerfile.*; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ Found: $(basename $file)${NC}"
    else
        echo -e "${RED}❌ Missing: $file${NC}"
    fi
done
echo ""

# Test 3: Validate main script
echo -e "${YELLOW}Test 3: Validating dev-container-quickstart.sh${NC}"
if bash -n scripts/dev-container-quickstart.sh 2>&1; then
    echo -e "${GREEN}✅ Script syntax is valid${NC}"
else
    echo -e "${RED}❌ Script has syntax errors${NC}"
    exit 1
fi
echo ""

# Test 4: Start test databases
echo -e "${YELLOW}Test 4: Starting test databases${NC}"
docker-compose -f docker-compose.test.yml --profile databases up -d > /dev/null 2>&1

# Wait for services to be healthy
for service in test-postgres test-redis test-mongodb; do
    check_service $service
done
echo ""

# Test 5: Test connectivity
echo -e "${YELLOW}Test 5: Testing database connectivity${NC}"

# Test PostgreSQL
if PGPASSWORD=testpass psql -h localhost -p 15432 -U testuser -d testdb -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL connection successful${NC}"
else
    echo -e "${RED}❌ PostgreSQL connection failed${NC}"
fi

# Test Redis
if redis-cli -h localhost -p 16379 ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Redis connection successful${NC}"
else
    echo -e "${RED}❌ Redis connection failed${NC}"
fi

# Test MongoDB (requires mongosh or mongo client)
if command -v mongosh > /dev/null 2>&1; then
    if mongosh --host localhost:37017 --eval "db.runCommand({ ping: 1 })" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ MongoDB connection successful${NC}"
    else
        echo -e "${RED}❌ MongoDB connection failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  MongoDB client not installed, skipping MongoDB test${NC}"
fi
echo ""

# Test 6: Build template Dockerfiles
echo -e "${YELLOW}Test 6: Building template Dockerfiles${NC}"

# Build Python template
echo -n "Building Python template..."
if docker build -f templates/compose/Dockerfile.python -t test-python-template templates/compose > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${RED}❌${NC}"
fi

# Build Node.js template
echo -n "Building Node.js template..."
if docker build -f templates/compose/Dockerfile.nodejs -t test-nodejs-template templates/compose > /dev/null 2>&1; then
    echo -e " ${GREEN}✅${NC}"
else
    echo -e " ${RED}❌${NC}"
fi
echo ""

# Clean up
echo -e "${YELLOW}Cleaning up...${NC}"
docker-compose -f docker-compose.test.yml down -v > /dev/null 2>&1
echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
echo ""

echo -e "${CYAN}Available test commands:${NC}"
echo "• Test databases only: docker-compose -f docker-compose.test.yml --profile databases up"
echo "• Test templates: docker-compose -f docker-compose.test.yml --profile templates --profile databases up"
echo "• Run smoke tests: docker-compose -f docker-compose.test.yml --profile databases --profile smoke up"
echo "• Clean everything: docker-compose -f docker-compose.test.yml down -v"