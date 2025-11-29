#!/bin/bash

################################################################################
# n8n Workflow Metadata Generator 📄
# Extracts and enriches workflow metadata for documentation and execution
# Generates CLI arguments from workflow inputs
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

METADATA_DIR="${HOME}/.n8n/metadata"
mkdir -p "$METADATA_DIR"

extract_metadata() {
  local workflow_file="$1"
  
  if [[ ! -f "$workflow_file" ]]; then
    print_error "Workflow file not found: $workflow_file"
    return 1
  fi
  
  print_info "Extracting metadata from: $(basename "$workflow_file")"
  
  local workflow_id=$(basename "$workflow_file" .json)
  local metadata_file="${METADATA_DIR}/${workflow_id}.json"
  
  # Extract metadata using Python
  python3 -c "
import json
with open('$workflow_file', 'r') as f:
  wf = json.load(f)

metadata = {
  'id': wf.get('id', '$workflow_id'),
  'name': wf.get('name', '$workflow_id'),
  'description': wf.get('description', 'n8n workflow'),
  'tags': wf.get('tags', []),
  'version': wf.get('version', '1.0'),
  'nodes': [],
  'connections': wf.get('connections', {}),
  'inputs': [],
  'outputs': [],
  'created_at': wf.get('createdAt', 'unknown'),
  'updated_at': wf.get('updatedAt', 'unknown')
}

# Extract nodes and parameters
for node in wf.get('nodes', []):
  node_data = {
    'id': node.get('id'),
    'name': node.get('name'),
    'type': node.get('type'),
    'parameters': node.get('parameters', {})
  }
  metadata['nodes'].append(node_data)
  
  # Extract CLI-friendly parameters
  for param_key, param_val in node.get('parameters', {}).items():
    if param_key not in ['nodeCredentialType', 'authentication']:
      metadata['inputs'].append({
        'name': param_key,
        'type': 'string',
        'value': str(param_val) if not isinstance(param_val, dict) else 'object',
        'node_id': node.get('id')
      })

with open('$metadata_file', 'w') as f:
  json.dump(metadata, f, indent=2)
" || print_error "Failed to extract metadata"
  
  print_success "Metadata saved to: $metadata_file"
}

generate_cli_spec() {
  local metadata_file="$1"
  
  if [[ ! -f "$metadata_file" ]]; then
    print_error "Metadata file not found: $metadata_file"
    return 1
  fi
  
  local cli_spec_file="${metadata_file%.json}.cli.txt"
  
  print_info "Generating CLI specification..."
  
  python3 -c "
import json
with open('$metadata_file', 'r') as f:
  metadata = json.load(f)

cli_args = f\"\"\"WORKFLOW: {metadata['name']}
DESCRIPTION: {metadata['description']}
VERSION: {metadata['version']}

CLI USAGE:
  ./scripts/n8n-runner.sh --workflow {metadata['id']}\"\"\"

if metadata.get('inputs'):
  cli_args += \"\\n\nOPTIONAL ARGUMENTS:\\n\"
  for input_param in metadata['inputs'][:10]:  # Limit to 10 for readability
    cli_args += f\"  --{input_param['name']} VALUE\\n\"

with open('$cli_spec_file', 'w') as f:
  f.write(cli_args)
" || print_error "Failed to generate CLI spec"
  
  print_success "CLI spec saved to: $cli_spec_file"
}

validate_metadata() {
  local metadata_file="$1"
  
  if [[ ! -f "$metadata_file" ]]; then
    print_error "Metadata file not found: $metadata_file"
    return 1
  fi
  
  print_header "✅ Validating Metadata"
  
  python3 -c "
import json
with open('$metadata_file', 'r') as f:
  metadata = json.load(f)

required_fields = ['id', 'name', 'description']
errors = 0

for field in required_fields:
  if field not in metadata or not metadata[field]:
    print(f'ERROR: Missing required field: {field}')
    errors += 1

if errors == 0:
  print(f'✅ Metadata is valid')
  print(f'   Name: {metadata.get(\"name\")}')
  print(f'   Nodes: {len(metadata.get(\"nodes\", []))}')
  print(f'   Inputs: {len(metadata.get(\"inputs\", []))}')
else:
  print(f'❌ Found {errors} validation errors')
" || print_error "Validation failed"
}

generate_docs() {
  print_header "📄 Generating Documentation"
  
  if [[ ! -d "$METADATA_DIR" ]]; then
    print_error "No metadata directory found"
    return 1
  fi
  
  local docs_file="${HOME}/n8n-workflows-documentation.md"
  
  echo "# n8n Workflows Documentation" > "$docs_file"
  echo "" >> "$docs_file"
  echo "Generated: $(date)" >> "$docs_file"
  echo "" >> "$docs_file"
  
  # Add workflow entries
  for metadata_file in "${METADATA_DIR}"/*.json; do
    if [[ -f "$metadata_file" ]]; then
      python3 -c "
import json
with open('$metadata_file', 'r') as f:
  metadata = json.load(f)

doc = f\"\"\"\n## {metadata.get('name', 'Unknown')}

**ID:** \`{metadata.get('id')}\`  
**Description:** {metadata.get('description')}  
**Version:** {metadata.get('version')}  

### Inputs
\"\"\" 
if metadata.get('inputs'):
  for inp in metadata['inputs'][:5]:
    doc += f\"- \`{inp['name']}\` (type: {inp.get('type', 'string')})\\n\"
else:
  doc += \"No inputs configured\\n\"

doc += f\"\"\"\n### Usage
\`\`\`bash
./scripts/n8n-runner.sh --workflow {metadata.get('id')}
\`\`\`
\"\"\" 
print(doc, end='')
" >> "$docs_file" || true
    fi
  done
  
  print_success "Documentation generated: $docs_file"
}

show_menu() {
  print_header "n8n Workflow Metadata Generator"
  echo "Commands:"
  echo "  extract <file>    Extract metadata from workflow file"
  echo "  generate-cli <file> Generate CLI specification"
  echo "  validate <file>   Validate workflow metadata"
  echo "  docs              Generate documentation from all workflows"
  echo "  list              List all extracted metadata"
  echo "  help              Show this menu"
  echo ""
}

list_metadata() {
  print_header "📄 Extracted Workflow Metadata"
  
  if [[ ! -d "$METADATA_DIR" ]]; then
    print_info "No metadata extracted yet"
    return
  fi
  
  for metadata_file in "${METADATA_DIR}"/*.json; do
    if [[ -f "$metadata_file" ]]; then
      python3 -c "
import json
with open('$metadata_file', 'r') as f:
  metadata = json.load(f)
  print(f\"  {metadata.get('name', 'Unknown')} ({metadata.get('id')})\")  
" || true
    fi
  done
}

case "${1:-help}" in
  extract) extract_metadata "${2:-.}" && generate_cli "${METADATA_DIR}/$(basename "${2:-.}" .json).json" ;;
  generate-cli) generate_cli_spec "$2" ;;
  validate) validate_metadata "$2" ;;
  docs) generate_docs ;;
  list) list_metadata ;;
  *) show_menu ;;
esac
