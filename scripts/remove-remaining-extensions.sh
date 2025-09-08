#!/bin/bash

# Remove remaining non-essential extensions that had dependencies

echo "🧹 Removing remaining extensions with dependencies..."
echo ""

# First remove the dependents, then the dependencies
REMOVE_ORDER=(
    "ms-azure-load-testing.microsoft-testing"  # Depends on Copilot
    "ms-azuretools.vscode-azureresourcegroups" # Azure Resources
    "ms-azuretools.vscode-containers"          # Container Tools
    "github.copilot-chat"                      # Copilot Chat
    "github.copilot"                            # GitHub Copilot
    "google.geminicodeassist"                  # Gemini
    "ms-toolsai.jupyter"                       # Jupyter
    "ms-python.python"                         # Python
    "vscjava.vscode-java-debug"               # Java Debug
    "redhat.java"                              # Java
    "redhat.vscode-yaml"                       # YAML
)

for ext in "${REMOVE_ORDER[@]}"; do
    if code --list-extensions | grep -q "^$ext$"; then
        echo "Removing $ext..."
        code --uninstall-extension "$ext" --force 2>/dev/null || true
    fi
done

echo ""
echo "✅ Done! Remaining extensions:"
code --list-extensions | wc -l
code --list-extensions