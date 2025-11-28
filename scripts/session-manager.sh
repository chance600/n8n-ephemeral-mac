#!/bin/bash

# =============================================================================
# 💾 n8n Session Manager
# =============================================================================
# Manages session state for n8n workflows, enabling save/restore of execution
# context across container restarts. Supports session caching, rollback, and
# automatic state preservation.
#
# Author: n8n-ephemeral-mac
# License: MIT
# =============================================================================

set -e

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
N8N_DATA_DIR="${N8N_DATA_DIR:-$HOME/.n8n}"
SESSION_DIR="$N8N_DATA_DIR/sessions"
HISTORY_DIR="$SESSION_DIR/history"
CACHE_DIR="$SESSION_DIR/cache"
CURRENT_SESSION="$SESSION_DIR/current.json"
SESSION_RETENTION_DAYS=7

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "${CYAN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  💾 $1"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_step() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

# Check if n8n is running
check_n8n_running() {
    if docker ps --format '{{.Names}}' | grep -q "n8n"; then
        return 0
    else
        return 1
    fi
}

# Initialize session directories
init_session_dirs() {
    mkdir -p "$SESSION_DIR" "$HISTORY_DIR" "$CACHE_DIR"
    print_info "Session directories initialized"
}

# Get timestamp for session naming
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# =============================================================================
# Core Session Management Functions
# =============================================================================

# Save current session state
save_session() {
    print_header "Saving Session State"
    
    init_session_dirs
    
    if ! check_n8n_running; then
        print_error "n8n is not running. No active session to save."
        return 1
    fi
    
    local timestamp=$(get_timestamp)
    local session_file="$HISTORY_DIR/session_${timestamp}.json"
    
    print_step "Capturing execution state..."
    
    # Create session snapshot
    local session_data='{
        "timestamp": "'"$timestamp"'",
        "date": "'"$(date -Iseconds)"'",
        "n8n_version": "'"$(docker exec n8n n8n --version 2>/dev/null || echo "unknown")"'",
        "container_id": "'"$(docker ps --filter "name=n8n" --format "{{.ID}}" | head -n1)"'",
        "uptime": "'"$(docker ps --filter "name=n8n" --format "{{.Status}}" | head -n1)"'"
    }'
    
    echo "$session_data" > "$session_file"
    
    # Copy to current session
    cp "$session_file" "$CURRENT_SESSION"
    
    # Backup database (if SQLite)
    if [ -f "$N8N_DATA_DIR/database.sqlite" ]; then
        print_step "Backing up database..."
        cp "$N8N_DATA_DIR/database.sqlite" "$HISTORY_DIR/database_${timestamp}.sqlite"
        print_success "Database backed up"
    fi
    
    # Cache workflow execution data
    if [ -d "$N8N_DATA_DIR/.cache" ]; then
        print_step "Caching workflow data..."
        cp -r "$N8N_DATA_DIR/.cache" "$CACHE_DIR/cache_${timestamp}"
        print_success "Workflow cache saved"
    fi
    
    print_success "Session saved: $session_file"
    print_info "Session ID: ${timestamp}"
    
    return 0
}

# Restore session from snapshot
restore_session() {
    print_header "Restoring Session State"
    
    init_session_dirs
    
    local session_id="$1"
    
    if [ -z "$session_id" ]; then
        # Restore from current session
        if [ ! -f "$CURRENT_SESSION" ]; then
            print_error "No current session found. Use 'list' to see available sessions."
            return 1
        fi
        print_info "Restoring from current session..."
    else
        # Restore from specific session
        local session_file="$HISTORY_DIR/session_${session_id}.json"
        if [ ! -f "$session_file" ]; then
            print_error "Session not found: $session_id"
            print_info "Use './scripts/session-manager.sh list' to see available sessions"
            return 1
        fi
        cp "$session_file" "$CURRENT_SESSION"
        print_info "Restoring session: $session_id"
    fi
    
    if check_n8n_running; then
        print_warning "n8n is currently running. Consider stopping it before restore."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Restore cancelled"
            return 1
        fi
    fi
    
    # Restore database if available
    if [ -n "$session_id" ] && [ -f "$HISTORY_DIR/database_${session_id}.sqlite" ]; then
        print_step "Restoring database..."
        # Create safety backup first
        if [ -f "$N8N_DATA_DIR/database.sqlite" ]; then
            cp "$N8N_DATA_DIR/database.sqlite" "$N8N_DATA_DIR/database.sqlite.pre-restore"
        fi
        cp "$HISTORY_DIR/database_${session_id}.sqlite" "$N8N_DATA_DIR/database.sqlite"
        print_success "Database restored"
    fi
    
    # Restore cache if available
    if [ -n "$session_id" ] && [ -d "$CACHE_DIR/cache_${session_id}" ]; then
        print_step "Restoring workflow cache..."
        rm -rf "$N8N_DATA_DIR/.cache"
        cp -r "$CACHE_DIR/cache_${session_id}" "$N8N_DATA_DIR/.cache"
        print_success "Workflow cache restored"
    fi
    
    print_success "Session restored successfully"
    print_info "You can now start n8n with: ./start-n8n.sh"
    
    return 0
}

# List available sessions
list_sessions() {
    print_header "Available Sessions"
    
    if [ ! -d "$HISTORY_DIR" ] || [ -z "$(ls -A $HISTORY_DIR/session_*.json 2>/dev/null)" ]; then
        print_warning "No sessions found"
        print_info "Save a session with: ./scripts/session-manager.sh save"
        return 0
    fi
    
    echo -e "${CYAN}Session ID${NC}\t\t${GREEN}Date${NC}\t\t\t${YELLOW}Size${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────────"
    
    for session_file in "$HISTORY_DIR"/session_*.json; do
        local basename=$(basename "$session_file")
        local session_id=${basename#session_}
        session_id=${session_id%.json}
        
        local date=$(date -r "$session_file" "+%Y-%m-%d %H:%M:%S")
        local size=$(du -h "$session_file" | cut -f1)
        
        # Check if database backup exists
        local db_indicator=""
        if [ -f "$HISTORY_DIR/database_${session_id}.sqlite" ]; then
            db_indicator=" 💾"
        fi
        
        # Check if cache exists
        local cache_indicator=""
        if [ -d "$CACHE_DIR/cache_${session_id}" ]; then
            cache_indicator=" 📦"
        fi
        
        echo -e "${BLUE}$session_id${NC}\t${GREEN}$date${NC}\t${YELLOW}$size${NC}${db_indicator}${cache_indicator}"
    done
    
    echo ""
    print_info "💾 = Database backup available"
    print_info "📦 = Workflow cache available"
    echo ""
    print_info "Restore a session with: ./scripts/session-manager.sh restore <SESSION_ID>"
}

# Clean old sessions
clean_sessions() {
    print_header "Cleaning Old Sessions"
    
    if [ ! -d "$HISTORY_DIR" ]; then
        print_info "No sessions directory found"
        return 0
    fi
    
    local days=${1:-$SESSION_RETENTION_DAYS}
    
    print_step "Removing sessions older than $days days..."
    
    local count=0
    
    # Clean session files
    while IFS= read -r -d '' file; do
        rm "$file"
        ((count++))
        print_info "Removed: $(basename "$file")"
    done < <(find "$HISTORY_DIR" -name "session_*.json" -type f -mtime +"$days" -print0)
    
    # Clean database backups
    while IFS= read -r -d '' file; do
        rm "$file"
        ((count++))
        print_info "Removed: $(basename "$file")"
    done < <(find "$HISTORY_DIR" -name "database_*.sqlite" -type f -mtime +"$days" -print0)
    
    # Clean cache directories
    while IFS= read -r -d '' dir; do
        rm -rf "$dir"
        ((count++))
        print_info "Removed: $(basename "$dir")"
    done < <(find "$CACHE_DIR" -name "cache_*" -type d -mtime +"$days" -print0)
    
    if [ $count -eq 0 ]; then
        print_success "No old sessions to clean"
    else
        print_success "Cleaned $count old session files/directories"
    fi
}

# Show session statistics
show_stats() {
    print_header "Session Statistics"
    
    local total_sessions=$(ls -1 "$HISTORY_DIR"/session_*.json 2>/dev/null | wc -l | tr -d ' ')
    local total_size=$(du -sh "$SESSION_DIR" 2>/dev/null | cut -f1)
    local current_exists="No"
    
    if [ -f "$CURRENT_SESSION" ]; then
        current_exists="Yes"
    fi
    
    echo -e "${CYAN}Total Sessions:${NC}\t\t${GREEN}$total_sessions${NC}"
    echo -e "${CYAN}Current Session:${NC}\t\t${GREEN}$current_exists${NC}"
    echo -e "${CYAN}Total Storage Used:${NC}\t${YELLOW}$total_size${NC}"
    echo -e "${CYAN}Retention Period:${NC}\t${BLUE}$SESSION_RETENTION_DAYS days${NC}"
    
    echo ""
    print_info "Session directory: $SESSION_DIR"
}

# =============================================================================
# Main Script Logic
# =============================================================================

show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  save              Save current n8n session state"
    echo "  restore [ID]      Restore session (current or specific ID)"
    echo "  list              List all available sessions"
    echo "  clean [days]      Clean sessions older than N days (default: $SESSION_RETENTION_DAYS)"
    echo "  stats             Show session statistics"
    echo "  help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 save"
    echo "  $0 restore"
    echo "  $0 restore 20251128_140530"
    echo "  $0 list"
    echo "  $0 clean 14"
    echo "  $0 stats"
    echo ""
}

# Main command handler
case "${1:-help}" in
    save)
        save_session
        ;;
    restore)
        restore_session "$2"
        ;;
    list)
        list_sessions
        ;;
    clean)
        clean_sessions "$2"
        ;;
    stats)
        show_stats
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
