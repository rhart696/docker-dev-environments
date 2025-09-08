#!/bin/bash

echo "🔧 Fixing VS Code Remote Extension Host Crashes"
echo "=============================================="
echo ""

# Kill any running VS Code processes
echo "📍 Step 1: Stopping VS Code processes..."
pkill -f "vscode-server" 2>/dev/null
sleep 2

# Clear VS Code cache and problematic extension data
echo "📍 Step 2: Clearing extension cache and corrupt data..."

# Remove extension host logs to force fresh start
rm -rf ~/.vscode-server/data/logs/*/exthost*

# Clear extension cache
rm -rf ~/.vscode-server/extensions/.obsolete
rm -rf ~/.vscode-server/extensions/.vscode-cpptools-refactor
rm -rf ~/.vscode-server/extensions/ms-vscode.cpptools-themes*

# Remove any Windsurf/Codeium remnants
echo "📍 Step 3: Removing problematic extension remnants..."
rm -rf ~/.vscode-server/extensions/codeium.windsurfpyright* 2>/dev/null
rm -rf ~/.vscode-server/extensions/Anthropic.claude-code* 2>/dev/null
rm -rf ~/.vscode-server/extensions/openai.chatgpt* 2>/dev/null
rm -rf ~/.vscode-server/extensions/GitHub.copilot* 2>/dev/null
rm -rf ~/.vscode-server/extensions/kombai.kombai* 2>/dev/null

# Clear VS Code workspace storage for removed extensions
echo "📍 Step 4: Clearing workspace storage..."
find ~/.vscode-server -name "state.vscdb" -exec rm {} \; 2>/dev/null
find ~/.vscode-server -name "state.vscdb.backup" -exec rm {} \; 2>/dev/null

# Reset extension database
echo "📍 Step 5: Resetting extension database..."
rm -f ~/.vscode-server/data/User/globalStorage/state.vscdb*

# Clear any extension-specific caches
echo "📍 Step 6: Clearing extension-specific caches..."
rm -rf ~/.vscode-server/data/CachedExtensions
rm -rf ~/.vscode-server/data/CachedExtensionVSIXs

# Clean up extension manifests
echo "📍 Step 7: Cleaning extension manifests..."
find ~/.vscode-server/extensions -name "package.json" -path "*/.obsolete/*" -delete 2>/dev/null

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "🔄 Next steps:"
echo "  1. Close all VS Code windows"
echo "  2. Wait 10 seconds"
echo "  3. Reopen VS Code"
echo ""
echo "💡 If crashes persist, run:"
echo "  code --list-extensions --show-versions"
echo "  to check for version conflicts"