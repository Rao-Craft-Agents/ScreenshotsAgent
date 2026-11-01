//  WHAT: The devices a call captures on, from what it asks: simulators found in the catalog (each once, in the order
//        asked), whether the Mac app is wanted, and every request that names nothing installed.
//  PIN:  ASKED IS REFUSED, DEFAULT IS NOTED. A device the call names that is not installed refuses the call (it
//        meant that device); a default family with none installed is left out with a note.

import Foundation

struct DevicePick: Sendable, Equatable {
    /// The simulators, in the order asked.
    var simulators: [SimulatorDevice] = []
    /// Whether the Mac app is captured too.
    var mac = false
    /// Why a request named nothing: refusals.
    var problems: [String] = []
    /// A default left out, and why.
    var notes: [String] = []

    static func pick(_ asked: [String]?, from catalog: SimulatorCatalog) -> DevicePick {
        let entries = (asked ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let requests = entries.isEmpty ? DeviceRequest.standard : entries.map(DeviceRequest.parse)
        var pick = DevicePick()
        for request in requests {
            switch request {
            case .mac:
                pick.mac = true
            case .newest(let family):
                if let device = catalog.newest(family) {
                    if !pick.simulators.contains(device) { pick.simulators.append(device) }
                } else if entries.isEmpty {
                    pick.notes.append("no \(family) simulator is installed, so none was captured on one")
                } else {
                    pick.problems.append("no \(family) simulator is installed: add one in Xcode (Settings › Components) or with `xcrun simctl create`")
                }
            case .named(let name):
                if let device = catalog.named(name) {
                    if !pick.simulators.contains(device) { pick.simulators.append(device) }
                } else {
                    let offered = catalog.names()
                    let instead = offered.isEmpty ? "none is installed" : "this Mac has \(offered.joined(separator: ", "))"
                    pick.problems.append("no simulator is named `\(name)`: \(instead) (or say `iPhone` or `iPad` for the newest)")
                }
            }
        }
        if pick.simulators.isEmpty, !pick.mac, pick.problems.isEmpty {
            pick.problems.append("no iPhone or iPad simulator is installed: add one in Xcode (Settings › Components)")
        }
        return pick
    }
}
