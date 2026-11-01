//  WHAT: Waiting for a screen to settle: look, look again, and keep the frame once two looks in a row match and it is
//        not blank; past the cap, keep the last look and say it did not settle.
//  PIN:  A FIRST WAIT, THEN LOOKS. A look right after a launch sees the launch animation; the first waits a moment.

import Foundation

struct Settle: Sendable {
    /// The most seconds to wait for a screen.
    var cap: TimeInterval
    /// Seconds before the first look.
    var first: TimeInterval = 0.8
    /// Seconds between two looks.
    var pause: TimeInterval = 0.25

    /// The frame kept, and how it was kept.
    struct Outcome: Sendable, Equatable {
        var frame: Data
        /// Two looks in a row matched.
        var settled: Bool
        /// The frame kept is blank (the launch screen, or a page with nothing on it).
        var blank: Bool
        /// How many looks it took.
        var looks: Int
    }

    /// Looks with `look` until two frames in a row match and are not blank, or `cap` seconds pass.
    func wait(_ look: () async throws -> Data) async throws -> Outcome {
        let start = Date()
        try await pauseFor(first)
        var previous: Data?
        var looks = 0
        while true {
            let frame = try await look()
            looks += 1
            let blank = FrameLook.isBlank(frame)
            if let previous, previous == frame, !blank {
                return Outcome(frame: frame, settled: true, blank: false, looks: looks)
            }
            if Date().timeIntervalSince(start) >= cap {
                return Outcome(frame: frame, settled: false, blank: blank, looks: looks)
            }
            previous = frame
            try await pauseFor(pause)
        }
    }

    private func pauseFor(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
