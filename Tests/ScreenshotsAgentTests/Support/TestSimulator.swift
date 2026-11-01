import Foundation

/// A simulator of the test's own: created shut down, on the newest iOS runtime, as the newest iPhone type it
/// supports, and deleted when the test is done. A person's simulators are never used.
struct TestSimulator {
    let udid: String
    let name: String

    static func create(named name: String) throws -> TestSimulator {
        let listing = try run(["xcrun", "simctl", "list", "runtimes", "available", "--json"])
        let runtimes = (try JSONSerialization.jsonObject(with: Data(listing.utf8)) as? [String: Any])?["runtimes"] as? [[String: Any]] ?? []
        let iOS = runtimes.filter { ($0["platform"] as? String) == "iOS" }.sorted {
            ($0["version"] as? String ?? "").compare($1["version"] as? String ?? "", options: .numeric) == .orderedDescending
        }
        guard let runtime = iOS.first, let runtimeID = runtime["identifier"] as? String,
              let type = (runtime["supportedDeviceTypes"] as? [[String: Any]])?.first(where: { ($0["productFamily"] as? String) == "iPhone" }),
              let typeID = type["identifier"] as? String else { throw Failure.noRuntime }
        let udid = try run(["xcrun", "simctl", "create", name, typeID, runtimeID]).trimmingCharacters(in: .whitespacesAndNewlines)
        return TestSimulator(udid: udid, name: name)
    }

    /// Its state as `simctl` says it: `Booted`, `Shutdown`.
    func state() throws -> String {
        let listing = try Self.run(["xcrun", "simctl", "list", "devices", "--json"])
        let devices = (try JSONSerialization.jsonObject(with: Data(listing.utf8)) as? [String: Any])?["devices"] as? [String: [[String: Any]]] ?? [:]
        return devices.values.joined().first { ($0["udid"] as? String) == udid }?["state"] as? String ?? "gone"
    }

    /// Shuts it down if it runs, and deletes it.
    func delete() {
        _ = try? Self.run(["xcrun", "simctl", "shutdown", udid])
        _ = try? Self.run(["xcrun", "simctl", "delete", udid])
    }

    @discardableResult
    static func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    enum Failure: Error {
        /// No iOS runtime with an iPhone is installed.
        case noRuntime
    }
}
