#!/bin/bash

################################################################################
# n8n MCP Tool Registry & Auto-Discovery 🔭
# Auto-generates MCP tool definitions from workflow metadata
# Enables AI assistants to discover and use n8n workflows as tools
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}" >&2; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${PURPLE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

REGISTRY_FILE="${HOME}/.n8n/mcp-tool-registry.json"
REGISTRY_CACHE="${HOME}/.n8n/mcp-registry-cache.json"

generate_registry() {
  print_header "🔧 Generating MCP Tool Registry"
  
  local registry=$(cat <<'EOF'
{
  "version": "1.0",
  "generated": "TIMESTAMP",
  "tools": []
}
EOF
  )
  
  # Get all workflow files
  local workflows=()
  if [[ -d "${HOME}/.n8n/workflows" ]]; then
    mapfile -t workflows < <(find "${HOME}/.n8n/workflows" -name "*.json" -type f)
  fi
  
  print_info "Found ${#workflows[@]} workflows"
  
  local tools_json="[]"
  for workflow_file in "${workflows[@]}"; do
    print_info "Processing: $(basename "$workflow_file")"
    
    # Extract workflow metadata
    local workflow_id=$(basename "$workflow_file" .json)
    local workflow_name=$(python3 -c "import json; print(json.load(open('$workflow_file')).get('name', '$workflow_id'))" 2>/dev/null || echo "$workflow_id")
    local workflow_desc=$(python3 -c "import json; print(json.load(open('$workflow_file')).get('description', 'n8n workflow'))" 2>/dev/null || echo "n8n workflow")
    
    # Get input parameters from workflow nodes
    local inputs=$(python3 -c "
import json
wf = json.load(open('$workflow_file'))
nodes = wf.get('nodes', [])
inputs = []
for node in nodes:
  if node.get('type') == 'n8n-nodes-base.httpRequest':
    if 'parameters' in node:
      params = node['parameters']
      for k, v in params.items():
        if k not in ['method', 'url']:
          inputs.append({'name': k, 'type': 'string', 'required': False})
print(json.dumps(inputs))
" 2>/dev/null || echo "[]")
    
    # Create MCP tool definition
    local tool=$(cat <<EOF
{
  "name": "$workflow_name",
  "workflow_id": "$workflow_id",
  "description": "$workflow_desc",
  "type": "workflow",
  "inputSchema": {
    "type": "object",
    "properties": {},
    "required": []
  },
  "outputSchema": {
    "type": "object",
    "description": "Workflow execution result"
  },
  "tags": ["n8n", "workflow", "automation"],
  "version": "1.0"
}
EOF
    )
    
    tools_json=$(python3 -c "import json; tools=json.loads('''$tools_json'''); tools.append(json.loads('''$tool''')); print(json.dumps(tools))")
  done
  
  # Finalize registry
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  registry=$(echo "$registry" | sed "s/TIMESTAMP/$timestamp/")
  
  echo "$registry" | python3 -c "import json, sys; r=json.load(sys.stdin); r['tools']=$tools_json; print(json.dumps(r, indent=2))" > "$REGISTRY_FILE"
  
  print_success "Registry generated: $REGISTRY_FILE"
}

list_tools() {
  print_header "📚 Available MCP Tools"
  
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    print_info "Registry not generated. Run: generate"
    return
  fi
  
  python3 -c "
import json
with open('$REGISTRY_FILE', 'r') as f:
  registry = json.load(f)
  tools = registry.get('tools', [])
  print(f'Total tools: {len(tools)}')
  print()
  for tool in tools:
    print(f'  {tool[\"name\"]}:')
    print(f'    ID: {tool.get(\"workflow_id\", \"?\")}')
    print(f'    Description: {tool.get(\"description\", \"No description\")}')
    print()
"  
fi
}

export_registry() {
  print_info "Exporting registry for AI model consumption..."
  
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    print_error "Registry not generated"
  fi
  
  local export_file="${HOME}/Downloads/n8n-mcp-tools-$(date +%Y%m%d-%H%M%S).json"
  cp "$REGISTRY_FILE" "$export_file"
  
  print_success "Registry exported to: $export_file"
}

validate_tools() {
  print_header "✅ Validating Tool Definitions"
  
  if [[ ! -f "$REGISTRY_FILE" ]]; then
    print_error "Registry not generated"
  fi
  
  python3 -c "
import json
with open('$REGISTRY_FILE', 'r') as f:
  registry = json.load(f)
  tools = registry.get('tools', [])
  
  errors = 0
  for tool in tools:
    required_fields = ['name', 'description', 'inputSchema']
    for field in required_fields:
      if field not in tool:
        print(f'ERROR: Tool {tool.get(\"name\", \"unknown\")} missing {field}')
        errors += 1
  
  if errors == 0:
    print(f'✅ All {len(tools)} tools validated successfully')
  else:
    print(f'❌ Found {errors} validation errors')
" || print_error "Validation failed"
}

show_menu() {
  print_header "n8n MCP Tool Registry"
  echo "Commands:"
  echo "  generate    Generate/update tool registry from workflows"
  echo "  list        List all available MCP tools"
  echo "  export      Export registry for AI models"
  echo "  validate    Validate tool definitions"
  echo "  help        Show this menu"
  echo ""
}

case "${1:-help}" in
  generate) generate_registry ;;
  list) list_tools ;;
  export) export_registry ;;
  validate) validate_tools ;;
  *) show_menu ;;
esac
