#!/bin/bash
# GitHub Actions Self-Hosted Runner - Auto-Start Setup
# Run this script to enable auto-start on login

set -e

RUNNER_DIR="$HOME/actions-runner"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.github.actions.runner.plist"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "🚀 GitHub Actions Runner - Auto-Start Setup"
echo "============================================"

# Check if runner exists
if [ ! -f "$RUNNER_DIR/run.sh" ]; then
    echo "❌ Runner not found at $RUNNER_DIR"
    echo "   Please install the runner first."
    exit 1
fi

# Fix LaunchAgents folder permissions if needed
echo "📁 Checking LaunchAgents folder..."
if [ ! -w "$LAUNCH_AGENTS_DIR" ]; then
    echo "⚠️  Fixing permissions on $LAUNCH_AGENTS_DIR..."
    sudo chown -R $(whoami):staff "$LAUNCH_AGENTS_DIR"
fi

mkdir -p "$LAUNCH_AGENTS_DIR"
mkdir -p "$RUNNER_DIR/logs"

# Create the plist file
echo "� Creating LaunchAgent..."
cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.github.actions.runner</string>
    <key>ProgramArguments</key>
    <array>
        <string>$RUNNER_DIR/run.sh</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$RUNNER_DIR</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$RUNNER_DIR/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$RUNNER_DIR/logs/stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

# Stop existing runner if running
echo "🔄 Loading LaunchAgent..."
pkill -f "Runner.Listener" 2>/dev/null || true
launchctl unload "$PLIST_PATH" 2>/dev/null || true
sleep 1
launchctl load "$PLIST_PATH"

# Verify it started
sleep 3
if launchctl list | grep -q "com.github.actions.runner"; then
    echo ""
    echo "✅ Auto-start setup complete!"
    echo ""
    echo "📊 Status:"
    echo "   - Runner will start automatically on login"
    echo "   - Runner will restart if it crashes"
    echo "   - Logs: $RUNNER_DIR/logs/"
    echo ""
    echo "🛠️  Commands:"
    echo "   - View logs: tail -f $RUNNER_DIR/logs/stdout.log"
    echo "   - Stop: launchctl unload $PLIST_PATH"
    echo "   - Start: launchctl load $PLIST_PATH"
    echo "   - Status: launchctl list | grep github.actions"
else
    echo "❌ Failed to start. Check logs at $RUNNER_DIR/logs/"
fi

