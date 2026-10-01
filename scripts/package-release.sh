#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
TAG="v$VERSION"

if [ -n "\${GITHUB_REF_NAME:-}" ] && [ "$GITHUB_REF_NAME" != "$TAG" ]; then
  printf 'Tag mismatch: expected %s, got %s\n' "$TAG" "$GITHUB_REF_NAME" >&2
  exit 1
fi

./build-app.sh

ZIP="$ROOT/dist/ChatGPT-Quota-Overlay-v$VERSION-macOS.zip"
SHA="$ZIP.sha256"
rm -f "$ZIP" "$SHA"

ditto -c -k --sequesterRsrc --keepParent \
  "$ROOT/dist/ChatGPT Quota Overlay.app" \
  "$ZIP"

(
  cd "$ROOT/dist"
  shasum -a 256 "$(basename "$ZIP")" > "$(basename "$SHA")"
)

printf 'Release: %s\n' "$ZIP"
printf 'SHA256: %s\n' "$SHA"
