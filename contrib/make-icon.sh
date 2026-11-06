#!/usr/bin/env bash
# Regenerate Resources/AppIcon.icns from contrib/make-icon.swift.
set -euo pipefail

cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

swift contrib/make-icon.swift "$tmp/icon.png"

set="$tmp/AppIcon.iconset"
mkdir "$set"
for s in 16 32 128 256 512; do
    sips -z $s $s "$tmp/icon.png" --out "$set/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$tmp/icon.png" --out "$set/icon_${s}x${s}@2x.png" >/dev/null
done

mkdir -p Resources
iconutil -c icns "$set" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
