# Changelog

## 0.1.4.2

- Change the menu-bar text from the single binding limit (for example `W 37%`) to the full remaining pair `5h/week`.
- Example: `37/100` means 37% remaining in the 5-hour window and 100% remaining in the weekly window.
- Keep full labels and percent signs in the hover tooltip and menu details.
- Show missing windows explicitly, e.g. `37/—` or `—/100`.
- Stale cached data keeps the compact `~` prefix, e.g. `~37/100`.


## 0.1.4.1

- Create the macOS status item only after `applicationDidFinishLaunching`, instead of during `AppDelegate` construction.
- Explicitly reassert `NSStatusItem.isVisible` and variable length after the first main-loop turn.
- Show `Q —` before the first quota sample so the menu-bar item remains identifiable even when quota is temporarily unavailable.
- Keep the fix one-shot and event-driven; no polling loop.


## 0.1.4

- Replace the ChatGPT sidebar overlay with a compact native macOS menu-bar status item.
- Remove ChatGPT window tracking, avatar-zone geometry, z-order logic, and Accessibility permission entirely.
- Show only the binding active quota in the menu bar: e.g. `W 6%` or `5h 12%`.
- Show both windows and reset times in the menu.
- Handle accounts where the 5-hour window is absent instead of displaying a fake/empty second meter.
- Parse `resetsAt` from the structured App Server snapshot.
- Deduplicate unchanged `account/rateLimits/updated` telemetry before UI redraw.
- Preserve event-driven refresh, stale-state handling, Start at Login, security hardening, CI, and release packaging.
- Add tests for binding-limit selection, single-window plans, stale state, and reset timestamps.


## 0.1.3.4

- Centralize widget placement in a named avatar/rail anchor geometry model.
- Keep the quota widget fixed relative to ChatGPT's profile-avatar zone.
- Make Accessibility AXObserver move/resize callbacks the primary realtime drag/resize tracking path.
- Keep the no-Accessibility fallback event-driven; no recurring polling.
- Clarify the right-click menu with `Live tracking: On` / `Live tracking: Off — Enable…`.
- Explicitly avoid traversing or reading ChatGPT's avatar/profile UI element.
- Add anchor-geometry regression tests.
- Preserve the v0.1.3.3 focus-ordering and relaunch behavior.


## 0.1.3.3

- Fix the overlay disappearing when focus moves from ChatGPT to another app.
- Order the overlay immediately above the tracked ChatGPT window rather than dropping its window level on deactivation.
- Keep active third-party apps naturally above ChatGPT + overlay.
- Fix failure to reattach after ChatGPT is quit and launched again.
- Add bounded event-triggered WindowServer settle callbacks after ChatGPT launch/activate/unhide and Space changes.
- Keep the implementation event-driven; no recurring polling loop.


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
