# Security model

ChatGPT Quota Overlay is intentionally narrow: read two Codex quota windows and draw a tiny local overlay.

## Trust boundaries

1. **ChatGPT.app / bundled Codex**
   - Codex is accepted only from known paths inside recognized \`ChatGPT.app\` / \`Codex.app\` bundles (\`com.openai.chat\` or \`com.openai.codex\`).
   - The Codex executable must pass an OpenAI Developer ID signature requirement.
   - Arbitrary PATH binaries are not used.

2. **Codex authentication**
   - The overlay does not parse cookies, \`auth.json\`, API keys, or Keychain entries.
   - The OpenAI Codex child process performs its own authenticated App Server work.

3. **App Server data**
   - Only \`initialize\` and \`account/rateLimits/read\` are sent by this client.
   - \`account/rateLimits/updated\` is the only quota notification consumed.
   - Full responses are not written to disk or logs.
   - Buffers, request counts, and request timeouts are bounded.
   - Failed source health never silently presents old values as fresh: cached values are explicitly marked stale.

4. **macOS Accessibility**
   - Optional and not requested on startup.
   - Used only for ChatGPT window move, resize, focus, minimize/restore, destruction, and frame metadata.
   - No UI text, keystrokes, conversation content, or controls are read or manipulated.

5. **Window metadata without Accessibility**
   - Public CGWindow metadata is read only when macOS emits app, Space, or screen lifecycle events.
   - No pixels are captured and no recurring window polling loop is used.

6. **Filesystem activity**
   - The optional Codex session watcher uses FSEvents on an existing \`CODEX_HOME/sessions\` directory.
   - It receives change events only; it does not open session files and does not create the directory.

7. **Start at Login**
   - Uses Apple's \`SMAppService.mainApp\` API.
   - No custom LaunchAgent plist is created.
   - Approval, when required, is managed by macOS Login Items settings.

## Network behavior

The overlay does not open its own network sockets. The OpenAI-signed Codex child may contact OpenAI using the user's existing ChatGPT/Codex authentication to obtain current rate limits.

The child process receives only an allow-listed subset of environment variables. Unrelated GitHub, AWS, database, and shell secrets are not inherited by default.

## Installer and release behavior

- no \`sudo\`;
- no edits to \`/Applications/ChatGPT.app\`;
- no automatic \`xattr -d\` or Gatekeeper bypass;
- installs only to \`~/Applications/ChatGPT Quota Overlay.app\`;
- local builds receive an ad-hoc signature only; this is not Developer ID signing or notarization;
- releases include a SHA-256 checksum;
- no in-app auto-updater is present.

## Recovery model

App Server failures do not trigger a retry loop. Existing quota values are marked stale, the failed child is cleaned up, and the next real user/system event performs one recovery attempt. This limits background activity and avoids a crash/retry loop.

## Remaining risks

- Accessibility is intrinsically powerful. Users can run without it, but exact same-app window focus/close tracking is less immediate until the next macOS lifecycle event.
- The quota protocol is shipped by OpenAI and can change. A protocol change may temporarily make quota unavailable or stale until the parser is updated.
- The project is not App Sandbox-enabled because it launches the separately installed ChatGPT-bundled Codex executable and optionally observes the user's Codex session directory.
- Ad-hoc signing is suitable for local builds but does not provide Developer ID identity or notarization for broad public distribution.
