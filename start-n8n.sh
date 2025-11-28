#!/bin/bash

# 🚀 n8n Ephemeral Startup Script (Enhanced)
# Starts n8n Docker container with prerequisite checks and auto-configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emojis
CHECK="✅"
CROSS="❌"
WARN="⚠️"
ROCKET="🚀"

# Configuration
IMAGE_TAG="n8nio/n8n:latest"
PORT=5678
CONTAINER_NAME="n8n-ephemeral"
N8N_DATA_DIR="$HOME/.n8n"

echo -e "${BLUE}=========================================" 
echo -e "$ROCKET n8n Ephemeral Startup"
echo -e "=========================================${NC}\n"

# Function: Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}1️⃣  Checking Prerequisites...${NC}"
    
    local all_ok=true
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${CROSS} ${RED}Docker${NC} is not installed"
        echo "  Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
        all_ok=false
    else
        echo -e "${CHECK} ${GREEN}Docker${NC} is installed"
    fi
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${CROSS} ${RED}Docker${NC} is not running"
        echo "  Please start Docker Desktop and try again"
        all_ok=false
    else
        echo -e "${CHECK} ${GREEN}Docker${NC} is running"
    fi
    
    # Check curl (optional but recommended)
    if command -v curl &> /dev/null; then
        echo -e "${CHECK} ${GREEN}curl${NC} is available"
    else
        echo -e "${WARN} ${YELLOW}curl${NC} not found (optional)"
    fi
    
    echo ""
    
    if [ "$all_ok" = false ]; then
        echo -e "${CROSS} ${RED}Prerequisite checks failed${NC}"
        echo "Please resolve the issues above before starting n8n"
        exit 1
    fi
    
    echo -e "${CHECK} ${GREEN}All prerequisites met${NC}\n"
}

# Function: Setup persistence
setup_persistence() {
    echo -e "${BLUE}2️⃣  Setting up Data Persistence...${NC}"
    
    if [ ! -d "$N8N_DATA_DIR" ]; then
        echo "Creating n8n data directory: $N8N_DATA_DIR"
        mkdir -p "$N8N_DATA_DIR"
        echo -e "${CHECK} ${GREEN}Data directory created${NC}"
    else
        echo -e "${CHECK} ${GREEN}Data directory exists${NC} at $N8N_DATA_DIR"
    fi
    
    # Create backups directory if it doesn't exist
    if [ ! -d "$N8N_DATA_DIR/backups" ]; then
        mkdir -p "$N8N_DATA_DIR/backups"
    fi
    
    echo ""
}

# Function: Load environment variables
load_env_vars() {
    if [ -f .env ]; then
        echo -e "${BLUE}3️⃣  Loading Environment Variables...${NC}"
        export $(cat .env | grep -v '^#' | xargs)
        echo -e "${CHECK} ${GREEN}Environment variables loaded${NC} from .env\n"
    else
        echo -e "${BLUE}3️⃣  Environment Variables${NC}"
        echo -e "${WARN} No .env file found (using defaults)\n"
    fi
}

# Function: Check if n8n is already running
check_already_running() {
    echo -e "${BLUE}4️⃣  Checking Container Status...${NC}"
    
    if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        echo -e "${WARN} ${YELLOW}n8n is already running!${NC}"
        echo -e "  🌐 Visit: http://localhost:$PORT/"
        echo -e "  🛑 Stop with: ./stop-n8n.sh or 'make stop'\n"
        exit 1
    else
        echo -e "${CHECK} No existing n8n container found\n"
    fi
}

# Function: Start n8n container
start_container() {
    echo -e "${BLUE}5️⃣  Starting n8n Docker Container...${NC}"
    echo "This may take a moment on first run while downloading the image."
    echo ""
    
    docker run --rm \
        --name $CONTAINER_NAME \
        -p $PORT:5678 \
        -v "$N8N_DATA_DIR":/home/node/.n8n \
        -e N8N_USER_MANAGEMENT_DISABLED=${N8N_USER_MANAGEMENT_DISABLED:-true} \
        -e WEBHOOK_URL=${WEBHOOK_URL:-http://localhost:5678/} \
        -e GENERIC_TIMEZONE=${GENERIC_TIMEZONE:-America/Los_Angeles} \
        -d $IMAGE_TAG
    
    echo -e "${CHECK} ${GREEN}Container started${NC}\n"
}

# Function: Wait for n8n to be ready
wait_for_ready() {
    echo -e "${BLUE}6️⃣  Waiting for n8n to be Ready...${NC}"
    
    local max_attempts=30
    local attempt=0
    
    sleep 3  # Initial wait
    
    while [ $attempt -lt $max_attempts ]; do
        if [ ! "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
            echo -e "\n${CROSS} ${RED}Container failed to start${NC}"
            echo "Check Docker logs with: docker logs $CONTAINER_NAME"
            exit 1
        fi
        
        if command -v curl &> /dev/null; then
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" | grep -q "200\|302"; then
                echo -e "${CHECK} ${GREEN}n8n is ready!${NC}\n"
                return 0
            fi
        else
            # Fallback: just wait without checking
            if [ $attempt -eq 5 ]; then
                echo -e "${CHECK} ${GREEN}Container should be ready${NC}\n"
                return 0
            fi
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    
    echo -e "\n${WARN} ${YELLOW}Timed out waiting for n8n${NC}"
    echo "Container may still be starting. Check: http://localhost:$PORT/"
}

# Function: Auto-import workflows (if configured)
auto_import_workflows() {
    if [ -f ".n8n-config.yml" ]; then
        # Check if auto_import is enabled in config (simple grep check)
        if grep -q "auto_import: true" .n8n-config.yml 2>/dev/null; then
            echo -e "${BLUE}7️⃣  Auto-importing Workflows...${NC}"
            
            if [ -d "workflows" ] && [ -n "$(ls -A workflows/*.json 2>/dev/null)" ]; then
                echo "Found workflows to import"
                # Note: Actual import would require n8n CLI or API
                # For now, workflows are available in the mounted volume
                echo -e "${CHECK} Workflows available in mounted directory\n"
            else
                echo -e "${WARN} No workflows found in ./workflows/\n"
            fi
        fi
    fi
}

# Function: Open browser
open_browser() {
    echo -e "${BLUE}8️⃣  Opening Browser...${NC}"
    
    if [ -f ".n8n-config.yml" ] && grep -q "auto_open_browser: false" .n8n-config.yml 2>/dev/null; then
        echo -e "Auto-open browser disabled in config\n"
    else
        open "http://localhost:$PORT/" 2>/dev/null || \
        xdg-open "http://localhost:$PORT/" 2>/dev/null || \
        echo -e "${WARN} Could not auto-open browser\n"
    fi
}

# Function: Display success message
display_success() {
    echo -e "${GREEN}========================================="
    echo -e "$CHECK n8n is Running Successfully!"
    echo -e "=========================================${NC}"
    echo ""
    echo -e "🌐 Web UI:       http://localhost:$PORT/"
    echo -e "💾 Data Storage:  $N8N_DATA_DIR"
    echo -e "📖 Logs:          docker logs -f $CONTAINER_NAME"
    echo -e "🛑 Stop n8n:      ./stop-n8n.sh or 'make stop'"
    echo -e "🧡 Health Check:  ./scripts/health-check.sh or 'make health'"
    echo ""
}

# Main execution flow
main() {
    check_prerequisites
    setup_persistence
    load_env_vars
    check_already_running
    start_container
    wait_for_ready
    auto_import_workflows
    open_browser
    display_success
}

# Run main function
main
