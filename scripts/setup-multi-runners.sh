#!/bin/bash
# Setup multiple self-hosted GitHub Actions runners for parallel CI
# This creates 2 additional runners (total 3) to run jobs in parallel

set -e

REPO_URL="https://github.com/ravitejakamalapuram/InvTrack"
RUNNER_VERSION="2.321.0"
RUNNER_ARCH="osx-arm64"

# Function to setup a runner instance
setup_runner() {
    local RUNNER_NUM=$1
    local RUNNER_DIR=~/actions-runner-${RUNNER_NUM}
    local RUNNER_NAME="macbook-runner-${RUNNER_NUM}"
    
    echo "🔧 Setting up runner ${RUNNER_NUM} in ${RUNNER_DIR}..."
    
    # Create directory if it doesn't exist
    if [ -d "$RUNNER_DIR" ]; then
        echo "  Directory exists, checking if configured..."
        if [ -f "$RUNNER_DIR/.runner" ]; then
            echo "  ✅ Runner ${RUNNER_NUM} already configured"
            return 0
        fi
    else
        mkdir -p "$RUNNER_DIR"
        
        # Download and extract runner
        echo "  📥 Downloading runner..."
        curl -sL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" | tar xz -C "$RUNNER_DIR"
    fi
    
    # Get registration token
    echo "  🔑 Getting registration token..."
    TOKEN=$(gh api repos/ravitejakamalapuram/InvTrack/actions/runners/registration-token -X POST --jq '.token')
    
    # Configure runner
    echo "  ⚙️ Configuring runner..."
    cd "$RUNNER_DIR"
    ./config.sh --url "$REPO_URL" --token "$TOKEN" --name "$RUNNER_NAME" --work "_work" --labels "self-hosted,macOS,ARM64" --unattended --replace
    
    echo "  ✅ Runner ${RUNNER_NUM} configured!"
}

# Function to create LaunchAgent for a runner
create_launch_agent() {
    local RUNNER_NUM=$1
    local RUNNER_DIR=~/actions-runner-${RUNNER_NUM}
    local PLIST_PATH=~/Library/LaunchAgents/com.github.actions.runner-${RUNNER_NUM}.plist
    
    echo "📝 Creating LaunchAgent for runner ${RUNNER_NUM}..."
    
    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.github.actions.runner-${RUNNER_NUM}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${RUNNER_DIR}/run.sh</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${RUNNER_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${RUNNER_DIR}/logs/runner.log</string>
    <key>StandardErrorPath</key>
    <string>${RUNNER_DIR}/logs/runner.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF
    
    mkdir -p "$RUNNER_DIR/logs"
    echo "  ✅ LaunchAgent created"
}

# Function to start a runner
start_runner() {
    local RUNNER_NUM=$1
    local PLIST_PATH=~/Library/LaunchAgents/com.github.actions.runner-${RUNNER_NUM}.plist
    
    echo "🚀 Starting runner ${RUNNER_NUM}..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"
    echo "  ✅ Runner ${RUNNER_NUM} started"
}

# Main
echo "================================================"
echo "🏃 Setting up parallel GitHub Actions runners"
echo "================================================"
echo ""

# Setup runners 2 and 3 (runner 1 is the existing one)
for i in 2 3; do
    setup_runner $i
    create_launch_agent $i
    start_runner $i
    echo ""
done

echo "================================================"
echo "✅ All runners configured!"
echo ""
echo "Checking runner status..."
gh api repos/ravitejakamalapuram/InvTrack/actions/runners --jq '.runners[] | "\(.name): \(.status)"'
echo "================================================"

