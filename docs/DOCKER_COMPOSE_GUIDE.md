# 🐳 The Complete Docker Compose Guide

> A comprehensive guide to understanding, using, and mastering Docker Compose for development environments

## Table of Contents

1. [What is Docker Compose?](#what-is-docker-compose)
2. [Why Use Docker Compose?](#why-use-docker-compose)
3. [When NOT to Use Docker Compose](#when-not-to-use-docker-compose)
4. [Core Concepts](#core-concepts)
5. [Real-World Use Cases](#real-world-use-cases)
6. [Docker Compose vs Alternatives](#docker-compose-vs-alternatives)
7. [Practical Workflows](#practical-workflows)
8. [How-To Guides](#how-to-guides)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)
11. [Advanced Patterns](#advanced-patterns)

---

## What is Docker Compose?

Docker Compose is a **declarative orchestration tool** that lets you define and run multi-container Docker applications using a simple YAML file. Think of it as "infrastructure as code" for your local development environment.

### The Elevator Pitch
Instead of running multiple `docker run` commands with complex parameters, you define everything in a `docker-compose.yml` file and run `docker-compose up`. All your services, networks, volumes, and configurations are managed together as a single application stack.

### Key Components

```yaml
version: '3.8'  # Compose file format version

services:       # Your containers
  web:
    build: .
    ports:
      - "3000:3000"
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - db-data:/var/lib/postgresql/data

volumes:        # Persistent storage
  db-data:

networks:       # Container networking
  default:
    driver: bridge
```

---

## Why Use Docker Compose?

### ✅ **Benefits**

#### 1. **Declarative Configuration**
Define your entire stack in version-controlled YAML files:
```yaml
# Everything is code - reviewable, trackable, shareable
services:
  app:
    image: node:20
    environment:
      NODE_ENV: development
```

#### 2. **Single Command Operations**
```bash
docker-compose up     # Start everything
docker-compose down   # Stop everything
docker-compose logs   # View all logs
docker-compose ps     # Check status
```

#### 3. **Service Dependencies**
Automatically manage startup order:
```yaml
services:
  web:
    depends_on:
      - db
      - redis
    # Web waits for db and redis to start
```

#### 4. **Development-Production Parity**
Use the same compose file with overrides:
```bash
# Development
docker-compose up

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

#### 5. **Isolated Environments**
Each project gets its own network and namespace:
```bash
myproject_web_1      # Container names are prefixed
myproject_db_1       # No conflicts between projects
myproject_default    # Isolated network
```

#### 6. **Easy Scaling**
```bash
docker-compose up --scale worker=3  # Run 3 worker instances
```

#### 7. **Simplified Networking**
Services can reference each other by name:
```python
# In your app code
redis_client = Redis(host='redis')  # Not localhost:6379
db_url = 'postgresql://user:pass@postgres:5432/db'
```

---

## When NOT to Use Docker Compose

### ❌ **Anti-Patterns**

#### 1. **Simple Single-Container Apps**
```bash
# Overkill for a simple script
python app.py  # Just run it directly

# Or use plain Docker if needed
docker run -it python:3.11 python app.py
```

#### 2. **Production Orchestration**
Docker Compose is **NOT for production clusters**:
- No auto-scaling across machines
- No self-healing
- No rolling updates
- No secrets management

**Use instead**: Kubernetes, Docker Swarm, ECS, or managed services

#### 3. **Stateless Microservices in Production**
For production microservices, use:
- **Kubernetes**: Industry standard
- **Cloud Run/Lambda**: Serverless
- **ECS/Fargate**: AWS native

#### 4. **Learning Projects**
When learning a new language/framework, start simple:
```bash
# Start with this
npm start

# Not this (unless you need a database)
docker-compose up
```

#### 5. **CI/CD Pipelines**
GitHub Actions, GitLab CI, etc. have better native solutions:
```yaml
# GitHub Actions - use service containers
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_PASSWORD: postgres
```

---

## Core Concepts

### Services
A service is a container configuration that can be instantiated one or more times:
```yaml
services:
  web:
    image: nginx:alpine    # Use an image
    build: ./frontend      # Or build from Dockerfile
    restart: unless-stopped
    deploy:
      replicas: 2          # Run 2 instances
```

### Networks
Compose creates isolated networks for inter-service communication:
```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access

services:
  web:
    networks:
      - frontend
      - backend
  db:
    networks:
      - backend  # Only accessible from backend network
```

### Volumes
Persist data and share files between containers:
```yaml
volumes:
  db-data:           # Named volume (managed by Docker)

services:
  db:
    volumes:
      - db-data:/var/lib/postgresql/data     # Named volume
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro  # Bind mount
      - type: tmpfs
        target: /tmp  # Temporary filesystem
```

### Environment Variables
Multiple ways to set them:
```yaml
services:
  app:
    # Inline
    environment:
      - NODE_ENV=development
      - DB_HOST=postgres

    # From file
    env_file:
      - .env
      - .env.local

    # From host
    environment:
      - USER  # Pass through from host
```

### Profiles
Conditionally include services:
```yaml
services:
  web:
    # Always runs
    image: nginx

  debug:
    profiles: ["debug"]  # Only runs with --profile debug
    image: busybox

  test:
    profiles: ["test"]   # Only runs with --profile test
    image: pytest
```

---

## Real-World Use Cases

### 🏗️ **1. Full-Stack Web Application**

**Scenario**: React frontend, Node.js API, PostgreSQL database, Redis cache

```yaml
version: '3.8'

services:
  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:4000
    volumes:
      - ./frontend:/app
      - /app/node_modules  # Anonymous volume for node_modules
    command: npm start

  api:
    build: ./backend
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    volumes:
      - ./backend:/app
      - /app/node_modules

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=myapp
    volumes:
      - postgres-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  adminer:
    image: adminer
    ports:
      - "8080:8080"
    depends_on:
      - postgres

volumes:
  postgres-data:
```

### 📊 **2. Data Science Environment**

**Scenario**: Jupyter, PostgreSQL, MinIO (S3), Spark

```yaml
version: '3.8'

services:
  jupyter:
    image: jupyter/datascience-notebook
    ports:
      - "8888:8888"
    environment:
      - JUPYTER_ENABLE_LAB=yes
    volumes:
      - ./notebooks:/home/jovyan/work
      - ./data:/home/jovyan/data
    command: start-notebook.sh --NotebookApp.token=''

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_PASSWORD=postgres
    volumes:
      - ./data/postgres:/var/lib/postgresql/data

  minio:
    image: minio/minio
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      - MINIO_ROOT_USER=minioadmin
      - MINIO_ROOT_PASSWORD=minioadmin
    command: server /data --console-address ":9001"
    volumes:
      - ./data/minio:/data

  spark:
    image: bitnami/spark:3
    environment:
      - SPARK_MODE=master
    ports:
      - "8081:8080"
      - "7077:7077"
```

### 🧪 **3. Microservices Development**

**Scenario**: Multiple services with service mesh

```yaml
version: '3.8'

services:
  gateway:
    build: ./gateway
    ports:
      - "80:80"
    depends_on:
      - auth-service
      - user-service
      - product-service

  auth-service:
    build: ./services/auth
    environment:
      - JWT_SECRET=${JWT_SECRET}
      - REDIS_URL=redis://redis:6379

  user-service:
    build: ./services/users
    environment:
      - DATABASE_URL=postgresql://postgres:5432/users
    depends_on:
      - postgres

  product-service:
    build: ./services/products
    environment:
      - MONGODB_URI=mongodb://mongo:27017/products
    depends_on:
      - mongo

  postgres:
    image: postgres:15
    volumes:
      - postgres-data:/var/lib/postgresql/data

  mongo:
    image: mongo:7
    volumes:
      - mongo-data:/data/db

  redis:
    image: redis:7-alpine

  rabbitmq:
    image: rabbitmq:3-management
    ports:
      - "15672:15672"  # Management UI

volumes:
  postgres-data:
  mongo-data:
```

### 🔬 **4. Testing Environment**

**Scenario**: E2E tests with Selenium Grid

```yaml
version: '3.8'

services:
  app:
    build: .
    environment:
      - NODE_ENV=test
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=test

  selenium-hub:
    image: selenium/hub:4
    ports:
      - "4444:4444"

  chrome:
    image: selenium/node-chrome:4
    depends_on:
      - selenium-hub
    environment:
      - SE_EVENT_BUS_HOST=selenium-hub
      - SE_EVENT_BUS_PUBLISH_PORT=4442
      - SE_EVENT_BUS_SUBSCRIBE_PORT=4443
    deploy:
      replicas: 2

  firefox:
    image: selenium/node-firefox:4
    depends_on:
      - selenium-hub
    environment:
      - SE_EVENT_BUS_HOST=selenium-hub
      - SE_EVENT_BUS_PUBLISH_PORT=4442
      - SE_EVENT_BUS_SUBSCRIBE_PORT=4443

  tests:
    build: ./e2e
    depends_on:
      - app
      - selenium-hub
    environment:
      - SELENIUM_HUB=http://selenium-hub:4444
      - APP_URL=http://app:3000
    command: npm test
```

---

## Docker Compose vs Alternatives

### **Docker Compose vs Kubernetes**

| Aspect | Docker Compose | Kubernetes |
|--------|---------------|------------|
| **Complexity** | Simple YAML | Complex manifests |
| **Learning Curve** | Hours | Weeks/Months |
| **Use Case** | Local dev | Production clusters |
| **Scaling** | Single machine | Multi-node clusters |
| **Self-healing** | No | Yes |
| **Service Discovery** | Basic (DNS) | Advanced |
| **Secrets** | Basic | Advanced |
| **Setup Time** | 1 minute | Hours/Days |

**When to use Kubernetes**: Production, need auto-scaling, multi-region, enterprise

### **Docker Compose vs Vagrant**

| Aspect | Docker Compose | Vagrant |
|--------|---------------|---------|
| **Technology** | Containers | Virtual Machines |
| **Resource Usage** | Light (MB) | Heavy (GB) |
| **Startup Time** | Seconds | Minutes |
| **Isolation** | Process-level | Full OS |
| **Use Case** | Apps | Full systems |

**When to use Vagrant**: Need full OS, kernel development, testing OS-level features

### **Docker Compose vs Cloud Services**

| Aspect | Docker Compose | Cloud (RDS, Cloud Run, etc.) |
|--------|---------------|------------------------------|
| **Cost** | Free (local) | Pay per use |
| **Management** | You manage | Fully managed |
| **Internet** | Works offline | Requires internet |
| **Data** | Local | Cloud storage |
| **Scaling** | Manual | Automatic |

**When to use Cloud**: Production, need managed services, team collaboration

### **Docker Compose vs Dev Containers**

| Aspect | Docker Compose | VS Code Dev Containers |
|--------|---------------|------------------------|
| **IDE Integration** | Any editor | VS Code only |
| **Configuration** | docker-compose.yml | devcontainer.json |
| **Multi-service** | Native | Via Docker Compose |
| **Extensions** | N/A | Auto-installed |
| **Use Case** | Any development | VS Code development |

**Best Practice**: Use Dev Containers WITH Docker Compose for VS Code projects

---

## Practical Workflows

### 🔄 **Daily Development Workflow**

```bash
# Morning: Start your stack
cd myproject
docker-compose up -d
docker-compose logs -f app  # Watch app logs

# During development
docker-compose exec app bash  # Shell into container
docker-compose restart app     # Restart after changes

# Debugging
docker-compose logs db         # Check database logs
docker-compose ps              # See what's running
docker-compose top             # See processes

# End of day
docker-compose down            # Stop everything
```

### 🧹 **Clean Slate Workflow**

```bash
# Nuclear option - remove everything
docker-compose down -v         # Stop and remove volumes
docker system prune -a         # Clean all unused images
docker volume prune            # Clean unused volumes

# Fresh start
docker-compose build --no-cache
docker-compose up
```

### 🐛 **Debugging Workflow**

```bash
# 1. Check if services are running
docker-compose ps

# 2. Check logs
docker-compose logs service-name
docker-compose logs --tail=50 -f service-name

# 3. Shell into container
docker-compose exec service-name bash
# Inside container:
ping other-service  # Test networking
env | grep DB       # Check environment
curl http://other-service:port  # Test connectivity

# 4. Inspect networking
docker network ls
docker network inspect myproject_default

# 5. Check resource usage
docker stats
docker-compose top
```

### 🚀 **Deployment Workflow**

```bash
# Development
docker-compose up

# Staging (with override)
docker-compose -f docker-compose.yml -f docker-compose.staging.yml up

# Production build
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build
docker-compose -f docker-compose.yml -f docker-compose.prod.yml push
```

---

## How-To Guides

### 📝 **How to Add a New Service**

1. **Edit docker-compose.yml**:
```yaml
services:
  # Existing services...

  newservice:
    image: newservice:latest
    environment:
      - CONFIG=value
    depends_on:
      - db
    ports:
      - "8000:8000"
```

2. **Update dependent services**:
```yaml
services:
  app:
    environment:
      - NEWSERVICE_URL=http://newservice:8000
    depends_on:
      - db
      - newservice  # Add dependency
```

3. **Restart stack**:
```bash
docker-compose down
docker-compose up
```

### 🔐 **How to Handle Secrets**

**Option 1: Environment Files**
```bash
# .env (git-ignored)
DB_PASSWORD=supersecret
API_KEY=abc123

# docker-compose.yml
services:
  app:
    env_file: .env
```

**Option 2: Docker Secrets (Swarm mode)**
```yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt

services:
  app:
    secrets:
      - db_password
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
```

**Option 3: 1Password Integration**
```yaml
# docker-compose.override.yml
services:
  app:
    environment:
      - DB_PASSWORD=${DB_PASSWORD}  # Set via: op run --env-file=".env" -- docker-compose up
```

### 🔄 **How to Update a Service**

**Update image version**:
```yaml
services:
  db:
    image: postgres:15  # Changed from postgres:14
```

**Pull and restart**:
```bash
docker-compose pull db
docker-compose up -d db  # Recreates just the db service
```

**For custom builds**:
```bash
docker-compose build --no-cache service-name
docker-compose up -d service-name
```

### 📊 **How to Backup Data**

**Database backup**:
```bash
# PostgreSQL
docker-compose exec postgres pg_dump -U user dbname > backup.sql

# MongoDB
docker-compose exec mongo mongodump --out /backup
docker cp myproject_mongo_1:/backup ./mongo-backup

# Redis
docker-compose exec redis redis-cli SAVE
docker cp myproject_redis_1:/data/dump.rdb ./redis-backup.rdb
```

**Volume backup**:
```bash
# Stop service
docker-compose stop db

# Backup volume
docker run --rm \
  -v myproject_db-data:/source \
  -v $(pwd):/backup \
  alpine tar czf /backup/db-backup.tar.gz -C /source .

# Restart service
docker-compose start db
```

### 🎯 **How to Debug Connection Issues**

**Test from app container**:
```bash
# Shell into app
docker-compose exec app bash

# Test DNS resolution
nslookup postgres
ping postgres

# Test port connectivity
nc -zv postgres 5432
telnet postgres 5432

# Test with curl (for HTTP services)
curl http://api:3000/health

# Check environment
env | grep -E "DB|DATABASE|POSTGRES"
```

**Check network configuration**:
```bash
# List networks
docker network ls

# Inspect network
docker network inspect myproject_default

# See container's network settings
docker inspect myproject_app_1 | grep -A 10 NetworkMode
```

### 🔧 **How to Override Settings**

**Development overrides**:
```yaml
# docker-compose.override.yml (auto-loaded)
services:
  app:
    volumes:
      - ./src:/app/src  # Hot reload
    environment:
      - DEBUG=true
    command: npm run dev  # Override production command
```

**Environment-specific**:
```bash
# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up

# Testing
docker-compose -f docker-compose.yml -f docker-compose.test.yml up
```

---

## Best Practices

### ✅ **DO's**

#### 1. **Use Specific Versions**
```yaml
# Good
image: postgres:15-alpine

# Bad
image: postgres:latest
image: postgres
```

#### 2. **Set Resource Limits**
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

#### 3. **Use Health Checks**
```yaml
services:
  api:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

#### 4. **Order Dependencies**
```yaml
services:
  app:
    depends_on:
      db:
        condition: service_healthy  # Wait for health check
      redis:
        condition: service_started
```

#### 5. **Use Named Volumes**
```yaml
# Good - managed by Docker
volumes:
  db-data:

services:
  db:
    volumes:
      - db-data:/var/lib/postgresql/data

# Less ideal - bind mount
services:
  db:
    volumes:
      - ./data:/var/lib/postgresql/data
```

#### 6. **Separate Concerns**
```yaml
# docker-compose.yml - base configuration
# docker-compose.override.yml - development overrides
# docker-compose.prod.yml - production settings
# docker-compose.test.yml - test configuration
```

### ❌ **DON'Ts**

#### 1. **Don't Use Latest Tags**
```yaml
# Bad - unpredictable
image: node:latest

# Good - predictable
image: node:20.11.0-alpine
```

#### 2. **Don't Hardcode Secrets**
```yaml
# Bad
environment:
  - DB_PASSWORD=mysecretpassword

# Good
environment:
  - DB_PASSWORD=${DB_PASSWORD}
env_file:
  - .env
```

#### 3. **Don't Expose Unnecessary Ports**
```yaml
# Bad - exposes database to host
services:
  db:
    ports:
      - "5432:5432"

# Good - only accessible within Docker network
services:
  db:
    # No ports mapping, accessed via service name
```

#### 4. **Don't Ignore the Build Context**
```yaml
# Bad - sends entire directory
build: .

# Good - specific context
build:
  context: ./app
  dockerfile: Dockerfile
```

---

## Troubleshooting

### Common Issues and Solutions

#### **Issue: "Cannot connect to database"**
```bash
# Check if database is running
docker-compose ps

# Check logs
docker-compose logs db

# Test connection from app
docker-compose exec app bash
> ping postgres  # Should resolve
> nc -zv postgres 5432  # Should succeed

# Solution: Use service name, not localhost
# Wrong: postgresql://localhost:5432/db
# Right: postgresql://postgres:5432/db
```

#### **Issue: "Port already in use"**
```bash
# Find what's using the port
lsof -i :3000  # macOS/Linux
netstat -ano | findstr :3000  # Windows

# Solutions:
# 1. Stop the conflicting service
# 2. Change port mapping:
ports:
  - "3001:3000"  # Use different host port
```

#### **Issue: "Container keeps restarting"**
```bash
# Check logs
docker-compose logs service-name

# Common causes:
# 1. Missing environment variables
# 2. Database not ready (add health check)
# 3. Wrong command
# 4. Permission issues

# Debug interactively:
docker-compose run --rm service-name bash
```

#### **Issue: "Changes not reflected"**
```bash
# For code changes:
# 1. Check volume mounts
volumes:
  - ./src:/app/src  # Should be bind mount for development

# 2. Check if hot reload is enabled
command: npm run dev  # Not npm start

# For Dockerfile changes:
docker-compose build --no-cache service-name
docker-compose up -d service-name
```

#### **Issue: "Out of disk space"**
```bash
# Clean up
docker system prune -a --volumes  # WARNING: Removes everything
docker volume prune               # Remove unused volumes
docker image prune -a            # Remove unused images

# Check disk usage
docker system df
```

---

## Advanced Patterns

### 🎭 **Multi-Stage Environments**

```yaml
# Base configuration
# docker-compose.yml
services:
  app:
    image: myapp:${TAG:-latest}
    environment:
      - NODE_ENV=${NODE_ENV:-development}

# Development additions
# docker-compose.override.yml
services:
  app:
    build: .
    volumes:
      - ./src:/app/src
    command: npm run dev

# Production overrides
# docker-compose.prod.yml
services:
  app:
    restart: always
    command: npm start
    deploy:
      replicas: 3
```

### 🔀 **Service Mesh Pattern**

```yaml
services:
  # API Gateway
  gateway:
    image: traefik:2.10
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock

  # Microservices with labels
  auth:
    image: auth-service
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.auth.rule=PathPrefix(`/auth`)"
      - "traefik.http.services.auth.loadbalancer.server.port=3000"

  users:
    image: user-service
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.users.rule=PathPrefix(`/users`)"
    deploy:
      replicas: 2
```

### 🔄 **Blue-Green Deployment**

```yaml
services:
  app-blue:
    image: myapp:v1
    networks:
      - backend
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.local`)"
      - "traefik.http.services.app.loadbalancer.server.port=3000"
      - "deployment=blue"

  app-green:
    image: myapp:v2
    networks:
      - backend
    labels:
      - "traefik.enable=false"  # Disabled initially
      - "deployment=green"
    profiles:
      - green  # Only starts with --profile green

networks:
  backend:

# Switch: Enable green, disable blue
```

### 🧪 **Testing Pyramid**

```yaml
services:
  # Unit tests (fastest, most numerous)
  unit-tests:
    build:
      context: .
      target: test  # Multi-stage Dockerfile
    command: npm run test:unit
    profiles: ["test"]

  # Integration tests (slower, fewer)
  integration-tests:
    build: .
    command: npm run test:integration
    depends_on:
      - db
      - redis
    profiles: ["test"]
    environment:
      - DATABASE_URL=postgresql://postgres:5432/test

  # E2E tests (slowest, fewest)
  e2e-tests:
    build: ./e2e
    command: npm run test:e2e
    depends_on:
      - app
      - selenium
    profiles: ["test"]
    environment:
      - APP_URL=http://app:3000
      - SELENIUM_URL=http://selenium:4444

  # Test infrastructure
  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=test
    profiles: ["test"]

  selenium:
    image: selenium/standalone-chrome:4
    profiles: ["test"]

# Run: docker-compose --profile test up
```

### 📦 **Monorepo Pattern**

```yaml
# Root docker-compose.yml
services:
  frontend:
    build: ./packages/frontend
    ports:
      - "3000:3000"
    environment:
      - API_URL=http://api:4000

  api:
    build: ./packages/api
    ports:
      - "4000:4000"
    depends_on:
      - db
    environment:
      - DATABASE_URL=postgresql://postgres:5432/app

  admin:
    build: ./packages/admin
    ports:
      - "3001:3000"
    environment:
      - API_URL=http://api:4000

  shared:
    # Shared library container
    build: ./packages/shared
    volumes:
      - shared-lib:/app/dist
    command: npm run build:watch

  db:
    image: postgres:15

volumes:
  shared-lib:

# Each service can mount the shared volume
```

---

## Summary Cheat Sheet

### Essential Commands
```bash
docker-compose up -d                # Start in background
docker-compose down                  # Stop and remove
docker-compose restart service       # Restart specific service
docker-compose logs -f service       # Follow logs
docker-compose exec service bash     # Shell into service
docker-compose ps                    # List services
docker-compose build                 # Build images
docker-compose pull                  # Pull latest images
docker-compose config                # Validate and view config
```

### Quick Debugging
```bash
docker-compose logs service          # Check logs
docker-compose exec service env      # Check environment
docker network inspect project_default  # Check networking
docker stats                         # Check resources
docker-compose top                   # Check processes
```

### File Structure
```
myproject/
├── docker-compose.yml               # Base configuration
├── docker-compose.override.yml      # Development overrides (auto-loaded)
├── docker-compose.prod.yml          # Production overrides
├── .env                             # Environment variables (git-ignored)
├── .env.example                     # Environment template
└── services/
    ├── app/
    │   └── Dockerfile
    └── worker/
        └── Dockerfile
```

### Decision Tree
```
Need multiple services? → Yes → Docker Compose
                       ↓
                       No → Plain Docker or direct execution

Local development? → Yes → Docker Compose
                  ↓
                  No → Production? → Use Kubernetes/Cloud

Need service discovery? → Yes → Docker Compose (or K8s)
                       ↓
                       No → Individual containers

Team collaboration? → Yes → Docker Compose (consistent env)
                   ↓
                   No → Your choice
```

---

## 🎯 Key Takeaways

1. **Docker Compose is for local development orchestration**, not production
2. **Start simple** - you can always add services later
3. **Use version control** - your docker-compose.yml is code
4. **Keep secrets secret** - never commit passwords
5. **Name your volumes** - makes data management easier
6. **Use health checks** - ensures proper startup order
7. **Override wisely** - separate dev/prod configurations
8. **Clean up regularly** - Docker uses disk space
9. **Service names are DNS names** - use them for connections
10. **When in doubt, check the logs** - `docker-compose logs`

## 📚 Additional Resources

- [Official Docker Compose Documentation](https://docs.docker.com/compose/)
- [Compose File Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Compose Samples](https://github.com/docker/awesome-compose)
- [Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Networking in Compose](https://docs.docker.com/compose/networking/)

---

*Remember: Docker Compose is a tool, not a goal. Use it when it helps, skip it when it doesn't.*