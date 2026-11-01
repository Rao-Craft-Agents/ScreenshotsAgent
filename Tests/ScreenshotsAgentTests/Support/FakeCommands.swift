import Foundation
@testable import ScreenshotsAgent

/// A Mac's tools as a capture sees them, answered in memory: `simctl` with the fixture catalog, devices that boot and
/// switch appearance, an app whose screens are blank for the first looks after a launch and then show the page the
/// launch asked for, and an `xcodebuild` that leaves an app among its products. Every line it is given is kept.
final class FakeCommands: CommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [[String]] = []
    private var appearances: [String: String] = [:]
    private var pages: [String: String] = [:]
    private var looks: [String: Int] = [:]

    /// `simctl list --json`'s answer.
    var catalog = Fixture.catalog
    /// Devices that had status bar overrides before the call.
    var overridden: Set<String> = []
    /// How many looks after a launch are still the blank launch screen.
    var blankLooks = 2
    /// Whether the build fails.
    var buildFails = false
    /// Seconds the build takes: long enough to cancel a call in.
    var buildSeconds: Double = 0
    /// What `simctl launch` says the app's process is.
    var pid: Int32 = ProcessInfo.processInfo.processIdentifier
    /// The app's bundle identifier.
    var identifier = "com.example.cookbook"

    /// Every command line, in order.
    var lines: [[String]] { lock.withLock { kept } }

    /// The lines that ran `simctl <verb>`.
    func simctl(_ verb: String) -> [[String]] { lines.filter { $0.count > 2 && $0[1] == "simctl" && $0[2] == verb } }

    func run(_ command: Command) async throws -> CommandOutput {
        let arguments = command.arguments
        lock.withLock { kept.append(arguments) }
        if arguments.starts(with: ["xcrun", "xcodebuild"]) { return try await build(command) }
        guard arguments.count > 2, arguments[1] == "simctl" else { return CommandOutput() }
        let verb = arguments[2]
        switch verb {
        case "list":
            return CommandOutput(output: Data(catalog.utf8))
        case "ui" where arguments.count == 5:
            return CommandOutput(output: Data((appearance(arguments[3]) + "\n").utf8))
        case "ui":
            lock.withLock { appearances[arguments[3]] = arguments[5] }
            return CommandOutput()
        case "status_bar" where arguments[4] == "list":
            let listing = "Current Status Bar Overrides:\n=============================\n" + (overridden.contains(arguments[3]) ? "Time: 10:10\n" : "")
            return CommandOutput(output: Data(listing.utf8))
        case "launch":
            let udid = arguments[4]
            let page = arguments.firstIndex(of: "-destination").map { arguments[$0 + 1] } ?? "launch"
            lock.withLock { pages[udid] = page; looks[udid] = 0 }
            return CommandOutput(output: Data("\(arguments[5]): \(pid)\n".utf8))
        case "io":
            let udid = arguments[3]
            let (look, page) = lock.withLock { () -> (Int, String?) in
                let look = looks[udid, default: 0]
                looks[udid] = look + 1
                return (look, pages[udid])
            }
            let dark = appearance(udid) == "dark"
            // An iPad's screen is three to four, an iPhone's taller. Before any launch it shows its home screen.
            let width = udid.hasPrefix("PAD") ? 195 : 120
            let frame = page != nil && look < blankLooks ? Frames.screen(dark: dark, width: width) : Frames.screen(page: page ?? "home", dark: dark, width: width)
            try frame.write(to: URL(fileURLWithPath: arguments.last!))
            return CommandOutput()
        default:
            return CommandOutput()
        }
    }

    /// The appearance a device is in now: light until set.
    func appearance(_ udid: String) -> String {
        lock.withLock { appearances[udid] ?? "light" }
    }

    private func build(_ command: Command) async throws -> CommandOutput {
        if buildSeconds > 0 { try await Task.sleep(nanoseconds: UInt64(buildSeconds * 1_000_000_000)) }
        let arguments = command.arguments
        if buildFails {
            if let log = command.log {
                try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
                try "Compiling\n/app/Components/RecipeList/RecipeList+View.swift:12:5: error: cannot find 'Recipe' in scope\n** BUILD FAILED **\n"
                    .write(to: log, atomically: true, encoding: .utf8)
            }
            return CommandOutput(status: 65)
        }
        let derived = URL(fileURLWithPath: arguments[arguments.firstIndex(of: "-derivedDataPath")! + 1])
        let configuration = arguments[arguments.firstIndex(of: "-configuration")! + 1]
        let mac = arguments.contains("platform=macOS")
        let app = derived.appendingPathComponent("Build/Products/\(configuration)\(mac ? "" : "-iphonesimulator")/Cookbook.app")
        let plist = mac ? app.appendingPathComponent("Contents/Info.plist") : app.appendingPathComponent("Info.plist")
        try FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": identifier, "CFBundleExecutable": "Cookbook"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: plist)
        if let log = command.log {
            try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "** BUILD SUCCEEDED **\n".write(to: log, atomically: true, encoding: .utf8)
        }
        return CommandOutput()
    }
}
