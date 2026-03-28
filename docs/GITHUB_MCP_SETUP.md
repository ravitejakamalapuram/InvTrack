# GitHub MCP Server Setup Guide

**Complete setup guide for using GitHub MCP server with InvTrack**

---

## 📋 Overview

The GitHub MCP (Model Context Protocol) server enables AI assistants to interact directly with GitHub repositories - creating commits, pushing changes, managing branches, creating pull requests, and more.

---

## 🔧 Configuration

The GitHub MCP server is already configured in `.vscode/mcp.json`:

```json
{
  "servers": {
    "firebase": { ... },
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

---

## 🚀 Setup Steps

### 1. Create GitHub Personal Access Token

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
   - Direct link: https://github.com/settings/tokens

2. Click **"Generate new token (classic)"**

3. Configure the token:
   - **Note:** `InvTrack MCP Server`
   - **Expiration:** 90 days (or custom)
   - **Scopes:** Select these permissions:
     - ✅ `repo` (Full control of private repositories)
       - This includes: `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`
     - ✅ `workflow` (Update GitHub Action workflows)
     - ✅ `write:packages` (Upload packages to GitHub Package Registry)
     - ✅ `read:packages` (Download packages from GitHub Package Registry)

4. Click **"Generate token"**

5. **IMPORTANT:** Copy the token immediately (you won't see it again!)

### 2. Set Environment Variable

Add the token to your shell configuration:

**For Zsh (default on macOS):**
```bash
echo 'export GITHUB_TOKEN="your_token_here"' >> ~/.zshrc
source ~/.zshrc
```

**For Bash:**
```bash
echo 'export GITHUB_TOKEN="your_token_here"' >> ~/.bashrc
source ~/.bashrc
```

**Verify:**
```bash
echo $GITHUB_TOKEN
```

### 3. Install MCP Server Package

The GitHub MCP server will auto-install when first used (via `npx`), but you can pre-install:

```bash
npx -y @modelcontextprotocol/server-github --help
```

### 4. Configure Git (if not already done)

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### 5. Restart Your AI Assistant

- **Augment/VS Code:** Reload window (`Cmd+Shift+P` → "Reload Window")
- **Claude Desktop:** Restart the application

---

## 🎯 Available Operations

Once configured, you can ask your AI assistant to:

### **Git Operations:**
- ✅ Stage files (`git add`)
- ✅ Create commits
- ✅ Push changes
- ✅ Create branches
- ✅ Merge branches
- ✅ View commit history
- ✅ View file diff

### **GitHub Operations:**
- ✅ Create pull requests
- ✅ List/view issues
- ✅ Create issues
- ✅ Add issue comments
- ✅ Manage labels
- ✅ View repository info
- ✅ Fork repositories

---

## 📝 Usage Examples

### **Push Changes:**
```
AI: "Push my changes to GitHub with commit message 'Fix FIRE progress ring edge cases'"
```

### **Create Pull Request:**
```
AI: "Create a pull request for these Crashlytics fixes"
```

### **View Status:**
```
AI: "Show me the current git status"
```

---

## 🔒 Security Best Practices

1. **Token Storage:**
   - ✅ Store in environment variable (not in files)
   - ❌ Never commit `.env` files with tokens
   - ❌ Never share tokens publicly

2. **Token Permissions:**
   - ✅ Use minimum required scopes
   - ✅ Set expiration dates
   - ✅ Regenerate regularly (every 90 days)

3. **Token Revocation:**
   - If compromised, immediately revoke at: https://github.com/settings/tokens

---

## 🐛 Troubleshooting

### **Error: `GITHUB_TOKEN not found`**
```bash
# Check if token is set
echo $GITHUB_TOKEN

# If empty, add to shell config
echo 'export GITHUB_TOKEN="your_token_here"' >> ~/.zshrc
source ~/.zshrc
```

### **Error: `Authentication failed`**
- Token may be expired or invalid
- Regenerate token at: https://github.com/settings/tokens
- Update `GITHUB_TOKEN` environment variable

### **Error: `Permission denied`**
- Check token scopes (needs `repo` permission)
- Regenerate token with correct scopes

### **MCP Server Not Loading:**
```bash
# Test manually
npx -y @modelcontextprotocol/server-github --help

# Check if Node.js/npm is installed
node --version
npm --version
```

---

## ✅ Verification

Test the setup with these commands:

```bash
# 1. Check environment variable
echo $GITHUB_TOKEN

# 2. Check git configuration
git config --global user.name
git config --global user.email

# 3. Check repository status
git status

# 4. Test MCP server
npx -y @modelcontextprotocol/server-github --help
```

---

## 📚 Additional Resources

- **GitHub MCP Server:** https://github.com/modelcontextprotocol/servers/tree/main/src/github
- **MCP Documentation:** https://modelcontextprotocol.io/
- **GitHub Token Docs:** https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens

---

**Setup Complete!** 🎉

You can now use AI-powered GitHub operations directly from your development environment.

