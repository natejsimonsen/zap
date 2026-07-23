#!/usr/bin/env bash
# Remove the Zap login-item LaunchAgent (does not quit a running Zap).
set -euo pipefail

LABEL="com.zap.launcher"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
rm -f "$PLIST"
echo "Removed login item '${LABEL}'."
