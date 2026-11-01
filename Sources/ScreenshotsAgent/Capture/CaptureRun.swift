//  WHAT: One call from input to answer: the plan read (every problem at once), the simulators booted while the app
//        builds, every screen captured on each, the Mac too when asked and allowed, then the images, the contact
//        sheet and the README staged and moved into the project together.
//  PIN:  LEFT AS FOUND, WHATEVER HAPPENS. Each simulator is put back (the app ended, its appearance and status bar
//        restored, shut down only when this call booted it) when its screens are done, and on a failure or a cancel;
//        the restore runs in a task of its own, so a cancel cannot end it halfway.
//  PIN:  IMAGES, AND THE README ONLY WHEN IT CHANGES. A host builds a project after a call that changed anything but
//        media, so the README is rewritten (and answered) only when its table differs: a capture repeated answers
//        images alone.

import Foundation

struct CaptureRun: Sendable {
    var commands: any CommandRunning = SystemCommands()
    var note: @Sendable (String) -> Void = { _ in }
    var yield: @Sendable (ScreenshotsFrame) -> Void = { _ in }
    /// Seconds before a screen's first look, and between looks.
    var first: TimeInterval = 0.8
    var pause: TimeInterval = 0.25
    /// Whether this process may record the screen, asked without a prompt.
    var mayRecordScreen: @Sendable () -> Bool = { MacCapture.mayRecordScreen() }
    /// Where builds keep their products between calls: a folder a project under the temporary folder.
    var derivedRoot = FileManager.default.temporaryDirectory.appendingPathComponent("screenshots-agent", isDirectory: true)

    func capture(_ input: ScreenshotsAgent.Input) async throws -> ScreenshotsResult {
        let files = AgentFiles(directory: input.directory)
        let listing = try? await commands.run(.simctl(["list", "--json"], timeout: 60))
        let catalog = listing.flatMap { $0.succeeded ? try? SimulatorCatalog.decode($0.output) : nil }
        let plan = try CapturePlan.read(input, files: files, catalog: catalog)
        let devices = plan.simulators.map(\.name) + (plan.mac ? ["the Mac"] : [])
        note("capturing \(plan.destinations.count) destination\(plan.destinations.count == 1 ? "" : "s") of \(plan.project.name) on "
             + "\(devices.joined(separator: ", ")) in \(plan.appearances.map(\.rawValue).joined(separator: " and "))")

        let stage = FileManager.default.temporaryDirectory.appendingPathComponent("screenshots-stage-\(UUID().uuidString.prefix(8))", isDirectory: true)
        // Looks at a screen land in `frames/`, never a dotted name: `screencapture` will not write one.
        try FileManager.default.createDirectory(at: stage.appendingPathComponent("frames", isDirectory: true), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: stage) }
        let settle = Settle(cap: plan.cap, first: first, pause: pause)
        var notes = plan.notes
        var shots: [Shot] = []

        var sessions = plan.simulators.map(SimulatorSession.init(device:))
        if !sessions.isEmpty {
            do {
                // Booting starts first and goes on while the app builds.
                for index in sessions.indices { try await sessions[index].boot(commands, note: note) }
                let app = try await AppBuild.build(project: plan.project, scheme: plan.scheme, target: .simulator(udid: sessions[0].device.udid),
                                                   derivedRoot: derivedRoot, commands: commands, note: note)
                yield(.built(scheme: plan.scheme, platform: "iOS Simulator"))
                let capture = SimulatorCapture(commands: commands, settle: settle, note: note, yield: yield)
                let folders = Self.folders(for: plan.simulators)
                for index in sessions.indices {
                    try await sessions[index].ready(commands, frame: stage.appendingPathComponent("frames/\(sessions[index].device.udid).png"), pause: pause)
                    try await sessions[index].install(app, commands: commands)
                    let found = try await capture.capture(&sessions[index], app: app, plan: plan, folder: folders[index], stage: stage)
                    shots += found.shots
                    notes += found.notes
                    notes += await restore(&sessions[index])
                }
            } catch {
                for index in sessions.indices { _ = await restore(&sessions[index]) }
                throw error
            }
        }

        if plan.mac, let scheme = plan.macScheme {
            if !mayRecordScreen() {
                let reason = "the Mac app was not captured: this process may not record the screen (allow the app that runs it in System Settings › Privacy & Security › Screen & System Audio Recording)"
                if shots.isEmpty { throw ScreenshotsError.nothing(reason) }
                notes.append(reason)
            } else {
                do {
                    let app = try await AppBuild.build(project: plan.project, scheme: scheme, target: .mac, derivedRoot: derivedRoot, commands: commands, note: note)
                    yield(.built(scheme: scheme, platform: "macOS"))
                    let found = try await MacCapture(commands: commands, settle: settle, note: note, yield: yield).capture(app: app, plan: plan, stage: stage)
                    shots += found.shots
                    notes += found.notes
                } catch let error as ScreenshotsError where !shots.isEmpty {
                    notes.append("the Mac app was not captured: \(error)")
                }
            }
        }
        guard !shots.isEmpty else { throw ScreenshotsError.nothing(notes.last ?? "every launch ended before its screen settled") }

        // The sheet and the README show the folder: this call's screens and those an earlier capture left.
        let readmePlace = plan.into.appendingPathComponent("README.md")
        let previous = (try? String(contentsOf: readmePlace, encoding: .utf8)) ?? ""
        let shown = ScreenshotsFolder.merged(shots, in: plan.into, order: plan.order, names: ScreenshotsFolder.names(fromReadme: previous))
        if shown.count > shots.count {
            let earlier = shown.count - shots.count
            notes.append("the sheet and the README also show \(earlier) screen\(earlier == 1 ? "" : "s") an earlier capture left in \(files.relative(plan.into))")
        }
        var placed = shots.map { (from: $0.staged, to: plan.into.appendingPathComponent($0.relative)) }
        let sheet = stage.appendingPathComponent("sheet.png")
        let names = Self.unique(shown.map(\.device))
        let appearances = ScreenshotsAppearance.allCases.filter { appearance in shown.contains { $0.appearance == appearance } }
        let subtitle = "\(shown.count) screen\(shown.count == 1 ? "" : "s") · \(names.joined(separator: ", ")) · "
            + appearances.map(\.rawValue).joined(separator: " and ")
        do {
            try ContactSheet(title: plan.project.name, subtitle: subtitle, rows: ContactSheet.rows(shown)).render().write(to: sheet)
        } catch let error as ContactSheetError {
            throw ScreenshotsError.nothing(error.description)
        }
        placed.append((from: sheet, to: plan.into.appendingPathComponent("sheet.png")))
        let destinations = ScreenshotsFolder.ordered(Self.unique(shown.map(\.destination)), by: plan.order)
        let readme = ScreenshotsReadme.text(app: plan.project.name, shots: shown, destinations: destinations, appearances: appearances, mock: plan.mock)
        let readmeChanged = previous != readme
        if readmeChanged {
            let staged = stage.appendingPathComponent("README.md")
            try readme.write(to: staged, atomically: true, encoding: .utf8)
            placed.append((from: staged, to: readmePlace))
        }
        let written = try files.place(placed)
        note("wrote \(shots.count) screen\(shots.count == 1 ? "" : "s"), the contact sheet\(readmeChanged ? " and the README" : "") into \(files.relative(plan.into))")
        return ScreenshotsResult(path: plan.into.appendingPathComponent("sheet.png").path, paths: written, devices: Self.unique(shots.map(\.device)),
                                 appearances: plan.appearances, destinations: plan.destinations.map(\.name), screens: shots.count, notes: notes)
    }

    /// `values` each once, in the order they first come.
    static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    /// Puts `session`'s device back as it was found, in a task a cancel cannot end; answers what it could not.
    private func restore(_ session: inout SimulatorSession) async -> [String] {
        let snapshot = session
        let commands = self.commands
        let (restored, notes) = await Task.detached {
            var restoring = snapshot
            let notes = await restoring.restore(commands)
            return (restoring, notes)
        }.value
        session = restored
        return notes
    }

    /// A folder a simulator: its name made safe, and its runtime added when two share a name.
    static func folders(for devices: [SimulatorDevice]) -> [String] {
        let names = devices.map { FolderName.of($0.name) }
        return devices.enumerated().map { index, device in
            names.filter { $0 == names[index] }.count > 1 ? FolderName.of("\(device.name) \(device.runtime)") : names[index]
        }
    }
}
