import Foundation

/// A command line to run: the tool and its arguments (found on the path, as `/usr/bin/env` finds them), the folder it
/// runs in, what it adds to the environment, where a long one's output goes, and how long it may take.
struct Command: Sendable, Equatable {
    /// The tool, then its arguments: `["xcrun", "simctl", "boot", udid]`.
    var arguments: [String]
    /// The folder it runs in; the process's when nil.
    var directory: URL?
    /// Variables added to the process's environment.
    var environment: [String: String]
    /// A file its stdout and stderr go to, for output too long to hold (a build); nil keeps them in memory.
    var log: URL?
    /// Seconds before it is ended; nil waits for it.
    var timeout: TimeInterval?

    init(_ arguments: [String], directory: URL? = nil, environment: [String: String] = [:], log: URL? = nil, timeout: TimeInterval? = nil) {
        self.arguments = arguments; self.directory = directory; self.environment = environment; self.log = log; self.timeout = timeout
    }

    /// `xcrun simctl <arguments>`.
    static func simctl(_ arguments: [String], timeout: TimeInterval? = 120) -> Command {
        Command(["xcrun", "simctl"] + arguments, timeout: timeout)
    }

    /// The line as a person would type it, for a note or an error.
    var line: String {
        arguments.map { $0.isEmpty ? "''" : ($0.contains(" ") ? "'\($0)'" : $0) }.joined(separator: " ")
    }
}
