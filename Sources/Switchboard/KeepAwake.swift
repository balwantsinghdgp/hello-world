import Foundation
import IOKit.pwr_mgt

/// Holds a power assertion that stops the display and system from idle-sleeping.
final class KeepAwake {
    static let shared = KeepAwake()

    private let lock = NSLock()
    private var assertionID: IOPMAssertionID = 0
    private var active = false

    var isOn: Bool {
        lock.lock(); defer { lock.unlock() }
        return active
    }

    func set(_ on: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard on != active else { return }
        if on {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Switchboard Keep Awake" as CFString,
                &assertionID
            )
            active = (result == kIOReturnSuccess)
        } else {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
            active = false
        }
    }
}
