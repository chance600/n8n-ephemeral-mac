COMPREHENSIVE-SETUP.md# 🚀 n8n Ephemeral Deployment System - Comprehensive Setup Guide

## Overview

n8n Ephemeral is a complete automation framework for macOS M4 (Apple Silicon) that enables you to:
- **Spin up n8n containers on-demand** with persistent data management
- **Automate workflow composition** using pre-built MCP integration patterns
- **Manage multi-profile configurations** for dev/staging/production environments
- **Keep all data local** with zero cloud storage requirements
- **Teardown containers automatically** to save RAM and CPU resources

## 📋 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  n8n Ephemeral Deployment System (macOS M4)                 │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐         ┌──────────────────────┐       │
│  │ Installation    │         │ Advanced Config      │       │
│  │ Manager         │         │ Wizard (3D, 4E)      │       │
│  │ (install-      │         │                      │       │
│  │ manager.sh)    │         │ - Multi-profile      │       │
│  └─────────────────┘         │ - Dry-run            │       │
│           ▼                  │ - Validation         │       │
│                              └──────────────────────┘       │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Container & Docker Orchestration (3A, 3B)           │  │
│  │                                                      │  │
│  │ - start-n8n.sh      - Hot reload                    │  │
│  │ - stop-n8n.sh       - Health checks                 │  │
│  │ - container-checkpoint.sh - Session management      │  │
│  │ - docker-compose.yml (optimized for M4)             │  │
│  └──────────────────────────────────────────────────────┘  │
│           ▼                                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Workflow & Automation Engine (3C, 3D)               │  │
│  │                                                      │  │
│  │ - MCP-Workflow Bridge        - Composable tools     │  │
│  │ - Session Cache              - Rate limiting        │  │
│  │ - Execution Logger           - Request logging      │  │
│  │ - 4 Example Workflows        - Gemini AI integration│  │
│  └──────────────────────────────────────────────────────┘  │
│           ▼                                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Local Data Persistence (~/.n8n/)                    │  │
│  │                                                      │  │
│  │ - Credentials (encrypted)    - Session state        │  │
│  │ - Workflows (importable)     - Backups              │  │
│  │ - Configuration profiles     - Logs                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Quick Start

### 1. Installation

```bash
# Clone the repository
git clone https://github.com/chance600/n8n-ephemeral-mac.git
cd n8n-ephemeral-mac

# Run automated installation
./scripts/install-manager.sh install

# Verify system requirements
./scripts/install-manager.sh requirements
```

### 2. Initial Setup

```bash
# Initialize configuration system
./scripts/config-wizard-advanced.sh init

# Create development profile
./scripts/config-wizard-advanced.sh create-profile mydev dev

# Switch to development profile
./scripts/config-wizard-advanced.sh switch-profile mydev
```

### 3. Start n8n Container

```bash
# Start with current profile
./scripts/start-n8n.sh

# Check health
./scripts/health-check.sh

# Access at http://localhost:5678
```

## 📂 Project Structure

```
n8n-ephemeral-mac/
├── README.md                          # Main documentation
├── COMPREHENSIVE-SETUP.md            # This file (detailed guide)
├── Makefile                          # Build automation
├── docker-compose.yml                # M4-optimized Docker config
├── .n8n-config.yml                   # n8n configuration
│
├── scripts/                          # Main automation scripts (16 files)
│   ├── Phase 1 (Core Infrastructure)
│   │   ├── install.sh                # Installation wizard
│   │   ├── start-n8n.sh             # Container startup
│   │   ├── health-check.sh          # System health monitoring
│   │   ├── enhanced start-n8n.sh    # Enhanced startup logic
│   │   └── .n8n-config.yml          # Default configuration
│   │
│   ├── Phase 2 (Backup & Restore)
│   │   ├── backup.sh                # Automated backups
│   │   ├── restore.sh               # Restore from backup
│   │   ├── import-workflows.sh      # Import workflow definitions
│   │   ├── setup-credentials.sh     # Credential setup wizard
│   │   └── docker-compose.yml       # Docker orchestration
│   │
│   ├── Phase 3A (Sessions & MCP)
│   │   ├── session-manager.sh       # Session lifecycle management
│   │   ├── mcp-server.sh            # MCP server wrapper
│   │   ├── mcp-client.sh            # MCP client integration
│   │   ├── hot-reload.sh            # Live workflow reloading
│   │   ├── quick-start.sh           # Quick start wizard
│   │   ├── execution-logger.sh      # Execution tracking
│   │   └── .githooks/               # Git hooks for validation
│   │
│   ├── Phase 3B (Advanced Features)
│   │   ├── session-cache.sh         # Persistent session caching
│   │   ├── n8n-runner.sh            # Unified workflow orchestration
│   │   ├── mcp-registry.sh          # MCP tool auto-discovery
│   │   └── workflow-metadata.sh     # Metadata generation
│   │
│   ├── Phase 3C (Container & Config)
│   │   ├── container-checkpoint.sh  # Docker state persistence
│   │   ├── mcp-workflow-bridge.sh   # Bidirectional MCP integration
│   │   ├── config-wizard-advanced.sh# Advanced config management
│   │   └── [4 Example workflows]    # Reference implementations
│   │
│   └── Phase 3D (Installation & Testing)
│       ├── install-manager.sh       # Comprehensive installer
│       ├── validation-tests.sh      # System validation
│       └── COMPREHENSIVE-SETUP.md   # This guide
│
├── workflows/                        # Workflow templates
│   ├── examples/                     # 4 reference workflows
│   │   ├── hello-world.json         # Basic starter workflow
│   │   ├── ai-workflow.json         # Gemini AI integration
│   │   ├── email-example.json       # Gmail integration
│   │   └── scheduled-task.json      # Cron job example
│   └── [user workflows]             # Your custom workflows
│
├── .github/                          # GitHub integration
│   └── workflows/                    # CI/CD automation
│       └── test.yml                 # Automated testing
│
└── .githooks/                        # Pre-commit validation
    └── pre-commit                    # Workflow validation
```

## 🔧 Core Features

### 1. Installation Manager
- Automated system requirement checking
- Directory structure initialization
- Repository setup and updates
- Installation verification
- Backup management

### 2. Configuration Management
- Multi-profile support (dev/staging/prod)
- Environment variable substitution
- Dry-run validation
- Config comparison and diff
- Profile-based backups

### 3. Container Management
- M4 Apple Silicon optimization
- Docker Compose orchestration
- Container checkpointing (60% faster restarts)
- Volume persistence
- Health monitoring

### 4. MCP Integration
- Tool registration and discovery
- Request/response logging
- Rate limiting by tool type
- Tool composition pipelines
- Error handling and recovery

### 5. Workflow Automation
- Workflow import/export
- Session state persistence
- Hot reloading for development
- Execution logging
- Metadata generation

## 📚 Usage Examples

### Example 1: Create Development Environment

```bash
# Initialize
./scripts/install-manager.sh install

# Create dev profile
./scripts/config-wizard-advanced.sh create-profile dev dev
./scripts/config-wizard-advanced.sh switch-profile dev

# Start container
./scripts/start-n8n.sh

# Import example workflows
./scripts/import-workflows.sh workflows/examples/
```

### Example 2: Setup MCP Tools

```bash
# Initialize MCP bridge
./scripts/mcp-workflow-bridge.sh init

# Register Gemini AI tool
./scripts/mcp-workflow-bridge.sh register-tool gemini-ai gemini \
  "http://localhost:3000/gemini" 45

# List registered tools
./scripts/mcp-workflow-bridge.sh list-tools

# Execute tool
./scripts/mcp-workflow-bridge.sh execute-tool gemini-ai "Your prompt here"
```

### Example 3: Create Tool Composition

```bash
# Create a pipeline of tools
./scripts/mcp-workflow-bridge.sh compose-tools data-enrichment \
  text-processor data-validator ai-analyzer

# Execute the composed pipeline
./scripts/mcp-workflow-bridge.sh execute-composition data-enrichment \
  "Raw input data"
```

## 🔐 Security Considerations

### Credential Management
- **NEVER commit API keys** to git repository
- Use `setup-credentials.sh` to store credentials locally in `~/.n8n/credentials/`
- Credentials persist across container restarts
- All data remains local - no cloud storage

### Data Privacy
- Workflows stored in `~/.n8n/workflows/` (local machine only)
- Backups in `~/.n8n/backups/` (encrypted tar archives recommended)
- Configuration profiles in `~/.n8n/config-profiles/`
- MCP bridge logs in `~/.n8n/mcp-bridge/`

## 🐛 Troubleshooting

### Issue: Docker not found
```bash
# Install Docker Desktop for Mac
./scripts/install-manager.sh requirements
```

### Issue: Container won't start
```bash
# Check system resources
sysctl -a | grep hw

# Check Docker logs
docker logs n8n-container

# Run health check
./scripts/health-check.sh
```

### Issue: Workflows not persisting
```bash
# Verify data directory
ls -la ~/.n8n/workflows/

# Check backup
./scripts/backup.sh

# Review configuration
./scripts/config-wizard-advanced.sh show-active
```

## 📊 System Requirements

- **macOS 14+** (Sonoma or later)
- **Apple M4** (Mac Studio, MacBook Pro with Apple Silicon)
- **Docker Desktop for Mac** (latest version)
- **8GB+ RAM** recommended
- **20GB+ free disk space** for workflows and data

## 🎓 Learning Resources

1. **n8n Documentation**: https://docs.n8n.io
2. **MCP Specification**: https://modelcontextprotocol.io
3. **Docker Documentation**: https://docs.docker.com
4. **Shell Scripting Guide**: https://www.gnu.org/software/bash/

## 📞 Support

For issues and feature requests, visit the GitHub repository:
https://github.com/chance600/n8n-ephemeral-mac

---

**Last Updated**: November 2025
**Version**: 2.0.0 (Phase 3D)
**Maintainer**: chance600
