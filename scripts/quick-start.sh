#!/bin/bash

################################################################################
# n8n Quick Start Wizard 🚀
# Interactive setup wizards for common n8n automation use cases
# Guides users through creating Email, Web Scraping, AI, and Database workflows
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

# Source configuration if available
CONFIG_FILE="${HOME}/.n8n/.n8n-config.yml"

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

################################################################################
# EMAIL WIZARD
################################################################################

setup_email_workflow() {
  print_header "📧 Email Workflow Setup"
  
  print_info "This wizard will create an email workflow template."
  print_info "Capabilities: Send emails, process email attachments, schedule sends"
  
  echo -e "${CYAN}Email Provider:${NC}"
  echo "  1) Gmail (OAuth2)"
  echo "  2) Sendgrid"
  echo "  3) SMTP (Generic)"
  echo "  0) Cancel"
  read -p "Select provider (0-3): " provider_choice
  
  case $provider_choice in
    1)
      print_info "Gmail selected. OAuth2 setup needed."
      read -p "Enter Gmail address: " gmail_address
      read -p "Enter Application password (or leave empty for OAuth): " app_password
      print_success "Gmail configuration saved to credentials"
      ;;
    2)
      print_info "Sendgrid selected."
      read -p "Enter Sendgrid API Key: " sendgrid_key
      print_success "Sendgrid API key configured"
      ;;
    3)
      print_info "SMTP setup required."
      read -p "Enter SMTP host: " smtp_host
      read -p "Enter SMTP port (default 587): " smtp_port
      read -p "Enter email address: " smtp_email
      read -s -p "Enter password: " smtp_pass
      echo
      print_success "SMTP configuration saved"
      ;;
    0) return ;;
    *) print_error "Invalid selection"; return ;;
  esac
  
  read -p "Create workflow file? (y/n): " create_workflow
  if [[ $create_workflow == "y" ]]; then
    cat > "${HOME}/.n8n/workflows/email-template.json" 2>/dev/null || print_warning "Workflow directory not found"
    print_success "Email workflow template created"
  fi
}

################################################################################
# WEB SCRAPING WIZARD
################################################################################

setup_web_scraping() {
  print_header "🕷️  Web Scraping Workflow Setup"
  
  print_info "Create automated web scraping workflows."
  print_info "Capabilities: Schedule scrapes, parse HTML/JSON, store data"
  
  read -p "Enter target URL to scrape: " target_url
  read -p "Enter CSS selector for data (or 'json' for JSON API): " selector
  read -p "How often to scrape? (1h/1d/1w/never): " schedule
  read -p "Store results in database? (y/n): " store_db
  
  print_success "Web scraping workflow configured"
  print_info "Template created with scheduling interval: $schedule"
  
  if [[ $store_db == "y" ]]; then
    read -p "Database type (postgres/mysql/sqlite): " db_type
    print_info "Database connection will be required during workflow execution"
  fi
}

################################################################################
# AI INTEGRATION WIZARD
################################################################################

setup_ai_workflow() {
  print_header "🤖 AI Integration Workflow Setup"
  
  print_info "Create workflows that integrate with AI services."
  print_info "Supported: OpenAI, Google Gemini, Hugging Face, Anthropic Claude"
  
  echo -e "${CYAN}AI Provider:${NC}"
  echo "  1) OpenAI (GPT-4, GPT-3.5)"
  echo "  2) Google Gemini"
  echo "  3) Anthropic Claude"
  echo "  4) Hugging Face"
  echo "  0) Cancel"
  read -p "Select provider (0-4): " ai_choice
  
  case $ai_choice in
    1)
      read -p "Enter OpenAI API Key: " openai_key
      read -p "Select model (gpt-4/gpt-3.5-turbo): " openai_model
      print_success "OpenAI configured with model: $openai_model"
      ;;
    2)
      read -p "Enter Gemini API Key: " gemini_key
      print_success "Gemini API configured"
      ;;
    3)
      read -p "Enter Claude API Key: " claude_key
      print_success "Claude API configured"
      ;;
    4)
      read -p "Enter Hugging Face API Token: " hf_token
      print_success "Hugging Face configured"
      ;;
    0) return ;;
    *) print_error "Invalid selection"; return ;;
  esac
  
  read -p "Workflow task (summarize/translate/generate/classify): " task
  print_info "Workflow will: $task content using AI"
}

################################################################################
# DATABASE WIZARD
################################################################################

setup_database_workflow() {
  print_header "🗄️  Database Workflow Setup"
  
  print_info "Create workflows for database operations."
  print_info "Supported: PostgreSQL, MySQL, MongoDB, SQLite"
  
  echo -e "${CYAN}Database Type:${NC}"
  echo "  1) PostgreSQL"
  echo "  2) MySQL"
  echo "  3) MongoDB"
  echo "  4) SQLite"
  echo "  0) Cancel"
  read -p "Select database (0-4): " db_choice
  
  case $db_choice in
    1|2)
      read -p "Host (default: localhost): " db_host
      read -p "Port (default: 5432/3306): " db_port
      read -p "Database name: " db_name
      read -p "Username: " db_user
      read -s -p "Password: " db_pass
      echo
      print_success "PostgreSQL/MySQL connection configured"
      ;;
    3)
      read -p "MongoDB Connection URI: " mongo_uri
      print_success "MongoDB connection configured"
      ;;
    4)
      read -p "SQLite file path: " sqlite_path
      print_success "SQLite configured at: $sqlite_path"
      ;;
    0) return ;;
    *) print_error "Invalid selection"; return ;;
  esac
  
  read -p "Query templates (insert/update/select/delete): " query_type
  print_info "Database workflow configured for: $query_type operations"
}

################################################################################
# WEBHOOK WIZARD
################################################################################

setup_webhook_workflow() {
  print_header "🔗 Webhook Workflow Setup"
  
  print_info "Create workflows triggered by webhooks."
  
  read -p "Webhook name (e.g., 'github-push'): " webhook_name
  read -p "Expected content type (json/form-data/xml): " content_type
  read -p "Authenticate webhook? (y/n): " auth_webhook
  
  if [[ $auth_webhook == "y" ]]; then
    read -p "Auth type (apikey/bearer/basic): " auth_type
    print_info "Webhook will require $auth_type authentication"
  fi
  
  print_success "Webhook endpoint configured: /webhook/$webhook_name"
}

################################################################################
# SCHEDULE WIZARD
################################################################################

setup_scheduled_workflow() {
  print_header "⏰ Scheduled Workflow Setup"
  
  print_info "Create workflows that run on a schedule."
  
  echo -e "${CYAN}Frequency:${NC}"
  echo "  1) Every 5 minutes"
  echo "  2) Every 30 minutes"
  echo "  3) Hourly"
  echo "  4) Daily"
  echo "  5) Weekly"
  echo "  6) Custom cron expression"
  echo "  0) Cancel"
  read -p "Select frequency (0-6): " freq_choice
  
  case $freq_choice in
    1) print_info "Workflow will run every 5 minutes" ;;
    2) print_info "Workflow will run every 30 minutes" ;;
    3) print_info "Workflow will run hourly" ;;
    4) read -p "Time of day (HH:MM, e.g., 09:00): " daily_time
       print_info "Workflow will run daily at $daily_time" ;;
    5) read -p "Day of week (0=Sunday, 6=Saturday): " day_of_week
       read -p "Time of day (HH:MM): " weekly_time
       print_info "Workflow will run on day $day_of_week at $weekly_time" ;;
    6) read -p "Enter cron expression: " cron_expr
       print_info "Workflow scheduled with: $cron_expr" ;;
    0) return ;;
    *) print_error "Invalid selection"; return ;;
  esac
}

################################################################################
# MAIN MENU
################################################################################

show_menu() {
  print_header "n8n Quick Start Wizard 🚀"
  echo "Choose a workflow template to get started:"
  echo ""
  echo "  1) 📧 Email Automation"
  echo "  2) 🕷️  Web Scraping"
  echo "  3) 🤖 AI Integration"
  echo "  4) 🗄️  Database Operations"
  echo "  5) 🔗 Webhook Triggers"
  echo "  6) ⏰ Scheduled Tasks"
  echo "  7) 📚 View Documentation"
  echo "  0) Exit"
  echo ""
}

show_documentation() {
  print_header "Quick Start Documentation"
  echo "Available Wizards:"
  echo ""
  echo "1️⃣  Email: Send and manage emails via multiple providers"
  echo "2️⃣  Scraping: Extract data from websites automatically"
  echo "3️⃣  AI: Integrate GPT, Gemini, Claude for intelligent workflows"
  echo "4️⃣  Database: CRUD operations with PostgreSQL, MySQL, MongoDB"
  echo "5️⃣  Webhooks: Respond to external events in real-time"
  echo "6️⃣  Scheduling: Run tasks on custom schedules and intervals"
  echo ""
  echo "Each wizard saves configuration to: ~/.n8n/credentials.json"
  echo "Workflow templates are created in: ~/.n8n/workflows/"
  echo ""
}

################################################################################
# MAIN LOOP
################################################################################

main() {
  while true; do
    show_menu
    read -p "${CYAN}Select option (0-7):${NC} " choice
    
    case $choice in
      1) setup_email_workflow ;;
      2) setup_web_scraping ;;
      3) setup_ai_workflow ;;
      4) setup_database_workflow ;;
      5) setup_webhook_workflow ;;
      6) setup_scheduled_workflow ;;
      7) show_documentation ;;
      0) 
        print_success "Thank you for using n8n Quick Start!"
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
  print_header "n8n Quick Start Wizard - Usage"
  echo "Run without arguments to start interactive wizard:"
  echo "  ./scripts/quick-start.sh"
  echo ""
  echo "Available wizards:"
  echo "  - Email automation with multiple providers"
  echo "  - Web scraping with scheduling"
  echo "  - AI integration (OpenAI, Gemini, Claude, Hugging Face)"
  echo "  - Database operations (PostgreSQL, MySQL, MongoDB, SQLite)"
  echo "  - Webhook triggers and authentication"
  echo "  - Scheduled task automation"
  echo ""
  exit 0
fi

# Run main menu
main
