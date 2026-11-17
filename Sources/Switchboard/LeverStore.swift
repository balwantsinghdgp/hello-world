import Foundation

/// Owns the lever list and their current on/off states. All published state is
/// mutated on the main thread; the system calls run on a serial background queue.
final class LeverStore: ObservableObject {
    static let shared = LeverStore()

    let levers = LeverCatalog.all
    @Published private(set) var states: [String: Bool] = [:]

    private let queue = DispatchQueue(label: "switchboard.levers", qos: .userInitiated)

    func lever(_ id: String) -> Lever? {
        levers.first { $0.id == id }
    }

    func isOn(_ id: String) -> Bool {
        states[id] ?? false
    }

    /// Re-reads every toggle from the system.
    func refresh() {
        queue.async { [levers] in
            var fresh: [String: Bool] = [:]
            for lever in levers {
                if case .toggle(let read, _) = lever.kind {
                    fresh[lever.id] = read()
                }
            }
            DispatchQueue.main.async { self.states = fresh }
        }
    }

    /// Flips a toggle, or runs an action.
    func trigger(_ lever: Lever) {
        switch lever.kind {
        case .toggle:
            let target = !isOn(lever.id)
            states[lever.id] = target // optimistic; corrected by the read-back
            apply([lever.id: target]) { _ in }
        case .action(let perform):
            queue.async { perform() }
        }
    }

    /// Sets several toggles to the given values. `done` receives the previous
    /// value of each lever that actually had to change.
    func apply(_ desired: [String: Bool], done: @escaping ([String: Bool]) -> Void) {
        queue.async { [levers] in
            var previous: [String: Bool] = [:]
            var readBack: [String: Bool] = [:]
            for lever in levers {
                guard let target = desired[lever.id],
                      case .toggle(let read, let write) = lever.kind
                else { continue }
                let current = read()
                if current != target {
                    previous[lever.id] = current
                    write(target)
                }
                readBack[lever.id] = read()
            }
            DispatchQueue.main.async {
                self.states.merge(readBack) { _, new in new }
                done(previous)
            }
        }
    }
}
