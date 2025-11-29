install-manager.sh#!/bin/bash

# 📦 n8n Ephemeral Installation & Update Manager
# Comprehensive system setup, version management, and validation
# Handles installation, updates, verification, and dependency management
# macOS M4 optimized for Apple Silicon

set -euo pipefail

# Configuration
REPO_DIR="${HOME}/.n8n/ephemeral"
VERSION_FILE="${REPO_DIR}/.version"
BACKUP_DIR="${HOME}/.n8n/backups"
LOG_FILE="${HOME}/.n8n/install.log"
CURRENT_VERSION="2.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging function
log_message() {
  local level="$1"
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
  echo "$message"
}

# Check system requirements
check_requirements() {
  log_message "INFO" "Checking system requirements..."
  
  local missing_reqs=()
  
  # Check for Docker
  if ! command -v docker &> /dev/null; then
    missing_reqs+=("Docker")
  fi
  
  # Check for Docker Compose
  if ! command -v docker-compose &> /dev/null; then
    missing_reqs+=("Docker Compose")
  fi
  
  # Check for jq
  if ! command -v jq &> /dev/null; then
    missing_reqs+=("jq")
  fi
  
  # Check for git
  if ! command -v git &> /dev/null; then
    missing_reqs+=("Git")
  fi
  
  # Check macOS version (M4 = Sonoma or later)
  local macos_version=$(sw_vers -productVersion | cut -d. -f1)
  if [[ $macos_version -lt 14 ]]; then
    missing_reqs+=("macOS 14+ (Sonoma)")
  fi
  
  if [[ ${#missing_reqs[@]} -gt 0 ]]; then
    echo "${RED}❌ Missing requirements:${NC}"
    for req in "${missing_reqs[@]}"; do
      echo "  • $req"
    done
    return 1
  fi
  
  echo "${GREEN}✅ All system requirements satisfied${NC}"
  return 0
}

# Initialize directories
init_directories() {
  log_message "INFO" "Initializing directory structure..."
  
  mkdir -p "${REPO_DIR}"
  mkdir -p "${BACKUP_DIR}"
  mkdir -p "${HOME}/.n8n/config-profiles"
  mkdir -p "${HOME}/.n8n/mcp-bridge"
  mkdir -p "${HOME}/.n8n/sessions"
  
  # Set permissions
  chmod 700 "${HOME}/.n8n"
  
  echo "${GREEN}✅ Directory structure initialized${NC}"
}

# Download and extract repository
setup_repository() {
  log_message "INFO" "Setting up repository..."
  
  if [[ -d "${REPO_DIR}/.git" ]]; then
    echo "Repository already exists. Running update..."
    cd "${REPO_DIR}"
    git pull origin main
  else
    git clone https://github.com/chance600/n8n-ephemeral-mac.git "${REPO_DIR}"
  fi
  
  echo "${GREEN}✅ Repository setup complete${NC}"
}

# Verify installation
verify_installation() {
  log_message "INFO" "Verifying installation..."
  
  local verification_errors=0
  
  # Check required scripts
  local required_scripts=(
    "scripts/start-n8n.sh"
    "scripts/health-check.sh"
    "scripts/session-manager.sh"
    "scripts/mcp-workflow-bridge.sh"
    "scripts/config-wizard-advanced.sh"
  )
  
  for script in "${required_scripts[@]}"; do
    if [[ ! -f "${REPO_DIR}/${script}" ]]; then
      echo "${RED}❌ Missing: $script${NC}"
      ((verification_errors++))
    fi
  done
  
  # Check configuration files
  local required_configs=(
    ".n8n-config.yml"
    "docker-compose.yml"
  )
  
  for config in "${required_configs[@]}"; do
    if [[ ! -f "${REPO_DIR}/${config}" ]]; then
      echo "${RED}❌ Missing: $config${NC}"
      ((verification_errors++))
    fi
  done
  
  if [[ $verification_errors -eq 0 ]]; then
    echo "${GREEN}✅ Installation verified successfully${NC}"
    return 0
  else
    echo "${RED}❌ Verification failed with $verification_errors error(s)${NC}"
    return 1
  fi
}

# Create version file
record_version() {
  local version="$1"
  echo "$version" > "$VERSION_FILE"
  echo "{\"version\":\"$version\",\"installed\":\"$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")\"}" > "${REPO_DIR}/.install-info.json"
}

# Get installed version
get_installed_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    cat "$VERSION_FILE"
  else
    echo "0.0.0"
  fi
}

# Check for updates
check_updates() {
  log_message "INFO" "Checking for updates..."
  
  local installed_version=$(get_installed_version)
  
  echo "${BLUE}📦 Installed version: ${installed_version}${NC}"
  echo "${BLUE}📦 Latest version: ${CURRENT_VERSION}${NC}"
  
  if [[ "$installed_version" == "$CURRENT_VERSION" ]]; then
    echo "${GREEN}✅ Already on latest version${NC}"
    return 0
  else
    echo "${YELLOW}⚠️  Update available!${NC}"
    return 1
  fi
}

# Backup before update
backup_system() {
  log_message "INFO" "Creating backup..."
  
  local backup_timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_file="${BACKUP_DIR}/backup_${backup_timestamp}.tar.gz"
  
  tar -czf "$backup_file" \
    -C "${HOME}/.n8n" config-profiles sessions mcp-bridge 2>/dev/null || true
  
  echo "${GREEN}✅ Backup created: $backup_file${NC}"
  log_message "INFO" "Backup created: $backup_file"
}

# Display system information
show_system_info() {
  echo "${CYAN}═══════════════════════════════════════════════════════${NC}"
  echo "${CYAN}  n8n Ephemeral System Information${NC}"
  echo "${CYAN}═══════════════════════════════════════════════════════${NC}"
  echo ""
  echo "${BLUE}System:${NC}"
  echo "  macOS Version: $(sw_vers -productVersion)"
  echo "  Architecture: $(uname -m)"
  echo "  CPU Cores: $(sysctl -n hw.ncpu)"
  echo "  Memory: $(expr $(sysctl -n hw.memsize) / 1024 / 1024 / 1024)GB"
  echo ""
  echo "${BLUE}Installation:${NC}"
  echo "  Version: $(get_installed_version)"
  echo "  Location: ${REPO_DIR}"
  echo "  Backups: ${BACKUP_DIR}"
  echo ""
  echo "${BLUE}Docker:${NC}"
  echo "  Docker: $(docker --version)"
  echo "  Compose: $(docker-compose --version)"
  echo ""
  echo "${CYAN}═══════════════════════════════════════════════════════${NC}"
}

# Main installation flow
install_system() {
  log_message "INFO" "═══ Starting n8n Ephemeral Installation ═══"
  
  echo "${PURPLE}🚀 Installing n8n Ephemeral Deployment System${NC}"
  echo ""
  
  check_requirements || {
    log_message "ERROR" "System requirements check failed"
    return 1
  }
  
  init_directories || {
    log_message "ERROR" "Directory initialization failed"
    return 1
  }
  
  setup_repository || {
    log_message "ERROR" "Repository setup failed"
    return 1
  }
  
  verify_installation || {
    log_message "ERROR" "Installation verification failed"
    return 1
  }
  
  record_version "$CURRENT_VERSION"
  
  echo ""
  echo "${GREEN}✅ Installation completed successfully!${NC}"
  log_message "INFO" "Installation completed successfully"
  
  echo ""
  show_system_info
}

# Update system
update_system() {
  log_message "INFO" "═══ Starting n8n Ephemeral Update ═══"
  
  echo "${PURPLE}🔄 Updating n8n Ephemeral System${NC}"
  echo ""
  
  if check_updates; then
    return 0
  fi
  
  backup_system
  
  cd "${REPO_DIR}"
  git fetch origin
  git merge origin/main
  
  verify_installation || {
    log_message "ERROR" "Update verification failed"
    return 1
  }
  
  record_version "$CURRENT_VERSION"
  
  echo ""
  echo "${GREEN}✅ Update completed successfully!${NC}"
  log_message "INFO" "Update completed successfully"
}

# Display help menu
show_help() {
  cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║  📦 n8n Ephemeral Installation & Update Manager       ║
║  Automated setup and maintenance for macOS M4         ║
╚═══════════════════════════════════════════════════════╝

Usage: install-manager.sh [COMMAND]

Commands:
  install              Full system installation
  update               Update to latest version
  verify               Verify system integrity
  check-updates        Check for available updates
  system-info          Display system information
  requirements         Check system requirements
  backup               Create system backup
  help                 Show this help menu

Examples:
  ./install-manager.sh install
  ./install-manager.sh update
  ./install-manager.sh verify
EOF
}

# Main command router
main() {
  local command="${1:-help}"
  
  mkdir -p "$(dirname "$LOG_FILE")"
  
  case "$command" in
    install) install_system ;;
    update) update_system ;;
    verify) verify_installation ;;
    check-updates) check_updates ;;
    system-info) show_system_info ;;
    requirements) check_requirements ;;
    backup) backup_system ;;
    help) show_help ;;
    *) echo "Unknown command: $command"; show_help; exit 1 ;;
  esac
}

main "$@"
