#!/bin/bash

################################################################################
# n8n Execution Logger 📊
# Real-time workflow execution monitoring and detailed logging
# Tracks performance metrics, errors, and execution history
################################################################################

set -euo pipefail

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="${HOME}/.n8n/logs"
LOG_FILE="${LOG_DIR}/execution.log"
ERROR_LOG="${LOG_DIR}/errors.log"
PERF_LOG="${LOG_DIR}/performance.log"
N8N_INSTANCE="http://localhost:5678"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

################################################################################
# UTILITY FUNCTIONS
################################################################################

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}" >&2
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
  echo -e "${CYAN}ℹ️  $1${NC}"
}

print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${PURPLE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

log_message() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local level=$1
  local message=$2
  echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

log_error() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local message=$1
  local stack_trace=${2:-""}
  echo "[$timestamp] ERROR: $message" >> "$ERROR_LOG"
  if [[ -n "$stack_trace" ]]; then
    echo "Stack trace: $stack_trace" >> "$ERROR_LOG"
    echo "---" >> "$ERROR_LOG"
  fi
}

log_performance() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local workflow_id=$1
  local duration=$2
  local status=$3
  echo "[$timestamp] Workflow: $workflow_id | Duration: ${duration}ms | Status: $status" >> "$PERF_LOG"
}

################################################################################
# MONITORING FUNCTIONS
################################################################################

monitor_executions() {
  print_header "🔄 Monitoring n8n Executions"
  print_info "Watching for workflow executions..."
  
  local prev_count=0
  
  while true; do
    if ! command -v curl &> /dev/null; then
      print_error "curl is required for monitoring"
      return 1
    fi
    
    # Fetch recent executions from n8n API
    local response=$(curl -s "${N8N_INSTANCE}/api/v1/executions?limit=10" 2>/dev/null || echo "{}")
    
    # Parse execution count
    local current_count=$(echo "$response" | grep -o '"id"' | wc -l)
    
    if [[ $current_count -gt $prev_count ]]; then
      print_success "New execution detected!"
      log_message "INFO" "New execution started"
    fi
    
    prev_count=$current_count
    sleep 5
  done
}

################################################################################
# LOG ANALYSIS FUNCTIONS
################################################################################

analyze_logs() {
  print_header "📈 Execution Log Analysis"
  
  if [[ ! -f "$LOG_FILE" ]]; then
    print_warning "No execution logs found"
    return
  fi
  
  local total_lines=$(wc -l < "$LOG_FILE")
  local success_count=$(grep -c "SUCCESS" "$LOG_FILE" || true)
  local error_count=$(grep -c "ERROR" "$LOG_FILE" || true)
  local warning_count=$(grep -c "WARNING" "$LOG_FILE" || true)
  
  echo "${CYAN}Log Summary:${NC}"
  echo "  Total entries: $total_lines"
  echo "  ${GREEN}✅ Success: $success_count${NC}"
  echo "  ${RED}❌ Errors: $error_count${NC}"
  echo "  ${YELLOW}⚠️  Warnings: $warning_count${NC}"
}

show_recent_errors() {
  print_header "❌ Recent Errors"
  
  if [[ ! -f "$ERROR_LOG" ]]; then
    print_info "No errors recorded"
    return
  fi
  
  echo -e "${RED}Last 10 errors:${NC}"
  tail -n 10 "$ERROR_LOG"
}

show_performance_stats() {
  print_header "⚡ Performance Statistics"
  
  if [[ ! -f "$PERF_LOG" ]]; then
    print_info "No performance data available"
    return
  fi
  
  echo -e "${CYAN}Execution Performance:${NC}"
  
  # Extract duration values and calculate stats
  local durations=$(grep -oP '(?<=Duration: )\d+' "$PERF_LOG" || true)
  
  if [[ -z "$durations" ]]; then
    print_info "No performance metrics yet"
    return
  fi
  
  local avg_duration=$(echo "$durations" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
  local max_duration=$(echo "$durations" | sort -n | tail -1)
  local min_duration=$(echo "$durations" | sort -n | head -1)
  
  echo "  Average duration: ${avg_duration}ms"
  echo "  Max duration: ${max_duration}ms"
  echo "  Min duration: ${min_duration}ms"
  echo "  Total executions: $(echo "$durations" | wc -w)"
}

################################################################################
# EXPORT FUNCTIONS
################################################################################

export_logs() {
  local format=${1:-json}
  local output_file="${LOG_DIR}/export_$(date +%s).${format}"
  
  print_info "Exporting logs to: $output_file"
  
  case $format in
    json)
      # Convert logs to JSON format
      echo '{"executions": [' > "$output_file"
      grep -v '^\[' "$LOG_FILE" 2>/dev/null | while read line; do
        echo "  {\"log\": \"$line\"}," >> "$output_file"
      done
      echo ']}' >> "$output_file"
      print_success "Logs exported to JSON"
      ;;
    csv)
      # Convert logs to CSV format
      echo "timestamp,level,message" > "$output_file"
      grep . "$LOG_FILE" 2>/dev/null | sed 's/\[//g; s/\]//g' | tr ' ' ',' >> "$output_file"
      print_success "Logs exported to CSV"
      ;;
    *)
      print_error "Unknown export format: $format"
      return 1
      ;;
  esac
}

################################################################################
# CLEANUP FUNCTIONS
################################################################################

cleanup_logs() {
  print_header "🧹 Cleaning Up Logs"
  
  local days_to_keep=${1:-30}
  
  print_info "Removing logs older than $days_to_keep days..."
  
  find "$LOG_DIR" -name "*.log" -mtime +"$days_to_keep" -delete
  find "$LOG_DIR" -name "*.json" -mtime +"$days_to_keep" -delete
  
  local remaining=$(find "$LOG_DIR" -type f | wc -l)
  print_success "Cleanup complete. $remaining log files remaining."
}

archive_logs() {
  print_header "📦 Archiving Logs"
  
  local archive_name="n8n-logs-$(date +%Y%m%d-%H%M%S).tar.gz"
  
  if [[ ! -d "$LOG_DIR" ]] || [[ ! "$(ls -A "$LOG_DIR")" ]]; then
    print_warning "No logs to archive"
    return
  fi
  
  tar -czf "${HOME}/Downloads/${archive_name}" -C "${LOG_DIR}/.." "logs/"
  print_success "Logs archived to: ~/Downloads/${archive_name}"
}

################################################################################
# MAIN MENU
################################################################################

show_menu() {
  print_header "n8n Execution Logger 📊"
  echo "Options:"
  echo ""
  echo "  1) 🔄 Monitor executions (real-time)"
  echo "  2) 📈 Analyze logs"
  echo "  3) ❌ Show recent errors"
  echo "  4) ⚡ Performance statistics"
  echo "  5) 💾 Export logs (JSON)"
  echo "  6) 💾 Export logs (CSV)"
  echo "  7) 🧹 Cleanup old logs"
  echo "  8) 📦 Archive logs"
  echo "  9) 📄 View full log"
  echo "  0) Exit"
  echo ""
}

view_full_log() {
  print_header "Full Execution Log"
  if [[ -f "$LOG_FILE" ]]; then
    less "$LOG_FILE"
  else
    print_warning "No logs available"
  fi
}

################################################################################
# MAIN LOOP
################################################################################

main() {
  while true; do
    show_menu
    read -p "${CYAN}Select option (0-9):${NC} " choice
    
    case $choice in
      1) monitor_executions ;;
      2) analyze_logs ;;
      3) show_recent_errors ;;
      4) show_performance_stats ;;
      5) export_logs json ;;
      6) export_logs csv ;;
      7) cleanup_logs ;;
      8) archive_logs ;;
      9) view_full_log ;;
      0)
        print_success "Thank you for using n8n Execution Logger!"
        exit 0
        ;;
      *)
        print_error "Invalid selection. Please try again."
        ;;
    esac
  done
}

# Show usage
if [[ $# -gt 0 ]] && [[ "$1" == "-h" || "$1" == "--help" ]]; then
  print_header "n8n Execution Logger - Usage"
  echo "Run without arguments to start interactive menu:"
  echo "  ./scripts/execution-logger.sh"
  echo ""
  echo "Available functions:"
  echo "  - Real-time execution monitoring"
  echo "  - Log analysis and statistics"
  echo "  - Error tracking and debugging"
  echo "  - Performance metrics collection"
  echo "  - Log export (JSON/CSV)"
  echo "  - Log cleanup and archival"
  echo ""
  exit 0
fi

# Run main menu
main
