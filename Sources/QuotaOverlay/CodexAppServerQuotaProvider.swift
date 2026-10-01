import Foundation

/// Reads real ChatGPT/Codex rolling quotas through the local Codex App Server.
///
/// Security properties:
/// - only a Codex executable inside a valid ChatGPT.app is accepted
/// - no cookies, auth.json, API keys, account IDs, or responses are persisted
/// - child-process environment is allow-listed instead of inherited wholesale
/// - this client sends only initialize + account/rateLimits/read
/// - protocol buffers and pending requests are bounded
final class CodexAppServerQuotaProvider: QuotaProvider {
    var onChange: ((Quota) -> Void)?

    private let queue = DispatchQueue(label: "built-by-ThienDzung.codex-app-server")
    private let queueKey = DispatchSpecificKey<Void>()
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var readBuffer = Data()
    private var initialized = false
    private var refreshAfterInitialize = false
    private var nextRequestID = 1
    private var pending: [Int: ([String: Any]) -> Void] = [:]
    private var requestTimeouts: [Int: DispatchWorkItem] = [:]
    private var lastRefreshAt: Date?
    private var lastRequestAt: Date?
    private var activityWorkItem: DispatchWorkItem?
    private var staleWorkItem: DispatchWorkItem?
    private var rateLimitRequestInFlight = false
    private var isStopping = false
    private var suppressNextTerminationStale = false
    private var lastCodexSnapshot: [String: Any]?
    private var lastQuota: Quota?

    private let minimumRequestSpacing: TimeInterval = 10
    private let requestTimeout: TimeInterval = 8
    private let maximumBufferBytes = 1_048_576
    private let maximumPendingRequests = 4
    private let staleAfter: TimeInterval = 15 * 60

    init() {
        queue.setSpecific(key: queueKey, value: ())
    }

    func start() {
        isStopping = false
        DispatchQueue.main.async { [weak self] in self?.onChange?(.unavailable) }
        queue.async { [weak self] in
            self?.ensureServerAndRefresh()
        }
    }

    func stop() {
        let cleanup = { [self] in
            isStopping = true
            activityWorkItem?.cancel()
            activityWorkItem = nil
            staleWorkItem?.cancel()
            staleWorkItem = nil
            cancelPendingRequests()
            initialized = false
            refreshAfterInitialize = false
            rateLimitRequestInFlight = false

            outputPipe?.fileHandleForReading.readabilityHandler = nil
            errorPipe?.fileHandleForReading.readabilityHandler = nil
            try? inputPipe?.fileHandleForWriting.close()
            process?.terminate()

            process = nil
            inputPipe = nil
            outputPipe = nil
            errorPipe = nil
            readBuffer.removeAll(keepingCapacity: false)
        }

        if DispatchQueue.getSpecific(key: queueKey) != nil {
            cleanup()
        } else {
            queue.sync(execute: cleanup)
        }
    }

    deinit { stop() }

    func refreshNow() {
        queue.async { [weak self] in
            self?.ensureServerAndRefresh(ignoreAge: true)
        }
    }

    func refreshIfOlder(than age: TimeInterval) {
        queue.async { [weak self] in
            guard let self else { return }

            // A dead/uninitialized source is retried on the next real event even
            // if cached quota values are still younger than the requested age.
            if self.process == nil || self.process?.isRunning != true || !self.initialized {
                self.ensureServerAndRefresh(ignoreAge: true)
                return
            }

            if let lastRefreshAt, Date().timeIntervalSince(lastRefreshAt) < age {
                return
            }
            self.ensureServerAndRefresh()
        }
    }

    /// One-shot debounce after a real Codex session filesystem event.
    /// This is event-driven; there is no recurring timer loop.
    func refreshAfterActivity() {
        queue.async { [weak self] in
            guard let self else { return }
            self.activityWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.ensureServerAndRefresh()
            }
            self.activityWorkItem = item
            self.queue.asyncAfter(deadline: .now() + 2.0, execute: item)
        }
    }

    private func ensureServerAndRefresh(ignoreAge: Bool = false) {
        if process == nil || process?.isRunning != true {
            startServer()
            refreshAfterInitialize = true
            return
        }

        guard initialized else {
            refreshAfterInitialize = true
            return
        }

        if !ignoreAge, let lastRequestAt,
           Date().timeIntervalSince(lastRequestAt) < minimumRequestSpacing {
            return
        }

        requestRateLimits()
    }

    private func startServer() {
        guard let executable = CodexBinaryResolver.resolve() else {
            markSourceUnavailable()
            return
        }

        isStopping = false
        suppressNextTerminationStale = false
        lastRequestAt = nil
        readBuffer.removeAll(keepingCapacity: false)

        let child = Process()
        let input = Pipe()
        let output = Pipe()
        let stderrPipe = Pipe()

        child.executableURL = executable
        child.arguments = ["app-server", "--stdio"]
        child.environment = safeChildEnvironment()
        child.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        child.standardInput = input
        child.standardOutput = output
        child.standardError = stderrPipe

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { [weak self] in self?.consume(data) }
        }

        // Drain stderr so the child cannot block. Nothing is logged or persisted.
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }

        child.terminationHandler = { [weak self] _ in
            self?.queue.async { [weak self] in
                guard let self else { return }
                self.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self.errorPipe?.fileHandleForReading.readabilityHandler = nil
                self.process = nil
                self.inputPipe = nil
                self.outputPipe = nil
                self.errorPipe = nil
                self.initialized = false
                self.rateLimitRequestInFlight = false
                self.cancelPendingRequests()
                if self.suppressNextTerminationStale {
                    self.suppressNextTerminationStale = false
                } else if !self.isStopping {
                    self.markSourceUnavailable()
                }
            }
        }

        do {
            try child.run()
            process = child
            inputPipe = input
            outputPipe = output
            errorPipe = stderrPipe
            sendInitialize()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            markSourceUnavailable()
        }
    }

    private func sendInitialize() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.3.2"
        sendRequest(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "chatgpt-quota-overlay",
                    "title": "ChatGPT Quota Overlay — built by ThienDzung",
                    "version": version
                ],
                "capabilities": [
                    "experimentalApi": false,
                    "requestAttestation": false
                ]
            ]
        ) { [weak self] response in
            guard let self else { return }
            guard response["error"] == nil else {
                self.handleServerFailure()
                return
            }

            self.initialized = true
            self.sendNotification(method: "initialized", params: [:])
            if self.refreshAfterInitialize {
                self.refreshAfterInitialize = false
                self.requestRateLimits()
            }
        }
    }

    private func requestRateLimits() {
        guard !rateLimitRequestInFlight else { return }

        let now = Date()
        if let lastRequestAt, now.timeIntervalSince(lastRequestAt) < minimumRequestSpacing {
            return
        }

        lastRequestAt = now
        rateLimitRequestInFlight = true

        sendRequest(method: "account/rateLimits/read", params: nil) { [weak self] response in
            guard let self else { return }
            self.rateLimitRequestInFlight = false

            guard response["error"] == nil,
                  let result = response["result"] as? [String: Any],
                  let snapshot = QuotaParser.codexSnapshot(fromRateLimitsResponse: result),
                  let quota = QuotaParser.quota(fromSnapshot: snapshot) else {
                self.handleServerFailure()
                return
            }

            self.acceptFreshQuota(quota, snapshot: snapshot)
        }
    }

    private func consume(_ data: Data) {
        guard readBuffer.count + data.count <= maximumBufferBytes else {
            handleProtocolFailure()
            return
        }

        readBuffer.append(data)

        while let newlineIndex = readBuffer.firstIndex(of: 0x0A) {
            let line = readBuffer[..<newlineIndex]
            readBuffer.removeSubrange(...newlineIndex)

            guard line.count <= maximumBufferBytes,
                  !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: Data(line)),
                  let message = object as? [String: Any] else {
                continue
            }
            handle(message)
        }
    }

    private func handle(_ message: [String: Any]) {
        if let id = Self.integerID(message["id"]), let callback = pending.removeValue(forKey: id) {
            requestTimeouts.removeValue(forKey: id)?.cancel()
            callback(message)
            return
        }

        guard let method = message["method"] as? String,
              method == "account/rateLimits/updated",
              let params = message["params"] as? [String: Any],
              let update = params["rateLimits"] as? [String: Any] else {
            return
        }

        if let limitID = update["limitId"] as? String, limitID != "codex" {
            return
        }

        let merged = QuotaParser.mergeSnapshot(base: lastCodexSnapshot, update: update)
        guard let quota = QuotaParser.quota(fromSnapshot: merged) else { return }

        acceptFreshQuota(quota, snapshot: merged)
    }

    private func sendRequest(
        method: String,
        params: [String: Any]?,
        callback: @escaping ([String: Any]) -> Void
    ) {
        guard pending.count < maximumPendingRequests else { return }
        guard method == "initialize" || method == "account/rateLimits/read" else { return }

        let id = nextRequestID
        nextRequestID += 1
        pending[id] = callback

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, let callback = self.pending.removeValue(forKey: id) else { return }
            self.requestTimeouts.removeValue(forKey: id)
            callback(["error": ["message": "request timeout"]])
        }
        requestTimeouts[id] = timeout
        queue.asyncAfter(deadline: .now() + requestTimeout, execute: timeout)

        var message: [String: Any] = ["method": method, "id": id]
        if let params { message["params"] = params }
        send(message)
    }

    private func sendNotification(method: String, params: [String: Any]) {
        guard method == "initialized" else { return }
        send(["method": method, "params": params])
    }

    private func send(_ object: [String: Any]) {
        guard let handle = inputPipe?.fileHandleForWriting,
              var data = try? JSONSerialization.data(withJSONObject: object) else { return }
        data.append(0x0A)

        do {
            try handle.write(contentsOf: data)
        } catch {
            handleServerFailure()
        }
    }

    private func handleProtocolFailure() {
        readBuffer.removeAll(keepingCapacity: false)
        handleServerFailure()
    }

    /// Marks cached data stale and tears down the current App Server. Recovery is
    /// intentionally event-driven: the next hover/activation/session/network/wake
    /// event resolves the bundled Codex binary again and starts a fresh server.
    private func handleServerFailure() {
        initialized = false
        rateLimitRequestInFlight = false
        cancelPendingRequests()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        try? inputPipe?.fileHandleForWriting.close()
        if process?.isRunning == true {
            suppressNextTerminationStale = true
            process?.terminate()
        }
        markSourceUnavailable()
    }

    private func cancelPendingRequests() {
        requestTimeouts.values.forEach { $0.cancel() }
        requestTimeouts.removeAll()
        pending.removeAll()
    }

    private func emit(_ quota: Quota) {
        DispatchQueue.main.async { [weak self] in self?.onChange?(quota) }
    }

    private func acceptFreshQuota(_ quota: Quota, snapshot: [String: Any]) {
        let fresh = Quota(
            fiveHourPercent: quota.fiveHourPercent,
            weekPercent: quota.weekPercent,
            freshness: .fresh
        )
        lastCodexSnapshot = snapshot
        lastRefreshAt = Date()
        lastQuota = fresh
        scheduleStaleTransition(from: lastRefreshAt!)
        emit(fresh)
    }

    private func markSourceUnavailable() {
        staleWorkItem?.cancel()
        staleWorkItem = nil

        if let lastQuota, lastQuota.hasValues {
            let stale = lastQuota.markedStale()
            self.lastQuota = stale
            emit(stale)
        } else {
            emit(.unavailable)
        }
    }

    private func scheduleStaleTransition(from refreshDate: Date) {
        staleWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self,
                  self.lastRefreshAt == refreshDate,
                  let lastQuota = self.lastQuota,
                  lastQuota.hasValues else {
                return
            }
            let stale = lastQuota.markedStale()
            self.lastQuota = stale
            self.emit(stale)
        }
        staleWorkItem = item
        queue.asyncAfter(deadline: .now() + staleAfter, execute: item)
    }

    private func safeChildEnvironment() -> [String: String] {
        let source = ProcessInfo.processInfo.environment
        let allowed = [
            "HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "PATH", "SHELL",
            "CODEX_HOME",
            "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
            "http_proxy", "https_proxy", "all_proxy", "no_proxy",
            "SSL_CERT_FILE", "SSL_CERT_DIR"
        ]

        var result: [String: String] = [:]
        for key in allowed {
            if let value = source[key] { result[key] = value }
        }
        if result["PATH"] == nil {
            result["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
        }
        return result
    }

    private static func integerID(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}
