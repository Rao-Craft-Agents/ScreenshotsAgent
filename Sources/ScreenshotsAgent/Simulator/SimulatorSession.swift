//  WHAT: One simulator through a call: booted headless if it was not running, its status bar set to 9:41, the app
//        installed and launched once a destination, its appearance switched, its screen read; then left as it was
//        found: the app ended, the appearance put back, the status bar cleared, and shut down only if this call
//        booted it.
//  PIN:  HEADLESS. `simctl boot` starts a device with no window; Simulator.app is never opened, so nothing shows on
//        the person's screen.
//  PIN:  ONLY WHAT IT BOOTED. A device already running belongs to someone (a person, a test run): it is used as it
//        is and never shut down; one this call booted is shut down when the call is done with it.

import Foundation

struct SimulatorSession: Sendable {
    var device: SimulatorDevice
    /// Whether this call booted it, and so shuts it down.
    private(set) var bootedHere = false
    /// Its appearance before this call set one; nil when it could not be read.
    private(set) var appearanceBefore: ScreenshotsAppearance?
    /// The appearance this call last set.
    private(set) var appearanceSet: ScreenshotsAppearance?
    /// Whether it had status bar overrides of its own before this call's.
    private(set) var hadOverrides = false
    /// Whether this call overrode its status bar.
    private(set) var overrode = false
    /// The app this call installed, ended when the call is done.
    private(set) var app: String?
    /// Whether it has been left as it was found.
    private(set) var restored = false

    init(device: SimulatorDevice) { self.device = device }

    /// Starts booting it, headless, when it is not running: the boot goes on while the app builds.
    mutating func boot(_ commands: any CommandRunning, note: @Sendable (String) -> Void) async throws {
        guard !device.booted else { return }
        note("booting \(device.name) (headless)")
        let output = try await commands.run(.simctl(["boot", device.udid], timeout: 180))
        if output.succeeded {
            bootedHere = true
        } else if !output.errors.contains("current state: Booted") {
            throw ScreenshotsError.device("boot \(device.name)", output.complaint)
        }
    }

    /// Waits for it to finish booting and to draw its home screen, reads how it is set, and sets the 9:41 status bar.
    /// `frame` is where its screen is looked at; `pause` the seconds between looks.
    ///
    /// PIN: `bootstatus` says a device is done while it still shows its boot logo, so the screen is waited on until
    /// it shows something before the app is launched over it.
    mutating func ready(_ commands: any CommandRunning, frame: URL, pause: TimeInterval) async throws {
        let status = try await commands.run(.simctl(["bootstatus", device.udid], timeout: 300))
        guard status.succeeded else { throw ScreenshotsError.device("finish booting \(device.name)", status.complaint) }
        let drawn = Date().addingTimeInterval(120)
        while FrameLook.isBlank(try await screenshot(to: frame, commands: commands)) {
            guard Date() < drawn else { throw ScreenshotsError.device("finish booting \(device.name)", "its screen stayed on the boot logo for two minutes") }
            if pause > 0 { try await Task.sleep(nanoseconds: UInt64(pause * 2 * 1_000_000_000)) }
        }
        let appearance = try await commands.run(.simctl(["ui", device.udid, "appearance"]))
        appearanceBefore = ScreenshotsAppearance(rawValue: appearance.text.lowercased())
        let listing = try await commands.run(.simctl(["status_bar", device.udid, "list"]))
        hadOverrides = StatusBar.hasOverrides(listing.text)
        for arguments in StatusBar.overrides() {
            let override = try await commands.run(.simctl(["status_bar", device.udid, "override"] + arguments))
            guard override.succeeded else { throw ScreenshotsError.device("set the status bar on \(device.name)", override.complaint) }
            overrode = true
        }
    }

    /// Installs `app` (the app's data on the device is kept).
    mutating func install(_ app: BuiltApp, commands: any CommandRunning) async throws {
        let output = try await commands.run(.simctl(["install", device.udid, app.bundle.path], timeout: 300))
        guard output.succeeded else { throw ScreenshotsError.device("install \(app.bundle.lastPathComponent) on \(device.name)", output.complaint) }
        self.app = app.identifier
    }

    /// Sets its appearance.
    mutating func set(_ appearance: ScreenshotsAppearance, commands: any CommandRunning) async throws {
        guard appearanceSet != appearance else { return }
        let output = try await commands.run(.simctl(["ui", device.udid, "appearance", appearance.rawValue]))
        guard output.succeeded else { throw ScreenshotsError.device("switch \(device.name) to \(appearance.rawValue)", output.complaint) }
        appearanceSet = appearance
    }

    /// Launches the app afresh with `arguments`; answers the process id `simctl` says it started, when it says one.
    func launch(_ identifier: String, arguments: [String], commands: any CommandRunning) async throws -> Int32? {
        let output = try await commands.run(.simctl(["launch", "--terminate-running-process", device.udid, identifier] + arguments))
        guard output.succeeded else { throw ScreenshotsError.device("launch \(identifier) on \(device.name)", output.complaint) }
        return output.text.split(separator: ":").last.flatMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// The screen as it is now, as a PNG with the screen's own rounded corners, written to `file`.
    func screenshot(to file: URL, commands: any CommandRunning) async throws -> Data {
        try? FileManager.default.removeItem(at: file)
        let output = try await commands.run(.simctl(["io", device.udid, "screenshot", "--type=png", "--mask=alpha", file.path], timeout: 60))
        guard output.succeeded, let data = try? Data(contentsOf: file) else {
            throw ScreenshotsError.device("take a screenshot on \(device.name)", output.complaint)
        }
        return data
    }

    /// Leaves it as it was found, as far as it can: answers a sentence for what it could not put back.
    mutating func restore(_ commands: any CommandRunning) async -> [String] {
        guard !restored else { return [] }
        restored = true
        var notes: [String] = []
        if let app { _ = try? await commands.run(.simctl(["terminate", device.udid, app], timeout: 30)) }
        if let before = appearanceBefore, let set = appearanceSet, before != set {
            let output = try? await commands.run(.simctl(["ui", device.udid, "appearance", before.rawValue]))
            if output?.succeeded != true { notes.append("\(device.name) was left in \(set.rawValue) appearance: it could not be switched back to \(before.rawValue)") }
        }
        if overrode {
            if hadOverrides {
                notes.append("\(device.name) had status bar overrides of its own; the 9:41 bar replaced them")
            } else {
                _ = try? await commands.run(.simctl(["status_bar", device.udid, "clear"]))
            }
        }
        if bootedHere {
            var output = try? await commands.run(.simctl(["shutdown", device.udid], timeout: 120))
            if output?.succeeded != true {
                // A device still booting (a build that failed early) shuts down once it has booted.
                _ = try? await commands.run(.simctl(["bootstatus", device.udid], timeout: 180))
                output = try? await commands.run(.simctl(["shutdown", device.udid], timeout: 120))
            }
            if output?.succeeded != true { notes.append("\(device.name) was booted for the capture and could not be shut down") }
        }
        return notes
    }
}
