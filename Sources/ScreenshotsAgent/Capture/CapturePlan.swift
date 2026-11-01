//  WHAT: What a call will capture, read from its input and the project before anything is built or booted: the
//        project and its schemes, the destinations, the appearances, the devices, the launch arguments, the settle
//        cap and the folder; and every problem with them, at once.
//  PIN:  REFUSED BEFORE ANYTHING RUNS. A call with a problem builds nothing, boots nothing and writes nothing, and
//        its refusal names every problem, so one fix answers them all.

import Foundation

struct CapturePlan: Sendable {
    var project: AppProject
    /// The scheme that builds the iOS app.
    var scheme: String
    /// The scheme that builds the Mac app, when the Mac is asked for and the project has one.
    var macScheme: String?
    var destinations: [DestinationCase]
    /// Every destination the app has, in its own order: how the sheet and the README order their columns.
    var order: [String]
    var appearances: [ScreenshotsAppearance]
    var simulators: [SimulatorDevice]
    /// Whether the Mac app is asked for.
    var mac: Bool
    /// The call's own launch arguments, given after `-mock YES -destination <case>`.
    var extra: [String]
    /// The most seconds a screen may take to settle.
    var cap: TimeInterval
    /// The folder the images go in.
    var into: URL
    /// Whether the app reads `-mock YES`, so its screens show mock data.
    var mock: Bool
    /// Sentences for what the call does differently from what it asked, and why.
    var notes: [String]

    /// The longest a call may wait on one screen.
    static let longestSettle = 300

    /// Reads `input` against the project in `files.root` and the simulators in `catalog` (nil when `simctl` did not
    /// answer). Throws `.refused` with every problem.
    static func read(_ input: ScreenshotsAgent.Input, files: AgentFiles, catalog: SimulatorCatalog?) throws -> CapturePlan {
        var problems: [String] = []
        var notes: [String] = []

        var project: AppProject?
        var scheme: String?
        do {
            project = try AppProject.find(in: files.root)
            scheme = try project?.iOSScheme(input.scheme)
        } catch ScreenshotsError.refused(let reasons) {
            problems += reasons
        }

        let scan = LaunchScan.scan(files.root)
        let destinations = Self.destinations(input.destinations, scan: scan, problems: &problems, notes: &notes)
        if !scan.readsMock {
            notes.append("the app does not read `-mock YES` (`$mocks` adds MockMode), so its screens show whatever data its services load")
        }

        var appearances: [ScreenshotsAppearance] = []
        for appearance in input.appearances ?? [] where !appearances.contains(appearance) { appearances.append(appearance) }
        if appearances.isEmpty { appearances = ScreenshotsAppearance.allCases }

        let extra = (input.arguments ?? []).filter { !$0.isEmpty }
        for reserved in ["-destination", "-mock"] where extra.contains(reserved) {
            problems.append(reserved == "-destination"
                ? "`-destination` is given by the capture, a launch a page: name the pages with `destinations`"
                : "`-mock YES` is given to every launch: a capture runs on mock data, never a live server")
        }

        let cap = input.settle ?? 15
        if cap < 1 || cap > longestSettle { problems.append("`settle` is the most seconds to wait for a screen: 1 to \(longestSettle)") }

        var pick = DevicePick()
        if let catalog {
            pick = DevicePick.pick(input.devices, from: catalog)
        } else {
            pick.mac = (input.devices ?? []).contains { DeviceRequest.parse($0) == .mac }
            let simulators = (input.devices ?? []).isEmpty || (input.devices ?? []).contains { DeviceRequest.parse($0) != .mac }
            if simulators { pick.problems.append("`xcrun simctl` did not answer: capturing on a simulator needs Xcode and an iOS simulator runtime") }
        }
        problems += pick.problems
        notes += pick.notes

        var macScheme: String?
        if pick.mac, let project, let scheme {
            macScheme = project.macScheme(besides: scheme)
            if macScheme == nil {
                let note = "the project has no scheme that builds a Mac app, so the Mac was not captured"
                if pick.simulators.isEmpty { problems.append(note) } else { notes.append(note) }
            }
        }

        guard problems.isEmpty, let project, let scheme else { throw ScreenshotsError.refused(problems) }
        let order = scan.cases.isEmpty ? destinations.map(\.name) : scan.cases.map(\.name)
        return CapturePlan(project: project, scheme: scheme, macScheme: macScheme, destinations: destinations, order: order, appearances: appearances,
                           simulators: pick.simulators, mac: pick.mac && macScheme != nil, extra: extra, cap: TimeInterval(cap),
                           into: files.resolve(input.into ?? "Resources/Screenshots"), mock: scan.readsMock, notes: notes)
    }

    /// What a launch of `destination` is given: `-mock YES -destination <case>`, then the call's own arguments.
    func arguments(for destination: DestinationCase) -> [String] {
        var arguments = ["-mock", "YES"]
        if let argument = destination.argument { arguments += ["-destination", argument] }
        return arguments + extra
    }

    /// The pages to open: the ones asked, checked against the project's `AppDestination`; else every case; else, when
    /// a launch cannot ask for a page, the screen the app opens on.
    static func destinations(_ asked: [String]?, scan: LaunchScan, problems: inout [String], notes: inout [String]) -> [DestinationCase] {
        let names = (asked ?? []).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard scan.readsLaunchArgument else {
            if scan.cases.isEmpty {
                notes.append("the app has no `AppDestination` a launch can open (`$granite` navigation writes one), so only the screen it opens on was captured")
            } else {
                notes.append("\(scan.file ?? "AppDestination") has no `launchArgument`, so a launch cannot open a page: only the screen the app opens on was captured")
            }
            return [.launch]
        }
        guard !scan.cases.isEmpty else {
            // The app reads `-destination` its own way: the call's names are taken as they are.
            if names.isEmpty {
                notes.append("the app reads `-destination` but declares no `AppDestination` to list its pages, so only the screen it opens on was captured: name the pages with `destinations`")
                return [.launch]
            }
            var seen: Set<String> = []
            return names.filter { seen.insert($0).inserted }.map { DestinationCase(name: FolderName.of($0), raw: $0) }
        }
        guard !names.isEmpty else { return scan.cases }
        var chosen: [DestinationCase] = []
        for name in names {
            let found = scan.cases.first { $0.name == name || $0.argument == name }
                ?? scan.cases.first { $0.name.caseInsensitiveCompare(name) == .orderedSame || $0.argument?.caseInsensitiveCompare(name) == .orderedSame }
            if let found {
                if !chosen.contains(found) { chosen.append(found) }
            } else {
                problems.append("the app has no destination `\(name)`: its destinations are \(scan.cases.map { "`\($0.name)`" }.joined(separator: ", "))")
            }
        }
        return chosen
    }
}
