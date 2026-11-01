import Foundation

/// What runs a capture's command lines: the machine's own tools (`SystemCommands`), or, in tests, a stand-in that
/// answers as `simctl` and `xcodebuild` would and keeps every line it was given.
protocol CommandRunning: Sendable {
    /// Runs `command` to its end. Throws only when it cannot start, or when the task awaiting it is cancelled.
    func run(_ command: Command) async throws -> CommandOutput
}
