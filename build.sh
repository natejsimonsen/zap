#!/usr/bin/env bash
# Build a release binary and wrap it in Zap.app.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Zap"
BUNDLE_ID="com.local.zap"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"

echo "==> Building release binary…"
swift build -c release

echo "==> Assembling ${APP_DIR}…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <!-- Menu-bar agent: no Dock icon. -->
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc code signature so the OS trusts the bundle for hotkey registration.
echo "==> Ad-hoc signing…"
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || \
    echo "   (codesign skipped — app still runs unsigned)"

echo ""
echo "Built ./${APP_DIR}"
echo "Install it with:  cp -R ${APP_DIR} /Applications/"
echo "Then add /Applications/${APP_DIR} to System Settings > General > Login Items."
