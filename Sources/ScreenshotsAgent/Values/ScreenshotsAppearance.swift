import Foundation

/// How the app is drawn while its screens are captured: the device's appearance.
public enum ScreenshotsAppearance: String, Codable, Sendable, CaseIterable {
    /// Light: dark text on light backgrounds.
    case light
    /// Dark: light text on dark backgrounds.
    case dark

    /// The word a person reads in a label: `Light`, `Dark`.
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}
