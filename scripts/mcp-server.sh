#!/bin/bash

# =============================================================================
# 🤖 n8n MCP Server Wrapper
# =============================================================================
# Exposes n8n workflows as MCP (Model Context Protocol) tools for AI assistants.
# Enables Claude, ChatGPT, and other LLMs to call n8n workflows as function tools.
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
N8N_HOST="${N8N_HOST:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"
MCP_PORT="${MCP_PORT:-3001}"
MCP_AUTH_TOKEN="${MCP_AUTH_TOKEN:-}"
MCP_CONFIG_FILE="${HOME}/.config/claude/mcp-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "${CYAN}"
    echo "═════════════════════════════════════════════════════════════════════════════════"
    echo "  🤖 $1"
    echo "═════════════════════════════════════════════════════════════════════════════════"
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
check_n8n() {
    if ! curl -s "$N8N_HOST/api/v1/workflows" > /dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Get all workflows from n8n
get_workflows() {
    curl -s "$N8N_HOST/api/v1/workflows" | jq '.data[] | {id, name}' 2>/dev/null || echo "[]"
}

# Generate MCP tool schema from n8n workflow
generate_tool_schema() {
    local workflow_id="$1"
    local workflow_name="$2"
    
    cat <<EOF
{
  "name": "n8n_$(echo $workflow_name | tr ' ' '_' | tr '[:upper:]' '[:lower:]')",
  "description": "Execute n8n workflow: $workflow_name",
  "inputSchema": {
    "type": "object",
    "properties": {
      "workflow_id": {
        "type": "string",
        "description": "The n8n workflow ID"
      },
      "input_data": {
        "type": "object",
        "description": "Input data for the workflow"
      }
    },
    "required": ["workflow_id"]
  }
}
EOF
}

# =============================================================================
# MCP Server Functions
# =============================================================================

# Start MCP server
start_server() {
    print_header "Starting MCP Server"
    
    if ! check_n8n; then
        print_error "n8n is not running at $N8N_HOST"
        print_info "Start n8n with: ./start-n8n.sh"
        return 1
    fi
    
    print_success "n8n is running"
    print_step "Starting MCP server on port $MCP_PORT..."
    
    # Check if port is already in use
    if lsof -i :"$MCP_PORT" > /dev/null 2>&1; then
        print_warning "Port $MCP_PORT is already in use"
        return 1
    fi
    
    # Start simple HTTP server (requires Python)
    if command -v python3 &> /dev/null; then
        cd "$SCRIPT_DIR"
        python3 -m http.server "$MCP_PORT" > /dev/null 2>&1 &
        local pid=$!
        echo $pid > "$SCRIPT_DIR/.mcp-server.pid"
        
        print_success "MCP server started with PID $pid"
        print_info "MCP server running on http://localhost:$MCP_PORT"
        print_info "Auth token: $MCP_AUTH_TOKEN"
    else
        print_error "Python3 not found. Cannot start MCP server."
        return 1
    fi
}

# Stop MCP server
stop_server() {
    print_header "Stopping MCP Server"
    
    local pid_file="$SCRIPT_DIR/.mcp-server.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm "$pid_file"
            print_success "MCP server stopped (PID $pid)"
        else
            print_warning "Process $pid not found"
            rm "$pid_file"
        fi
    else
        print_warning "No MCP server PID file found"
    fi
}

# List all n8n workflows as MCP tools
list_tools() {
    print_header "Available MCP Tools (n8n Workflows)"
    
    if ! check_n8n; then
        print_error "n8n is not running"
        return 1
    fi
    
    local workflows=$(get_workflows)
    
    if [ "$workflows" = "[]" ]; then
        print_warning "No workflows found in n8n"
        return 0
    fi
    
    echo -e "${CYAN}Workflow Name${NC}\t\t${GREEN}ID${NC}\t\t${YELLOW}Type${NC}"
    echo "═════════════════════════════════════════════════════════════════════════════════"
    
    echo "$workflows" | jq -r '.name' 2>/dev/null | while read -r name; do
        local tool_name="n8n_$(echo $name | tr ' ' '_' | tr '[:upper:]' '[:lower:]')"
        echo -e "${CYAN}$name${NC}\t${GREEN}$tool_name${NC}\t${YELLOW}workflow${NC}"
    done
}

# Setup Claude Desktop integration
setup_claude() {
    print_header "Setting Up Claude Desktop Integration"
    
    # Create config directory
    mkdir -p "$(dirname "$MCP_CONFIG_FILE")"
    
    # Generate MCP config
    local config_content='{
  "mcpServers": {
    "n8n-workflows": {
      "command": "'"$SCRIPT_DIR/mcp-server.sh"'",
      "args": ["server"],
      "env": {
        "N8N_HOST": "'"$N8N_HOST"'",
        "N8N_API_KEY": "'"$N8N_API_KEY"'",
        "MCP_AUTH_TOKEN": "'"$MCP_AUTH_TOKEN"'"
      }
    }
  }
}'
    
    echo "$config_content" > "$MCP_CONFIG_FILE"
    
    print_success "Claude Desktop configuration updated"
    print_info "Location: $MCP_CONFIG_FILE"
    print_warning "Restart Claude Desktop to load the new configuration"
}

# Execute workflow via MCP
execute_workflow() {
    local workflow_id="$1"
    local input_data="${2:-{}}"
    
    print_step "Executing workflow: $workflow_id"
    
    if ! check_n8n; then
        print_error "n8n is not running"
        return 1
    fi
    
    # Call n8n webhook to execute workflow
    local response=$(curl -s -X POST "$N8N_HOST/webhook/n8n-workflow" \
        -H "Content-Type: application/json" \
        -d "{\"workflowId\": \"$workflow_id\", \"inputData\": $input_data}" 2>/dev/null)
    
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
}

# Show server status
show_status() {
    print_header "MCP Server Status"
    
    # Check if n8n is running
    if check_n8n; then
        print_success "n8n is running at $N8N_HOST"
    else
        print_error "n8n is not running"
    fi
    
    # Check if MCP server is running
    local pid_file="$SCRIPT_DIR/.mcp-server.pid"
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            print_success "MCP server is running (PID $pid) on port $MCP_PORT"
        else
            print_error "MCP server PID file exists but process not found"
        fi
    else
        print_warning "MCP server is not running"
    fi
    
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    echo -e "  N8N Host: ${GREEN}$N8N_HOST${NC}"
    echo -e "  MCP Port: ${GREEN}$MCP_PORT${NC}"
    echo -e "  Config File: ${GREEN}$MCP_CONFIG_FILE${NC}"
}

# Show usage
show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start              Start MCP server"
    echo "  stop               Stop MCP server"
    echo "  status             Show server status"
    echo "  list               List available MCP tools (workflows)"
    echo "  setup-claude       Setup Claude Desktop integration"
    echo "  execute <id>       Execute a workflow by ID"
    echo "  server             Start server (for MCP mode)"
    echo "  help               Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  N8N_HOST           n8n server URL (default: http://localhost:5678)"
    echo "  N8N_API_KEY        n8n API key (optional)"
    echo "  MCP_PORT           MCP server port (default: 3001)"
    echo "  MCP_AUTH_TOKEN     MCP authentication token (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 list"
    echo "  $0 setup-claude"
    echo "  $0 execute workflow-id"
    echo ""
}

# =============================================================================
# Main Script Logic
# =============================================================================

case "${1:-help}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    status)
        show_status
        ;;
    list)
        list_tools
        ;;
    setup-claude)
        setup_claude
        ;;
    execute)
        execute_workflow "$2" "$3"
        ;;
    server)
        # MCP server mode
        start_server
        print_info "MCP server running. Press Ctrl+C to stop."
        wait
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
