import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?
    private let quotaProvider: QuotaProvider = CodexAppServerQuotaProvider()
    private let sessionWatcher = CodexSessionActivityWatcher()
    private let networkWatcher = NetworkReachabilityWatcher()
    private let launchAtLogin = LaunchAtLoginController()
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // NSStatusItem is created only after AppKit has finished launching.
        // Apple defines this callback as the point where app initialization is
        // complete and the main event loop has started.
        let statusBar = StatusBarController()
        self.statusBar = statusBar

        statusBar.launchAtLoginStateProvider = { [weak launchAtLogin] in
            launchAtLogin?.state ?? .unavailable
        }
        statusBar.onToggleLaunchAtLogin = { [weak launchAtLogin] in
            launchAtLogin?.toggle()
        }
        statusBar.onOpenLoginItemsSettings = { [weak launchAtLogin] in
            launchAtLogin?.openLoginItemsSettings()
        }
        statusBar.onRefresh = { [weak quotaProvider] in
            quotaProvider?.refreshNow()
        }
        statusBar.onMenuOpen = { [weak quotaProvider] in
            quotaProvider?.refreshIfOlder(than: 60)
        }
        statusBar.onQuit = {
            NSApp.terminate(nil)
        }

        quotaProvider.onChange = { [weak statusBar] quota in
            statusBar?.update(quota: quota)
        }

        // One-shot visibility reassertion on the next main-loop turn. This is
        // not polling; it simply lets the system menu bar finish its first layout.
        DispatchQueue.main.async { [weak statusBar] in
            statusBar?.ensureVisible()
        }

        quotaProvider.start()

        sessionWatcher.onActivity = { [weak quotaProvider] in
            quotaProvider?.refreshAfterActivity()
        }
        sessionWatcher.start()

        networkWatcher.onReachable = { [weak quotaProvider] in
            quotaProvider?.refreshIfOlder(than: 300)
        }
        networkWatcher.start()

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak quotaProvider] _ in
            quotaProvider?.refreshIfOlder(than: 300)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = nil

        sessionWatcher.stop()
        networkWatcher.stop()
        quotaProvider.stop()
        statusBar = nil
    }
}
