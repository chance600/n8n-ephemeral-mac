#!/bin/bash

# ⚡ Advanced Configuration Wizard for n8n Ephemeral Deployments
# Supports multi-profile setup, environment substitution, and config validation
# Enables dev/staging/prod configurations with dry-run and diff capabilities
# Part of n8n ephemeral deployment system for macOS M4

set -euo pipefail

# Configuration paths
CONFIG_DIR="${HOME}/.n8n/config-profiles"
ACTIVE_PROFILE_FILE="${HOME}/.n8n/active-profile"
CONFIG_ARCHIVE="${CONFIG_DIR}/archive"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize configuration directory
init_config_system() {
  mkdir -p "${CONFIG_DIR}" "${CONFIG_ARCHIVE}"
  
  if [[ ! -f "${ACTIVE_PROFILE_FILE}" ]]; then
    echo "default" > "${ACTIVE_PROFILE_FILE}"
    echo "${GREEN}✅ Initialized configuration system with default profile${NC}"
  fi
  
  # Create default profiles if not exist
  create_default_profiles
}

# Create default profiles (dev, staging, prod)
create_default_profiles() {
  # Development profile
  if [[ ! -f "${CONFIG_DIR}/dev.conf" ]]; then
    cat > "${CONFIG_DIR}/dev.conf" << 'EOF'
# Development Profile
N8N_ENVIRONMENT=development
N8N_LOG_LEVEL=debug
N8N_EDITOR_DISABLED=false
N8N_SMTP_ENABLED=false
DOCKER_MEMORY_LIMIT=2g
BACKUP_FREQUENCY=hourly
LOG_RETENTION_DAYS=7
ALLOW_ANONYMOUS_ACCESS=true
EOF
    echo "${GREEN}✅ Created development profile${NC}"
  fi
  
  # Staging profile
  if [[ ! -f "${CONFIG_DIR}/staging.conf" ]]; then
    cat > "${CONFIG_DIR}/staging.conf" << 'EOF'
# Staging Profile
N8N_ENVIRONMENT=staging
N8N_LOG_LEVEL=info
N8N_EDITOR_DISABLED=false
N8N_SMTP_ENABLED=true
DOCKER_MEMORY_LIMIT=3g
BACKUP_FREQUENCY=daily
LOG_RETENTION_DAYS=30
ALLOW_ANONYMOUS_ACCESS=false
EOF
    echo "${GREEN}✅ Created staging profile${NC}"
  fi
  
  # Production profile
  if [[ ! -f "${CONFIG_DIR}/prod.conf" ]]; then
    cat > "${CONFIG_DIR}/prod.conf" << 'EOF'
# Production Profile
N8N_ENVIRONMENT=production
N8N_LOG_LEVEL=warn
N8N_EDITOR_DISABLED=false
N8N_SMTP_ENABLED=true
DOCKER_MEMORY_LIMIT=4g
BACKUP_FREQUENCY=twice-daily
LOG_RETENTION_DAYS=90
ALLOW_ANONYMOUS_ACCESS=false
EOF
    echo "${GREEN}✅ Created production profile${NC}"
  fi
}

# List all available profiles
list_profiles() {
  local active=$(cat "${ACTIVE_PROFILE_FILE}" 2>/dev/null || echo "none")
  echo "${BLUE}📊 Available Configuration Profiles:${NC}"
  echo ""
  
  for profile in "${CONFIG_DIR}"/*.conf; do
    if [[ -f "$profile" ]]; then
      local profile_name=$(basename "$profile" .conf)
      if [[ "$profile_name" == "$active" ]]; then
        echo "${GREEN}✓${NC} $profile_name (${CYAN}ACTIVE${NC})"
      else
        echo "  $profile_name"
      fi
    fi
  done
  echo ""
}

# Switch active profile
switch_profile() {
  local new_profile="$1"
  
  if [[ ! -f "${CONFIG_DIR}/${new_profile}.conf" ]]; then
    echo "${RED}❌ Profile '${new_profile}' not found${NC}"
    return 1
  fi
  
  local old_profile=$(cat "${ACTIVE_PROFILE_FILE}")
  echo "${new_profile}" > "${ACTIVE_PROFILE_FILE}"
  
  echo "${GREEN}✅ Switched from '${old_profile}' to '${new_profile}'${NC}"
}

# Show active profile configuration
show_active_profile() {
  local active=$(cat "${ACTIVE_PROFILE_FILE}")
  echo "${BLUE}📚 Active Profile: ${CYAN}${active}${NC}"
  echo ""
  cat "${CONFIG_DIR}/${active}.conf" | grep -v '^#' | grep -v '^$'
  echo ""
}

# Substitute environment variables in configuration
substitute_environment_vars() {
  local config_file="$1"
  local output_file="${2:-}"
  
  if [[ -z "$output_file" ]]; then
    output_file=$(mktemp)
  fi
  
  # Replace environment variables using sed
  sed -E 's|\$\{([A-Z_]+)\}|'$(echo \${!1})'|g' "$config_file" > "$output_file"
  
  cat "$output_file"
}

# Validate configuration file
validate_config() {
  local config_file="$1"
  local errors=0
  
  echo "${BLUE}🔍 Validating configuration: $config_file${NC}"
  
  # Check for required keys
  local required_keys=("N8N_ENVIRONMENT" "N8N_LOG_LEVEL" "DOCKER_MEMORY_LIMIT")
  
  for key in "${required_keys[@]}"; do
    if ! grep -q "^${key}=" "$config_file"; then
      echo "${RED}❌ Missing required key: ${key}${NC}"
      ((errors++))
    fi
  done
  
  # Validate memory format
  local memory=$(grep "^DOCKER_MEMORY_LIMIT=" "$config_file" | cut -d'=' -f2)
  if ! [[ "$memory" =~ ^[0-9]+[gmk]$ ]]; then
    echo "${RED}❌ Invalid memory format: ${memory} (use format: 2g, 512m, etc)${NC}"
    ((errors++))
  fi
  
  if [[ $errors -eq 0 ]]; then
    echo "${GREEN}✅ Configuration is valid${NC}"
    return 0
  else
    echo "${RED}❌ Validation failed with ${errors} error(s)${NC}"
    return 1
  fi
}

# Create new custom profile
create_profile() {
  local profile_name="$1"
  local template_profile="${2:-default}"
  
  if [[ -f "${CONFIG_DIR}/${profile_name}.conf" ]]; then
    echo "${YELLOW}⚠️  Profile '${profile_name}' already exists${NC}"
    return 1
  fi
  
  # Copy from template
  local template_file="${CONFIG_DIR}/${template_profile}.conf"
  if [[ ! -f "$template_file" ]]; then
    template_file="${CONFIG_DIR}/dev.conf"
  fi
  
  cp "$template_file" "${CONFIG_DIR}/${profile_name}.conf"
  echo "${GREEN}✅ Created profile '${profile_name}' from template '${template_profile}'${NC}"
}

# Compare two configuration profiles
compare_profiles() {
  local profile1="$1"
  local profile2="$2"
  
  echo "${BLUE}🔍 Comparing profiles: ${profile1} vs ${profile2}${NC}"
  echo ""
  
  diff -u "${CONFIG_DIR}/${profile1}.conf" "${CONFIG_DIR}/${profile2}.conf" || true
}

# Backup current profile
backup_profile() {
  local active=$(cat "${ACTIVE_PROFILE_FILE}")
  local timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_file="${CONFIG_ARCHIVE}/${active}_${timestamp}.conf"
  
  cp "${CONFIG_DIR}/${active}.conf" "$backup_file"
  echo "${GREEN}✅ Backed up '${active}' to ${backup_file}${NC}"
}

# Restore profile from backup
restore_from_backup() {
  local backup_file="$1"
  
  if [[ ! -f "$backup_file" ]]; then
    echo "${RED}❌ Backup file not found: ${backup_file}${NC}"
    return 1
  fi
  
  local profile_name=$(basename "$backup_file" .conf | cut -d'_' -f1)
  cp "$backup_file" "${CONFIG_DIR}/${profile_name}.conf"
  
  echo "${GREEN}✅ Restored profile '${profile_name}' from backup${NC}"
}

# Dry-run: show what configuration would be applied
dry_run() {
  local profile="$1"
  
  echo "${YELLOW}🔄 Dry-run: Would apply profile '${profile}'${NC}"
  echo ""
  echo "${BLUE}Current active profile:${NC}"
  show_active_profile
  echo ""
  echo "${BLUE}Configuration to be applied:${NC}"
  cat "${CONFIG_DIR}/${profile}.conf" | grep -v '^#' | grep -v '^$'
  echo ""
  echo "${CYAN}Use 'switch-profile ${profile}' to apply${NC}"
}

# Display help
show_menu() {
  cat << 'EOF'
╔═══════════════════════════════════════════════════════╗
║    ⚡ Advanced Configuration Wizard                  ║
║    Multi-Profile n8n Ephemeral Setup                  ║
╚═══════════════════════════════════════════════════════╝

Commands:
  init                      Initialize configuration system
  list-profiles             Show all available profiles
  show-active               Display active profile config
  switch-profile <name>     Activate a configuration profile
  create-profile <name>     Create new profile from template
               [template]
  validate-config <file>    Validate configuration file
  compare-profiles <p1> <p2> Compare two profiles
  dry-run <profile>         Preview configuration changes
  backup-profile            Backup current profile
  restore <file>            Restore from backup file
  help                      Show this menu
EOF
}

# Main command router
main() {
  local command="${1:-help}"
  
  case "$command" in
    init) init_config_system ;;
    list-profiles) list_profiles ;;
    show-active) show_active_profile ;;
    switch-profile) switch_profile "${2:-}" ;;
    create-profile) create_profile "${2:-}" "${3:-dev}" ;;
    validate-config) validate_config "${2:-}" ;;
    compare-profiles) compare_profiles "${2:-}" "${3:-}" ;;
    dry-run) dry_run "${2:-}" ;;
    backup-profile) backup_profile ;;
    restore) restore_from_backup "${2:-}" ;;
    help) show_menu ;;
    *) echo "${RED}Unknown command: $command${NC}"; show_menu; exit 1 ;;
  esac
}

main "$@"
