# n8n Workflows

This directory contains pre-configured n8n workflows that are automatically imported when you start n8n.

## 🎯 How Automated Workflow Loading Works

### The `~/.n8n` Directory

When n8n starts, all your data is stored in `~/.n8n` on your Mac:

```
~/.n8n/
├── database.sqlite       # Stores workflows, executions, credentials
├── credentials/          # Encrypted API keys and OAuth tokens
└── nodes/               # Custom nodes (if any)
```

### Workflow Persistence

**The KEY to making ephemeral n8n work:**

1. **First Run**: Workflows are empty
2. **You configure once**: Set up your workflows, authenticate with Gmail/Google/etc.
3. **Everything persists**: All workflows and credentials are saved to `~/.n8n/database.sqlite`
4. **Future runs**: When you `./start-n8n.sh` again, everything is exactly as you left it

### 🚀 Quick Setup (One-Time)

**Option A: Import via UI (Easiest)**

1. Run `./start-n8n.sh`
2. Open http://localhost:5678
3. Click "Workflows" → "Import from File"
4. Select `workflows/gmail-ai-notes.json`
5. Authenticate your Google account
6. Click "Save" and "Activate"

Done! Next time you start n8n, this workflow will be ready.

**Option B: Auto-Import Script (Advanced)**

For fully automated setup, you can use the n8n CLI to import workflows on first launch:

```bash
# Inside the Docker container
docker exec n8n_ephemeral n8n import:workflow --input=/data/workflows/
```

## 📁 Included Workflows

### `gmail-ai-notes.json`

**What it does:**
- Monitors Gmail every minute for new emails
- Filters emails from: Tactiq, Fathom, Bluedot, Spinach, Gemini
- Extracts transcript content
- Sends to Gemini API to extract action items
- Creates tasks in Google Tasks

**Before you use it:**
1. Replace `YOUR_TASK_LIST_ID` with your actual Google Tasks list ID
2. Add your Gemini API key as a credential
3. Authenticate Gmail OAuth

## 🔧 Creating Your Own Workflows

### Method 1: Export from n8n UI

1. Build your workflow in n8n
2. Click "⋮" (menu) → "Download"
3. Save the JSON file to this `workflows/` directory
4. Commit to git

Now it's version controlled and can be shared/imported.

### Method 2: Edit JSON Directly

Workflow JSON structure:

```json
{
  "name": "Your Workflow Name",
  "nodes": [
    {
      "name": "Node Name",
      "type": "n8n-nodes-base.nodeName",
      "parameters": { /* node config */ }
    }
  ],
  "connections": { /* how nodes connect */ },
  "active": true
}
```

## 🔐 Credentials Management

**Important:** Credentials (API keys, OAuth tokens) are NOT stored in workflow JSON files.

They are:
- Stored encrypted in `~/.n8n/database.sqlite`
- Referenced by ID in workflow JSON
- Need to be set up once per n8n instance

### First-Time Auth Flow:

1. Import workflow JSON
2. n8n shows "Credentials not set" warning
3. Click the node → "Create New Credential"
4. Authenticate (OAuth) or enter API key
5. Save

Credentials persist across sessions in `~/.n8n`.

## 💡 Pro Tips

### Separate Credentials from Workflows

For security, workflow JSON should use credential *references*, not actual keys:

```json
"credentials": {
  "googleApi": {
    "id": "1",
    "name": "Google Account"
  }
}
```

The actual credentials are in the encrypted database.

### Version Control

- ✅ **DO** commit workflow JSON files
- ❌ **DON'T** commit `.env` with API keys
- ❌ **DON'T** commit `~/.n8n/` directory

### Testing Workflows

Before activating:
1. Click "Execute Workflow" in n8n UI
2. Check the output of each node
3. Fix any errors
4. Then activate for automatic execution

## 🎓 Example: Automated Meeting Notes Workflow

**Goal:** Every time you get meeting notes, extract action items and create calendar events.

**Workflow:**
```
Gmail Trigger (new email from Fathom)
  ↓
Extract transcript link
  ↓
HTTP Request (fetch full transcript)
  ↓
Gemini API (extract: action items, next meeting date)
  ↓
Split into two branches:
  ├─→ Google Tasks (create action items)
  └─→ Google Calendar (schedule follow-up if mentioned)
```

All of this runs automatically, on-demand, every time you spin up n8n.

## 📚 Learn More

- [n8n Workflow Examples](https://n8n.io/workflows/)
- [n8n Node Documentation](https://docs.n8n.io/integrations/builtin/)
- [Workflow JSON Structure](https://docs.n8n.io/workflows/)

---

**Remember:** Once configured, your workflows persist in `~/.n8n`. You only need to set them up once! 🎉
