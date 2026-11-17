import AppKit
import Foundation

enum LeverCategory: String, CaseIterable {
    case appearance = "Appearance"
    case desktop = "Desktop & Dock"
    case finder = "Finder"
    case system = "System"
    case screenshots = "Screenshots"
    case actions = "Actions"
}

/// One switch or one-shot action. `read`/`write`/`perform` run off the main thread.
struct Lever: Identifiable {
    enum Kind {
        case toggle(read: () -> Bool, write: (Bool) -> Void)
        case action(perform: () -> Void)
    }

    let id: String
    let title: String
    let symbol: String
    let category: LeverCategory
    let kind: Kind
    /// The value this lever should take while presenting, or nil if it is not
    /// something Presentation Mode can manage.
    var presentationValue: Bool? = nil
    /// Whether Presentation Mode manages this lever before the user customises it.
    var presentationDefault = false

    var isToggle: Bool {
        if case .toggle = kind { return true }
        return false
    }
}

enum LeverCatalog {
    static let all: [Lever] = [
        // MARK: Appearance
        Lever(
            id: "darkMode", title: "Dark Mode", symbol: "moon.fill", category: .appearance,
            kind: .toggle(
                read: { Shell.run("/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"]).output == "Dark" },
                write: { on in
                    Shell.appleScript("tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
                }
            )
        ),
        Lever(
            id: "hideMenuBar", title: "Auto-Hide Menu Bar", symbol: "menubar.rectangle", category: .appearance,
            kind: .toggle(
                read: { Defaults.bool("-g", "_HIHideMenuBar", default: false) },
                write: { on in
                    Shell.appleScript("tell application \"System Events\" to tell dock preferences to set autohide menu bar to \(on)")
                }
            ),
            presentationValue: true
        ),
        Lever(
            id: "stageManager", title: "Stage Manager", symbol: "rectangle.stack", category: .appearance,
            kind: defaultsToggle("com.apple.WindowManager", "GloballyEnabled", fallback: false)
        ),

        // MARK: Desktop & Dock
        Lever(
            id: "hideDesktopIcons", title: "Hide Desktop Icons", symbol: "eye.slash", category: .desktop,
            kind: defaultsToggle("com.apple.finder", "CreateDesktop", onValue: false, fallback: true, restart: "Finder"),
            presentationValue: true, presentationDefault: true
        ),
        Lever(
            id: "hideWidgets", title: "Hide Desktop Widgets", symbol: "square.grid.2x2", category: .desktop,
            kind: defaultsToggle("com.apple.WindowManager", "StandardHideWidgets", fallback: false),
            presentationValue: true, presentationDefault: true
        ),
        Lever(
            id: "hideDock", title: "Auto-Hide Dock", symbol: "dock.rectangle", category: .desktop,
            kind: .toggle(
                read: { Defaults.bool("com.apple.dock", "autohide", default: false) },
                write: { on in
                    Shell.appleScript("tell application \"System Events\" to tell dock preferences to set autohide to \(on)")
                }
            ),
            presentationValue: true, presentationDefault: true
        ),
        Lever(
            id: "dockRecents", title: "Recent Apps in Dock", symbol: "clock.arrow.circlepath", category: .desktop,
            kind: defaultsToggle("com.apple.dock", "show-recents", fallback: true, restart: "Dock"),
            presentationValue: false
        ),
        Lever(
            id: "dockMagnification", title: "Dock Magnification", symbol: "plus.magnifyingglass", category: .desktop,
            kind: defaultsToggle("com.apple.dock", "magnification", fallback: false, restart: "Dock")
        ),
        Lever(
            id: "clickToShowDesktop", title: "Click Wallpaper to Show Desktop", symbol: "macwindow", category: .desktop,
            kind: defaultsToggle("com.apple.WindowManager", "EnableStandardClickToShowDesktop", fallback: true),
            presentationValue: false
        ),

        // MARK: Finder
        Lever(
            id: "hiddenFiles", title: "Show Hidden Files", symbol: "doc", category: .finder,
            kind: defaultsToggle("com.apple.finder", "AppleShowAllFiles", fallback: false, restart: "Finder"),
            presentationValue: false
        ),
        Lever(
            id: "fileExtensions", title: "Show File Extensions", symbol: "textformat", category: .finder,
            kind: defaultsToggle("-g", "AppleShowAllExtensions", fallback: false, restart: "Finder")
        ),
        Lever(
            id: "pathBar", title: "Finder Path Bar", symbol: "folder", category: .finder,
            kind: defaultsToggle("com.apple.finder", "ShowPathbar", fallback: false, restart: "Finder")
        ),

        // MARK: System
        Lever(
            id: "keepAwake", title: "Keep Awake", symbol: "cup.and.saucer.fill", category: .system,
            kind: .toggle(
                read: { KeepAwake.shared.isOn },
                write: { KeepAwake.shared.set($0) }
            ),
            presentationValue: true, presentationDefault: true
        ),
        Lever(
            id: "doNotDisturb", title: "Do Not Disturb", symbol: "moon.circle.fill", category: .system,
            kind: .toggle(
                read: { DoNotDisturb.isOn },
                write: { DoNotDisturb.set($0) }
            ),
            presentationValue: true
        ),
        Lever(
            id: "mute", title: "Mute Sound", symbol: "speaker.slash.fill", category: .system,
            kind: .toggle(
                read: { Shell.appleScript("output muted of (get volume settings)").output == "true" },
                write: { on in Shell.appleScript("set volume output muted \(on)") }
            ),
            presentationValue: true
        ),
        Lever(
            id: "wifi", title: "Wi-Fi", symbol: "wifi", category: .system,
            kind: .toggle(
                read: { WiFi.isOn },
                write: { WiFi.set($0) }
            )
        ),

        // MARK: Screenshots
        Lever(
            id: "screenshotShadow", title: "Window Shadow in Screenshots", symbol: "camera.viewfinder", category: .screenshots,
            kind: defaultsToggle("com.apple.screencapture", "disable-shadow", onValue: false, fallback: false, restart: "SystemUIServer")
        ),
        Lever(
            id: "screenshotThumbnail", title: "Screenshot Preview Thumbnail", symbol: "photo", category: .screenshots,
            kind: defaultsToggle("com.apple.screencapture", "show-thumbnail", fallback: true, restart: "SystemUIServer")
        ),

        // MARK: Actions
        Lever(
            id: "hideOtherApps", title: "Hide Other Apps", symbol: "rectangle.on.rectangle", category: .actions,
            kind: .action(perform: { Actions.hideOtherApps() })
        ),
        Lever(
            id: "sleepDisplay", title: "Sleep Display", symbol: "display", category: .actions,
            kind: .action(perform: { Shell.run("/usr/bin/pmset", ["displaysleepnow"]) })
        ),
        Lever(
            id: "screenSaver", title: "Start Screen Saver", symbol: "sparkles", category: .actions,
            kind: .action(perform: { Shell.run("/usr/bin/open", ["-a", "ScreenSaverEngine"]) })
        ),
        Lever(
            id: "emptyTrash", title: "Empty Trash", symbol: "trash", category: .actions,
            kind: .action(perform: { Shell.appleScript("tell application \"Finder\" to empty trash") })
        ),
    ]

    /// A toggle backed by a boolean preference. `onValue` is the stored value that
    /// means the lever is on; `fallback` is what macOS assumes when the key is unset.
    private static func defaultsToggle(
        _ domain: String, _ key: String,
        onValue: Bool = true, fallback: Bool, restart: String? = nil
    ) -> Lever.Kind {
        .toggle(
            read: { Defaults.bool(domain, key, default: fallback) == onValue },
            write: { on in
                Defaults.set(domain, key, on == onValue)
                if let restart { Shell.killall(restart) }
            }
        )
    }
}

// MARK: - Helpers behind individual levers

/// macOS has no public API for Focus, so this drives two user-made Shortcuts
/// (see README) and remembers the state itself.
enum DoNotDisturb {
    static let onShortcut = "Switchboard DND On"
    static let offShortcut = "Switchboard DND Off"
    private static let key = "doNotDisturb.on"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: key) }

    static func set(_ on: Bool) {
        let result = Shell.run("/usr/bin/shortcuts", ["run", on ? onShortcut : offShortcut])
        if result.status == 0 {
            UserDefaults.standard.set(on, forKey: key)
        }
    }
}

enum WiFi {
    private static let device: String? = {
        let lines = Shell.run("/usr/sbin/networksetup", ["-listallhardwareports"]).output
            .components(separatedBy: .newlines)
        guard let port = lines.firstIndex(where: { $0.contains("Hardware Port: Wi-Fi") }),
              port + 1 < lines.count,
              lines[port + 1].hasPrefix("Device: ")
        else { return nil }
        return String(lines[port + 1].dropFirst("Device: ".count))
    }()

    static var isOn: Bool {
        guard let device else { return false }
        return Shell.run("/usr/sbin/networksetup", ["-getairportpower", device]).output.hasSuffix("On")
    }

    static func set(_ on: Bool) {
        guard let device else { return }
        Shell.run("/usr/sbin/networksetup", ["-setairportpower", device, on ? "on" : "off"])
    }
}

enum Actions {
    /// Hides every regular app except the one currently in front.
    static func hideOtherApps() {
        DispatchQueue.main.async {
            let front = NSWorkspace.shared.menuBarOwningApplication
            for app in NSWorkspace.shared.runningApplications
            where app.activationPolicy == .regular
                && app != front
                && app != NSRunningApplication.current {
                app.hide()
            }
        }
    }
}
