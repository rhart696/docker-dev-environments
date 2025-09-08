FROM mcr.microsoft.com/devcontainers/universal:2-linux

# Install additional tools
RUN apt-get update && apt-get install -y \
    postgresql-client \
    redis-tools \
    httpie \
    && rm -rf /var/lib/apt/lists/*

# Install global npm packages
RUN npm install -g \
    @nestjs/cli \
    create-react-app \
    next \
    prisma \
    vercel

# Install Python packages
RUN pip install \
    fastapi \
    django \
    sqlalchemy \
    alembic

WORKDIR /workspace