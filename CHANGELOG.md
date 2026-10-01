# Changelog

## 0.1.3.2

- Keep the overlay attached to a visible ChatGPT window when another app becomes active.
- Dynamically use floating level only while ChatGPT is active, then drop to normal level so other apps can cover it.
- Add event-driven Space, hide/unhide, launch/terminate, screen, focus, minimize/restore, and window-destroy handling.
- Improve multi-window, multi-monitor, and full-screen behavior.
- Add fresh / stale / unavailable quota states; stale data is dimmed and labeled \`cached\`.
- Mark successful data stale after a one-shot 15-minute freshness deadline.
- Harden App Server self-recovery without recurring retry polling.
- Add Start at Login using \`SMAppService.mainApp\`.
- Add macOS CI for build, tests, shell syntax, app packaging, plist validation, and signature verification.
- Add tag-based GitHub Release packaging with ZIP + SHA-256.
- Add a single \`VERSION\` source for build/release versioning.
- Keep in-app auto-update intentionally out of scope.

## 0.1.3.1

UI polish validated against the user's Retina macOS screenshot:

- Center the widget on the native left icon rail (~27 pt from the window edge).
- Move it down so it sits directly above the profile avatar instead of over "Recent".
- Reduce the widget from 46 pt to 40 pt.
- Use thinner, quieter ring tracks and stronger neutral center digits for readability.
- Keep blue = 5-hour quota and purple = weekly quota.
- Add a subtle hover surface without changing the quota colors.
- Preserve the hover tooltip.
- Integrate the macOS Swift compile compatibility fix found during real installation.
- Register the app bundle with LaunchServices before opening.

## 0.1.3

- Make Accessibility permission opt-in instead of prompting on launch.
- Add no-Accessibility window-frame fallback.
- Restrict Codex executable resolution to ChatGPT.app and validate the bundled Codex signature.
- Remove PATH fallback for Codex.
- Allow-list child-process environment variables.
- Bound App Server request count, timeout, and read buffer.
- Correctly merge sparse rate-limit update notifications.
- Make session activity watching read-only.
- Stop deleting Gatekeeper quarantine attributes during install.
- Add right-click actions for refresh, permission opt-in, and quit.
- Improve bottom-left rail placement.
- Add parser tests and security documentation.
