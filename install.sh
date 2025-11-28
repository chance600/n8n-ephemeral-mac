#!/bin/bash

# 📦 n8n Ephemeral Installation Script
# One-command setup for n8n ephemeral local runner

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emojis
CHECK="✅"
CROSS="❌"
WARN="⚠️"
ROCKET="🚀"
BOX="📦"

echo -e "${BLUE}============================================"
echo -e "$BOX n8n Ephemeral Installation"
echo -e "============================================${NC}\n"

# Function: Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${CROSS} ${RED}Not macOS${NC}"
        echo "This installer is designed for macOS M4. Detected: $OSTYPE"
        echo "For other systems, please install Docker manually and run ./start-n8n.sh"
        exit 1
    fi
    echo -e "${CHECK} ${GREEN}macOS detected${NC}"
}

# Function: Check prerequisites
check_prerequisites() {
    echo -e "\n${BLUE}1️⃣  Checking Prerequisites${NC}"
    echo "-------------------------------------------"
    
    local needs_install=false
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${CROSS} ${RED}Docker${NC} is not installed"
        needs_install=true
        
        echo -e "\n${YELLOW}Docker Installation Required${NC}"
        echo "Please install Docker Desktop for Mac:"
        echo "  1. Visit: https://www.docker.com/products/docker-desktop"
        echo "  2. Download Docker Desktop for Mac (Apple Silicon)"
        echo "  3. Install and start Docker Desktop"
        echo "  4. Run this script again"
        echo ""
        exit 1
    else
        echo -e "${CHECK} ${GREEN}Docker${NC} is installed"
    fi
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${WARN} ${YELLOW}Docker${NC} is not running"
        echo "  Please start Docker Desktop and run this script again"
        exit 1
    else
        echo -e "${CHECK} ${GREEN}Docker${NC} is running"
    fi
    
    # Check Git (should be present on macOS)
    if command -v git &> /dev/null; then
        echo -e "${CHECK} ${GREEN}Git${NC} is installed"
    else
        echo -e "${WARN} ${YELLOW}Git${NC} not found (installing via Xcode Command Line Tools)"
        xcode-select --install
    fi
    
    # Check curl
    if command -v curl &> /dev/null; then
        echo -e "${CHECK} ${GREEN}curl${NC} is installed"
    fi
    
    # Optional: Check jq
    if command -v jq &> /dev/null; then
        echo -e "${CHECK} ${GREEN}jq${NC} is installed"
    else
        echo -e "${WARN} ${YELLOW}jq${NC} not installed (optional)"
        echo "  Install with: brew install jq"
    fi
}

# Function: Setup repository
setup_repository() {
    echo -e "\n${BLUE}2️⃣  Setting up Repository${NC}"
    echo "-------------------------------------------"
    
    local repo_dir=$(pwd)
    echo -e "Repository location: ${GREEN}$repo_dir${NC}"
    
    # Make scripts executable
    if [ -f "start-n8n.sh" ]; then
        chmod +x start-n8n.sh
        echo -e "${CHECK} Made start-n8n.sh executable"
    fi
    
    if [ -f "stop-n8n.sh" ]; then
        chmod +x stop-n8n.sh
        echo -e "${CHECK} Made stop-n8n.sh executable"
    fi
    
    if [ -d "scripts" ]; then
        chmod +x scripts/*.sh 2>/dev/null || true
        echo -e "${CHECK} Made scripts executable"
    fi
}

# Function: Create data directories
create_data_dirs() {
    echo -e "\n${BLUE}3️⃣  Creating Data Directories${NC}"
    echo "-------------------------------------------"
    
    local n8n_dir="$HOME/.n8n"
    
    if [ ! -d "$n8n_dir" ]; then
        mkdir -p "$n8n_dir"
        echo -e "${CHECK} Created: $n8n_dir"
    else
        echo -e "${CHECK} Already exists: $n8n_dir"
    fi
    
    # Create subdirectories
    mkdir -p "$n8n_dir/backups"
    echo -e "${CHECK} Created: $n8n_dir/backups"
}

# Function: Create .env file from example
setup_env_file() {
    echo -e "\n${BLUE}4️⃣  Setting up Environment File${NC}"
    echo "-------------------------------------------"
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo -e "${CHECK} Created .env from .env.example"
            echo -e "${WARN} ${YELLOW}Remember to configure your credentials${NC}"
            echo "  Edit .env file to add your API keys"
        else
            echo -e "${WARN} No .env.example found, skipping"
        fi
    else
        echo -e "${CHECK} .env file already exists"
    fi
}

# Function: Pull Docker image
pull_docker_image() {
    echo -e "\n${BLUE}5️⃣  Pulling n8n Docker Image${NC}"
    echo "-------------------------------------------"
    echo "This may take a few minutes..."
    echo ""
    
    if docker pull n8nio/n8n:latest; then
        echo -e "\n${CHECK} ${GREEN}n8n Docker image downloaded${NC}"
    else
        echo -e "\n${WARN} ${YELLOW}Failed to pull image${NC}"
        echo "  Will download on first run"
    fi
}

# Function: Add to PATH (optional)
add_to_path() {
    echo -e "\n${BLUE}6️⃣  Optional: Add to PATH${NC}"
    echo "-------------------------------------------"
    
    local repo_dir=$(pwd)
    local shell_rc=""
    
    # Detect shell
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi
    
    if [ -n "$shell_rc" ]; then
        echo "Would you like to add this directory to your PATH?"
        echo "This will allow you to run n8n commands from anywhere."
        read -p "Add to PATH? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! grep -q "n8n-ephemeral-mac" "$shell_rc" 2>/dev/null; then
                echo "" >> "$shell_rc"
                echo "# n8n Ephemeral" >> "$shell_rc"
                echo "export PATH=\"$repo_dir:\$PATH\"" >> "$shell_rc"
                echo -e "${CHECK} Added to $shell_rc"
                echo "  Run: source $shell_rc"
            else
                echo -e "${CHECK} Already in PATH"
            fi
        else
            echo "Skipped adding to PATH"
        fi
    fi
}

# Function: Run health check
run_health_check() {
    echo -e "\n${BLUE}7️⃣  Running Health Check${NC}"
    echo "-------------------------------------------"
    
    if [ -f "scripts/health-check.sh" ]; then
        bash scripts/health-check.sh || true
    else
        echo -e "${WARN} Health check script not found"
    fi
}

# Function: Display success message
display_success() {
    echo -e "\n${GREEN}============================================"
    echo -e "$CHECK Installation Complete!"
    echo -e "============================================${NC}\n"
    
    echo -e "${ROCKET} ${GREEN}Next Steps:${NC}"
    echo ""
    echo "  1. Configure credentials (optional):"
    echo "     Edit the .env file with your API keys"
    echo ""
    echo "  2. Start n8n:"
    echo -e "     ${BLUE}./start-n8n.sh${NC} or ${BLUE}make start${NC}"
    echo ""
    echo "  3. Access Web UI:"
    echo "     http://localhost:5678"
    echo ""
    echo "  4. View available commands:"
    echo -e "     ${BLUE}make help${NC}"
    echo ""
    echo -e "${BLUE}Quick Commands:${NC}"
    echo "  make start   - Start n8n"
    echo "  make stop    - Stop n8n"
    echo "  make status  - Check status"
    echo "  make health  - Run health check"
    echo "  make logs    - View logs"
    echo ""
    echo -e "📚 For more info, see: README.md"
    echo ""
}

# Main installation flow
main() {
    check_macos
    check_prerequisites
    setup_repository
    create_data_dirs
    setup_env_file
    pull_docker_image
    add_to_path
    run_health_check
    display_success
}

# Run main function
main
