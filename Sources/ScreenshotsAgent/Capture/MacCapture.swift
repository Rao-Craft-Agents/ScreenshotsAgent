//  WHAT: The Mac app's screens: the app launched once a destination with the same arguments, in light or dark (forced
//        for the app alone by a launch argument, never the person's setting), its window read with
//        `screencapture -l` once it settles, then quit.
//  PIN:  NEVER A PROMPT. Only a process that may already record the screen captures the Mac
//        (`CGPreflightScreenCaptureAccess()`, which asks nothing); otherwise the Mac is skipped with a note.
//  PIN:  THE PERSON'S DATA STAYS THEIRS. What runs is a copy of the app signed for this Mac alone, without its
//        entitlements, so out of its sandbox, with a home folder of the capture's own (`CFFIXED_USER_HOME`): mock data
//        never lands in the container, settings or stores of the person's own copy (a sandboxed app ignores the home
//        it is given and writes to its container).
//  PIN:  IT SHOWS. A window is read only while it is on screen: the app opens without taking the focus, for the
//        seconds each screen takes, and quits; its window is drawn as an inactive one is, behind the person's work.

import CoreGraphics
import Foundation

struct MacCapture: Sendable {
    var commands: any CommandRunning
    var settle: Settle
    var note: @Sendable (String) -> Void
    var yield: @Sendable (ScreenshotsFrame) -> Void

    /// Whether this process may record the screen, asked without a prompt.
    static func mayRecordScreen() -> Bool { CGPreflightScreenCaptureAccess() }

    /// Captures every appearance and destination of `plan` in `app`'s window, into `stage/Mac/…`.
    func capture(app: BuiltApp, plan: CapturePlan, stage: URL) async throws -> (shots: [Shot], notes: [String]) {
        var shots: [Shot] = []
        var notes: [String] = []
        let home = stage.appendingPathComponent("mac-home", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        // `screencapture` will not write a file whose name starts with a dot, and exits 0 all the same.
        let frame = stage.appendingPathComponent("frames/mac.png")
        try FileManager.default.createDirectory(at: frame.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: home)
            try? FileManager.default.removeItem(at: frame)
        }
        let copy = try await unsandboxedCopy(of: app, in: stage)
        let executable = copy.appendingPathComponent("Contents/MacOS/\(app.executable)")
        for appearance in plan.appearances {
            var kept = 0
            for destination in plan.destinations {
                try Task.checkCancellation()
                let place = "Mac, \(appearance.rawValue), \(destination.name)"
                let arguments = plan.arguments(for: destination) + ["-ApplePersistenceIgnoreState", "YES"] + Self.appearance(appearance)
                let running = try launch(executable, arguments: arguments, home: home)
                defer { quit(running) }
                guard let window = try await window(of: running.process.processIdentifier, within: plan.cap) else {
                    notes.append("\(place): the app showed no window within \(Int(plan.cap)) s, so it was not captured")
                    continue
                }
                let outcome = try await settle.wait { try await self.read(window: window, to: frame) }
                guard running.isRunning else {
                    notes.append("\(place): the app quit before its window settled, so it was not kept")
                    continue
                }
                if !outcome.settled { notes.append("\(place) still changed after \(Int(plan.cap)) s; its last frame was kept") }
                let shot = Shot(device: "Mac", kind: "Mac", folder: "Mac", appearance: appearance, destination: destination.name,
                                staged: stage.appendingPathComponent("Mac/\(appearance.rawValue)/\(destination.name).png"))
                try FileManager.default.createDirectory(at: shot.staged.deletingLastPathComponent(), withIntermediateDirectories: true)
                try outcome.frame.write(to: shot.staged)
                shots.append(shot)
                kept += 1
                yield(.captured(device: "Mac", appearance: appearance, destination: destination.name))
            }
            note("captured \(kept) screen\(kept == 1 ? "" : "s") on the Mac in \(appearance.rawValue)")
        }
        return (shots, notes)
    }

    /// A copy of `app` in the stage, signed ad hoc with no entitlements: it runs out of the sandbox, so the home the
    /// capture gives it is where it keeps its data.
    private func unsandboxedCopy(of app: BuiltApp, in stage: URL) async throws -> URL {
        let copy = stage.appendingPathComponent("mac-app/\(app.bundle.lastPathComponent)")
        try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: app.bundle, to: copy)
        let signed = try await commands.run(Command(["codesign", "--force", "--sign", "-", copy.path], timeout: 120))
        guard signed.succeeded else { throw ScreenshotsError.device("sign a copy of the Mac app to run on its own", signed.complaint) }
        return copy
    }

    /// The launch arguments that draw the app alone in `appearance`, whatever the Mac's own is: dark by
    /// `AppleInterfaceStyle`; light by `NSRequiresAquaSystemAppearance`, since a light `AppleInterfaceStyle` is not
    /// a value and leaves a dark Mac's app dark.
    static func appearance(_ appearance: ScreenshotsAppearance) -> [String] {
        switch appearance {
        case .light: return ["-NSRequiresAquaSystemAppearance", "YES"]
        case .dark: return ["-AppleInterfaceStyle", "Dark"]
        }
    }

    /// Starts the app's executable with `arguments` and a home of its own; its output goes nowhere.
    private func launch(_ executable: URL, arguments: [String], home: URL) throws -> ProcessHandle {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["CFFIXED_USER_HOME": home.path]) { $1 }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let handle = ProcessHandle(process)
        try handle.start()
        return handle
    }

    /// Ends the app: SIGTERM, then SIGKILL if it is still there after three seconds; waits for it to be gone.
    private func quit(_ running: ProcessHandle) {
        running.end(grace: 3)
        running.waitForExit(10)
    }

    /// The id of the largest ordinary window `pid` shows on screen, waiting up to `seconds` for one.
    private func window(of pid: Int32, within seconds: TimeInterval) async throws -> CGWindowID? {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if let id = Self.largestWindow(of: pid) {
                return id
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        return nil
    }

    /// The largest window at the normal level that `pid` has on screen, at least 200 points a side.
    static func largestWindow(of pid: Int32) -> CGWindowID? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        var best: (id: CGWindowID, area: CGFloat)?
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? Int32) == pid, (window[kCGWindowLayer as String] as? Int) == 0,
                  let number = window[kCGWindowNumber as String] as? UInt32,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = bounds["Width"], let height = bounds["Height"], width >= 200, height >= 200 else { continue }
            if best == nil || width * height > best!.area { best = (number, width * height) }
        }
        return best?.id
    }

    /// The window `id` as a PNG, without its shadow, written to `file`.
    private func read(window id: CGWindowID, to file: URL) async throws -> Data {
        try? FileManager.default.removeItem(at: file)
        let output = try await commands.run(Command(["screencapture", "-x", "-o", "-l\(id)", "-t", "png", file.path], timeout: 30))
        guard output.succeeded, let data = try? Data(contentsOf: file) else {
            throw ScreenshotsError.device("read the Mac app's window", output.complaint)
        }
        return data
    }
}
