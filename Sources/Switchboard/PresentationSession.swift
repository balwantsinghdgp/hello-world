import Foundation

/// Presentation Mode: applies a set of levers when a session starts and puts
/// back exactly what it changed when the session ends.
final class PresentationSession: ObservableObject {
    static let shared = PresentationSession()

    @Published private(set) var isActive = false

    /// IDs of the levers Presentation Mode manages.
    @Published var managed: Set<String> {
        didSet { defaults.set(Array(managed), forKey: Keys.managed) }
    }
    @Published var hidesOtherApps: Bool {
        didSet { defaults.set(hidesOtherApps, forKey: Keys.hidesOtherApps) }
    }
    /// Start and end automatically when one of `watchedProcesses` is running.
    @Published var autoDetect: Bool {
        didSet {
            defaults.set(autoDetect, forKey: Keys.autoDetect)
            updateWatcher()
        }
    }
    /// Comma-separated process names that indicate the screen is being shared or recorded.
    @Published var watchedProcesses: String {
        didSet { defaults.set(watchedProcesses, forKey: Keys.watchedProcesses) }
    }

    private enum Keys {
        static let managed = "presentation.managed"
        static let hidesOtherApps = "presentation.hidesOtherApps"
        static let autoDetect = "presentation.autoDetect"
        static let watchedProcesses = "presentation.watchedProcesses"
        static let snapshot = "presentation.snapshot"
    }

    private let defaults = UserDefaults.standard
    private let store = LeverStore.shared
    private var startedAutomatically = false
    private var timer: Timer?
    private var missedPolls = 0
    private let pollQueue = DispatchQueue(label: "switchboard.watcher", qos: .utility)

    private init() {
        if let saved = defaults.stringArray(forKey: Keys.managed) {
            managed = Set(saved)
        } else {
            managed = Set(LeverCatalog.all.filter { $0.presentationDefault }.map(\.id))
        }
        hidesOtherApps = defaults.bool(forKey: Keys.hidesOtherApps)
        autoDetect = defaults.bool(forKey: Keys.autoDetect)
        // CptHost runs while Zoom is sharing a screen; screencaptureui is the
        // macOS screenshot / screen recording toolbar.
        watchedProcesses = defaults.string(forKey: Keys.watchedProcesses) ?? "CptHost, screencaptureui"

        restoreAfterCrash()
        updateWatcher()
    }

    func toggle() {
        if isActive { stop() } else { start(automatic: false) }
    }

    func start(automatic: Bool) {
        guard !isActive else { return }
        isActive = true
        startedAutomatically = automatic

        var desired: [String: Bool] = [:]
        for lever in store.levers where managed.contains(lever.id) {
            if let value = lever.presentationValue { desired[lever.id] = value }
        }
        store.apply(desired) { previous in
            // Saved to disk so a crash or quit mid-session can still be undone.
            self.defaults.set(previous, forKey: Keys.snapshot)
        }
        if hidesOtherApps { Actions.hideOtherApps() }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        // Queued behind any start still in flight, so its snapshot is saved first.
        store.apply([:]) { _ in self.restoreSnapshot() }
    }

    private func restoreSnapshot() {
        guard let snapshot = defaults.dictionary(forKey: Keys.snapshot) as? [String: Bool] else { return }
        defaults.removeObject(forKey: Keys.snapshot)
        store.apply(snapshot) { _ in }
    }

    /// If the app went away during a session, put the user's settings back on next launch.
    private func restoreAfterCrash() {
        restoreSnapshot()
    }

    // MARK: Share / record detection

    private func updateWatcher() {
        timer?.invalidate()
        timer = nil
        guard autoDetect else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let names = watchedProcesses
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        pollQueue.async {
            let capturing = names.contains { Shell.isRunning(processNamed: $0) }
            DispatchQueue.main.async { self.handle(capturing: capturing) }
        }
    }

    private func handle(capturing: Bool) {
        if capturing {
            missedPolls = 0
            if !isActive { start(automatic: true) }
        } else if isActive && startedAutomatically {
            // Two quiet polls in a row, so a brief process restart doesn't end the session.
            missedPolls += 1
            if missedPolls >= 2 { stop() }
        }
    }
}
