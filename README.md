# n8n Ephemeral Local Runner (Mac M4 Ready)

On-demand n8n automation for your MacBook M4. Spin up temporary instances only when needed, automate workflows, then tear down to free RAM and CPU.

## 🎯 What This Does

This repo provides scripts to:
- **Start n8n on-demand** - Only runs when you need it
- **Automatically open browser** - Opens http://localhost:5678 when ready
- **Persist your data** - All workflows and credentials saved to `~/.n8n`
- **Clean teardown** - Free system resources instantly when done
- **Optimized for Apple Silicon** - Native ARM64 support for M1/M2/M3/M4

## 📋 Prerequisites

- **Docker Desktop** - [Download here](https://www.docker.com/products/docker-desktop)
- **macOS** (Apple Silicon: M1/M2/M3/M4)
- **Terminal** (built-in, uses zsh or bash)

## 🚀 Quick Start

### 1. Clone this repository

```bash
git clone https://github.com/chance600/n8n-ephemeral-mac.git
cd n8n-ephemeral-mac
```

### 2. Make scripts executable

```bash
chmod +x start-n8n.sh stop-n8n.sh
```

### 3. Start n8n

```bash
./start-n8n.sh
```

Your browser will automatically open to http://localhost:5678

### 4. Stop n8n when done

```bash
./stop-n8n.sh
```

## 📁 What's Inside

- **`start-n8n.sh`** - Launches n8n in Docker, opens browser
- **`stop-n8n.sh`** - Stops container and frees resources
- **`.env.example`** - Optional environment variable template
- **`.gitignore`** - Keeps local data private

## 💾 Data Persistence

All your workflows, credentials, and settings are saved in:
```
~/.n8n/
```

This folder persists across sessions, so you never lose your work.

## ⚙️ Customization

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
```

Then edit `.env` with your preferred settings (timezone, execution data retention, etc.)

### Change Port

Edit `start-n8n.sh` and change the `PORT` variable:

```bash
PORT=5679  # Or any other port
```

## 🔧 Troubleshooting

### "Docker is not running"

Make sure Docker Desktop is installed and running.

### "n8n is already running"

Run `./stop-n8n.sh` first, then try starting again.

### Port already in use

Change the port in `start-n8n.sh` or stop the service using port 5678.

## 🎓 Use Cases

### For AI Note-Taking Automation

This setup is perfect for monitoring AI note-taking apps (Gemini, Bluedot, Spinach, Tactiq, Fathom, etc.) and automating workflows:

1. Set up Gmail triggers to catch meeting notes
2. Parse transcripts and extract action items
3. Send to Google Tasks, Notion, Slack, etc.
4. Run workflows on-demand when you need them
5. Stop n8n to free resources when done

### Example Workflow Ideas

- Auto-process meeting transcripts from your inbox
- Extract action items with AI (Gemini, GPT, etc.)
- Send summaries to Slack channels
- Create tasks in project management tools
- Weekly digest of all notes

## 📚 Learn More

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- [Workflow Templates](https://n8n.io/workflows/)

## 📄 License

MIT License - Feel free to use and modify!

## 🤝 Contributing

Pull requests welcome! Feel free to improve scripts, add features, or enhance documentation.

---

**Built for efficiency** ⚡ **Optimized for Mac M4** 🍎 **Free forever** 💸
