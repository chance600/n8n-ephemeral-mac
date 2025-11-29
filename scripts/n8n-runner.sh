#!/bin/bash

################################################################################
# n8n Unified Runner 🏃
# Single-command orchestration for complete n8n workflow lifecycle
# Handles: startup → cache restore → workflow import → execution
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}" >&2; exit 1; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${PURPLE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Defaults
WORKFLOW_NAME=""
WORKFLOW_ID=""
OUTPUT_FORMAT="json"
RUN_MODE="sync"
RESTORE_STATE=true
AUTO_START=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --workflow) WORKFLOW_NAME="$2"; shift 2 ;;
    --id) WORKFLOW_ID="$2"; shift 2 ;;
    --output) OUTPUT_FORMAT="$2"; shift 2 ;;
    --mode) RUN_MODE="$2"; shift 2 ;;
    --no-cache) RESTORE_STATE=false; shift ;;
    --no-start) AUTO_START=false; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) print_error "Unknown option: $1"; ;;
  esac
done

show_help() {
  print_header "n8n Unified Runner"
  echo "Usage: ./scripts/n8n-runner.sh --workflow <name> [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --workflow NAME     Workflow name to execute (required)"
  echo "  --id ID            Workflow ID (optional)"
  echo "  --output FORMAT    Output format: json|text|csv (default: json)"
  echo "  --mode MODE        Execution mode: sync|async (default: sync)"
  echo "  --no-cache         Skip session state restoration"
  echo "  --no-start         Don't auto-start n8n container"
  echo ""
  echo "Examples:"
  echo "  ./scripts/n8n-runner.sh --workflow email-blast"
  echo "  ./scripts/n8n-runner.sh --workflow scraper --mode async"
  echo "  ./scripts/n8n-runner.sh --workflow ai-task --output csv --no-cache"
}

check_n8n_running() {
  if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

start_n8n() {
  print_info "Starting n8n container..."
  
  if ! check_n8n_running; then
    ./scripts/start-n8n.sh > /dev/null 2>&1 || print_error "Failed to start n8n"
    
    # Wait for n8n to be ready
    local count=0
    while ! check_n8n_running && [[ $count -lt 30 ]]; do
      print_info "Waiting for n8n... ($count/30)"
      sleep 1
      count=$((count + 1))
    done
    
    if check_n8n_running; then
      print_success "n8n is ready"
    else
      print_error "n8n failed to start"
    fi
  else
    print_success "n8n already running"
  fi
}

restore_session() {
  if [[ "$RESTORE_STATE" == "true" ]]; then
    print_info "Restoring session from cache..."
    if ./scripts/session-cache.sh restore; then
      print_success "Session restored"
    else
      print_info "No previous session to restore (first run)"
    fi
  fi
}

import_workflows() {
  print_info "Importing workflows..."
  
  if [[ -d "${HOME}/.n8n/workflows" ]]; then
    local count=$(find "${HOME}/.n8n/workflows" -name "*.json" | wc -l)
    print_info "Found $count workflows to import"
    
    # Import workflows
    ./scripts/import-workflows.sh > /dev/null 2>&1 || print_error "Failed to import workflows"
    print_success "Workflows imported"
  fi
}

execute_workflow() {
  if [[ -z "$WORKFLOW_NAME" ]]; then
    print_error "No workflow specified. Use --workflow <name>"
  fi
  
  print_header "⌨️  Executing Workflow: $WORKFLOW_NAME"
  
  # Find workflow by name or ID
  local workflow_file
  if [[ -n "$WORKFLOW_ID" ]]; then
    workflow_file="${HOME}/.n8n/workflows/${WORKFLOW_ID}.json"
  else
    workflow_file=$(find "${HOME}/.n8n/workflows" -name "*${WORKFLOW_NAME}*.json" | head -1)
  fi
  
  if [[ ! -f "$workflow_file" ]]; then
    print_error "Workflow not found: $WORKFLOW_NAME"
  fi
  
  local start_time=$(date +%s%N)
  print_info "Starting execution..."
  
  # Execute workflow (using n8n CLI or API)
  local result={}
  if [[ "$RUN_MODE" == "async" ]]; then
    result=$(curl -s -X POST http://localhost:5678/api/v1/workflows/execute \
      -H "Content-Type: application/json" \
      -d "{\"workflowId\": \"$(basename $workflow_file .json)\"}")
  else
    result=$(curl -s -X POST http://localhost:5678/api/v1/workflows/execute \
      -H "Content-Type: application/json" \
      -d "{\"workflowId\": \"$(basename $workflow_file .json)\"}")
  fi
  
  local end_time=$(date +%s%N)
  local duration=$(( (end_time - start_time) / 1000000 ))
  
  # Record execution
  ./scripts/session-cache.sh record "$WORKFLOW_NAME" "success" "$duration" 2>/dev/null || true
  
  # Format output
  case $OUTPUT_FORMAT in
    json)
      echo "$result" | python3 -m json.tool
      ;;
    text)
      echo "$result" | python3 -c "import sys, json; d=json.load(sys.stdin); print('\\n'.join([f'{k}: {v}' for k,v in d.items()]))"
      ;;
    csv)
      echo "$result" | python3 -c "import sys, json; d=json.load(sys.stdin); print(','.join(d.keys())); print(','.join(map(str,d.values())))"
      ;;
  esac
  
  print_success "Workflow execution completed in ${duration}ms"
  ./scripts/session-cache.sh save 2>/dev/null || true
}

################################################################################
# MAIN EXECUTION
################################################################################

print_header "n8n Unified Runner 🏃"

if [[ "$AUTO_START" == "true" ]]; then
  start_n8n
else
  if ! check_n8n_running; then
    print_error "n8n is not running. Use --auto-start or start manually."
  fi
fi

restore_session
import_workflows
execute_workflow
