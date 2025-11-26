# n8n Workflow Function Library

> **Building workflows as reusable functions for your ephemeral n8n deployment**

## What is a Function?

In this context, a "function" is a pre-configured n8n workflow that:
- Solves a specific problem (data extraction, lead generation, notifications, etc.)
- Can be easily enabled/disabled
- Has clear dependencies and cost information
- Works independently or can be composed with other functions
- Is documented with metadata in `functions-registry.json`

## Why Functions?

Traditional workflow management requires:
- Manual configuration in the n8n UI
- Rebuilding workflows from scratch
- No clear organization or discovery

The function library approach provides:
- ✅ **Version control** - All workflows in git
- ✅ **Documentation** - Clear metadata for each function
- ✅ **Discoverability** - Browse the registry to find what you need
- ✅ **Reusability** - Share functions across projects
- ✅ **Composability** - Chain multiple functions together
- ✅ **Cost transparency** - Know what each function costs

## Function Categories

### Data Extraction & Processing
Functions that extract, parse, and process data from various sources

### Lead Generation & Outreach
Functions that find, enrich, and contact potential leads

### Notifications & Alerts
Functions that send notifications via various channels

## Available Functions

See `functions-registry.json` for the complete list of available functions with detailed metadata.

## How to Use Functions

### 1. Browse Available Functions
Check `functions-registry.json` to see all available functions

### 2. Enable a Function
Edit `functions-registry.json` and set `enabled: true` for the function

### 3. Configure Credentials
Each function requires specific credentials - check the `dependencies` field

### 4. Test the Function
For manual triggers, click Execute Workflow in n8n UI

## How to Add a New Function

### Step 1: Create the Workflow in n8n
Build your workflow in the UI and test thoroughly

### Step 2: Export the Workflow
Export to JSON format and save to workflows directory

### Step 3: Register the Function
Add an entry to `functions-registry.json` with all required metadata

## Best Practices

### Security
- ❌ NEVER commit credentials to git
- ❌ NEVER hardcode API keys in workflows
- ✅ Always use n8n's credential system

### Cost Management
- Document all API costs
- Use free tiers when possible
- Include rate limits in notes

### Documentation
- Write clear descriptions
- List all dependencies
- Include setup instructions

## Contributing

To contribute a new function:
1. Build and test the workflow
2. Export to JSON
3. Add to `functions-registry.json`
4. Submit pull request

**Built with ❤️ for ephemeral n8n deployments on Mac M4**
