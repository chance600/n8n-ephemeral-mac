#!/bin/bash

# 💾 n8n Data Backup Script
# Creates timestamped backups of n8n data directory

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
DISK="💾"

# Configuration
N8N_DATA_DIR="$HOME/.n8n"
BACKUP_DIR="$N8N_DATA_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_backup_$TIMESTAMP"

echo -e "${BLUE}=========================================" 
echo -e "$DISK n8n Data Backup"
echo -e "=========================================${NC}\n"

# Function: Check if n8n data directory exists
check_data_dir() {
    echo -e "${BLUE}1️⃣  Checking n8n Data Directory${NC}"
    
    if [ ! -d "$N8N_DATA_DIR" ]; then
        echo -e "${CROSS} ${RED}n8n data directory not found${NC}: $N8N_DATA_DIR"
        echo "  Please start n8n at least once to create the data directory"
        exit 1
    fi
    
    echo -e "${CHECK} Found n8n data directory\n"
}

# Function: Create backup directory
create_backup_dir() {
    echo -e "${BLUE}2️⃣  Preparing Backup Directory${NC}"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${CHECK} Created backup directory"
    else
        echo -e "${CHECK} Backup directory exists"
    fi
    
    echo ""
}

# Function: Calculate directory size
get_dir_size() {
    du -sh "$N8N_DATA_DIR" 2>/dev/null | awk '{print $1}' || echo "Unknown"
}

# Function: Create backup
create_backup() {
    echo -e "${BLUE}3️⃣  Creating Backup${NC}"
    
    local data_size=$(get_dir_size)
    echo "Data directory size: $data_size"
    echo "Backup name: $BACKUP_NAME.tar.gz"
    echo ""
    
    echo -n "Creating compressed archive... "
    
    # Create tar.gz archive, excluding the backups directory itself
    if tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" \
        -C "$HOME" \
        --exclude='.n8n/backups' \
        --exclude='.n8n/*.log' \
        '.n8n' 2>/dev/null; then
        echo -e "${CHECK}"
    else
        echo -e "${CROSS}"
        echo -e "${CROSS} ${RED}Backup failed${NC}"
        exit 1
    fi
}

# Function: Verify backup
verify_backup() {
    echo -e "\n${BLUE}4️⃣  Verifying Backup${NC}"
    
    local backup_file="$BACKUP_DIR/$BACKUP_NAME.tar.gz"
    
    if [ -f "$backup_file" ]; then
        local backup_size=$(du -sh "$backup_file" 2>/dev/null | awk '{print $1}' || echo "Unknown")
        echo -e "${CHECK} Backup file created: $backup_size"
        echo "  Location: $backup_file"
    else
        echo -e "${CROSS} ${RED}Backup file not found${NC}"
        exit 1
    fi
}

# Function: Clean old backups
clean_old_backups() {
    echo -e "\n${BLUE}5️⃣  Cleaning Old Backups${NC}"
    
    local retention_days=30
    local backup_count=$(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f 2>/dev/null | wc -l | tr -d ' ')
    
    echo "Total backups: $backup_count"
    echo "Retention policy: $retention_days days"
    
    # Find and delete backups older than retention period
    local deleted=0
    while IFS= read -r old_backup; do
        rm -f "$old_backup"
        ((deleted++))
    done < <(find "$BACKUP_DIR" -name "n8n_backup_*.tar.gz" -type f -mtime +$retention_days 2>/dev/null)
    
    if [ $deleted -gt 0 ]; then
        echo -e "${CHECK} Deleted $deleted old backup(s)"
    else
        echo -e "${CHECK} No old backups to delete"
    fi
}

# Function: Display summary
display_summary() {
    echo -e "\n${GREEN}=========================================" 
    echo -e "$CHECK Backup Complete!"
    echo -e "=========================================${NC}"
    echo ""
    echo "Backup Details:"
    echo "  Name: $BACKUP_NAME.tar.gz"
    echo "  Location: $BACKUP_DIR/"
    echo ""
    echo "To restore this backup:"
    echo -e "  ${BLUE}./scripts/restore.sh $BACKUP_NAME.tar.gz${NC}"
    echo ""
}

# Main execution
main() {
    check_data_dir
    create_backup_dir
    create_backup
    verify_backup
    clean_old_backups
    display_summary
}

# Run main function
main
