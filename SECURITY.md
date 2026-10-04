# Security model

ChatGPT Quota Overlay v0.1.4 is intentionally narrow: obtain the current Codex rate-limit snapshot from the OpenAI-signed bundled Codex process and display a tiny macOS menu-bar status item.

## Trust boundaries

1. **ChatGPT.app / bundled Codex**
   - Codex is accepted only from known paths inside recognized `ChatGPT.app` / `Codex.app` bundles.
   - The Codex executable must pass the OpenAI Developer ID signature requirement.
   - Arbitrary PATH binaries are not used.

2. **Codex authentication**
   - The app does not parse cookies, `auth.json`, API keys, or Keychain entries.
   - The OpenAI Codex child process performs its own authenticated App Server work.

3. **App Server data**
   - Only `initialize` and `account/rateLimits/read` are sent by this client.
   - `account/rateLimits/updated` is the quota notification consumed.
   - Full responses are not written to disk or logs.
   - Buffers, request counts, and request timeouts are bounded.
   - Unchanged rate-limit telemetry is deduplicated before UI redraw.
   - Failed source health never silently presents old values as fresh; cached values are explicitly marked stale.

4. **macOS UI**
   - The app uses a standard `NSStatusItem` in the system menu bar.
   - It does not overlay ChatGPT windows.
   - It does not inspect ChatGPT UI/accessibility elements, screen pixels, conversations, or account-avatar controls.
   - Accessibility permission is not requested or used.

5. **Filesystem activity**
   - The optional Codex session watcher uses FSEvents on an existing `CODEX_HOME/sessions` directory.
   - It receives change events only; it does not open session files and does not create the directory.

6. **Start at Login**
   - Uses Apple's `SMAppService.mainApp` API.
   - No custom LaunchAgent plist is created.

## Network behavior

The app does not open its own network sockets. The OpenAI-signed Codex child may contact OpenAI using the user's existing ChatGPT/Codex authentication to obtain current rate limits.

The child receives only an allow-listed subset of environment variables. Unrelated GitHub, AWS, database, and shell secrets are not inherited by default.

## Installer and release behavior

- no `sudo`;
- no edits to `/Applications/ChatGPT.app`;
- no Gatekeeper bypass;
- installs only to `~/Applications/ChatGPT Quota Overlay.app`;
- local builds receive an ad-hoc signature only;
- releases include a SHA-256 checksum;
- no in-app auto-updater.

## Recovery model

App Server failures do not trigger a retry loop. Existing quota values are marked stale, the failed child is cleaned up, and the next real event performs one recovery attempt.

## Remaining risks

- The quota protocol is shipped by OpenAI and can change. A protocol change may temporarily make quota unavailable until the parser is updated.
- The project is not App Sandbox-enabled because it launches the separately installed ChatGPT-bundled Codex executable and optionally observes the existing Codex session directory.
- A macOS menu-bar item can be temporarily hidden when the menu bar has insufficient space.
- Ad-hoc signing is suitable for local builds but is not Developer ID signing or notarization for broad public distribution.
