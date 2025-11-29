#!/bin/bash

# ===================================================================
# 🔄 n8n Workflow Hot Reloader
# ===================================================================
# Automatically reloads n8n workflows when JSON files change.
# Perfect for development: edit workflow JSON, instant reload in n8n.
#
# Author: n8n-ephemeral-mac
# License: MIT
# ===================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config
N8N_HOST="${N8N_HOST:-http://localhost:5678}"
WORKFLOW_DIR="${1:-.}/workflows"
PID_FILE="${HOME}/.n8n/hot-reload.pid"
LOG_FILE="${HOME}/.n8n/hot-reload.log"

print_header() {
    echo -e "${CYAN}"
    echo "═════════════════════════════════════════════════════════════════════"
    echo "  🔄 $1"
    echo "═════════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_step() { echo -e "${PURPLE}🔄 $1${NC}"; }

# Check if fswatch is installed
check_requirements() {
    if ! command -v fswatch &> /dev/null; then
        print_error "fswatch is required for hot reload"
        print_info "Install with: brew install fswatch"
        return 1
    fi
    return 0
}

# Validate workflow JSON
validate_workflow() {
    local file="$1"
    if ! jq empty "$file" 2>/dev/null; then
        print_error "Invalid JSON in $file"
        return 1
    fi
    return 0
}

# Upload workflow to n8n
upload_workflow() {
    local file="$1"
    local filename=$(basename "$file" .json)
    
    print_step "Uploading: $filename"
    
    if ! validate_workflow "$file"; then
        return 1
    fi
    
    local workflow_data=$(jq '.' "$file")
    local workflow_id=$(echo "$workflow_data" | jq -r '.id // empty')
    
    if [ -n "$workflow_id" ] && [ "$workflow_id" != "null" ]; then
        local response=$(curl -s -X PATCH "$N8N_HOST/api/v1/workflows/$workflow_id" \
            -H "Content-Type: application/json" \
            -d "$workflow_data" 2>/dev/null)
    else
        local response=$(curl -s -X POST "$N8N_HOST/api/v1/workflows" \
            -H "Content-Type: application/json" \
            -d "$workflow_data" 2>/dev/null)
    fi
    
    if echo "$response" | jq -e '.id' > /dev/null 2>&1; then
        print_success "Updated: $filename"
        if command -v osascript &> /dev/null; then
            osascript -e "display notification \"Workflow updated: $filename\" with title \"n8n Hot Reload\"" 2>/dev/null
        fi
        return 0
    else
        print_error "Failed to upload $filename"
        return 1
    fi
}

# Start watcher
start_watcher() {
    print_header "Starting Workflow Hot Reloader"
    
    if ! check_requirements; then
        return 1
    fi
    
    if [ ! -d "$WORKFLOW_DIR" ]; then
        print_error "Workflow directory not found: $WORKFLOW_DIR"
        return 1
    fi
    
    print_info "Watching: $WORKFLOW_DIR"
    print_info "n8n Host: $N8N_HOST"
    print_info "Press Ctrl+C to stop"
    echo ""
    
    # Initial sync
    print_step "Initial workflow sync..."
    local count=0
    for workflow_file in "$WORKFLOW_DIR"/*.json; do
        if [ -f "$workflow_file" ]; then
            upload_workflow "$workflow_file"
            ((count++))
        fi
    done
    print_success "Synced $count workflows"
    echo ""
    
    # Save PID
    mkdir -p "$(dirname "$PID_FILE")"
    echo $$ > "$PID_FILE"
    
    # Watch for changes
    fswatch -r "$WORKFLOW_DIR" 2>/dev/null | while read -r file; do
        if [[ "$file" == *.json ]]; then
            sleep 0.5
            upload_workflow "$file"
        fi
    done
}

# Stop watcher
stop_watcher() {
    print_header "Stopping Hot Reloader"
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm "$PID_FILE"
            print_success "Hot reloader stopped"
        else
            print_info "Process not found"
            rm "$PID_FILE"
        fi
    else
        print_info "Hot reloader not running"
    fi
}

# Show status
show_status() {
    print_header "Hot Reloader Status"
    
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            print_success "Hot reloader is running (PID: $pid)"
        else
            print_info "PID file exists but process not running"
        fi
    else
        print_info "Hot reloader is not running"
    fi
    
    if [ -d "$WORKFLOW_DIR" ]; then
        local count=$(find "$WORKFLOW_DIR" -name "*.json" | wc -l)
        print_info "Watching: $WORKFLOW_DIR ($count workflows)"
    fi
}

show_usage() {
    echo "Usage: $0 <command> [workflow-dir]"
    echo ""
    echo "Commands:"
    echo "  start [dir]    Start watching workflows (default: ./workflows)"
    echo "  stop           Stop watching"
    echo "  status         Show status"
    echo "  help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 start ./my-workflows"
    echo "  $0 stop"
    echo ""
}

case "${1:-help}" in
    start) start_watcher ;;
    stop) stop_watcher ;;
    status) show_status ;;
    help|--help|-h) show_usage ;;
    *) print_error "Unknown command: $1"; show_usage; exit 1 ;;
esac
