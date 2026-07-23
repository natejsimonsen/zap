#!/usr/bin/env bash
# Install a LaunchAgent so Zap starts at login (and start it now).
# Works for a flox/nix install (resolves the stable ~/.flox run path) or a
# /Applications install. Re-run after switching install methods.
set -euo pipefail

LABEL="com.zap.launcher"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# Resolve the zap executable. Prefer one already on PATH (e.g. run from an activated
# flox env, or as the packaged `zap-autostart`), then a flox default-env lookup, then
# /Applications. The flox run path (~/.flox/run/…) is stable across `flox upgrade`.
ZAP="$(command -v zap 2>/dev/null || true)"
if [ -z "$ZAP" ] && command -v flox >/dev/null 2>&1; then
  ZAP="$(flox activate -d "$HOME" -c 'command -v zap' 2>/dev/null || true)"
fi
if [ -z "$ZAP" ] && [ -x "/Applications/Zap.app/Contents/MacOS/Zap" ]; then
  ZAP="/Applications/Zap.app/Contents/MacOS/Zap"
fi
if [ -z "$ZAP" ]; then
  echo "error: could not find zap (flox env or /Applications/Zap.app). Install Zap first." >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${ZAP}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

DOMAIN="gui/$(id -u)"
launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null || true
launchctl bootstrap "${DOMAIN}" "${PLIST}"
launchctl kickstart -k "${DOMAIN}/${LABEL}"

echo "Installed login item '${LABEL}' -> ${ZAP}"
echo "Zap will now start at login. Remove with: make autostart-off"
