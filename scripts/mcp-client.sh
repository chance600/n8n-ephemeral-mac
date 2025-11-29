#!/bin/bash

# =============================================================================
# 🤖 n8n MCP Client Helper
# =============================================================================
# Allows n8n workflows to call external MCP servers (Claude Desktop, other LLMs).
# Enables bidirectional AI integration: n8n can invoke AI tools via MCP protocol.
#
# Author: n8n-ephemeral-mac
# License: MIT
# =============================================================================

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
MCP_CLIENT_CONFIG="${HOME}/.n8n/mcp-clients.json"
MCP_CACHE_DIR="${HOME}/.n8n/mcp-cache"

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

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_step() { echo -e "${PURPLE}🔄 $1${NC}"; }

# Initialize config
init_config() {
    mkdir -p "$(dirname "$MCP_CLIENT_CONFIG")"
    mkdir -p "$MCP_CACHE_DIR"
    
    if [ ! -f "$MCP_CLIENT_CONFIG" ]; then
        echo '{}' > "$MCP_CLIENT_CONFIG"
    fi
}

# Add MCP server
add_server() {
    local name="$1"
    local host="$2"
    local port="$3"
    local auth_token="${4:-}"
    
    init_config
    
    print_step "Adding MCP server: $name"
    
    local server_entry='{"name":"'$name'","host":"'$host'","port":'$port',"auth_token":"'$auth_token'","added":'"$(date +%s)"'}'
    
    local updated=$(jq ".servers[] |= select(.name != \"$name\") | .servers += [$server_entry]" "$MCP_CLIENT_CONFIG" 2>/dev/null || echo '{"servers":['$server_entry']}')
    echo "$updated" | jq '.' > "$MCP_CLIENT_CONFIG"
    
    print_success "MCP server added: $name"
}

# Remove MCP server
remove_server() {
    local name="$1"
    
    init_config
    
    print_step "Removing MCP server: $name"
    
    jq "del(.servers[] | select(.name == \"$name\"))" "$MCP_CLIENT_CONFIG" > "${MCP_CLIENT_CONFIG}.tmp"
    mv "${MCP_CLIENT_CONFIG}.tmp" "$MCP_CLIENT_CONFIG"
    
    print_success "MCP server removed: $name"
}

# List registered servers
list_servers() {
    print_header "Registered MCP Servers"
    
    init_config
    
    if [ ! -s "$MCP_CLIENT_CONFIG" ] || [ "$(jq '.servers | length' "$MCP_CLIENT_CONFIG" 2>/dev/null)" -eq 0 ]; then
        print_warning "No MCP servers registered"
        return 0
    fi
    
    echo -e "${CYAN}Name${NC}\t\t${GREEN}Host${NC}\t\t${YELLOW}Port${NC}"
    echo "════════════════════════════════════════════════════════"
    
    jq -r '.servers[] | "\(.name)\t\(.host)\t\(.port)"' "$MCP_CLIENT_CONFIG" | while read -r line; do
        echo -e "${CYAN}$line${NC}"
    done
}

# Call MCP tool
call_tool() {
    local server_name="$1"
    local tool_name="$2"
    local tool_input="${3:-{}}"
    
    init_config
    
    print_step "Calling MCP tool: $tool_name on $server_name"
    
    # Get server config
    local server=$(jq ".servers[] | select(.name == \"$server_name\")" "$MCP_CLIENT_CONFIG" 2>/dev/null)
    
    if [ -z "$server" ]; then
        print_error "MCP server not found: $server_name"
        return 1
    fi
    
    local host=$(echo "$server" | jq -r '.host')
    local port=$(echo "$server" | jq -r '.port')
    local auth_token=$(echo "$server" | jq -r '.auth_token')
    
    # Make MCP call
    local headers="-H 'Content-Type: application/json'"
    if [ -n "$auth_token" ] && [ "$auth_token" != "null" ]; then
        headers="$headers -H 'Authorization: Bearer $auth_token'"
    fi
    
    local response=$(curl -s -X POST "http://$host:$port/call" \
        $headers \
        -d "{\"tool\": \"$tool_name\", \"input\": $tool_input}" 2>/dev/null)
    
    # Cache result
    local cache_file="$MCP_CACHE_DIR/$(echo "${server_name}_${tool_name}_$(date +%s)" | sed 's/[^a-zA-Z0-9]/_/g').json"
    echo "$response" > "$cache_file"
    
    # Output result
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    
    print_success "Tool executed: $tool_name"
}

# Get cached results
get_cache() {
    local pattern="${1:-*}"
    
    print_header "MCP Cache Results"
    
    if [ -z "$(ls -A "$MCP_CACHE_DIR"/$pattern.json 2>/dev/null)" ]; then
        print_warning "No cached results found"
        return 0
    fi
    
    for file in "$MCP_CACHE_DIR"/$pattern.json; do
        echo -e "${CYAN}$(basename "$file")${NC}"
        jq '.' "$file"
        echo ""
    done
}

# Clear cache
clear_cache() {
    print_step "Clearing MCP cache"
    rm -rf "$MCP_CACHE_DIR"/*
    print_success "Cache cleared"
}

# Test MCP server
test_server() {
    local server_name="$1"
    
    print_step "Testing MCP server: $server_name"
    
    init_config
    
    local server=$(jq ".servers[] | select(.name == \"$server_name\")" "$MCP_CLIENT_CONFIG" 2>/dev/null)
    
    if [ -z "$server" ]; then
        print_error "MCP server not found: $server_name"
        return 1
    fi
    
    local host=$(echo "$server" | jq -r '.host')
    local port=$(echo "$server" | jq -r '.port')
    
    if curl -s -o /dev/null -w '%{http_code}' "http://$host:$port/health" | grep -q "200"; then
        print_success "MCP server is healthy"
    else
        print_error "MCP server is not responding"
        return 1
    fi
}

show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add-server <name> <host> <port> [auth_token]  Register new MCP server"
    echo "  remove-server <name>                          Unregister MCP server"
    echo "  list-servers                                  List registered servers"
    echo "  call-tool <server> <tool> [input]             Call MCP tool"
    echo "  get-cache [pattern]                           Get cached results"
    echo "  clear-cache                                   Clear cache"
    echo "  test-server <name>                            Test server connection"
    echo "  help                                          Show this help"
    echo ""
}

case "${1:-help}" in
    add-server) add_server "$2" "$3" "$4" "$5" ;;
    remove-server) remove_server "$2" ;;
    list-servers) list_servers ;;
    call-tool) call_tool "$2" "$3" "$4" ;;
    get-cache) get_cache "$2" ;;
    clear-cache) clear_cache ;;
    test-server) test_server "$2" ;;
    help|--help|-h) show_usage ;;
    *) print_error "Unknown command: $1"; echo ""; show_usage; exit 1 ;;
esac
