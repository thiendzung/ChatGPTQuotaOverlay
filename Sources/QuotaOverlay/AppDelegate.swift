import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = OverlayPanel()
    private let tracker = ChatGPTWindowTracker()
    private let quotaProvider: QuotaProvider = CodexAppServerQuotaProvider()
    private let sessionWatcher = CodexSessionActivityWatcher()
    private let networkWatcher = NetworkReachabilityWatcher()
    private let launchAtLogin = LaunchAtLoginController()
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panel.accessibilityEnabledProvider = { [weak tracker] in
            tracker?.isAccessibilityEnabled ?? false
        }
        panel.onRequestAccessibility = { [weak tracker] in
            tracker?.requestAccessibilityPermission()
        }
        panel.launchAtLoginStateProvider = { [weak launchAtLogin] in
            launchAtLogin?.state ?? .unavailable
        }
        panel.onToggleLaunchAtLogin = { [weak launchAtLogin] in
            launchAtLogin?.toggle()
        }
        panel.onOpenLoginItemsSettings = { [weak launchAtLogin] in
            launchAtLogin?.openLoginItemsSettings()
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
        tracker.onStateChange = { [weak self] state in
            self?.applyWindowState(state)
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

    private func applyWindowState(_ state: ChatGPTWindowState?) {
        guard let state else {
            panel.orderOut(nil)
            return
        }

        let appKitFrame = appKitFrame(fromQuartzFrame: state.frame)
        guard let screen = screen(containing: appKitFrame) else {
            panel.orderOut(nil)
            return
        }

        let size = OverlayPanel.preferredSize.width
        var quotaFrame = SidebarAnchorGeometry.quotaFrame(
            chatGPTFrame: appKitFrame,
            quotaSize: size
        )

        // Clamp only to the physical screen, not visibleFrame. In ChatGPT full
        // screen the Dock/menu-bar insets should not push the overlay inward.
        let bounds = screen.frame
        quotaFrame.origin.x = min(
            max(quotaFrame.origin.x, bounds.minX + 4),
            bounds.maxX - size - 4
        )
        quotaFrame.origin.y = min(
            max(quotaFrame.origin.y, bounds.minY + 4),
            bounds.maxY - size - 4
        )

        panel.setFrame(quotaFrame, display: true)
        panel.present(
            aboveChatGPTWindowID: state.windowID,
            isChatGPTActive: state.isChatGPTActive
        )
    }

    /// CGWindow/AX use Quartz global coordinates (origin at the top-left of the
    /// primary display). AppKit uses a bottom-left origin. Using the primary
    /// display height as the global flip axis also handles displays arranged
    /// above, below, or beside the primary display.
    private func appKitFrame(fromQuartzFrame frame: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return frame }
        return CGRect(
            x: frame.minX,
            y: primary.frame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        let candidate = NSScreen.screens
            .map { ($0, intersectionArea($0.frame, frame)) }
            .max { $0.1 < $1.1 }
        guard let candidate, candidate.1 > 0 else { return nil }
        return candidate.0
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}
