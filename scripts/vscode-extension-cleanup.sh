#!/bin/bash

# VS Code Extension Cleanup Script
# Removes non-essential global extensions while keeping core functionality

echo "VS Code Extension Cleanup Script"
echo "================================="
echo ""

# Backup current extensions
echo "📦 Backing up current extension list..."
code --list-extensions > ~/vscode-extensions-backup-$(date +%Y%m%d-%H%M%S).txt
echo "✅ Backup saved to ~/vscode-extensions-backup-*.txt"
echo ""

# Extensions to keep (DO NOT REMOVE)
KEEP_EXTENSIONS=(
    "ms-vscode-remote.remote-wsl"
    "ms-azuretools.vscode-docker"
    "ms-vscode-remote.remote-containers"
    "editorconfig.editorconfig"
    "eamodio.gitlens"
    "gruntfuggly.todo-tree"
    "yzhang.markdown-all-in-one"
)

# Extensions to remove
REMOVE_EXTENSIONS=(
    # AI Assistants
    "anthropic.claude-code"
    "google.geminicodeassist"
    "google.gemini-cli-vscode-ide-companion"
    "github.copilot"
    "github.copilot-chat"
    "codeium.codeium"
    "codeium.windsurfpyright"
    "coderabbit.coderabbit-vscode"
    "openai.chatgpt"
    "rooveterinaryinc.roo-cline"
    "rooveterinaryinc.roo-code-nightly"
    "kilocode.kilo-code"
    "saoudrizwan.claude-dev"
    "rexdotsh.claudesync"
    "kombai.kombai"
    
    # Language-specific
    "ms-python.python"
    "ms-python.vscode-pylance"
    "ms-python.debugpy"
    "ms-python.flake8"
    "ms-python.isort"
    "ms-python.vscode-python-envs"
    "golang.go"
    "redhat.java"
    "vscjava.vscode-java-debug"
    "vscjava.vscode-java-test"
    "ms-vscode.cpptools"
    "ms-vscode.cpptools-extension-pack"
    "ms-vscode.cpptools-themes"
    "ms-vscode.cmake-tools"
    "ms-dotnettools.csdevkit"
    "ms-dotnettools.csharp"
    "ms-dotnettools.vscode-dotnet-runtime"
    "dart-code.dart-code"
    
    # Cloud/Platform specific
    "ms-azuretools.azure-dev"
    "ms-azuretools.vscode-azure-github-copilot"
    "ms-azuretools.vscode-azure-mcp-server"
    "ms-azuretools.vscode-azureappservice"
    "ms-azuretools.vscode-azurecontainerapps"
    "ms-azuretools.vscode-azurefunctions"
    "ms-azuretools.vscode-azureresourcegroups"
    "ms-azuretools.vscode-azurestaticwebapps"
    "ms-azuretools.vscode-azurestorage"
    "ms-azuretools.vscode-azurevirtualmachines"
    "ms-azuretools.vscode-containers"
    "ms-azuretools.vscode-cosmosdb"
    "ms-vscode.vscode-node-azure-pack"
    "googlecloudtools.cloudcode"
    "googlecloudtools.firebase-dataconnect-vscode"
    "jsayol.firebase-explorer"
    "me-dutour-mathieu.vscode-firebase"
    "toba.vsfire"
    "ms-kubernetes-tools.vscode-kubernetes-tools"
    
    # Jupyter/Data Science
    "ms-toolsai.jupyter"
    "ms-toolsai.jupyter-keymap"
    "ms-toolsai.jupyter-renderers"
    "ms-toolsai.vscode-jupyter-cell-tags"
    "ms-toolsai.vscode-jupyter-powertoys"
    "ms-toolsai.vscode-jupyter-slideshow"
    
    # Testing tools
    "ms-playwright.playwright"
    "ms-azure-load-testing.microsoft-testing"
    "keploy.keployio"
    
    # Misc tools to move to project-specific
    "christian-kohler.npm-intellisense"
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode"
    "dotenv.dotenv-vscode"
    "graphql.vscode-graphql-syntax"
    "pflannery.vscode-versionlens"
    "redhat.vscode-yaml"
    "requesty.requesty"
    "teamsdevapp.ms-teams-vscode-extension"
    "teamsdevapp.vscode-ai-foundry"
    "visualstudioexptteam.intellicode-api-usage-examples"
    "visualstudioexptteam.vscodeintellicode"
    "ms-windows-ai-studio.windows-ai-studio"
    "ms-vscode.vscode-copilot-vision"
    "ms-vscode.vscode-github-issue-notebooks"
    "ms-vscode.vscode-typescript-next"
    "ms-vscode.live-server"
    "donjayamanne.githistory"
    "github.vscode-github-actions"
    "github.vscode-pull-request-github"
    "me-dutour-mathieu.vscode-github-actions"
    "davidanson.vscode-markdownlint"
)

echo "🔍 Analyzing extensions to remove..."
echo ""

# Count extensions
TOTAL_BEFORE=$(code --list-extensions | wc -l)
REMOVE_COUNT=${#REMOVE_EXTENSIONS[@]}

echo "📊 Current extensions: $TOTAL_BEFORE"
echo "📉 Extensions to remove: $REMOVE_COUNT"
echo "📈 Extensions to keep: ${#KEEP_EXTENSIONS[@]}"
echo ""

# Confirmation prompt
read -p "⚠️  This will remove $REMOVE_COUNT extensions. Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operation cancelled"
    exit 1
fi

echo ""
echo "🗑️  Removing extensions..."
echo ""

# Remove extensions
REMOVED=0
FAILED=0

for ext in "${REMOVE_EXTENSIONS[@]}"; do
    if code --list-extensions | grep -q "^$ext$"; then
        echo -n "  Removing $ext... "
        if code --uninstall-extension "$ext" 2>/dev/null; then
            echo "✅"
            ((REMOVED++))
        else
            echo "❌ Failed"
            ((FAILED++))
        fi
    fi
done

echo ""
echo "📊 Summary:"
echo "  ✅ Successfully removed: $REMOVED"
if [ $FAILED -gt 0 ]; then
    echo "  ❌ Failed to remove: $FAILED"
fi

TOTAL_AFTER=$(code --list-extensions | wc -l)
echo "  📈 Total extensions now: $TOTAL_AFTER (was $TOTAL_BEFORE)"
echo ""

echo "✨ Cleanup complete!"
echo ""
echo "💡 Next steps:"
echo "  1. Restart VS Code to apply changes"
echo "  2. Use dev containers for project-specific extensions"
echo "  3. Run 'cat ~/vscode-extensions-backup-*.txt' to see backup"
echo ""