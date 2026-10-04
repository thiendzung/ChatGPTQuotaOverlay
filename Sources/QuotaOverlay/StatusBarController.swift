import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    var onRefresh: (() -> Void)?
    var onMenuOpen: (() -> Void)?
    var onToggleLaunchAtLogin: (() -> Void)?
    var onOpenLoginItemsSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var launchAtLoginStateProvider: (() -> LaunchAtLoginState)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var quota: Quota = .unavailable

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private lazy var dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter
    }()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        statusItem.length = NSStatusItem.variableLength
        statusItem.isVisible = true

        configureButton()
        rebuildMenu()
    }

    func ensureVisible() {
        statusItem.length = NSStatusItem.variableLength
        statusItem.isVisible = true
        configureButton()
    }

    func update(quota: Quota) {
        guard quota != self.quota else { return }
        self.quota = quota

        if let button = statusItem.button {
            button.title = quota.statusBarText
            button.toolTip = quota.freshness == .unavailable
                ? "Codex quota unavailable"
                : quota.hoverText
        }

        rebuildMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        button.title = quota.statusBarText
        button.toolTip = quota.freshness == .unavailable
            ? "Codex quota unavailable"
            : quota.hoverText
        button.image = nil
        button.imagePosition = .noImage
    }

    func menuWillOpen(_ menu: NSMenu) {
        onMenuOpen?()
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: "Codex quota", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        addQuotaRow(
            label: "5h",
            percent: quota.fiveHourPercent,
            resetsAt: quota.fiveHourResetsAt
        )
        addQuotaRow(
            label: "Week",
            percent: quota.weekPercent,
            resetsAt: quota.weekResetsAt
        )

        if let binding = quota.bindingLimit {
            let limiter = NSMenuItem(
                title: "Current limiter: \(binding.kind.displayName) \(binding.percent)%",
                action: nil,
                keyEquivalent: ""
            )
            limiter.isEnabled = false
            menu.addItem(limiter)
        }

        if quota.freshness == .stale {
            let stale = NSMenuItem(
                title: "Cached — waiting for fresh Codex usage data",
                action: nil,
                keyEquivalent: ""
            )
            stale.isEnabled = false
            menu.addItem(stale)
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(
            title: "Refresh quota now",
            action: #selector(refreshNow(_:)),
            keyEquivalent: ""
        )
        refresh.target = self
        menu.addItem(refresh)

        addLaunchAtLoginItem()

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit ChatGPT Quota",
            action: #selector(quitApp(_:)),
            keyEquivalent: ""
        )
        quit.target = self
        menu.addItem(quit)
    }

    private func addQuotaRow(label: String, percent: Int?, resetsAt: Date?) {
        let value = percent.map { "\($0)%" } ?? "not active"
        var title = "\(label)  \(value)"

        if let resetsAt {
            title += " · resets \(resetDescription(resetsAt))"
        }

        let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        row.isEnabled = false
        menu.addItem(row)
    }

    private func addLaunchAtLoginItem() {
        let state = launchAtLoginStateProvider?() ?? .unavailable

        switch state {
        case .off, .on:
            let item = NSMenuItem(
                title: "Start at Login",
                action: #selector(toggleLaunchAtLogin(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.state = state == .on ? .on : .off
            menu.addItem(item)

        case .requiresApproval:
            let item = NSMenuItem(
                title: "Start at Login: Needs approval…",
                action: #selector(openLoginItemsSettings(_:)),
                keyEquivalent: ""
            )
            item.target = self
            menu.addItem(item)

        case .unavailable:
            let item = NSMenuItem(
                title: "Start at Login: Unavailable",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func resetDescription(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return timeFormatter.string(from: date)
        }
        return dateTimeFormatter.string(from: date)
    }

    @objc private func refreshNow(_ sender: Any?) {
        onRefresh?()
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        onToggleLaunchAtLogin?()
        rebuildMenu()
    }

    @objc private func openLoginItemsSettings(_ sender: Any?) {
        onOpenLoginItemsSettings?()
    }

    @objc private func quitApp(_ sender: Any?) {
        onQuit?()
    }
}
