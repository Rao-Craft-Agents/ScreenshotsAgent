import Foundation
import GraniteAgents

/// What a call answers, as `granite-answer/1`: the files written, as absolute paths, what they show, and what was
/// captured of what the call planned.
public struct ScreenshotsResult: AgentAnswer, Equatable {
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
    /// One `screen` a capture (`iPhone 18 Pro/dark/feed`), and the `sheet`.
    public var made: [AgentMade]
    /// One `screen` a planned device, appearance and destination, and the `sheet`.
    public var expected: [AgentExpected]
    /// What it could only do in part: a screen that did not settle, the Mac not captured.
    public var problems: [AgentProblem]

    public init(path: String?, paths: [String], devices: [String], appearances: [ScreenshotsAppearance], destinations: [String],
                screens: Int, notes: [String], made: [AgentMade] = [], expected: [AgentExpected] = [], problems: [AgentProblem] = []) {
        self.path = path; self.paths = paths; self.devices = devices; self.appearances = appearances
        self.destinations = destinations; self.screens = screens; self.notes = notes
        self.made = made; self.expected = expected; self.problems = problems
    }
}
