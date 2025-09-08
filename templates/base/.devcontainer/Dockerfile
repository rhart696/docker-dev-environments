# Base development container with AI assistant support
ARG VARIANT="20-bookworm"
FROM mcr.microsoft.com/devcontainers/javascript-node:${VARIANT}

# Install additional OS packages
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        build-essential \
        curl \
        wget \
        jq \
        ripgrep \
        fd-find \
        bat \
        httpie \
        iptables \
        python3-pip \
        postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install global Node tools (minimal)
RUN npm install -g \
    npm@latest \
    pnpm \
    yarn \
    npm-check-updates

# Optional: Install Claude Code CLI (uncomment if needed)
# RUN npm install -g @anthropic/claude-cli

# Optional: Install Gemini CLI (uncomment if needed)
# RUN curl -fsSL https://gemini.google.com/cli/install.sh | bash \
#     && echo 'export PATH="$HOME/.gemini/bin:$PATH"' >> /home/vscode/.zshrc

# Create directories for configs
RUN mkdir -p /home/vscode/.config/claude \
    && mkdir -p /home/vscode/.config/gemini \
    && mkdir -p /home/vscode/.local/share \
    && chown -R vscode:vscode /home/vscode/.config \
    && chown -R vscode:vscode /home/vscode/.local

# Switch to non-root user
USER vscode

# Set up shell aliases and functions
RUN echo '# Dev Container Aliases' >> ~/.zshrc \
    && echo 'alias ll="ls -la"' >> ~/.zshrc \
    && echo 'alias gs="git status"' >> ~/.zshrc \
    && echo 'alias gp="git pull"' >> ~/.zshrc \
    && echo 'alias gc="git commit"' >> ~/.zshrc \
    && echo 'alias gco="git checkout"' >> ~/.zshrc \
    && echo 'alias docker-clean="docker system prune -af"' >> ~/.zshrc \
    && echo '' >> ~/.zshrc \
    && echo '# AI Assistant Helpers' >> ~/.zshrc \
    && echo 'alias claude-help="claude --help 2>/dev/null || echo \"Claude CLI not installed. Uncomment installation in Dockerfile.\""' >> ~/.zshrc \
    && echo 'alias gemini-help="gemini --help 2>/dev/null || echo \"Gemini CLI not installed. Uncomment installation in Dockerfile.\""' >> ~/.zshrc

# Set working directory
WORKDIR /workspace

# Keep container running
CMD ["sleep", "infinity"]