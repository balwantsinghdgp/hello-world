import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon, even when run unbundled via `swift run`.
        NSApp.setActivationPolicy(.accessory)
        LeverStore.shared.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeepAwake.shared.set(false)
    }
}

@main
struct SwitchboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var session = PresentationSession.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(LeverStore.shared)
                .environmentObject(session)
        } label: {
            Image(systemName: session.isActive ? "record.circle.fill" : "switch.2")
        }
        .menuBarExtraStyle(.window)
    }
}
