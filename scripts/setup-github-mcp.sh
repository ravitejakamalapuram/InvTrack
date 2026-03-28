#!/bin/bash

# GitHub MCP Server Setup Script for InvTrack
# This script helps configure the GitHub Personal Access Token

set -e

echo "=========================================="
echo "  GitHub MCP Server Setup for InvTrack"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if GITHUB_TOKEN is already set
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${GREEN}✅ GITHUB_TOKEN is already set${NC}"
    echo "Current token: ${GITHUB_TOKEN:0:10}..."
    echo ""
    read -p "Do you want to update it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing token."
        exit 0
    fi
fi

# Instructions
echo -e "${YELLOW}📋 Before continuing, you need to create a GitHub Personal Access Token:${NC}"
echo ""
echo "1. Go to: https://github.com/settings/tokens"
echo "2. Click 'Generate new token (classic)'"
echo "3. Set these scopes:"
echo "   ✅ repo (Full control of private repositories)"
echo "   ✅ workflow (Update GitHub Action workflows)"
echo "4. Generate and copy the token"
echo ""
read -p "Press Enter when you have your token ready..."
echo ""

# Get token from user
echo -n "Paste your GitHub Personal Access Token: "
read -s GITHUB_TOKEN_INPUT
echo ""

if [ -z "$GITHUB_TOKEN_INPUT" ]; then
    echo -e "${RED}❌ No token provided. Exiting.${NC}"
    exit 1
fi

# Determine shell config file
SHELL_CONFIG=""
if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
else
    echo -e "${YELLOW}⚠️  Could not detect shell. Please add manually:${NC}"
    echo "export GITHUB_TOKEN=\"$GITHUB_TOKEN_INPUT\""
    exit 1
fi

# Add to shell config
echo ""
echo "Adding GITHUB_TOKEN to $SHELL_CONFIG..."

# Remove old token if exists
if grep -q "export GITHUB_TOKEN=" "$SHELL_CONFIG"; then
    echo "Removing old GITHUB_TOKEN..."
    sed -i.bak '/export GITHUB_TOKEN=/d' "$SHELL_CONFIG"
fi

# Add new token
echo "export GITHUB_TOKEN=\"$GITHUB_TOKEN_INPUT\"" >> "$SHELL_CONFIG"

echo -e "${GREEN}✅ Token added to $SHELL_CONFIG${NC}"
echo ""

# Export for current session
export GITHUB_TOKEN="$GITHUB_TOKEN_INPUT"

# Verify
echo "Verifying setup..."
echo ""

# Check git config
if git config --global user.name > /dev/null 2>&1; then
    GIT_NAME=$(git config --global user.name)
    echo -e "${GREEN}✅ Git user.name: $GIT_NAME${NC}"
else
    echo -e "${YELLOW}⚠️  Git user.name not set${NC}"
    read -p "Enter your name for Git: " GIT_NAME_INPUT
    git config --global user.name "$GIT_NAME_INPUT"
    echo -e "${GREEN}✅ Git user.name set${NC}"
fi

if git config --global user.email > /dev/null 2>&1; then
    GIT_EMAIL=$(git config --global user.email)
    echo -e "${GREEN}✅ Git user.email: $GIT_EMAIL${NC}"
else
    echo -e "${YELLOW}⚠️  Git user.email not set${NC}"
    read -p "Enter your email for Git: " GIT_EMAIL_INPUT
    git config --global user.email "$GIT_EMAIL_INPUT"
    echo -e "${GREEN}✅ Git user.email set${NC}"
fi

# Test MCP server
echo ""
echo "Testing GitHub MCP server installation..."
if npx -y @modelcontextprotocol/server-github --help > /dev/null 2>&1; then
    echo -e "${GREEN}✅ GitHub MCP server is available${NC}"
else
    echo -e "${RED}❌ GitHub MCP server test failed${NC}"
    echo "Run: npx -y @modelcontextprotocol/server-github --help"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Reload your shell: source $SHELL_CONFIG"
echo "2. Restart your AI assistant (Augment/VS Code)"
echo "3. Test by asking AI to push changes to GitHub"
echo ""
echo "For more details, see: docs/GITHUB_MCP_SETUP.md"

