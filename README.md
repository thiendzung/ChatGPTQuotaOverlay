# ChatGPT Quota Overlay v0.1.4

**built by ThienDzung**

A minimal macOS menu-bar companion for the real Codex / Work quota reported by the Codex App Server.

## Why v0.1.4 changed the UI

The previous sidebar overlay competed with ChatGPT's own dynamic controls, required window tracking, and could collide with temporary icons near the account avatar.

v0.1.4 removes that entire class of problems. The app now uses the macOS menu bar, which is a stable system surface and does not depend on ChatGPT's sidebar layout.

## Compact display

The menu bar shows only the **binding active limit** — the active window with the least allowance remaining.

Examples:

- `W 6%` — weekly quota is the current limiter.
- `5h 12%` — the 5-hour window is the current limiter.
- `~W 6%` — cached/stale weekly value.
- `—` — no reliable quota is available.

This is intentional: when both a 5-hour and weekly window apply, allowance must remain in both. Showing the smaller remaining window is the most useful single glance.

Hover shows the complete snapshot:

`5h 78% · Week 6%`

Clicking the menu-bar item shows:

- 5-hour remaining + reset time, when that window exists;
- weekly remaining + reset time;
- the current binding limit;
- stale/cached status;
- Refresh quota now;
- Start at Login;
- Quit.

If the account currently exposes only one usage window, v0.1.4 shows only that real window and does not invent the missing one.

## Real quota source

The app launches the Codex binary bundled inside an OpenAI-signed ChatGPT/Codex application and uses:

- `account/rateLimits/read` for the initial/current snapshot;
- `account/rateLimits/updated` for live changes.

The selector prefers `rateLimitsByLimitId.codex` and falls back to the compatible `rateLimits` shape.

The app converts App Server `usedPercent` into remaining percentage.

## Refresh model

No continuous polling loop.

- startup: one read;
- App Server rate-limit event: update immediately;
- unchanged rate-limit telemetry: freshness is renewed but the UI is not redrawn;
- Codex session activity: one refresh after a 2-second debounce;
- opening the menu: refresh if older than 60 seconds;
- Mac wake / network recovery: refresh if older than 5 minutes;
- minimum spacing between explicit reads: 10 seconds;
- stale transition: one-shot after 15 minutes without a fresh sample.

## Permissions

v0.1.4 needs **no Accessibility permission**.

It also does not require:

- Screen Recording;
- Full Disk Access;
- Apple Events / Automation;
- microphone or camera;
- direct Keychain access.

The app does not inspect ChatGPT UI elements, conversations, avatar controls, window positions, or screen pixels.

## Authentication and privacy

The overlay itself does not read:

- browser cookies;
- `~/.codex/auth.json`;
- API keys;
- Keychain credentials.

Authentication remains inside the OpenAI-signed Codex child process.

Full App Server responses are not logged or persisted. Only the small rate-limit snapshot required for the UI is retained in memory.

## Start at Login

Click the menu-bar item and choose `Start at Login`.

This uses Apple's `SMAppService.mainApp` API. No custom LaunchAgent is installed.

## Install / upgrade

```bash
chmod +x install.sh
./install.sh
```

Installed to:

```text
~/Applications/ChatGPT Quota Overlay.app
```

The installer does not use `sudo`, modify `ChatGPT.app`, or remove Gatekeeper quarantine attributes.

## Build and test

```bash
swift test
./build-app.sh
```

GitHub CI validates:

- shell syntax;
- release build;
- tests;
- app packaging;
- plist;
- local ad-hoc signature integrity.

## Compatibility

- macOS 13+
- ChatGPT/Codex bundle IDs `com.openai.chat` or `com.openai.codex`
- Codex App Server rate-limit protocol

This is a local companion app, not an official OpenAI extension.
