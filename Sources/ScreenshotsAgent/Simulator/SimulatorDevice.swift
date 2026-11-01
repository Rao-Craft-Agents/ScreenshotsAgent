import Foundation

/// A simulator installed on this Mac, as `simctl list` describes it.
struct SimulatorDevice: Sendable, Equatable, Hashable {
    var udid: String
    /// Its name: `iPhone 18 Pro`, or a name a person gave it.
    var name: String
    /// What it is: the device type's name, `iPhone 18 Pro`.
    var type: String
    /// `iPhone` or `iPad`.
    var family: String
    /// Its model's numbers, `iPhone19,2` read as [19, 2]: the first is the generation.
    var model: [Int]
    /// The runtime it runs: `iOS 27.0`.
    var runtime: String
    /// The runtime's version, `27.0` read as [27, 0].
    var runtimeVersion: [Int]
    /// Whether it is booted now.
    var booted: Bool

    /// Whether it is the newer of two to capture on: a newer runtime, then a newer generation, then the line's first
    /// model (the Pro before the Pro Max), then one already booted, then one with its type's own name.
    func isNewer(than other: SimulatorDevice) -> Bool {
        if runtimeVersion != other.runtimeVersion { return other.runtimeVersion.lexicographicallyPrecedes(runtimeVersion) }
        let generation = model.first ?? 0, otherGeneration = other.model.first ?? 0
        if generation != otherGeneration { return generation > otherGeneration }
        let line = model.dropFirst().first ?? 0, otherLine = other.model.dropFirst().first ?? 0
        if line != otherLine { return line < otherLine }
        if booted != other.booted { return booted }
        let stock = name == type, otherStock = other.name == other.type
        if stock != otherStock { return stock }
        return name < other.name
    }
}
