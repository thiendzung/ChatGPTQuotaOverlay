import AppKit
import ApplicationServices

struct ChatGPTWindowState: Equatable {
    let frame: CGRect
    let windowID: CGWindowID
    let isChatGPTActive: Bool
}

/// Event-driven ChatGPT window tracking.
///
/// Without Accessibility permission, CGWindowList is sampled only when macOS
/// reports an application/Space/screen lifecycle event. With Accessibility,
/// the focused ChatGPT window also emits move/resize/minimize/focus events.
/// No recurring polling loop is used.
final class ChatGPTWindowTracker {
    var onStateChange: ((ChatGPTWindowState?) -> Void)?
    var onChatGPTActivated: (() -> Void)?
    var onAccessibilityStatusChange: ((Bool) -> Void)?

    private struct WindowInfo {
        let id: CGWindowID
        let frame: CGRect
    }

    private let acceptedBundleIDs: Set<String> = ["com.openai.chat", "com.openai.codex"]

    private var workspaceObservers: [NSObjectProtocol] = []
    private var screenObserver: NSObjectProtocol?

    private var axObserver: AXObserver?
    private var axAppElement: AXUIElement?
    private var observedWindow: AXUIElement?
    private var observedPID: pid_t?

    private var targetPID: pid_t?
    private var targetWindowID: CGWindowID?
    private var lastState: ChatGPTWindowState?
    private var lastAccessibilityStatus: Bool?

    var isAccessibilityEnabled: Bool { AXIsProcessTrusted() }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ]

        workspaceObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.handleWorkspaceEvent(note)
            }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshWindowState()
        }

        refreshWindowState()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { center.removeObserver($0) }
        workspaceObservers.removeAll()

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil

        detachAXObserver()
        targetPID = nil
        targetWindowID = nil
        emit(nil)
    }

    func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // One-shot recheck only. Returning from System Settings will also
        // naturally trigger a workspace application-activation event.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshWindowState()
        }
    }

    deinit { stop() }

    private func handleWorkspaceEvent(_ notification: Notification) {
        if notification.name == NSWorkspace.didTerminateApplicationNotification,
           let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.processIdentifier == targetPID {
            targetPID = nil
            targetWindowID = nil
            detachAXObserver()
        }

        if notification.name == NSWorkspace.didActivateApplicationNotification,
           let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           isChatGPT(app) {
            targetPID = app.processIdentifier
            onChatGPTActivated?()
        }

        refreshWindowState()
    }

    private func refreshWindowState() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let frontmostChatGPT = frontmost.flatMap { isChatGPT($0) ? $0 : nil }

        let app: NSRunningApplication?
        if let frontmostChatGPT {
            app = frontmostChatGPT
            targetPID = frontmostChatGPT.processIdentifier
        } else if let targetPID,
                  let tracked = NSRunningApplication(processIdentifier: targetPID),
                  !tracked.isTerminated,
                  isChatGPT(tracked) {
            app = tracked
        } else {
            app = firstRunningChatGPTApplication()
            targetPID = app?.processIdentifier
        }

        guard let app, !app.isTerminated else {
            detachAXObserver()
            targetPID = nil
            targetWindowID = nil
            emit(nil)
            return
        }

        let trusted = AXIsProcessTrusted()
        if lastAccessibilityStatus != trusted {
            lastAccessibilityStatus = trusted
            onAccessibilityStatusChange?(trusted)
        }

        if trusted {
            ensureAXObserver(for: app)
        } else {
            detachAXObserver()
        }

        guard !app.isHidden else {
            emit(nil)
            return
        }

        let windows = visibleWindowInfos(processIdentifier: app.processIdentifier)
        guard !windows.isEmpty else {
            // No normal ChatGPT window exists on the active Space. This also
            // covers minimized/closed windows without requiring Screen Recording.
            emit(nil)
            return
        }

        let isActive = frontmost?.processIdentifier == app.processIdentifier
        let selected: WindowInfo
        if isActive {
            // CGWindowList is ordered front-to-back, so the first normal window
            // is the active/topmost ChatGPT document window.
            selected = windows[0]
        } else if let targetWindowID,
                  let existing = windows.first(where: { $0.id == targetWindowID }) {
            selected = existing
        } else {
            // If the previously tracked window moved to another Space or closed,
            // bind to the visible ChatGPT window on the current Space.
            selected = windows[0]
        }

        targetWindowID = selected.id
        emit(ChatGPTWindowState(
            frame: selected.frame,
            windowID: selected.id,
            isChatGPTActive: isActive
        ))

        if trusted {
            attachFocusedWindowNotifications(for: app)
        }
    }

    private func isChatGPT(_ app: NSRunningApplication) -> Bool {
        if let bundleID = app.bundleIdentifier, acceptedBundleIDs.contains(bundleID) {
            return true
        }
        return app.localizedName == "ChatGPT" || app.localizedName == "Codex"
    }

    private func firstRunningChatGPTApplication() -> NSRunningApplication? {
        for bundleID in acceptedBundleIDs {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first(where: { !$0.isTerminated }) {
                return app
            }
        }
        return NSWorkspace.shared.runningApplications.first(where: {
            !$0.isTerminated && isChatGPT($0)
        })
    }

    private func visibleWindowInfos(processIdentifier pid: pid_t) -> [WindowInfo] {
        guard let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return raw.compactMap { info -> WindowInfo? in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value == pid,
                  let layer = info[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0,
                  let windowNumber = info[kCGWindowNumber as String] as? NSNumber,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width >= 400,
                  rect.height >= 300 else {
                return nil
            }

            if let alpha = info[kCGWindowAlpha as String] as? NSNumber,
               alpha.doubleValue <= 0.01 {
                return nil
            }

            return WindowInfo(id: CGWindowID(windowNumber.uint32Value), frame: rect)
        }
    }

    private func ensureAXObserver(for app: NSRunningApplication) {
        if observedPID == app.processIdentifier, axObserver != nil {
            return
        }

        detachAXObserver()

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var createdObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<ChatGPTWindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            let name = notification as String

            if name == kAXMovedNotification as String || name == kAXResizedNotification as String {
                tracker.emitAXFrame()
                return
            }

            // Focus/create/destroy/minimize changes can change the selected CG
            // window, so resolve the active-space state again on the main loop.
            DispatchQueue.main.async { [weak tracker] in
                tracker?.refreshWindowState()
            }
        }

        guard AXObserverCreate(app.processIdentifier, callback, &createdObserver) == .success,
              let createdObserver else {
            return
        }

        axObserver = createdObserver
        axAppElement = appElement
        observedPID = app.processIdentifier

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        _ = AXObserverAddNotification(
            createdObserver,
            appElement,
            kAXFocusedWindowChangedNotification as CFString,
            refcon
        )
        _ = AXObserverAddNotification(
            createdObserver,
            appElement,
            kAXWindowCreatedNotification as CFString,
            refcon
        )

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(createdObserver),
            .commonModes
        )
    }

    private func attachFocusedWindowNotifications(for app: NSRunningApplication) {
        guard let observer = axObserver,
              observedPID == app.processIdentifier,
              let appElement = axAppElement else {
            return
        }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return
        }

        let window = unsafeBitCast(value, to: AXUIElement.self)
        if let observedWindow, CFEqual(observedWindow, window) {
            return
        }

        removeObservedWindowNotifications()
        observedWindow = window

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications: [String] = [
            kAXMovedNotification,
            kAXResizedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
            kAXUIElementDestroyedNotification
        ]

        for name in notifications {
            _ = AXObserverAddNotification(observer, window, name as CFString, refcon)
        }
    }

    private func removeObservedWindowNotifications() {
        guard let observer = axObserver, let observedWindow else {
            self.observedWindow = nil
            return
        }

        let notifications: [String] = [
            kAXMovedNotification,
            kAXResizedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
            kAXUIElementDestroyedNotification
        ]
        for name in notifications {
            _ = AXObserverRemoveNotification(observer, observedWindow, name as CFString)
        }
        self.observedWindow = nil
    }

    private func detachAXObserver() {
        removeObservedWindowNotifications()

        if let observer {
            if let appElement = axAppElement {
                _ = AXObserverRemoveNotification(
                    observer,
                    appElement,
                    kAXFocusedWindowChangedNotification as CFString
                )
                _ = AXObserverRemoveNotification(
                    observer,
                    appElement,
                    kAXWindowCreatedNotification as CFString
                )
            }
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
        }

        axObserver = nil
        axAppElement = nil
        observedPID = nil
    }

    private func emitAXFrame() {
        guard let window = observedWindow else {
            refreshWindowState()
            return
        }

        var minimizedValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            window,
            kAXMinimizedAttribute as CFString,
            &minimizedValue
        ) == .success,
        let minimized = minimizedValue as? Bool,
        minimized {
            emit(nil)
            return
        }

        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
            let posValue, let sizeValue,
            CFGetTypeID(posValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else {
            refreshWindowState()
            return
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(unsafeBitCast(posValue, to: AXValue.self), .cgPoint, &position)
        AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size)

        guard let windowID = targetWindowID else {
            refreshWindowState()
            return
        }

        let isActive = NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID
        emit(ChatGPTWindowState(
            frame: CGRect(origin: position, size: size),
            windowID: windowID,
            isChatGPTActive: isActive
        ))
    }

    private func emit(_ state: ChatGPTWindowState?) {
        guard state != lastState else { return }
        lastState = state
        onStateChange?(state)
    }
}
