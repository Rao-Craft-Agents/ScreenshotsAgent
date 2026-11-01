import Foundation

/// What a command did: how it exited, what it printed, what it said on stderr, and whether it ran out of time.
struct CommandOutput: Sendable, Equatable {
    var status: Int32
    var output: Data
    var errors: String
    var timedOut: Bool

    init(status: Int32 = 0, output: Data = Data(), errors: String = "", timedOut: Bool = false) {
        self.status = status; self.output = output; self.errors = errors; self.timedOut = timedOut
    }

    /// Whether it exited cleanly in time.
    var succeeded: Bool { status == 0 && !timedOut }

    /// What it printed, as text, trimmed.
    var text: String { String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }

    /// What it said went wrong, in one line for a note: stderr's last useful line, else stdout's.
    var complaint: String {
        if timedOut { return "it did not finish in time" }
        let lines = (errors + "\n" + text).split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let useful = lines.last { !$0.hasPrefix("Underlying error") && $0.count > 3 } ?? "it exited with \(status)"
        return String(useful.prefix(300))
    }
}
