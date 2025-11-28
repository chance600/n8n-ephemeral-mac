#!/bin/bash

# 📋 n8n Workflow Import Script
# Imports workflow JSON files from ./workflows/ directory into running n8n instance

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Emojis
CHECK="✅"
CROSS="❌"
WARN="⚠️"
INFO="ℹ️"
DOCS="📋"

# Configuration
CONTAINER_NAME="n8n-ephemeral"
WORKFLOWS_DIR="./workflows"
N8N_DATA_DIR="$HOME/.n8n"

echo -e "${BLUE}=========================================" 
echo -e "$DOCS n8n Workflow Import"
echo -e "=========================================${NC}\n"

# Function: Check if n8n is running
check_n8n_running() {
    echo -e "${BLUE}1️⃣  Checking n8n Status${NC}"
    
    if ! docker ps -q -f name=$CONTAINER_NAME > /dev/null 2>&1; then
        echo -e "${CROSS} ${RED}n8n is not running${NC}"
        echo "  Please start n8n first: ./start-n8n.sh or 'make start'"
        exit 1
    fi
    
    echo -e "${CHECK} ${GREEN}n8n is running${NC}\n"
}

# Function: Check workflows directory
check_workflows_dir() {
    echo -e "${BLUE}2️⃣  Checking Workflows Directory${NC}"
    
    if [ ! -d "$WORKFLOWS_DIR" ]; then
        echo -e "${CROSS} ${RED}Workflows directory not found${NC}: $WORKFLOWS_DIR"
        echo "  Create the directory and add workflow JSON files"
        exit 1
    fi
    
    echo -e "${CHECK} Found workflows directory: $WORKFLOWS_DIR\n"
}

# Function: Count workflow files
count_workflows() {
    local count=$(find "$WORKFLOWS_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo $count
}

# Function: Import workflows via file copy
import_workflows_file_copy() {
    echo -e "${BLUE}3️⃣  Importing Workflows${NC}"
    echo "Using direct file copy method..."
    echo ""
    
    local workflow_count=$(count_workflows)
    
    if [ "$workflow_count" -eq 0 ]; then
        echo -e "${WARN} ${YELLOW}No workflow files found${NC} in $WORKFLOWS_DIR"
        echo "  Add .json workflow files to import"
        exit 0
    fi
    
    echo "Found $workflow_count workflow file(s)"
    echo ""
    
    local imported=0
    local skipped=0
    
    # Create workflows directory in n8n data if it doesn't exist
    mkdir -p "$N8N_DATA_DIR/workflows"
    
    for workflow_file in "$WORKFLOWS_DIR"/*.json; do
        if [ -f "$workflow_file" ]; then
            local filename=$(basename "$workflow_file")
            local target="$N8N_DATA_DIR/workflows/$filename"
            
            echo -n "  Importing: $filename... "
            
            # Copy workflow file
            if cp "$workflow_file" "$target"; then
                echo -e "${CHECK}"
                ((imported++))
            else
                echo -e "${CROSS}"
                ((skipped++))
            fi
        fi
    done
    
    echo ""
    echo -e "${CHECK} Import complete"
    echo "  Imported: $imported"
    [ $skipped -gt 0 ] && echo -e "  ${WARN} Skipped: $skipped"
    
    echo ""
    echo -e "${INFO} ${BLUE}Note:${NC} Workflows are copied to ~/.n8n/workflows/"
    echo "  You may need to refresh the n8n UI to see imported workflows"
    echo "  Or restart n8n: make restart"
}

# Function: Import via n8n API (advanced)
import_workflows_api() {
    echo -e "${BLUE}3️⃣  Importing Workflows via API${NC}"
    echo ""
    
    local workflow_count=$(count_workflows)
    
    if [ "$workflow_count" -eq 0 ]; then
        echo -e "${WARN} ${YELLOW}No workflow files found${NC} in $WORKFLOWS_DIR"
        exit 0
    fi
    
    echo "Found $workflow_count workflow file(s)"
    echo ""
    
    # Check if n8n is accessible
    if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:5678" | grep -q "200\|302"; then
        echo -e "${CROSS} ${RED}n8n API not accessible${NC}"
        echo "  Falling back to file copy method..."
        echo ""
        import_workflows_file_copy
        return
    fi
    
    local imported=0
    local skipped=0
    
    for workflow_file in "$WORKFLOWS_DIR"/*.json; do
        if [ -f "$workflow_file" ]; then
            local filename=$(basename "$workflow_file")
            echo -n "  Importing: $filename... "
            
            # Try to import via API
            # Note: This requires authentication setup
            # For now, we'll use file copy method
            echo -e "${INFO} (using file copy)"
            cp "$workflow_file" "$N8N_DATA_DIR/workflows/$filename"
            ((imported++))
        fi
    done
    
    echo ""
    echo -e "${CHECK} Import complete: $imported workflow(s)"
}

# Function: Display summary
display_summary() {
    echo ""
    echo -e "${BLUE}=========================================" 
    echo -e "Summary"
    echo -e "=========================================${NC}"
    echo ""
    echo -e "🌐 View workflows at: http://localhost:5678/workflows"
    echo -e "🔄 Restart n8n if needed: make restart"
    echo ""
}

# Main execution
main() {
    check_n8n_running
    check_workflows_dir
    import_workflows_file_copy
    display_summary
}

# Run main function
main
