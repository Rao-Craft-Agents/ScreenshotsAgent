import Foundation

/// What a run says as it goes.
public enum ScreenshotsFrame: Sendable {
    /// The app was built: the scheme, and the platform it was built for.
    case built(scheme: String, platform: String)
    /// One screen was captured: the device's name, the appearance and the destination.
    case captured(device: String, appearance: ScreenshotsAppearance, destination: String)
    /// The images, the contact sheet and the README are written.
    case written(ScreenshotsResult)

    public var result: ScreenshotsResult? {
        if case .written(let result) = self { return result }
        return nil
    }
}
