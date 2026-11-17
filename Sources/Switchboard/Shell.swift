import Foundation

/// Thin wrappers around the command-line tools the levers are built on.
enum Shell {
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return (-1, "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus, output)
    }

    @discardableResult
    static func appleScript(_ source: String) -> (status: Int32, output: String) {
        run("/usr/bin/osascript", ["-e", source])
    }

    static func killall(_ name: String) {
        run("/usr/bin/killall", [name])
    }

    static func isRunning(processNamed name: String) -> Bool {
        run("/usr/bin/pgrep", ["-x", name]).status == 0
    }
}

/// Reads and writes boolean preferences in any domain via `defaults`.
/// Use "-g" as the domain for the global domain.
enum Defaults {
    static func bool(_ domain: String, _ key: String, default fallback: Bool) -> Bool {
        let result = Shell.run("/usr/bin/defaults", ["read", domain, key])
        guard result.status == 0 else { return fallback }
        return ["1", "true", "yes"].contains(result.output.lowercased())
    }

    static func set(_ domain: String, _ key: String, _ value: Bool) {
        Shell.run("/usr/bin/defaults", ["write", domain, key, "-bool", value ? "true" : "false"])
    }
}
