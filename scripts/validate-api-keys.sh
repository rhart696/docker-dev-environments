#!/bin/bash

# API Key Validation Script
# Validates that AI service API keys are properly configured and functional

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SECRETS_DIR="$HOME/.secrets"
CONFIG_DIR="$HOME/.config"

# Results tracking
CLAUDE_VALID=false
GEMINI_VALID=false
CODEIUM_VALID=false

echo -e "${BLUE}=== API Key Validation ===${NC}"
echo ""

# Function to validate Claude API key
validate_claude() {
    echo -e "${YELLOW}Validating Claude API key...${NC}"

    # Check for API key from various sources
    if command -v op &> /dev/null && op account get &> /dev/null; then
        # Try 1Password first
        API_KEY=$(op read "op://Private/Anthropic/api_key" 2>/dev/null || echo "")
    fi

    if [ -z "$API_KEY" ] && [ -f "$SECRETS_DIR/claude_api_key" ]; then
        API_KEY=$(cat "$SECRETS_DIR/claude_api_key")
    elif [ -z "$API_KEY" ] && [ -n "$CLAUDE_API_KEY" ]; then
        API_KEY="$CLAUDE_API_KEY"
    elif [ -z "$API_KEY" ] && [ -f "$CONFIG_DIR/claude/api_key" ]; then
        API_KEY=$(cat "$CONFIG_DIR/claude/api_key")
    fi

    if [ -z "$API_KEY" ]; then
        echo -e "${RED}❌ Claude API key not found${NC}"
        echo "  Expected locations:"
        echo "    - 1Password: op://Private/Anthropic/api_key"
        echo "    - $SECRETS_DIR/claude_api_key"
        echo "    - \$CLAUDE_API_KEY environment variable"
        echo "    - $CONFIG_DIR/claude/api_key"
        return 1
    fi
    
    # Test API key
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        "https://api.anthropic.com/v1/messages" \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "model": "claude-3-haiku-20240307",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "Hi"}]
        }' 2>/dev/null)
    
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "400" ]; then
        echo -e "${GREEN}✅ Claude API key is valid${NC}"
        CLAUDE_VALID=true
        return 0
    elif [ "$RESPONSE" = "401" ]; then
        echo -e "${RED}❌ Claude API key is invalid (Authentication failed)${NC}"
        return 1
    elif [ "$RESPONSE" = "429" ]; then
        echo -e "${YELLOW}⚠️  Claude API key is valid but rate limited${NC}"
        CLAUDE_VALID=true
        return 0
    else
        echo -e "${RED}❌ Claude API validation failed (HTTP $RESPONSE)${NC}"
        return 1
    fi
}

# Function to validate Gemini API key
validate_gemini() {
    echo -e "${YELLOW}Validating Gemini API key...${NC}"

    # Check for API key from various sources
    if command -v op &> /dev/null && op account get &> /dev/null; then
        # Try 1Password first
        API_KEY=$(op read "op://Private/Gemini/api_key" 2>/dev/null || op read "op://Private/Google Gemini/credential" 2>/dev/null || echo "")
    fi

    if [ -z "$API_KEY" ] && [ -f "$SECRETS_DIR/gemini_api_key" ]; then
        API_KEY=$(cat "$SECRETS_DIR/gemini_api_key")
    elif [ -z "$API_KEY" ] && [ -n "$GEMINI_API_KEY" ]; then
        API_KEY="$GEMINI_API_KEY"
    elif [ -z "$API_KEY" ] && [ -f "$CONFIG_DIR/gemini/api_key" ]; then
        API_KEY=$(cat "$CONFIG_DIR/gemini/api_key")
    fi

    if [ -z "$API_KEY" ]; then
        echo -e "${RED}❌ Gemini API key not found${NC}"
        echo "  Expected locations:"
        echo "    - 1Password: op://Private/Gemini/api_key or op://Private/Google Gemini/credential"
        echo "    - $SECRETS_DIR/gemini_api_key"
        echo "    - \$GEMINI_API_KEY environment variable"
        echo "    - $CONFIG_DIR/gemini/api_key"
        return 1
    fi
    
    # Test API key
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://generativelanguage.googleapis.com/v1beta/models?key=$API_KEY" 2>/dev/null)
    
    if [ "$RESPONSE" = "200" ]; then
        echo -e "${GREEN}✅ Gemini API key is valid${NC}"
        GEMINI_VALID=true
        return 0
    elif [ "$RESPONSE" = "400" ] || [ "$RESPONSE" = "403" ]; then
        echo -e "${RED}❌ Gemini API key is invalid${NC}"
        return 1
    elif [ "$RESPONSE" = "429" ]; then
        echo -e "${YELLOW}⚠️  Gemini API key is valid but rate limited${NC}"
        GEMINI_VALID=true
        return 0
    else
        echo -e "${RED}❌ Gemini API validation failed (HTTP $RESPONSE)${NC}"
        return 1
    fi
}

# Function to validate Codeium API key
validate_codeium() {
    echo -e "${YELLOW}Validating Codeium API key...${NC}"

    # Check for API key from various sources
    if command -v op &> /dev/null && op account get &> /dev/null; then
        # Try 1Password first
        API_KEY=$(op read "op://Private/Codeium/api_key" 2>/dev/null || echo "")
    fi

    if [ -z "$API_KEY" ] && [ -f "$SECRETS_DIR/codeium_api_key" ]; then
        API_KEY=$(cat "$SECRETS_DIR/codeium_api_key")
    elif [ -z "$API_KEY" ] && [ -n "$CODEIUM_API_KEY" ]; then
        API_KEY="$CODEIUM_API_KEY"
    fi

    if [ -z "$API_KEY" ]; then
        echo -e "${YELLOW}⚠️  Codeium API key not found (optional)${NC}"
        return 0
    fi
    
    # Codeium validation would go here
    # For now, just check if key exists and has proper format
    if [ -n "$API_KEY" ] && [ ${#API_KEY} -gt 20 ]; then
        echo -e "${GREEN}✅ Codeium API key format looks valid${NC}"
        CODEIUM_VALID=true
        return 0
    else
        echo -e "${RED}❌ Codeium API key format invalid${NC}"
        return 1
    fi
}

# Function to create API key template
create_api_key_template() {
    echo -e "${YELLOW}Creating API key template...${NC}"
    
    mkdir -p "$SECRETS_DIR"
    
    if [ ! -f "$SECRETS_DIR/README.md" ]; then
        cat > "$SECRETS_DIR/README.md" << 'EOF'
# API Keys Directory

This directory contains API keys for AI services used by the Docker Dev Environments.

## Setup Instructions

1. **Claude API Key**
   - Get your API key from: https://console.anthropic.com/
   - Save it to: `claude_api_key`
   - Command: `echo "your-api-key" > claude_api_key`

2. **Gemini API Key**
   - Get your API key from: https://makersuite.google.com/app/apikey
   - Save it to: `gemini_api_key`
   - Command: `echo "your-api-key" > gemini_api_key`

3. **Codeium API Key** (Optional)
   - Get your API key from: https://codeium.com/
   - Save it to: `codeium_api_key`
   - Command: `echo "your-api-key" > codeium_api_key`

## Security

- Set proper permissions: `chmod 600 *_api_key`
- Never commit these files to version control
- Add this directory to .gitignore

## Validation

Run the validation script to test your keys:
```bash
~/active-projects/docker-dev-environments/scripts/validate-api-keys.sh
```
EOF
        echo -e "${GREEN}✅ Created API key template at $SECRETS_DIR/README.md${NC}"
    fi
}

# Function to setup API keys interactively
setup_api_keys() {
    echo ""
    echo -e "${BLUE}=== API Key Setup ===${NC}"
    echo ""
    
    # Claude setup
    if [ ! -f "$SECRETS_DIR/claude_api_key" ] && [ -z "$CLAUDE_API_KEY" ]; then
        echo -e "${YELLOW}Claude API key not found.${NC}"
        echo "Get your key from: https://console.anthropic.com/"
        read -p "Enter Claude API key (or press Enter to skip): " CLAUDE_KEY
        if [ -n "$CLAUDE_KEY" ]; then
            echo "$CLAUDE_KEY" > "$SECRETS_DIR/claude_api_key"
            chmod 600 "$SECRETS_DIR/claude_api_key"
            echo -e "${GREEN}✅ Claude API key saved${NC}"
        fi
    fi
    
    # Gemini setup
    if [ ! -f "$SECRETS_DIR/gemini_api_key" ] && [ -z "$GEMINI_API_KEY" ]; then
        echo -e "${YELLOW}Gemini API key not found.${NC}"
        echo "Get your key from: https://makersuite.google.com/app/apikey"
        read -p "Enter Gemini API key (or press Enter to skip): " GEMINI_KEY
        if [ -n "$GEMINI_KEY" ]; then
            echo "$GEMINI_KEY" > "$SECRETS_DIR/gemini_api_key"
            chmod 600 "$SECRETS_DIR/gemini_api_key"
            echo -e "${GREEN}✅ Gemini API key saved${NC}"
        fi
    fi
    
    # Codeium setup (optional)
    if [ ! -f "$SECRETS_DIR/codeium_api_key" ] && [ -z "$CODEIUM_API_KEY" ]; then
        echo -e "${YELLOW}Codeium API key not found (optional).${NC}"
        echo "Get your key from: https://codeium.com/"
        read -p "Enter Codeium API key (or press Enter to skip): " CODEIUM_KEY
        if [ -n "$CODEIUM_KEY" ]; then
            echo "$CODEIUM_KEY" > "$SECRETS_DIR/codeium_api_key"
            chmod 600 "$SECRETS_DIR/codeium_api_key"
            echo -e "${GREEN}✅ Codeium API key saved${NC}"
        fi
    fi
}

# Main execution
main() {
    # Check if --setup flag is provided
    if [ "$1" = "--setup" ]; then
        create_api_key_template
        setup_api_keys
        echo ""
    fi
    
    # Validate API keys
    echo -e "${BLUE}Validating API Keys...${NC}"
    echo ""
    
    # Validate each service
    validate_claude || true
    echo ""
    validate_gemini || true
    echo ""
    validate_codeium || true
    echo ""
    
    # Summary
    echo -e "${BLUE}=== Validation Summary ===${NC}"
    
    if [ "$CLAUDE_VALID" = true ]; then
        echo -e "${GREEN}✅ Claude: Valid${NC}"
    else
        echo -e "${RED}❌ Claude: Invalid or not configured${NC}"
    fi
    
    if [ "$GEMINI_VALID" = true ]; then
        echo -e "${GREEN}✅ Gemini: Valid${NC}"
    else
        echo -e "${RED}❌ Gemini: Invalid or not configured${NC}"
    fi
    
    if [ "$CODEIUM_VALID" = true ]; then
        echo -e "${GREEN}✅ Codeium: Valid${NC}"
    else
        echo -e "${YELLOW}⚠️  Codeium: Not configured (optional)${NC}"
    fi
    
    echo ""
    
    # Provide next steps
    if [ "$CLAUDE_VALID" = false ] || [ "$GEMINI_VALID" = false ]; then
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Run with --setup flag to configure API keys interactively:"
        echo "   $0 --setup"
        echo ""
        echo "2. Or manually create API key files in $SECRETS_DIR/"
        echo ""
        echo "3. Get API keys from:"
        echo "   - Claude: https://console.anthropic.com/"
        echo "   - Gemini: https://makersuite.google.com/app/apikey"
        echo "   - Codeium: https://codeium.com/ (optional)"
        exit 1
    else
        echo -e "${GREEN}All required API keys are valid and ready to use!${NC}"
        exit 0
    fi
}

# Run main function
main "$@"