#!/bin/bash

# Verify Claude and Gemini CLI tools are still available

echo "🔍 Checking AI CLI Tools Status"
echo "================================"
echo ""

# Check Claude CLI
echo "📘 Claude Code CLI:"
if command -v claude &> /dev/null; then
    echo "✅ Claude CLI is installed"
    claude --version 2>/dev/null || echo "   Version check requires API key"
else
    echo "❌ Claude CLI not found"
    echo "   Install with: npm install -g @anthropic/claude-cli"
fi

echo ""

# Check Gemini CLI
echo "💎 Gemini CLI:"
if command -v gemini &> /dev/null; then
    echo "✅ Gemini CLI is installed"
    gemini --version 2>/dev/null || echo "   Version check may require setup"
elif [ -f "$HOME/.gemini/bin/gemini" ]; then
    echo "✅ Gemini CLI found at ~/.gemini/bin/gemini"
    echo "   Add to PATH: export PATH=\"\$HOME/.gemini/bin:\$PATH\""
else
    echo "❌ Gemini CLI not found"
    echo "   Install with: curl -fsSL https://gemini.google.com/cli/install.sh | bash"
fi

echo ""

# Check npm global packages
echo "📦 NPM Global Packages:"
npm list -g --depth=0 2>/dev/null | grep -E "(claude|gemini|@anthropic)" || echo "   No AI CLI tools in npm global"

echo ""

# Check Docker
echo "🐳 Docker Status:"
docker --version
docker ps &>/dev/null && echo "✅ Docker daemon is running" || echo "⚠️  Docker daemon not running"

echo ""
echo "💡 These CLI tools work independently of VS Code extensions!"
echo "   You can use them in any terminal or dev container."