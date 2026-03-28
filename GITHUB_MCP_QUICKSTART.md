# 🚀 GitHub MCP Server - Quick Start

**5-minute setup to enable AI-powered Git/GitHub operations**

---

## ⚡ Quick Setup (Choose One)

### **Option 1: Automated Setup (Recommended)**

Run the setup script:

```bash
./scripts/setup-github-mcp.sh
```

This will:
- Guide you through creating a GitHub token
- Add it to your shell configuration
- Verify git configuration
- Test the MCP server

---

### **Option 2: Manual Setup**

#### 1. Create GitHub Token

Go to: https://github.com/settings/tokens → **Generate new token (classic)**

Required scopes:
- ✅ `repo` (Full control of private repositories)
- ✅ `workflow` (Update GitHub Action workflows)

#### 2. Add to Shell Config

```bash
# For Zsh (macOS default)
echo 'export GITHUB_TOKEN="your_token_here"' >> ~/.zshrc
source ~/.zshrc

# For Bash
echo 'export GITHUB_TOKEN="your_token_here"' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Verify

```bash
echo $GITHUB_TOKEN
```

#### 4. Restart AI Assistant

Reload VS Code or restart your AI assistant.

---

## ✅ What You Can Do Now

### **Push Changes:**
```
"Push my changes with message 'Fix edge cases in FIRE progress ring'"
```

### **Create Pull Request:**
```
"Create a PR for the Crashlytics fixes"
```

### **View Status:**
```
"Show me the git status"
```

### **Create Branch:**
```
"Create a new branch called 'feature/new-feature'"
```

### **View Commits:**
```
"Show me recent commits"
```

---

## 📚 Full Documentation

- **Complete Guide:** `docs/GITHUB_MCP_SETUP.md`
- **Troubleshooting:** See "🐛 Troubleshooting" section in full guide

---

## 🔒 Security Note

- ✅ Token stored in environment variable (not in files)
- ✅ Never commit tokens to repository
- ✅ Set expiration (90 days recommended)
- ✅ Regenerate if compromised

---

## 🎯 Current Status

**Configuration:**
- ✅ MCP server configured in `.vscode/mcp.json`
- ✅ Setup script ready at `scripts/setup-github-mcp.sh`
- ⚠️ Requires GitHub token (run setup script)

**Next Step:** Run `./scripts/setup-github-mcp.sh` to complete setup.

---

**Ready to push your Crashlytics fixes to GitHub!** 🚀

