import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = OverlayPanel()
    private let tracker = ChatGPTWindowTracker()
    private let quotaProvider: QuotaProvider = CodexAppServerQuotaProvider()
    private let sessionWatcher = CodexSessionActivityWatcher()
    private let networkWatcher = NetworkReachabilityWatcher()
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // v0.1.3 deliberately does not request Accessibility on launch.
        // Basic positioning works without it; the user may opt in to live
        // move/resize tracking from the widget's right-click menu.
        panel.accessibilityEnabledProvider = { [weak tracker] in
            tracker?.isAccessibilityEnabled ?? false
        }
        panel.onRequestAccessibility = { [weak tracker] in
            tracker?.requestAccessibilityPermission()
        }
        panel.onRefresh = { [weak quotaProvider] in
            quotaProvider?.refreshNow()
        }
        panel.onQuit = {
            NSApp.terminate(nil)
        }

        quotaProvider.onChange = { [weak self] quota in
            self?.panel.update(quota: quota)
        }
        quotaProvider.start()

        panel.onHover = { [weak self] in
            self?.quotaProvider.refreshIfOlder(than: 60)
        }

        tracker.onChatGPTActivated = { [weak self] in
            self?.quotaProvider.refreshIfOlder(than: 300)
        }
        tracker.onFrameChange = { [weak self] frame in
            self?.positionPanel(chatGPTFrame: frame)
        }
        tracker.start()

        sessionWatcher.onActivity = { [weak self] in
            self?.quotaProvider.refreshAfterActivity()
        }
        sessionWatcher.start()

        networkWatcher.onReachable = { [weak self] in
            self?.quotaProvider.refreshIfOlder(than: 300)
        }
        networkWatcher.start()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.quotaProvider.refreshIfOlder(than: 300)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil
        tracker.stop()
        sessionWatcher.stop()
        networkWatcher.stop()
        quotaProvider.stop()
    }

    private func positionPanel(chatGPTFrame frame: CGRect?) {
        guard let frame else {
            panel.orderOut(nil)
            return
        }

        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main else {
            panel.orderOut(nil)
            return
        }

        // ChatGPT's compact left rail is ~106 px wide. The widget is centered
        // at ~53 px from the window's left edge, matching the native icon rail.
        let size: CGFloat = 46
        let railCenterX = frame.minX + 53
        var x = railCenterX - size / 2

        // AX/CG window bounds use a top-origin coordinate system. Convert the
        // ChatGPT window's bottom edge to AppKit coordinates, then keep the
        // widget ~79 px above it so it sits cleanly above the profile avatar.
        let chatGPTBottomY = screen.frame.maxY - frame.maxY
        var y = chatGPTBottomY + 79

        let visible = screen.visibleFrame
        x = min(max(x, visible.minX + 4), visible.maxX - size - 4)
        y = min(max(y, visible.minY + 4), visible.maxY - size - 4)

        panel.setFrame(NSRect(x: x, y: y, width: size, height: size), display: true)
        panel.orderFrontRegardless()
    }
}
