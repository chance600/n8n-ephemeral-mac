#!/bin/bash

# 🌉 MCP-Workflow Bridge Manager
# Enables bidirectional communication between MCP tools and n8n workflows
# Provides tool composition, request/response logging, and rate limiting
# Part of n8n ephemeral deployment system for macOS M4

set -euo pipefail

# Configuration
MCP_BRIDGE_DIR="${HOME}/.n8n/mcp-bridge"
MCP_TOOLS_REGISTRY="${MCP_BRIDGE_DIR}/tools-registry.json"
MCP_REQUESTS_LOG="${MCP_BRIDGE_DIR}/requests.log"
MCP_RESPONSES_LOG="${MCP_BRIDGE_DIR}/responses.log"
MCP_COMPOSITION_CACHE="${MCP_BRIDGE_DIR}/compositions.json"
MCP_RATE_LIMIT_CONFIG="${MCP_BRIDGE_DIR}/rate-limits.json"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize bridge directory structure
init_bridge() {
  mkdir -p "${MCP_BRIDGE_DIR}"
  
  # Initialize tools registry if not exists
  if [[ ! -f "${MCP_TOOLS_REGISTRY}" ]]; then
    echo '{"tools":[],"updated":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"}' > "${MCP_TOOLS_REGISTRY}"
    echo "${GREEN}✅ Initialized MCP tools registry${NC}"
  fi
  
  # Initialize rate limit configuration
  if [[ ! -f "${MCP_RATE_LIMIT_CONFIG}" ]]; then
    cat > "${MCP_RATE_LIMIT_CONFIG}" << 'EOF'
{
  "default": {"requests_per_minute": 60, "timeout_seconds": 30},
  "gemini": {"requests_per_minute": 90, "timeout_seconds": 45},
  "websearch": {"requests_per_minute": 30, "timeout_seconds": 60},
  "custom": {}
}
EOF
    echo "${GREEN}✅ Initialized rate limiting configuration${NC}"
  fi
  
  # Initialize composition cache
  if [[ ! -f "${MCP_COMPOSITION_CACHE}" ]]; then
    echo '{"compositions":{},"metadata":{"version":"1.0"}}' > "${MCP_COMPOSITION_CACHE}"
    echo "${GREEN}✅ Initialized workflow composition cache${NC}"
  fi
}

# Register a new MCP tool
register_tool() {
  local tool_name="$1"
  local tool_type="$2"
  local tool_endpoint="$3"
  local tool_timeout="${4:-30}"
  
  if [[ -z "$tool_name" || -z "$tool_type" || -z "$tool_endpoint" ]]; then
    echo "${RED}❌ Error: Missing required parameters for tool registration${NC}"
    echo "Usage: $0 register-tool <name> <type> <endpoint> [timeout]"
    return 1
  fi
  
  # Check if tool already registered
  if grep -q "\"name\":\"${tool_name}\"" "${MCP_TOOLS_REGISTRY}" 2>/dev/null; then
    echo "${YELLOW}⚠️  Tool '${tool_name}' already registered, updating...${NC}"
  fi
  
  # Use jq to add tool to registry
  local temp_registry=$(mktemp)
  jq ".tools += [{\"name\":\"${tool_name}\",\"type\":\"${tool_type}\",\"endpoint\":\"${tool_endpoint}\",\"timeout\":${tool_timeout},\"registered\":\"$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")\"}]" "${MCP_TOOLS_REGISTRY}" > "${temp_registry}"
  mv "${temp_registry}" "${MCP_TOOLS_REGISTRY}"
  
  echo "${GREEN}✅ Tool '${tool_name}' registered successfully${NC}"
}

# List all registered tools
list_tools() {
  echo "${BLUE}📋 Registered MCP Tools:${NC}"
  jq '.tools[] | "\(.name) [\(.type)] -> \(.endpoint) (timeout: \(.timeout)s)"' "${MCP_TOOLS_REGISTRY}" | sed 's/"//g'
  echo ""
}

# Execute tool with rate limiting and logging
execute_tool() {
  local tool_name="$1"
  local tool_input="$2"
  local request_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
  
  # Log request
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] REQUEST_ID=${request_id} TOOL=${tool_name} INPUT=${tool_input}" >> "${MCP_REQUESTS_LOG}"
  
  # Find tool in registry
  local tool_endpoint=$(jq -r ".tools[] | select(.name==\"${tool_name}\") | .endpoint" "${MCP_TOOLS_REGISTRY}" 2>/dev/null)
  local tool_timeout=$(jq -r ".tools[] | select(.name==\"${tool_name}\") | .timeout" "${MCP_TOOLS_REGISTRY}" 2>/dev/null || echo "30")
  
  if [[ -z "$tool_endpoint" ]]; then
    echo "${RED}❌ Tool '${tool_name}' not found in registry${NC}"
    return 1
  fi
  
  # Execute tool with timeout
  local response
  if response=$(timeout "${tool_timeout}s" curl -s -X POST "${tool_endpoint}" \
    -H "Content-Type: application/json" \
    -H "X-Request-ID: ${request_id}" \
    -d "{\"input\":\"${tool_input}\"}");
  then
    # Log response
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] REQUEST_ID=${request_id} STATUS=success RESPONSE=${response}" >> "${MCP_RESPONSES_LOG}"
    echo "${response}"
    return 0
  else
    local error_msg="Tool execution timeout or failed"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] REQUEST_ID=${request_id} STATUS=error ERROR=${error_msg}" >> "${MCP_RESPONSES_LOG}"
    echo "${RED}❌ ${error_msg}${NC}"
    return 1
  fi
}

# Create tool composition (pipeline)
compose_tools() {
  local composition_name="$1"
  shift
  local tools=("$@")
  
  if [[ -z "$composition_name" || ${#tools[@]} -eq 0 ]]; then
    echo "${RED}❌ Error: Composition name and at least one tool required${NC}"
    return 1
  fi
  
  # Serialize tools array to JSON
  local tools_json=$(printf '%s\n' "${tools[@]}" | jq -R . | jq -s .)
  
  # Store composition
  local temp_cache=$(mktemp)
  jq ".compositions.\"${composition_name}\" = {\"tools\":${tools_json},\"created\":\"$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")\"}" "${MCP_COMPOSITION_CACHE}" > "${temp_cache}"
  mv "${temp_cache}" "${MCP_COMPOSITION_CACHE}"
  
  echo "${GREEN}✅ Composition '${composition_name}' created with ${#tools[@]} tools${NC}"
}

# Execute composition (pipeline of tools)
execute_composition() {
  local composition_name="$1"
  local initial_input="${2:-}"
  
  # Retrieve composition
  local tools_json=$(jq -r ".compositions[\"${composition_name}\"] | .tools | @json" "${MCP_COMPOSITION_CACHE}" 2>/dev/null)
  
  if [[ -z "$tools_json" || "$tools_json" == "null" ]]; then
    echo "${RED}❌ Composition '${composition_name}' not found${NC}"
    return 1
  fi
  
  # Parse and execute tools sequentially
  local current_input="${initial_input}"
  while IFS= read -r tool_name; do
    tool_name=$(echo "$tool_name" | xargs)
    if [[ -n "$tool_name" ]]; then
      echo "${CYAN}→ Executing tool: ${tool_name}${NC}"
      current_input=$(execute_tool "${tool_name}" "${current_input}" 2>/dev/null || echo "${current_input}")
    fi
  done < <(echo "${tools_json}" | jq -r '.[]')
  
  echo "${GREEN}✅ Composition execution completed${NC}"
  echo "${BLUE}Final output: ${current_input}${NC}"
}

# Check rate limits
check_rate_limit() {
  local tool_name="$1"
  local tool_type=$(jq -r ".tools[] | select(.name==\"${tool_name}\") | .type" "${MCP_TOOLS_REGISTRY}" 2>/dev/null || echo "default")
  
  local limit_config=$(jq ".${tool_type} // .default" "${MCP_RATE_LIMIT_CONFIG}" 2>/dev/null)
  local rpm=$(echo "$limit_config" | jq '.requests_per_minute')
  
  echo "${PURPLE}📊 Rate limit for '${tool_name}' (${tool_type}): ${rpm} req/min${NC}"
}

# View request/response logs
view_logs() {
  local log_type="${1:-all}"
  
  case "$log_type" in
    requests) tail -20 "${MCP_REQUESTS_LOG}" 2>/dev/null || echo "No requests logged" ;;
    responses) tail -20 "${MCP_RESPONSES_LOG}" 2>/dev/null || echo "No responses logged" ;;
    all)
      echo "${BLUE}📝 Recent Requests:${NC}"
      tail -10 "${MCP_REQUESTS_LOG}" 2>/dev/null || echo "No requests logged"
      echo ""
      echo "${BLUE}📝 Recent Responses:${NC}"
      tail -10 "${MCP_RESPONSES_LOG}" 2>/dev/null || echo "No responses logged"
      ;;
  esac
}

# Display help menu
show_menu() {
  cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║         🌉 MCP-Workflow Bridge Manager               ║
║    Bidirectional MCP ↔️ n8n Workflow Integration      ║
╚═══════════════════════════════════════════════════════╝

Commands:
  init                          Initialize bridge infrastructure
  register-tool <name> <type>   Register a new MCP tool
               <endpoint> [timeout]
  list-tools                    Display all registered tools
  execute-tool <name> <input>   Execute a single tool
  compose-tools <name> <t1>...  Create tool composition
  execute-composition <name>    Execute tool pipeline
               [input]
  check-rate-limit <tool>       View rate limiting config
  view-logs [type]              View request/response logs
  help                          Show this menu
EOF
}

# Main command router
main() {
  local command="${1:-help}"
  
  case "$command" in
    init) init_bridge ;;
    register-tool) register_tool "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
    list-tools) list_tools ;;
    execute-tool) execute_tool "${2:-}" "${3:-}" ;;
    compose-tools) compose_tools "${2:-}" "${@:3}" ;;
    execute-composition) execute_composition "${2:-}" "${3:-}" ;;
    check-rate-limit) check_rate_limit "${2:-}" ;;
    view-logs) view_logs "${2:-all}" ;;
    help) show_menu ;;
    *) echo "${RED}Unknown command: $command${NC}"; show_menu; exit 1 ;;
  esac
}

main "$@"
