//  WHAT: The iPhone and iPad simulators installed on this Mac, read from one `xcrun simctl list --json`: each device
//        with its type's family and model, its runtime's version, and whether it is booted.
//  PIN:  ONLY WHAT CAN RUN. A device or runtime `simctl` marks unavailable is left out, as is any that is not iOS.

import Foundation

struct SimulatorCatalog: Sendable, Equatable {
    /// Every available iPhone and iPad, newest first.
    var devices: [SimulatorDevice]

    /// The catalog `simctl list --json` describes.
    static func decode(_ data: Data) throws -> SimulatorCatalog {
        let list = try JSONDecoder().decode(Listing.self, from: data)
        var types: [String: Listing.DeviceType] = [:]
        for type in list.devicetypes ?? [] { types[type.identifier] = type }
        var runtimes: [String: Listing.Runtime] = [:]
        for runtime in list.runtimes ?? [] { runtimes[runtime.identifier] = runtime }
        var devices: [SimulatorDevice] = []
        for (runtimeID, entries) in list.devices ?? [:] {
            guard let runtime = runtimes[runtimeID], runtime.isAvailable ?? true, (runtime.platform ?? "iOS") == "iOS" else { continue }
            for entry in entries where entry.isAvailable ?? true {
                guard let typeID = entry.deviceTypeIdentifier, let type = types[typeID] else { continue }
                let family = type.productFamily ?? (type.name.hasPrefix("iPad") ? "iPad" : type.name.hasPrefix("iPhone") ? "iPhone" : "")
                guard family == "iPhone" || family == "iPad" else { continue }
                devices.append(SimulatorDevice(udid: entry.udid, name: entry.name, type: type.name, family: family,
                                               model: numbers(type.modelIdentifier ?? ""), runtime: runtime.name ?? "iOS \(runtime.version)",
                                               runtimeVersion: numbers(runtime.version), booted: entry.state == "Booted"))
            }
        }
        devices.sort { $0.isNewer(than: $1) }
        return SimulatorCatalog(devices: devices)
    }

    /// The newest device of `family` (`iPhone`, `iPad`).
    func newest(_ family: String) -> SimulatorDevice? {
        devices.first { $0.family.caseInsensitiveCompare(family) == .orderedSame }
    }

    /// The device named `name` (any case) or with that UDID; of several, the newest.
    func named(_ name: String) -> SimulatorDevice? {
        devices.first { $0.udid.caseInsensitiveCompare(name) == .orderedSame }
            ?? devices.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Up to `limit` names, newest first and each once: what a refusal offers instead.
    func names(limit: Int = 8) -> [String] {
        var seen: Set<String> = []
        return devices.map(\.name).filter { seen.insert($0).inserted }.prefix(limit).map { $0 }
    }

    /// `iPhone19,2` → [19, 2]; `27.0.1` → [27, 0, 1].
    static func numbers(_ text: String) -> [Int] {
        text.split { !$0.isNumber }.compactMap { Int($0) }
    }

    /// The parts of `simctl list --json` the catalog reads.
    private struct Listing: Decodable {
        struct DeviceType: Decodable {
            var identifier: String
            var name: String
            var productFamily: String?
            var modelIdentifier: String?
        }
        struct Runtime: Decodable {
            var identifier: String
            var version: String
            var name: String?
            var platform: String?
            var isAvailable: Bool?
        }
        struct Device: Decodable {
            var udid: String
            var name: String
            var state: String?
            var isAvailable: Bool?
            var deviceTypeIdentifier: String?
        }
        var devicetypes: [DeviceType]?
        var runtimes: [Runtime]?
        var devices: [String: [Device]]?
    }
}
