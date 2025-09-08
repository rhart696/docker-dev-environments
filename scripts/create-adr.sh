#!/bin/bash

# ADR Creation Script
# Automatically creates and tracks Architecture Decision Records

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
ADR_DIR="docs/adr"
TEMPLATE_FILE="$ADR_DIR/template.md"

# Get next ADR number
get_next_number() {
    local last_adr=$(ls $ADR_DIR/*.md 2>/dev/null | grep -E '[0-9]{4}' | sort -V | tail -1)
    if [ -z "$last_adr" ]; then
        echo "0001"
    else
        local last_num=$(basename "$last_adr" | grep -oE '^[0-9]{4}')
        printf "%04d" $((10#$last_num + 1))
    fi
}

# Create ADR
create_adr() {
    local title="$1"
    local status="${2:-Proposed}"
    local tags="${3:-architecture}"
    
    # Generate filename
    local number=$(get_next_number)
    local filename_title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
    local filename="$ADR_DIR/${number}-${filename_title}.md"
    
    echo -e "${BLUE}Creating ADR-${number}: ${title}${NC}"
    
    # Create ADR content
    cat > "$filename" << EOF
# ADR-${number}: ${title}

Date: $(date +%Y-%m-%d)
Status: ${status}
Deciders: [List stakeholders]
Tags: ${tags}

## Context

[Describe the context and problem statement. What is the issue that we're seeing that motivates this decision or change?]

## Decision

[Describe the proposed solution and the decision that was made.]

## Consequences

### Positive
- [Positive consequence 1]
- [Positive consequence 2]

### Negative
- [Negative consequence 1]
- [Negative consequence 2]

## Alternatives Considered

1. **[Alternative 1]**
   - Pros: [...]
   - Cons: [...]

2. **[Alternative 2]**
   - Pros: [...]
   - Cons: [...]

## Implementation

[How will this be implemented? Include key milestones.]

## Validation

[How will we know if this decision was successful?]

## References

- [Link to relevant documentation]
- [Link to related ADRs]
EOF

    echo -e "${GREEN}✅ Created: $filename${NC}"
    
    # Update README index
    update_readme "$number" "$title" "$status" "$(date +%Y-%m-%d)" "$tags"
    
    # Git operations
    if command -v git &> /dev/null && [ -d .git ]; then
        git add "$filename"
        git add "$ADR_DIR/README.md"
        echo -e "${YELLOW}Ready to commit with: git commit -m \"docs: ADR-${number} ${title}\"${NC}"
    fi
    
    echo "$filename"
}

# Update README index
update_readme() {
    local number="$1"
    local title="$2"
    local status="$3"
    local date="$4"
    local tags="$5"
    
    local readme="$ADR_DIR/README.md"
    local filename_title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
    local link="${number}-${filename_title}.md"
    
    # Add to table (before the closing of the Index section)
    local new_row="| [ADR-${number}](${link}) | ${title} | ${status} | ${date} | ${tags} |"
    
    # Insert the new row into README
    if grep -q "| \[ADR-${number}\]" "$readme"; then
        echo "ADR-${number} already in index"
    else
        # Add to end of table
        sed -i "/^## Creating New ADRs/i ${new_row}" "$readme"
        echo -e "${GREEN}✅ Updated README index${NC}"
    fi
}

# Interactive mode
interactive_mode() {
    echo -e "${BLUE}=== ADR Creation Wizard ===${NC}"
    echo ""
    
    read -p "Title: " title
    
    echo "Status options: Proposed, Accepted, Deprecated, Superseded"
    read -p "Status [Proposed]: " status
    status=${status:-Proposed}
    
    read -p "Tags (comma-separated) [architecture]: " tags
    tags=${tags:-architecture}
    
    echo ""
    echo "Context (press Ctrl+D when done):"
    context=$(cat)
    
    echo ""
    echo "Decision (press Ctrl+D when done):"
    decision=$(cat)
    
    # Create ADR with provided content
    local filename=$(create_adr "$title" "$status" "$tags")
    
    # Update with actual content
    if [ -n "$context" ] || [ -n "$decision" ]; then
        sed -i "s|\[Describe the context.*\]|$context|" "$filename"
        sed -i "s|\[Describe the proposed.*\]|$decision|" "$filename"
    fi
    
    echo -e "${GREEN}✅ ADR created successfully!${NC}"
    echo "Edit: $filename"
}

# Auto-generate from git commits
auto_generate() {
    echo -e "${BLUE}Analyzing recent changes for decision patterns...${NC}"
    
    # Look for significant commits
    git log --oneline -n 20 | while read -r commit; do
        if echo "$commit" | grep -iE "(add|implement|switch|migrate|adopt|replace|remove) "; then
            echo "Potential ADR: $commit"
        fi
    done
    
    echo -e "${YELLOW}Review these commits and create ADRs for significant decisions${NC}"
}

# Main script
main() {
    # Ensure ADR directory exists
    mkdir -p "$ADR_DIR"
    
    case "${1:-}" in
        --interactive|-i)
            interactive_mode
            ;;
        --auto|-a)
            auto_generate
            ;;
        --help|-h)
            echo "Usage: $0 [options] [title] [status] [tags]"
            echo ""
            echo "Options:"
            echo "  -i, --interactive  Interactive mode with prompts"
            echo "  -a, --auto        Auto-detect from git commits"
            echo "  -h, --help        Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 \"Use Docker for environments\""
            echo "  $0 \"Adopt TDD\" Accepted testing,tdd"
            echo "  $0 --interactive"
            ;;
        "")
            echo "Error: Title required"
            echo "Usage: $0 \"Title of Decision\""
            exit 1
            ;;
        *)
            create_adr "$@"
            ;;
    esac
}

main "$@"