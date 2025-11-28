# n8n Ephemeral Makefile
# Common commands for managing n8n automation

.PHONY: start stop restart status logs health import backup restore test clean help

# Start n8n
start:
	@echo "🚀 Starting n8n ephemeral instance..."
	@./start-n8n.sh

# Stop n8n
stop:
	@echo "🛑 Stopping n8n..."
	@./stop-n8n.sh

# Restart n8n
restart: stop start
	@echo "♻️  n8n restarted"

# Check container status
status:
	@echo "📊 Container Status:"
	@docker ps | grep n8n-ephemeral || echo "❌ n8n not running"

# View logs
logs:
	@echo "📜 Viewing n8n logs (Ctrl+C to exit)..."
	@docker logs -f n8n-ephemeral

# Health check
health:
	@echo "🏥 Running health check..."
	@bash scripts/health-check.sh 2>/dev/null || echo "⚠️  Health check script not found. Create scripts/health-check.sh"

# Import workflows
import:
	@echo "📥 Importing workflows..."
	@bash scripts/import-workflows.sh 2>/dev/null || echo "⚠️  Import script not found. Create scripts/import-workflows.sh"

# Backup data
backup:
	@echo "💾 Creating backup..."
	@bash scripts/backup.sh 2>/dev/null || echo "⚠️  Backup script not found. Create scripts/backup.sh"

# Restore from backup
restore:
	@echo "📦 Restoring from backup..."
	@bash scripts/restore.sh 2>/dev/null || echo "⚠️  Restore script not found. Create scripts/restore.sh"

# Run tests
test:
	@echo "🧪 Running test suite..."
	@bash tests/test-suite.sh 2>/dev/null || echo "⚠️  Test suite not found. Create tests/test-suite.sh"

# Clean up (WARNING: removes data)
clean:
	@echo "⚠️  WARNING: This will delete all n8n data!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] && rm -rf ~/.n8n || echo "Cancelled"

# Show help
help:
	@echo "n8n Ephemeral - Available Commands:"
	@echo ""
	@echo "  make start      - Start n8n ephemeral instance"
	@echo "  make stop       - Stop n8n instance"
	@echo "  make restart    - Restart n8n"
	@echo "  make status     - Show container status"
	@echo "  make logs       - View n8n logs (live)"
	@echo "  make health     - Run health diagnostics"
	@echo "  make import     - Import workflows from workflows/"
	@echo "  make backup     - Create backup of n8n data"
	@echo "  make restore    - Restore from backup"
	@echo "  make test       - Run automated tests"
	@echo "  make clean      - Delete all n8n data (⚠️  WARNING)"
	@echo "  make help       - Show this help message"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make start"
	@echo "  2. Visit http://localhost:5678"
	@echo "  3. Configure workflows"
	@echo "  4. make stop (when done)"

# Default target
.DEFAULT_GOAL := help
