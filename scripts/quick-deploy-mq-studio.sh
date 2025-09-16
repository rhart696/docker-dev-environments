#!/bin/bash

# Quick deployment script for MQ Studio project
# Uses the optimized auto-commit script that fixes all known issues

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MQ_STUDIO_PATH="$HOME/code/clients/website-mq-studio"

echo -e "${BLUE}=== Deploying Optimized Auto-Commit to MQ Studio ===${NC}"
echo ""

# Check if project exists
if [ ! -d "$MQ_STUDIO_PATH/.git" ]; then
    echo -e "${YELLOW}MQ Studio project not found at: $MQ_STUDIO_PATH${NC}"
    exit 1
fi

# Copy the optimized script
echo -e "${BLUE}Installing optimized auto-commit script...${NC}"
mkdir -p "$MQ_STUDIO_PATH/scripts"
cp "$(dirname "$0")/auto-commit-optimized.sh" "$MQ_STUDIO_PATH/scripts/auto-commit.sh"
chmod +x "$MQ_STUDIO_PATH/scripts/auto-commit.sh"

# Test hooks in that project
echo -e "${BLUE}Testing pre-commit hooks in MQ Studio...${NC}"
cd "$MQ_STUDIO_PATH"
./scripts/auto-commit.sh test

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo -e "${BLUE}Quick start commands:${NC}"
echo ""
echo "  cd $MQ_STUDIO_PATH"
echo ""
echo "  # If hooks are slow (based on test above):"
echo "  AUTO_COMMIT_NO_VERIFY=true ./scripts/auto-commit.sh daemon"
echo ""
echo "  # Or if hooks are fast:"
echo "  ./scripts/auto-commit.sh daemon"
echo ""
echo "  # Check status anytime:"
echo "  ./scripts/auto-commit.sh status"
echo ""
echo -e "${GREEN}The optimized script fixes all known issues:${NC}"
echo "  ✅ Argument parsing bug fixed"
echo "  ✅ Simplified but smart"
echo "  ✅ Reliable hook bypass"
echo "  ✅ Proper error handling"