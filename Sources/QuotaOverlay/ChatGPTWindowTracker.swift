import AppKit
import ApplicationServices

/// Tracks only the ChatGPT window frame. Accessibility is optional:
/// - without it, window bounds are read on app activation using CGWindowList
/// - with it, move/resize changes are received as events via AXObserver
final class ChatGPTWindowTracker {
    var onFrameChange: ((CGRect?) -> Void)?
    var onChatGPTActivated: (() -> Void)?
    var onAccessibilityStatusChange: ((Bool) -> Void)?

    private var observer: AXObserver?
    private var observedWindow: AXUIElement?
    private var workspaceObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    var isAccessibilityEnabled: Bool { AXIsProcessTrusted() }

    func start() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.attachToFrontmostChatGPTWindow()
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.attachToFrontmostChatGPTWindow()
        }

        attachToFrontmostChatGPTWindow()
    }

    func stop() {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        workspaceObserver = nil
        screenObserver = nil
        detachAXObserver()
    }

    func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // One-shot recheck only. When the user returns from System Settings,
        // the normal application-activation event performs another check.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.attachToFrontmostChatGPTWindow()
        }
    }

    deinit { stop() }

    private func attachToFrontmostChatGPTWindow() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            detachAXObserver()
            onFrameChange?(nil)
            return
        }

        let bundleID = app.bundleIdentifier ?? ""
        let isChatGPT = bundleID == "com.openai.chat" || app.localizedName == "ChatGPT"
        guard isChatGPT else {
            detachAXObserver()
            onFrameChange?(nil)
            return
        }

        onChatGPTActivated?()
        let trusted = AXIsProcessTrusted()
        onAccessibilityStatusChange?(trusted)

        if trusted {
            attachAXObserver(to: app)
        } else {
            detachAXObserver()
            onFrameChange?(frontmostWindowFrame(processIdentifier: app.processIdentifier))
        }
    }

    private func attachAXObserver(to app: NSRunningApplication) {
        detachAXObserver()

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = value,
              CFGetTypeID(window) == AXUIElementGetTypeID() else {
            onFrameChange?(frontmostWindowFrame(processIdentifier: app.processIdentifier))
            return
        }

        let axWindow = unsafeBitCast(window, to: AXUIElement.self)
        observedWindow = axWindow

        var createdObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            let tracker = Unmanaged<ChatGPTWindowTracker>.fromOpaque(refcon).takeUnretainedValue()
            if notification as String == kAXUIElementDestroyedNotification as String {
                tracker.attachToFrontmostChatGPTWindow()
            } else {
                tracker.emitAXFrame()
            }
        }

        guard AXObserverCreate(app.processIdentifier, callback, &createdObserver) == .success,
              let createdObserver else {
            onFrameChange?(frontmostWindowFrame(processIdentifier: app.processIdentifier))
            return
        }

        observer = createdObserver
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(createdObserver, axWindow, kAXMovedNotification as CFString, refcon)
        AXObserverAddNotification(createdObserver, axWindow, kAXResizedNotification as CFString, refcon)
        AXObserverAddNotification(createdObserver, axWindow, kAXUIElementDestroyedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(createdObserver), .commonModes)
        emitAXFrame()
    }

    private func detachAXObserver() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedWindow = nil
    }

    private func emitAXFrame() {
        guard let window = observedWindow else {
            onFrameChange?(nil)
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
            onFrameChange?(nil)
            return
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(unsafeBitCast(posValue, to: AXValue.self), .cgPoint, &position)
        AXValueGetValue(unsafeBitCast(sizeValue, to: AXValue.self), .cgSize, &size)

        onFrameChange?(CGRect(origin: position, size: size))
    }

    private func frontmostWindowFrame(processIdentifier pid: pid_t) -> CGRect? {
        guard let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        return raw.compactMap { info -> CGRect? in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value == pid,
                  let layer = info[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0,
                  let bounds = info[kCGWindowBounds as String] as? CFDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width >= 400,
                  rect.height >= 300 else {
                return nil
            }
            return rect
        }
        .max { ($0.width * $0.height) < ($1.width * $1.height) }
    }
}
