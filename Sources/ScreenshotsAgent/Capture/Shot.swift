import Foundation

/// One screen captured: on which device, in which appearance, of which destination, and where its PNG waits.
struct Shot: Sendable, Equatable {
    /// The device as a person reads it: `iPhone 18 Pro`, `Mac`.
    var device: String
    /// What it is: `iPhone`, `iPad` or `Mac`; how wide a README shows it.
    var kind: String
    /// The device's folder: `iPhone-18-Pro`.
    var folder: String
    var appearance: ScreenshotsAppearance
    /// The destination's case: `recipes`.
    var destination: String
    /// The PNG in the call's staging folder.
    var staged: URL

    /// Where it goes, relative to the screenshots folder: `iPhone-18-Pro/dark/recipes.png`.
    var relative: String { "\(folder)/\(appearance.rawValue)/\(destination).png" }
}
