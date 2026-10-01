# ChatGPT Quota Overlay v0.1.3

**built by ThienDzung**

A small local macOS companion for ChatGPT Desktop that shows remaining Codex quota in the left icon rail.

## UI

- Outer blue ring: remaining 5-hour quota.
- Inner purple ring: remaining weekly quota.
- Center: the two remaining percentages, for example `62 / 55`.
- Hover: `5h 62% · Week 55%`.
- Right-click: manual refresh, optional live-window-tracking permission, or quit.

## What changed in v0.1.3

v0.1.3 is primarily a security, permission, and reliability release.

- Accessibility is **no longer requested automatically at launch**.
- Without Accessibility permission, the overlay still positions itself when ChatGPT becomes active.
- Accessibility is only needed for live move/resize tracking and is explicitly opt-in.
- The overlay resolves Codex only from a recognized `ChatGPT.app`/`Codex.app`; it no longer falls back to arbitrary binaries in PATH.
- The Codex child process receives an allow-listed environment instead of every environment variable from the overlay.
- App Server requests are allow-listed to `initialize` and `account/rateLimits/read`.
- App Server buffers, pending requests, and request timeouts are bounded.
- Sparse `account/rateLimits/updated` notifications are merged correctly instead of accidentally dropping the other quota window.
- The session watcher is read-only and no longer creates `~/.codex/sessions`.
- The installer no longer removes Gatekeeper quarantine attributes automatically.
- AXObserver run-loop sources are removed cleanly when tracking stops.
- Added parser tests and a documented threat model in `SECURITY.md`.

## Real quota source

The app launches the Codex binary bundled inside ChatGPT and uses the local Codex App Server:

- `account/rateLimits/read`
- `account/rateLimits/updated`

The overlay itself does **not** read browser cookies, `~/.codex/auth.json`, API keys, or Keychain credentials. Authentication is handled by the OpenAI Codex binary.

The App Server response can contain additional account metadata. v0.1.3 keeps the response only in memory long enough to extract the Codex rate-limit snapshot; it does not log or persist the response.

## Permissions

### Default mode: no special macOS permission

The overlay can identify the frontmost ChatGPT window and read its window bounds when ChatGPT becomes active. It does not capture pixels or inspect conversation content.

### Optional Accessibility permission

Accessibility is only used for event-driven window move/resize notifications, so the overlay follows ChatGPT immediately while the window is moved or resized.

To enable it:

1. Right-click the quota rings.
2. Choose `Enable live window tracking…`.
3. Approve `ChatGPT Quota Overlay` in macOS Privacy & Security > Accessibility.

Accessibility is a broad macOS permission. This app only uses it for the focused ChatGPT window's position and size.

Not required:

- Screen Recording
- Full Disk Access
- Automation / Apple Events
- microphone or camera
- direct Keychain access

## Refresh policy

No continuous polling loop.

- startup: read once
- App Server quota event: update immediately
- Codex session activity: one refresh after a 2-second debounce
- ChatGPT becomes active: refresh if data is older than 5 minutes
- hover: refresh if data is older than 60 seconds
- Mac wake/network recovery: refresh if data is older than 5 minutes
- minimum spacing between reads: 10 seconds

## Install / upgrade on macOS

```bash
chmod +x install.sh
./install.sh
```

The app is installed to:

```text
~/Applications/ChatGPT Quota Overlay.app
```

The installer does not use `sudo`, does not modify `ChatGPT.app`, and does not disable Gatekeeper.

## Manual build

```bash
./build-app.sh
open "dist/ChatGPT Quota Overlay.app"
```

## Tests

On macOS:

```bash
swift test
```

For a syntax-only check:

```bash
swiftc -parse Sources/QuotaOverlay/*.swift Tests/QuotaOverlayTests/*.swift
```

## Compatibility target

- macOS 13+
- ChatGPT/Codex desktop bundle IDs: `com.openai.chat` or `com.openai.codex`
- validated quota protocol shape: Codex App Server `account/rateLimits/read`

This is a local companion app, not an official OpenAI extension.
