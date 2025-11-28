#!/bin/bash

# 🔑 n8n Credentials Setup Wizard
# Interactive wizard to configure API credentials for n8n workflows

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Emojis
CHECK="✅"
KEY="🔑"
WARN="⚠️"
INFO="ℹ️"

ENV_FILE=".env"
ENV_EXAMPLE=".env.example"

echo -e "${BLUE}=========================================" 
echo -e "$KEY n8n Credentials Setup Wizard"
echo -e "=========================================${NC}\n"

echo -e "This wizard will help you configure API credentials for n8n."
echo -e "${WARN} ${YELLOW}Note:${NC} Never commit the .env file to git!\n"

# Function: Create .env from example
create_env_from_example() {
    if [ ! -f "$ENV_FILE" ] && [ -f "$ENV_EXAMPLE" ]; then
        echo -e "${INFO} Creating .env from .env.example..."
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo -e "${CHECK} .env file created\n"
    elif [ ! -f "$ENV_FILE" ]; then
        echo -e "${INFO} Creating new .env file...\n"
        touch "$ENV_FILE"
    fi
}

# Function: Update or add environment variable
update_env_var() {
    local key="$1"
    local value="$2"
    
    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        # Update existing
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
        rm -f "${ENV_FILE}.bak"
    else
        # Add new
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

# Function: Get current value
get_env_var() {
    local key="$1"
    grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || echo ""
}

# Function: Setup Gemini API
setup_gemini_api() {
    echo -e "${BLUE}1️⃣  Google Gemini API${NC}"
    echo "-------------------------------------------"
    echo "Gemini is used for AI-powered workflow automation."
    echo -e "Get your API key: ${BLUE}https://makersuite.google.com/app/apikey${NC}\n"
    
    local current=$(get_env_var "GEMINI_API_KEY")
    if [ -n "$current" ]; then
        echo -e "${INFO} Current key: ${current:0:10}...${current: -4}"
    fi
    
    read -p "Enter Gemini API key (or press Enter to skip): " gemini_key
    
    if [ -n "$gemini_key" ]; then
        update_env_var "GEMINI_API_KEY" "$gemini_key"
        echo -e "${CHECK} Gemini API key configured\n"
    else
        echo -e "${WARN} Skipped\n"
    fi
}

# Function: Setup Gmail OAuth
setup_gmail_oauth() {
    echo -e "${BLUE}2️⃣  Gmail OAuth2${NC}"
    echo "-------------------------------------------"
    echo "Required for sending emails via Gmail in workflows."
    echo -e "Setup: ${BLUE}https://console.cloud.google.com/apis/credentials${NC}\n"
    
    echo -e "${WARN} ${YELLOW}Note:${NC} Gmail OAuth requires interactive setup in n8n UI"
    echo "  1. Start n8n: ./start-n8n.sh"
    echo "  2. Go to: http://localhost:5678/credentials"
    echo "  3. Add 'Gmail OAuth2' credential"
    echo -e "  4. Follow the OAuth flow\n"
    
    read -p "Press Enter to continue..."
    echo ""
}

# Function: Setup Google Maps API
setup_google_maps_api() {
    echo -e "${BLUE}3️⃣  Google Maps API${NC}"
    echo "-------------------------------------------"
    echo "Used for geocoding and location services."
    echo -e "Get your API key: ${BLUE}https://console.cloud.google.com/google/maps-apis${NC}\n"
    
    local current=$(get_env_var "GOOGLE_MAPS_API_KEY")
    if [ -n "$current" ]; then
        echo -e "${INFO} Current key: ${current:0:10}...${current: -4}"
    fi
    
    read -p "Enter Google Maps API key (or press Enter to skip): " maps_key
    
    if [ -n "$maps_key" ]; then
        update_env_var "GOOGLE_MAPS_API_KEY" "$maps_key"
        echo -e "${CHECK} Google Maps API key configured\n"
    else
        echo -e "${WARN} Skipped\n"
    fi
}

# Function: Setup custom credentials
setup_custom_credentials() {
    echo -e "${BLUE}4️⃣  Custom Credentials${NC}"
    echo "-------------------------------------------"
    echo "Add any additional API keys or credentials."
    echo ""
    
    while true; do
        read -p "Add another credential? (y/N): " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            break
        fi
        
        read -p "Credential name (e.g., OPENAI_API_KEY): " cred_name
        read -p "Credential value: " cred_value
        
        if [ -n "$cred_name" ] && [ -n "$cred_value" ]; then
            update_env_var "$cred_name" "$cred_value"
            echo -e "${CHECK} $cred_name configured\n"
        fi
    done
}

# Function: Display summary
display_summary() {
    echo -e "\n${GREEN}=========================================" 
    echo -e "$CHECK Setup Complete!"
    echo -e "=========================================${NC}\n"
    
    echo "Your credentials have been saved to .env"
    echo ""
    echo "Next steps:"
    echo "  1. Review .env file: cat .env"
    echo "  2. Start n8n: ./start-n8n.sh or 'make start'"
    echo "  3. Configure OAuth credentials in n8n UI"
    echo "     URL: http://localhost:5678/credentials"
    echo ""
    echo -e "${WARN} ${YELLOW}Security Reminder:${NC}"
    echo "  - Never commit .env to version control"
    echo "  - Keep your API keys secure"
    echo "  - Rotate keys regularly"
    echo ""
}

# Main execution
main() {
    create_env_from_example
    setup_gemini_api
    setup_gmail_oauth
    setup_google_maps_api
    setup_custom_credentials
    display_summary
}

# Run main function
main
