#!/bin/bash

# 🧡 n8n Ephemeral Health Check Script
# Validates system prerequisites and n8n instance health

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
INFO="ℹ️"

echo -e "${BLUE}===========================================" 
echo -e "🧡 n8n Ephemeral Health Check"
echo -e "===========================================${NC}\n"

# Track overall health
HEALTH_OK=true

# Function to check command exists
check_command() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${CHECK} ${GREEN}$name${NC} is installed"
        return 0
    else
        echo -e "${CROSS} ${RED}$name${NC} is NOT installed"
        HEALTH_OK=false
        return 1
    fi
}

# Function to check Docker container
check_container() {
    local container_name="n8n-ephemeral"
    
    if docker ps -a --filter "name=$container_name" --format '{{.Names}}' | grep -q "$container_name"; then
        local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
        
        if [ "$status" = "running" ]; then
            echo -e "${CHECK} ${GREEN}n8n container${NC} is running"
            return 0
        else
            echo -e "${WARN} ${YELLOW}n8n container${NC} exists but is not running (status: $status)"
            HEALTH_OK=false
            return 1
        fi
    else
        echo -e "${INFO} ${BLUE}n8n container${NC} does not exist (not started yet)"
        return 2
    fi
}

# Function to check web UI accessibility  
check_web_ui() {
    local url="http://localhost:5678"
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|302"; then
        echo -e "${CHECK} ${GREEN}n8n Web UI${NC} is accessible at $url"
        return 0
    else
        echo -e "${CROSS} ${RED}n8n Web UI${NC} is not accessible at $url"
        HEALTH_OK=false
        return 1
    fi
}

# Function to check data persistence
check_persistence() {
    local n8n_dir="$HOME/.n8n"
    
    if [ -d "$n8n_dir" ]; then
        echo -e "${CHECK} ${GREEN}Data directory${NC} exists at $n8n_dir"
        
        # Check for key files
        local files_ok=true
        
        if [ -f "$n8n_dir/config" ]; then
            echo -e "  ${CHECK} config file found"
        else
            echo -e "  ${WARN} config file missing (will be created on first run)"
        fi
        
        return 0
    else
        echo -e "${WARN} ${YELLOW}Data directory${NC} does not exist (will be created on first run)"
        return 1
    fi
}

# Function to check disk space
check_disk_space() {
    local min_space_mb=500
    local available_space=$(df -m "$HOME" | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -gt "$min_space_mb" ]; then
        echo -e "${CHECK} ${GREEN}Disk space${NC} available: ${available_space}MB"
        return 0
    else
        echo -e "${WARN} ${YELLOW}Disk space${NC} low: ${available_space}MB (recommended: >500MB)"
        HEALTH_OK=false
        return 1
    fi
}

# Function to check memory
check_memory() {
    if command -v vm_stat &> /dev/null; then
        # macOS
        local free_mem=$(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
        local free_mb=$((free_mem * page_size / 1024 / 1024))
        
        if [ "$free_mb" -gt 512 ]; then
            echo -e "${CHECK} ${GREEN}Free memory${NC}: ~${free_mb}MB"
            return 0
        else
            echo -e "${WARN} ${YELLOW}Free memory${NC} low: ~${free_mb}MB"
            return 1
        fi
    else
        echo -e "${INFO} ${BLUE}Memory check${NC} skipped (vm_stat not available)"
        return 2
    fi
}

echo -e "${BLUE}1️⃣  Checking Prerequisites${NC}"
echo "-------------------------------------------"
check_command "docker" "Docker"
check_command "curl" "curl"
check_command "jq" "jq" || echo -e "  ${INFO} jq is optional but recommended"
echo ""

echo -e "${BLUE}2️⃣  Checking n8n Container${NC}"
echo "-------------------------------------------"
CONTAINER_STATUS=$(check_container; echo $?)

if [ "$CONTAINER_STATUS" -eq 0 ]; then
    # Container is running, check web UI
    echo ""
    echo -e "${BLUE}3️⃣  Checking Web UI${NC}"
    echo "-------------------------------------------"
    check_web_ui
elif [ "$CONTAINER_STATUS" -eq 2 ]; then
    echo -e "  ${INFO} Run 'make start' or './start-n8n.sh' to start n8n"
fi
echo ""

echo -e "${BLUE}4️⃣  Checking Data Persistence${NC}"
echo "-------------------------------------------"
check_persistence
echo ""

echo -e "${BLUE}5️⃣  Checking System Resources${NC}"
echo "-------------------------------------------"
check_disk_space
check_memory
echo ""

# Final summary
echo -e "${BLUE}===========================================" 
if [ "$HEALTH_OK" = true ]; then
    echo -e "${CHECK} ${GREEN}Overall Status: HEALTHY${NC}"
    echo -e "===========================================${NC}"
    exit 0
else
    echo -e "${CROSS} ${RED}Overall Status: ISSUES DETECTED${NC}"
    echo -e "===========================================${NC}"
    echo -e "\n${WARN} Please resolve the issues above before running n8n"
    exit 1
fi
