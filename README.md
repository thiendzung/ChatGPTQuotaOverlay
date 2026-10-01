# ChatGPT Quota Overlay v0.1.3.3

**built by ThienDzung**

A small local macOS companion for ChatGPT Desktop that shows remaining Codex quota in the left icon rail.

## UI

- Outer blue ring: remaining 5-hour quota.
- Inner purple ring: remaining weekly quota.
- Center: remaining percentages, for example \`61 / 55\`.
- Hover: \`5h 61% · Week 55%\`.
- Cached/stale quota is deliberately dimmed and the hover text adds \`cached\`.
- No usable quota data: \`— / —\`.

## v0.1.3.3

This hotfix focuses on the two lifecycle problems found during real macOS use: losing the overlay when another app becomes active, and failing to reattach after ChatGPT is quit/reopened.

- The overlay is now ordered directly above the tracked ChatGPT window instead of switching between normal/floating levels.
- Other applications can still sit above ChatGPT and the overlay naturally.
- ChatGPT launch/activate/unhide events trigger bounded one-shot settle callbacks so the overlay can reattach after the new window reaches WindowServer.
- No continuous polling loop is introduced.

The v0.1.3.2 reliability, permissions, Start at Login, CI, and release hardening remain in place.

### Window behavior

- Switching to another app no longer hides the widget just because ChatGPT lost focus.
- When ChatGPT is active, the overlay uses a floating level so it stays above ChatGPT.
- When another app becomes active, the overlay drops to normal level so that app can cover it naturally.
- Minimized, hidden, closed, off-Space, or terminated ChatGPT windows are hidden when their state can be observed.
- Active Space changes are handled as events; no window polling loop is used.
- Multi-monitor coordinates are converted using the primary display as the Quartz/AppKit flip axis.
- Multiple ChatGPT windows are supported: the active/topmost ChatGPT window is preferred, while the last tracked visible window is retained when another app becomes active.
- Full-screen ChatGPT remains supported through the auxiliary full-screen panel behavior.

Without Accessibility permission, window state is refreshed on macOS app/Space/screen lifecycle events. Enabling live window tracking adds exact move, resize, focus, minimize, restore, and window-destroy events.

### Quota freshness

The app distinguishes three states:

- **fresh**: normal rings and digits;
- **stale/cached**: values remain visible but are dimmed;
- **unavailable**: \`— / —\`.

A successful quota sample becomes stale after 15 minutes if no newer App Server result arrives. App Server failure marks existing values stale immediately. This uses a one-shot deadline, not recurring polling.

### Self-recovery

If the bundled Codex App Server exits, times out, or returns an invalid protocol response:

1. cached data is marked stale;
2. the broken child process is cleaned up;
3. no retry loop is started;
4. the next real event (hover, ChatGPT activation, Codex activity, network recovery, or Mac wake) resolves the OpenAI-signed Codex binary again and starts a fresh App Server.

### Start at Login

Right-click the rings and select \`Start at Login\`.

This uses Apple's \`SMAppService.mainApp\` API on macOS 13+. If macOS requires approval, the menu opens **System Settings > Login Items** using the official ServiceManagement API. No LaunchAgent plist is installed manually.

### CI and releases

GitHub Actions now verifies on macOS:

- shell syntax;
- \`swift build -c release\`;
- \`swift test\`;
- app packaging;
- plist validity;
- ad-hoc code-signature integrity.

Tags matching \`v*\` run a release workflow that builds the app, creates a macOS ZIP, writes a SHA-256 file, and publishes a GitHub Release.

There is intentionally **no in-app auto-updater** in v0.1.3.2.

## Real quota source

The app launches the Codex binary bundled inside an OpenAI-signed ChatGPT/Codex app and uses the local Codex App Server:

- \`account/rateLimits/read\`
- \`account/rateLimits/updated\`

The overlay does **not** read browser cookies, \`~/.codex/auth.json\`, API keys, or Keychain credentials. Full App Server responses are not logged or persisted.

## Permissions

### Default mode

No special privacy permission is requested at startup.

The app uses public window metadata to position itself when macOS reports relevant lifecycle events. It does not capture screen pixels or inspect conversation text.

### Optional Accessibility

Right-click the quota rings and choose \`Enable live window tracking…\`.

Accessibility is used only to observe the selected ChatGPT window's:

- move / resize;
- focus changes;
- minimize / restore;
- destruction.

The app does not read UI text, keystrokes, messages, or controls.

Not required:

- Screen Recording;
- Full Disk Access;
- Apple Events automation;
- microphone or camera;
- direct Keychain access.

## Refresh policy

No continuous polling loop.

- startup: one read;
- App Server quota event: immediate update;
- Codex session activity: one refresh after a 2-second debounce;
- ChatGPT activation: refresh if older than 5 minutes;
- hover: refresh if older than 60 seconds;
- Mac wake / network recovery: refresh if older than 5 minutes;
- minimum spacing between App Server reads: 10 seconds;
- freshness transition: one-shot at 15 minutes.

## Install / upgrade

\`\`\`bash
chmod +x install.sh
./install.sh
\`\`\`

Installed to:

\`\`\`text
~/Applications/ChatGPT Quota Overlay.app
\`\`\`

The installer does not use \`sudo\`, does not modify \`ChatGPT.app\`, and does not remove Gatekeeper quarantine attributes.

## Build and test

\`\`\`bash
swift test
./build-app.sh
\`\`\`

Syntax-only check:

\`\`\`bash
swiftc -frontend -parse Sources/QuotaOverlay/*.swift Tests/QuotaOverlayTests/*.swift
\`\`\`

Create a release package locally:

\`\`\`bash
./scripts/package-release.sh
\`\`\`

## Compatibility

- macOS 13+
- ChatGPT/Codex bundle IDs \`com.openai.chat\` or \`com.openai.codex\`
- Codex App Server \`account/rateLimits/read\`

This is a local companion app, not an official OpenAI extension.
