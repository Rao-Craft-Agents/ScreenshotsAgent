//  WHAT: The screens of one simulator: for each appearance, each destination launched afresh (`-mock YES
//        -destination <case>`), looked at until it settles, and kept as `<device>/<appearance>/<destination>.png`.
//  PIN:  A SCREEN THE APP LEFT IS NOT ITS SCREEN. When the app's process is gone after the wait (it crashed at
//        launch), the frame shows the home screen: it is dropped with a note, never kept as the destination.

import Foundation

struct SimulatorCapture: Sendable {
    var commands: any CommandRunning
    var settle: Settle
    var note: @Sendable (String) -> Void
    var yield: @Sendable (ScreenshotsFrame) -> Void

    /// Captures every appearance and destination of `plan` on `session`'s device, into `stage/<folder>/…`.
    func capture(_ session: inout SimulatorSession, app: BuiltApp, plan: CapturePlan, folder: String, stage: URL) async throws -> (shots: [Shot], notes: [String]) {
        var shots: [Shot] = []
        var notes: [String] = []
        let device = session.device
        let frame = stage.appendingPathComponent("frames/\(device.udid).png")
        try FileManager.default.createDirectory(at: frame.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: frame) }
        for appearance in plan.appearances {
            try await session.set(appearance, commands: commands)
            var kept = 0
            for destination in plan.destinations {
                try Task.checkCancellation()
                let current = session
                let process = try await current.launch(app.identifier, arguments: plan.arguments(for: destination), commands: commands)
                let outcome = try await settle.wait { try await current.screenshot(to: frame, commands: commands) }
                let place = "\(device.name), \(appearance.rawValue), \(destination.name)"
                if let process, !Self.isRunning(process) {
                    notes.append("\(place): the app quit before its screen settled (it may crash at launch), so it was not kept")
                    continue
                }
                if outcome.blank {
                    notes.append("\(place) was still blank after \(Int(plan.cap)) s; the blank frame was kept")
                } else if !outcome.settled {
                    notes.append("\(place) still changed after \(Int(plan.cap)) s (something on it moves); its last frame was kept")
                }
                let shot = Shot(device: device.name, kind: device.family, folder: folder, appearance: appearance, destination: destination.name,
                                staged: stage.appendingPathComponent("\(folder)/\(appearance.rawValue)/\(destination.name).png"))
                try FileManager.default.createDirectory(at: shot.staged.deletingLastPathComponent(), withIntermediateDirectories: true)
                try outcome.frame.write(to: shot.staged)
                shots.append(shot)
                kept += 1
                yield(.captured(device: device.name, appearance: appearance, destination: destination.name))
            }
            note("captured \(kept) screen\(kept == 1 ? "" : "s") on \(device.name) in \(appearance.rawValue)")
        }
        return (shots, notes)
    }

    /// Whether the process `pid` still runs: a simulator's app is a process of this Mac's.
    static func isRunning(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
