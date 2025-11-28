#!/bin/bash

# 🔄 n8n Data Restore Script
# Restores n8n data from a backup archive

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
RESTORE="🔄"

# Configuration
N8N_DATA_DIR="$HOME/.n8n"
BACKUP_DIR="$N8N_DATA_DIR/backups"
CONTAINER_NAME="n8n-ephemeral"

echo -e "${BLUE}=========================================" 
echo -e "$RESTORE n8n Data Restore"
echo -e "=========================================${NC}\n"

# Function: Check if n8n is running
check_n8n_not_running() {
    echo -e "${BLUE}1️⃣  Checking n8n Status${NC}"
    
    if docker ps -q -f name=$CONTAINER_NAME > /dev/null 2>&1; then
        echo -e "${WARN} ${YELLOW}n8n is currently running${NC}"
        echo "  For safety, please stop n8n before restoring:"
        echo -e "  ${BLUE}./stop-n8n.sh${NC} or ${BLUE}make stop${NC}"
        echo ""
        read -p "Stop n8n now? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Stopping n8n..."
            docker stop $CONTAINER_NAME > /dev/null 2>&1 || true
            sleep 2
            echo -e "${CHECK} n8n stopped\n"
        else
            echo -e "${CROSS} Restore cancelled. Please stop n8n manually."
            exit 1
        fi
    else
        echo -e "${CHECK} n8n is not running\n"
    fi
}

# Function: Get backup file
get_backup_file() {
    local backup_file="$1"
    
    echo -e "${BLUE}2️⃣  Locating Backup File${NC}"
    
    # If no argument provided, list available backups
    if [ -z "$backup_file" ]; then
        echo "Available backups:"
        echo ""
        
        if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/*.tar.gz 2>/dev/null)" ]; then
            echo -e "${CROSS} ${RED}No backups found${NC}"
            echo "  Location: $BACKUP_DIR"
            exit 1
        fi
        
        local count=1
        for backup in "$BACKUP_DIR"/*.tar.gz; do
            if [ -f "$backup" ]; then
                local filename=$(basename "$backup")
                local size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
                local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$backup" 2>/dev/null || stat -c "%y" "$backup" 2>/dev/null | cut -d'.' -f1)
                echo "  $count) $filename ($size) - $date"
                ((count++))
            fi
        done
        
        echo ""
        echo "Usage: $0 <backup-filename>"
        echo "Example: $0 n8n_backup_20251128_120000.tar.gz"
        exit 0
    fi
    
    # Check if backup file exists
    if [ ! -f "$BACKUP_DIR/$backup_file" ]; then
        # Try without directory prefix
        if [ -f "$backup_file" ]; then
            BACKUP_FILE="$backup_file"
        else
            echo -e "${CROSS} ${RED}Backup file not found${NC}: $backup_file"
            exit 1
        fi
    else
        BACKUP_FILE="$BACKUP_DIR/$backup_file"
    fi
    
    local size=$(du -sh "$BACKUP_FILE" 2>/dev/null | awk '{print $1}')
    echo -e "${CHECK} Found backup: $backup_file ($size)\n"
}

# Function: Create backup of current data
backup_current_data() {
    echo -e "${BLUE}3️⃣  Backing Up Current Data${NC}"
    
    if [ -d "$N8N_DATA_DIR" ]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local safety_backup="$BACKUP_DIR/pre_restore_backup_$timestamp.tar.gz"
        
        echo -n "Creating safety backup of current data... "
        
        mkdir -p "$BACKUP_DIR"
        
        if tar -czf "$safety_backup" \
            -C "$HOME" \
            --exclude='.n8n/backups' \
            '.n8n' 2>/dev/null; then
            echo -e "${CHECK}"
            echo "  Safety backup: $(basename "$safety_backup")"
        else
            echo -e "${WARN}"
            echo "  Failed to create safety backup (continuing anyway)"
        fi
    else
        echo -e "${INFO} No existing data to backup"
    fi
    
    echo ""
}

# Function: Restore from backup
restore_backup() {
    echo -e "${BLUE}4️⃣  Restoring Data${NC}"
    echo -e "${WARN} ${YELLOW}This will replace all current n8n data!${NC}"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${CROSS} Restore cancelled"
        exit 0
    fi
    
    echo ""
    echo -n "Removing current data... "
    
    if [ -d "$N8N_DATA_DIR" ]; then
        # Keep backups directory
        find "$N8N_DATA_DIR" -mindepth 1 -maxdepth 1 ! -name 'backups' -exec rm -rf {} \; 2>/dev/null
        echo -e "${CHECK}"
    else
        echo -e "${INFO} (none)"
    fi
    
    echo -n "Extracting backup... "
    
    if tar -xzf "$BACKUP_FILE" -C "$HOME" 2>/dev/null; then
        echo -e "${CHECK}"
    else
        echo -e "${CROSS}"
        echo -e "${CROSS} ${RED}Restore failed${NC}"
        echo "  Your data has NOT been modified"
        exit 1
    fi
}

# Function: Verify restore
verify_restore() {
    echo -e "\n${BLUE}5️⃣  Verifying Restore${NC}"
    
    if [ -d "$N8N_DATA_DIR" ]; then
        local files_count=$(find "$N8N_DATA_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
        echo -e "${CHECK} Data directory restored"
        echo "  Files restored: $files_count"
        
        # Check for key files
        if [ -f "$N8N_DATA_DIR/config" ]; then
            echo -e "  ${CHECK} Configuration found"
        fi
    else
        echo -e "${CROSS} ${RED}Verification failed${NC}"
        echo "  Data directory not found after restore"
        exit 1
    fi
}

# Function: Display summary
display_summary() {
    echo -e "\n${GREEN}=========================================" 
    echo -e "$CHECK Restore Complete!"
    echo -e "=========================================${NC}"
    echo ""
    echo "Your n8n data has been successfully restored."
    echo ""
    echo "Next steps:"
    echo -e "  1. Start n8n: ${BLUE}./start-n8n.sh${NC} or ${BLUE}make start${NC}"
    echo "  2. Verify your workflows and credentials"
    echo ""
}

# Main execution
main() {
    local backup_file="$1"
    
    check_n8n_not_running
    get_backup_file "$backup_file"
    backup_current_data
    restore_backup
    verify_restore
    display_summary
}

# Run main function
main "$@"
