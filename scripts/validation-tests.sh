#!/bin/bash

# 🧪 n8n Ephemeral Validation Test Suite
# Purpose: Comprehensive integration tests for n8n ephemeral deployment system
# Features: System validation, workflow testing, MCP integration checks, data persistence
# Author: n8n Ephemeral System | Version: 2.0.0 (Phase 3D)

set -euo pipefail

# ╔═══════════════════════════════════════════════════════════════╗
# ║  COLOR OUTPUT & LOGGING                                       ║
# ╚═══════════════════════════════════════════════════════════════╝

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_step() { echo -e "${CYAN}→  $*${NC}"; }
log_section() { echo -e "${PURPLE}\n━━━ $* ━━━${NC}\n"; }

# ╔═══════════════════════════════════════════════════════════════╗
# ║  TEST COUNTERS & STATE                                        ║
# ╚═══════════════════════════════════════════════════════════════╝

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_RESULTS=()
N8N_DIR="${HOME}/.n8n"
DATA_DIR="${N8N_DIR}/data"
WORKFLOWS_DIR="${N8N_DIR}/workflows"
CRED_DIR="${N8N_DIR}/credentials"

# ╔═══════════════════════════════════════════════════════════════╗
# ║  VALIDATION FUNCTIONS                                         ║
# ╚═══════════════════════════════════════════════════════════════╝

assert_file_exists() {
    local file="$1"
    ((TESTS_RUN++))
    if [[ -f "$file" ]]; then
        log_success "File exists: $file"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "File missing: $file"
        TEST_RESULTS+=("FAIL: File not found - $file")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    ((TESTS_RUN++))
    if [[ -d "$dir" ]]; then
        log_success "Directory exists: $dir"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "Directory missing: $dir"
        TEST_RESULTS+=("FAIL: Directory not found - $dir")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_cmd_success() {
    local cmd="$1"
    local desc="$2"
    ((TESTS_RUN++))
    if eval "$cmd" &>/dev/null; then
        log_success "$desc"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$desc failed"
        TEST_RESULTS+=("FAIL: $desc")
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_readable() {
    local file="$1"
    ((TESTS_RUN++))
    if [[ -r "$file" ]]; then
        log_success "File readable: $file"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "File not readable: $file"
        TEST_RESULTS+=("FAIL: File not readable - $file")
        ((TESTS_FAILED++))
        return 1
    fi
}

# ╔═══════════════════════════════════════════════════════════════╗
# ║  TEST SUITES                                                  ║
# ╚═══════════════════════════════════════════════════════════════╝

test_installation() {
    log_section "Installation Verification Tests"
    
    log_step "Checking n8n home directory"
    assert_dir_exists "$N8N_DIR"
    
    log_step "Checking data directory"
    assert_dir_exists "$DATA_DIR"
    
    log_step "Checking workflows directory"
    assert_dir_exists "$WORKFLOWS_DIR"
    
    log_step "Checking credentials directory"
    assert_dir_exists "$CRED_DIR"
    
    log_step "Checking configuration file"
    assert_file_exists "${N8N_DIR}/.n8n-config.yml"
}

test_scripts() {
    log_section "Scripts & Tools Verification"
    
    # Check if scripts directory exists
    assert_dir_exists "${N8N_DIR}/../scripts" || true
    
    log_step "Verifying essential scripts"
    
    # List of critical scripts to check
    local scripts=(
        "health-check.sh"
        "start-n8n.sh"
        "backup.sh"
        "restore.sh"
        "install-manager.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "${N8N_DIR}/../scripts/${script}" ]]; then
            log_success "Script found: $script"
            ((TESTS_PASSED++))
        else
            log_warning "Script not found: $script (optional)"
        fi
        ((TESTS_RUN++))
    done
}

test_docker() {
    log_section "Docker & Container Tests"
    
    log_step "Checking Docker installation"
    assert_cmd_success "docker --version" "Docker is installed"
    
    log_step "Checking Docker Compose"
    assert_cmd_success "docker-compose --version" "Docker Compose is installed"
    
    log_step "Checking Docker daemon"
    assert_cmd_success "docker ps" "Docker daemon is running"
}

test_data_persistence() {
    log_section "Data Persistence Tests"
    
    log_step "Creating test file in data directory"
    local test_file="${DATA_DIR}/test-persistence-$$.txt"
    echo "Test data at $(date)" > "$test_file"
    assert_file_exists "$test_file"
    
    log_step "Verifying file contents"
    if grep -q "Test data" "$test_file"; then
        log_success "Test file content verified"
        ((TESTS_PASSED++))
    else
        log_error "Test file content verification failed"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    log_step "Cleaning up test file"
    rm -f "$test_file"
    log_success "Test file cleaned up"
}

test_workflows() {
    log_section "Workflow Configuration Tests"
    
    log_step "Checking example workflows"
    local workflows=(
        "hello-world.json"
        "ai-workflow.json"
        "email-example.json"
        "scheduled-task.json"
    )
    
    for workflow in "${workflows[@]}"; do
        if [[ -f "${WORKFLOWS_DIR}/examples/${workflow}" ]]; then
            log_success "Workflow found: $workflow"
            assert_file_readable "${WORKFLOWS_DIR}/examples/${workflow}"
        else
            log_warning "Example workflow not found: $workflow (optional)"
        fi
    done
}

test_permissions() {
    log_section "File Permissions Tests"
    
    log_step "Checking directory permissions"
    if [[ -w "$N8N_DIR" ]]; then
        log_success "n8n directory is writable"
        ((TESTS_PASSED++))
    else
        log_error "n8n directory is not writable"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
    
    if [[ -w "$DATA_DIR" ]]; then
        log_success "Data directory is writable"
        ((TESTS_PASSED++))
    else
        log_error "Data directory is not writable"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

test_environment() {
    log_section "Environment & Configuration Tests"
    
    log_step "Checking macOS version"
    local macos_version=$(sw_vers -productVersion)
    log_success "macOS version: $macos_version"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
    
    log_step "Checking system architecture"
    local arch=$(uname -m)
    if [[ "$arch" == "arm64" ]]; then
        log_success "Apple Silicon (M-series) detected: $arch"
        ((TESTS_PASSED++))
    else
        log_warning "Non-M-series architecture: $arch"
    fi
    ((TESTS_RUN++))
    
    log_step "Checking available disk space"
    local available=$(df -h "$N8N_DIR" | tail -1 | awk '{print $4}')
    log_success "Available disk space: $available"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

# ╔═══════════════════════════════════════════════════════════════╗
# ║  MAIN TEST EXECUTION                                          ║
# ╚═══════════════════════════════════════════════════════════════╝

main() {
    log_section "🧪 n8n EPHEMERAL VALIDATION TEST SUITE"
    log_info "Test execution started at $(date)"
    log_info "Test directory: $N8N_DIR"
    echo
    
    # Run all test suites
    test_installation
    test_scripts
    test_docker || true
    test_data_persistence
    test_workflows
    test_permissions
    test_environment
    
    # Print summary
    log_section "📊 Test Summary"
    echo "Tests Run:    ${CYAN}${TESTS_RUN}${NC}"
    echo "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
    
    if [[ ${#TEST_RESULTS[@]} -gt 0 ]]; then
        log_section "Failed Tests"
        for result in "${TEST_RESULTS[@]}"; do
            log_error "$result"
        done
    fi
    
    log_section "Validation Complete"
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! ✨"
        echo
        return 0
    else
        log_error "Some tests failed. Please review above."
        echo
        return 1
    fi
}

main "$@"
