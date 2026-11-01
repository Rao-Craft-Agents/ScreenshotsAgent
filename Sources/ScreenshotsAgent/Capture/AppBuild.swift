//  WHAT: The app built by its scheme for a capture: for the simulator (one build every simulator installs) or for the
//        Mac, into a derived-data folder kept for the project between calls, so a second capture builds only what
//        changed; then the app the scheme's Run action launches, found among the products.
//  PIN:  NOT THE PERSON'S BUILD FOLDER. A capture builds into its own derived data, so it never waits on, or breaks,
//        a build Xcode or the turn's checks are running.
//  PIN:  A SIMULATOR NEEDS NO SIGNATURE. The simulator build is signed ad hoc (`CODE_SIGN_IDENTITY=-`), so a project
//        with no team, or a team this Mac has no certificate for, still installs; the Mac build signs as the
//        project says, which `granite` makes "Sign to Run Locally" until a team is chosen.

import Foundation

enum AppBuild {
    /// What a build is for.
    enum Target: Sendable, Equatable {
        /// The iOS simulator, built for the device given (its architecture), installed on every simulator.
        case simulator(udid: String)
        /// This Mac.
        case mac

        /// The products folder's suffix: `-iphonesimulator`, or none for the Mac.
        var products: String {
            switch self {
            case .simulator: return "-iphonesimulator"
            case .mac: return ""
            }
        }

        /// How a note names it.
        var name: String {
            switch self {
            case .simulator: return "the iOS simulator"
            case .mac: return "the Mac"
            }
        }
    }

    /// The derived-data folder for `project`, under `root`: one a project, named by it and its path, so two
    /// projects of one name never share products.
    static func derivedData(for project: AppProject, under root: URL) -> URL {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in project.container.path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        let name = project.name.filter { $0.isLetter || $0.isNumber }
        return root.appendingPathComponent("\(name.isEmpty ? "App" : name)-\(String(hash, radix: 16).prefix(10))", isDirectory: true)
    }

    /// The `xcodebuild` line.
    static func command(project: AppProject, scheme: String, configuration: String, target: Target, derived: URL, log: URL) -> Command {
        var arguments = ["xcrun", "xcodebuild"] + project.xcodebuildTarget + ["-scheme", scheme, "-configuration", configuration]
        switch target {
        case .simulator(let udid):
            arguments += ["-destination", "id=\(udid)"]
        case .mac:
            arguments += ["-destination", "platform=macOS"]
        }
        arguments += ["-derivedDataPath", derived.appendingPathComponent("DerivedData").path,
                      "-skipPackagePluginValidation", "-skipMacroValidation"]
        if case .simulator = target { arguments += ["CODE_SIGN_IDENTITY=-", "CODE_SIGNING_REQUIRED=NO"] }
        arguments.append("build")
        return Command(arguments, directory: project.container.deletingLastPathComponent(), log: log, timeout: 45 * 60)
    }

    /// Builds `scheme` for `target` and answers the app it makes. Throws `.build` with the error lines when it fails.
    static func build(project: AppProject, scheme: String, target: Target, derivedRoot: URL, commands: any CommandRunning,
                      note: @Sendable (String) -> Void) async throws -> BuiltApp {
        let file = project.scheme(scheme)
        let configuration = file?.configuration ?? "Debug"
        let derived = derivedData(for: project, under: derivedRoot)
        let log = derived.appendingPathComponent("build\(target.products.isEmpty ? "-mac" : target.products).log")
        let firstBuild = !FileManager.default.fileExists(atPath: derived.appendingPathComponent("DerivedData").path)
        note("building \(scheme) for \(target.name)\(firstBuild ? " (a first build fetches its packages: minutes)" : "")")
        let started = Date()
        let output = try await commands.run(command(project: project, scheme: scheme, configuration: configuration, target: target, derived: derived, log: log))
        let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        guard output.succeeded else {
            throw ScreenshotsError.build(scheme, output.timedOut ? "the build ran past 45 minutes" : digest(text, log: log))
        }
        let products = derived.appendingPathComponent("DerivedData/Build/Products/\(configuration)\(target.products)", isDirectory: true)
        guard let bundle = product(in: products, named: file?.product, scheme: scheme), let app = BuiltApp.read(bundle) else {
            throw ScreenshotsError.build(scheme, "the build made no app in \(products.path)")
        }
        note("built \(app.bundle.lastPathComponent) in \(Int(Date().timeIntervalSince(started).rounded())) s")
        return app
    }

    /// The app among `folder`'s products: the one the scheme launches, else the only one, else the scheme's namesake.
    static func product(in folder: URL, named: String?, scheme: String) -> URL? {
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".app") }.sorted()
        if let named, names.contains(named) { return folder.appendingPathComponent(named) }
        if names.count == 1 { return folder.appendingPathComponent(names[0]) }
        let stem = scheme.replacingOccurrences(of: "-iOS", with: "").replacingOccurrences(of: "-macOS", with: "")
        return names.first { $0 == "\(stem).app" }.map { folder.appendingPathComponent($0) }
    }

    /// The lines a failed build is read by: its errors, each once, and where the whole log is.
    static func digest(_ log: String, log file: URL) -> String {
        var seen: Set<String> = []
        let errors = log.split(separator: "\n").map(String.init).filter { $0.contains("error:") }
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { seen.insert($0).inserted }
        let lines = errors.isEmpty ? log.split(separator: "\n").suffix(8).map(String.init) : Array(errors.prefix(12))
        return (lines + ["(the whole log: \(file.path))"]).joined(separator: "\n")
    }
}
