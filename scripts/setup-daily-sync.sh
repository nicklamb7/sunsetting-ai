#!/bin/bash

###############################################################################
# Setup Daily Automated Sync
#
# This script sets up a daily cron job (or launchd on macOS) to automatically
# sync upstream OpenClaw changes into the Sunsetting fork.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Setting up daily upstream sync..."
echo "Repository: $REPO_ROOT"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS - using launchd"

    # Create launchd plist
    PLIST_FILE="$HOME/Library/LaunchAgents/ai.sunsetting.sync-upstream.plist"

    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.sunsetting.sync-upstream</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$REPO_ROOT/scripts/sync-upstream.sh</string>
        <string>--auto</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>$REPO_ROOT/sync-upstream-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$REPO_ROOT/sync-upstream-stderr.log</string>

    <key>WorkingDirectory</key>
    <string>$REPO_ROOT</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/.nvm/versions/node/v22.22.2/bin</string>
    </dict>
</dict>
</plist>
EOF

    # Load the plist
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    launchctl load "$PLIST_FILE"

    echo "✅ Daily sync configured via launchd"
    echo "   Plist: $PLIST_FILE"
    echo "   Schedule: Every day at 3:00 AM"
    echo ""
    echo "To test manually:"
    echo "   launchctl start ai.sunsetting.sync-upstream"
    echo ""
    echo "To disable:"
    echo "   launchctl unload $PLIST_FILE"

else
    echo "Detected Linux - using cron"

    # Add cron job
    CRON_COMMAND="0 3 * * * cd $REPO_ROOT && $REPO_ROOT/scripts/sync-upstream.sh --auto"

    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "sync-upstream.sh"; then
        echo "⚠️  Cron job already exists. Skipping."
    else
        (crontab -l 2>/dev/null; echo "$CRON_COMMAND") | crontab -
        echo "✅ Daily sync configured via cron"
        echo "   Schedule: Every day at 3:00 AM"
    fi

    echo ""
    echo "To view cron jobs:"
    echo "   crontab -l"
    echo ""
    echo "To remove:"
    echo "   crontab -e  # then delete the sync-upstream line"
fi

echo ""
echo "Manual sync anytime:"
echo "   cd $REPO_ROOT && ./scripts/sync-upstream.sh"
