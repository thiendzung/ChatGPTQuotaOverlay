#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"

chmod +x build-app.sh
./build-app.sh

TARGET_DIR="$HOME/Applications"
TARGET_APP="$TARGET_DIR/ChatGPT Quota Overlay.app"
STAGING_APP="$TARGET_DIR/.ChatGPT Quota Overlay.app.new.$$"

mkdir -p "$TARGET_DIR"
rm -rf "$STAGING_APP"
cp -R "$ROOT/dist/ChatGPT Quota Overlay.app" "$STAGING_APP"

# Stop only this overlay executable. No sudo and no changes to ChatGPT.app.
pkill -x ChatGPTQuotaOverlay 2>/dev/null || true

rm -rf "$TARGET_APP"
mv "$STAGING_APP" "$TARGET_APP"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$TARGET_APP" >/dev/null 2>&1 || true
fi
open -n "$TARGET_APP"

printf 'Installed v%s: %s\n' "$VERSION" "$TARGET_APP"
printf 'Note: the installer does not remove Gatekeeper quarantine attributes.\n'
