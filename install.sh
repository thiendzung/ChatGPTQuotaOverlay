#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

chmod +x build-app.sh
./build-app.sh

TARGET_DIR="$HOME/Applications"
TARGET_APP="$TARGET_DIR/ChatGPT Quota Overlay.app"
STAGING_APP="$TARGET_DIR/.ChatGPT Quota Overlay.app.new.$$"

mkdir -p "$TARGET_DIR"
rm -rf "$STAGING_APP"
cp -R "$ROOT/dist/ChatGPT Quota Overlay.app" "$STAGING_APP"

# Stop only the overlay executable. No sudo and no changes to ChatGPT.app.
pkill -x ChatGPTQuotaOverlay 2>/dev/null || true

rm -rf "$TARGET_APP"
mv "$STAGING_APP" "$TARGET_APP"
open "$TARGET_APP"

printf 'Installed: %s\n' "$TARGET_APP"
printf 'Note: v0.1.3 does not remove Gatekeeper quarantine attributes automatically.\n'
