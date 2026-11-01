import Foundation

/// What a call answers: the files written, as absolute paths, and what they show.
public struct ScreenshotsResult: Codable, Sendable, Equatable {
    /// The contact sheet: every screen on one image, labelled.
    public var path: String?
    /// Every file written: a PNG a screen, the contact sheet, and the README when its table changed.
    public var paths: [String]
    /// The devices captured, by name: `iPhone 18 Pro`, `iPad Pro 13-inch (M5)`, `Mac`.
    public var devices: [String]
    /// The appearances captured.
    public var appearances: [ScreenshotsAppearance]
    /// The destinations captured, in order.
    public var destinations: [String]
    /// How many screens were captured.
    public var screens: Int
    /// One sentence each: a screen that did not settle, a device left out, the Mac skipped, and why.
    public var notes: [String]

    public init(path: String?, paths: [String], devices: [String], appearances: [ScreenshotsAppearance], destinations: [String],
                screens: Int, notes: [String]) {
        self.path = path; self.paths = paths; self.devices = devices; self.appearances = appearances
        self.destinations = destinations; self.screens = screens; self.notes = notes
    }
}
