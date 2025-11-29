#!/bin/bash

################################################################################
# n8n Session Cache Manager 💾
# Persistent state caching between container restarts
# Serializes workflow state, execution history, and config snapshots
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

# Cache configuration
CACHE_DIR="${HOME}/.n8n/session-cache"
STATE_FILE="${CACHE_DIR}/state.json"
HISTORY_FILE="${CACHE_DIR}/execution-history.json"
METADATA_FILE="${CACHE_DIR}/metadata.json"
CREDS_SNAPSHOT="${CACHE_DIR}/credentials-snapshot.json"
MAX_CACHE_AGE=2592000  # 30 days in seconds

mkdir -p "$CACHE_DIR"

################################################################################
# UTILITY FUNCTIONS
################################################################################

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}" >&2; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${PURPLE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

################################################################################
# STATE MANAGEMENT
################################################################################

save_state() {
  print_info "Saving session state to cache..."
  
  local workflow_state=$(cat "${HOME}/.n8n/workflows.json" 2>/dev/null || echo '{}')
  local timestamp=$(date +%s)
  
  local state_json=$(cat <<EOF
{
  "timestamp": $timestamp,
  "version": "1.0",
  "workflows": $workflow_state,
  "workflow_count": $(echo "$workflow_state" | python3 -m json.tool 2>/dev/null | grep -c '"id"' || echo 0),
  "last_execution": $(date -u +%Y-%m-%dT%H:%M:%SZ)
}
EOF
  )
  
  echo "$state_json" > "$STATE_FILE"
  print_success "State saved"
}

restore_state() {
  print_header "🔄 Restoring Session State"
  
  if [[ ! -f "$STATE_FILE" ]]; then
    print_info "No cached state found (first run)"
    return 1
  fi
  
  local age=$(( $(date +%s) - $(stat -f%m "$STATE_FILE" 2>/dev/null || echo 0) ))
  
  if [[ $age -gt $MAX_CACHE_AGE ]]; then
    print_info "Cache expired ($(( age / 86400 )) days old)"
    return 1
  fi
  
  print_info "Cache is fresh ($(( age / 60 )) minutes old)"
  
  # Restore workflows
  if [[ -f "$STATE_FILE" ]]; then
    local workflows=$(python3 -c "import json; print(json.load(open('$STATE_FILE'))['workflows'])" 2>/dev/null)
    if [[ -n "$workflows" && "$workflows" != "{}" ]]; then
      print_success "Restoring $(python3 -c "import json; print(len(json.load(open('$STATE_FILE'))['workflows'].get('nodes', [])))" 2>/dev/null || echo "?") workflows from cache"
      echo "$workflows" > "${HOME}/.n8n/workflows.json"
      return 0
    fi
  fi
  
  return 1
}

################################################################################
# EXECUTION HISTORY
################################################################################

record_execution() {
  local workflow_name=$1
  local status=$2
  local duration=$3
  
  print_info "Recording execution: $workflow_name → $status"
  
  local record=$(cat <<EOF
{
  "workflow": "$workflow_name",
  "status": "$status",
  "duration_ms": $duration,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  )
  
  # Append to history (as JSON array)
  if [[ -f "$HISTORY_FILE" ]]; then
    # Add to existing array
    python3 -c "
import json
with open('$HISTORY_FILE', 'r') as f:
    history = json.load(f)
history.append($record)
with open('$HISTORY_FILE', 'w') as f:
    json.dump(history, f, indent=2)
" || echo "[]"
  else
    echo "[$record]" | python3 -m json.tool > "$HISTORY_FILE"
  fi
}

show_execution_history() {
  print_header "📜 Execution History"
  
  if [[ ! -f "$HISTORY_FILE" ]]; then
    print_info "No execution history"
    return
  fi
  
  local count=$(python3 -c "import json; print(len(json.load(open('$HISTORY_FILE'))))" 2>/dev/null || echo 0)
  local successes=$(python3 -c "import json; print(len([x for x in json.load(open('$HISTORY_FILE')) if x.get('status') == 'success']))" 2>/dev/null || echo 0)
  local failures=$(python3 -c "import json; print(len([x for x in json.load(open('$HISTORY_FILE')) if x.get('status') == 'failed']))" 2>/dev/null || echo 0)
  
  echo "Total executions: $count"
  echo -e "${GREEN}✅ Successes: $successes${NC}"
  echo -e "${RED}❌ Failures: $failures${NC}"
  echo ""
  echo "Recent executions:"
  tail -20 "$HISTORY_FILE" | python3 -m json.tool 2>/dev/null || cat "$HISTORY_FILE"
}

################################################################################
# CACHE METADATA
################################################################################

update_metadata() {
  local metadata=$(cat <<EOF
{
  "cache_version": "1.0",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "cache_dir": "$CACHE_DIR",
  "n8n_home": "${HOME}/.n8n",
  "hostname": "$(hostname)",
  "cache_size_mb": $(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}' || echo "0MB")
}
EOF
  )
  echo "$metadata" | python3 -m json.tool > "$METADATA_FILE"
}

show_cache_status() {
  print_header "📊 Cache Status"
  
  if [[ ! -f "$METADATA_FILE" ]]; then
    print_info "Cache not initialized"
    return
  fi
  
  python3 -m json.tool < "$METADATA_FILE" || cat "$METADATA_FILE"
  
  echo ""
  local cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
  print_info "Total cache size: $cache_size"
}

################################################################################
# CLEANUP & MAINTENANCE
################################################################################

clean_cache() {
  print_header "🧹 Cleaning Cache"
  
  print_info "Removing files older than 30 days..."
  find "$CACHE_DIR" -type f -mtime +30 -delete
  
  print_info "Removing orphaned history entries..."
  if [[ -f "$HISTORY_FILE" ]]; then
    # Keep only last 1000 executions
    python3 -c "
import json
with open('$HISTORY_FILE', 'r') as f:
    history = json.load(f)
history = history[-1000:] if len(history) > 1000 else history
with open('$HISTORY_FILE', 'w') as f:
    json.dump(history, f, indent=2)
" 2>/dev/null || true
  fi
  
  print_success "Cache cleaned"
}

export_cache() {
  local export_file="${HOME}/Downloads/n8n-session-cache-$(date +%Y%m%d-%H%M%S).tar.gz"
  
  print_info "Exporting cache to: $export_file"
  tar -czf "$export_file" -C "${HOME}/.n8n" session-cache/ 2>/dev/null
  
  print_success "Cache exported"
}

################################################################################
# MAIN MENU
################################################################################

show_menu() {
  print_header "n8n Session Cache Manager 💾"
  echo "Commands:"
  echo "  save        Save current session state to cache"
  echo "  restore     Restore session from cache"
  echo "  history     Show execution history"
  echo "  status      Show cache status and metadata"
  echo "  clean       Cleanup old cache files"
  echo "  export      Export cache to downloads"
  echo "  help        Show this menu"
  echo ""
}

case "${1:-help}" in
  save) save_state ;;
  restore) restore_state ;;
  history) show_execution_history ;;
  status) show_cache_status ;;
  clean) clean_cache ;;
  export) export_cache ;;
  record) record_execution "${2:-unknown}" "${3:-unknown}" "${4:-0}" ;;
  *) show_menu ;;
esac
