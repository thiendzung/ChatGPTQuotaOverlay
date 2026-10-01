# Security model

ChatGPT Quota Overlay is intentionally narrow: read the two Codex quota windows and draw a tiny overlay.

## Trust boundaries

1. **ChatGPT.app / bundled Codex**
   - The overlay accepts Codex only from known paths inside recognized `ChatGPT.ap``/`Codex.ap`` bundles (`com.openai.chat` or `com.openai.codex`), and the Codex executable itself must have a valid OpenAI Developer ID signature.
   - Arbitrary PATH binaries are not used.

2. **Codex authentication**
   - The overlay does not parse cookies, `auth.json`, API keys, or Keychain entries.
   - The OpenAI Codex child process performs its own authenticated App Server work.

3. **App Server data**
   - Only `initialize` and `account/rateLimits/read` are sent by this client.
   - `account/rateLimits/updated` is the only notification consumed.
   - Full responses are not written to disk or logs.
   - Buffers and outstanding requests are bounded.

4. **macOS Accessibility**
   - Optional, not requested on startup.
   - Used only to observe ChatGPT window move/resize events and read that window's frame.
   - No UI text, keystrokes, conversation content, or controls are read or manipulated.

5. **Filesystem activity**
   - The optional Codex session watcher uses FSEvents on the user's existing `CODEX_HOME/sessions` directory.
   - It receives change events only; it does not open session files and does not create the directory.

## Network behavior

The overlay does not open its own network sockets. The bundled Codex child may contact OpenAI using the user's existing ChatGPT/Codex authentication to obtain current rate limits.

The child process receives only an allow-listed subset of environment variables. Unrelated secrets such as GitHub, AWS, database, or other shell tokens are not inherited by default.

## Installer behavior

- no `sudo`
- no edits to `/Applications/ChatGPT.app`
- no automatic `xattr -d` / Gatekeeper bypass
- installs only to `~/Applications/ChatGPT Quota Overlay.app`

## Remaining risks

- Accessibility is intrinsically a powerful macOS permission. Users who do not want to grant it can run the overlay without it; live move/resize tracking will be less immediate.
- Quota data is obtained through a local Codex App Server process and therefore depends on the protocol shipped by OpenAI. Future protocol changes can temporarily make quota unavailable until the parser is updated.
- This project is not sandboxed because it launches the separately installed ChatGPT-bundled Codex executable and optionally observes the user's Codex session directory.
