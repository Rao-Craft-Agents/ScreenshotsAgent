//  WHAT: What a launch can ask of the app, read off its Swift the way the agents write it: the cases of `enum
//        AppDestination` in the order its tab bar lists them, whether `-destination <case>` reaches the app
//        (`AppDestination.launchArgument`, a read of the `destination` default), and whether `-mock YES` does
//        (`MockMode`, a read of the `mock` default).
//  PIN:  READ, NEVER BUILT. The scan is text: the enum's top-level `case` lines, so a `switch self { case .feed: … }`
//        inside a property is never taken for a destination.

import Foundation

struct LaunchScan: Sendable, Equatable {
    /// The cases, in the order the enum declares them; empty when the project has no `AppDestination`.
    var cases: [DestinationCase]
    /// The file that declares `AppDestination`, relative to the project; nil when there is none.
    var file: String?
    /// Whether the app reads the destination a launch asks for (`-destination <case>`).
    var readsLaunchArgument: Bool
    /// Whether the app reads `-mock YES` and answers from mock responses (`MockMode`, from the `mocks` agent).
    var readsMock: Bool

    /// Scans the Swift files under `root`, skipping build output, packages' checkouts and tests.
    static func scan(_ root: URL) -> LaunchScan {
        var cases: [DestinationCase] = []
        var file: String?
        var reads = false
        var mock = false
        for url in swiftFiles(under: root) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if file == nil, let found = enumCases(in: text) {
                cases = found
                file = relative(url, to: root)
            }
            if !reads, readsDestination(text) { reads = true }
            if !mock, readsMock(text) { mock = true }
        }
        return LaunchScan(cases: cases, file: file, readsLaunchArgument: reads, readsMock: mock)
    }

    /// Whether `text` reads `-mock YES`: `MockMode`, or a read of the `mock` default or of `-mock` among the launch's
    /// arguments.
    static func readsMock(_ text: String) -> Bool {
        text.contains("enum MockMode") || text.contains("struct MockMode")
            || text.range(of: #"forKey:\s*"mock""#, options: .regularExpression) != nil
            || text.contains("\"-mock\"")
    }

    /// Whether `text` reads the `destination` launch argument: `launchArgument`, or a read of the `destination`
    /// default or of `-destination` among the launch's arguments.
    static func readsDestination(_ text: String) -> Bool {
        text.contains("static var launchArgument: AppDestination")
            || text.range(of: #"forKey:\s*"destination""#, options: .regularExpression) != nil
            || text.contains("\"-destination\"")
    }

    /// The cases of `enum AppDestination` in `text`, or nil when `text` does not declare it.
    static func enumCases(in text: String) -> [DestinationCase]? {
        guard let head = text.range(of: #"\benum\s+AppDestination\b[^{]*\{"#, options: .regularExpression) else { return nil }
        var depth = 1
        var line = ""
        var cases: [DestinationCase] = []
        var index = head.upperBound
        var inString = false
        var inLineComment = false
        var inBlockComment = false
        while index < text.endIndex, depth > 0 {
            let character = text[index]
            let next = text.index(after: index)
            let following: Character? = next < text.endIndex ? text[next] : nil
            if inLineComment {
                if character == "\n" { inLineComment = false }
            } else if inBlockComment {
                if character == "*", following == "/" { inBlockComment = false; index = text.index(after: next); continue }
            } else if inString {
                if character == "\\" { line.append(character); if following != nil { line.append(following!); index = text.index(after: next); continue } }
                if character == "\"" { inString = false }
            } else if character == "/", following == "/" {
                inLineComment = true
            } else if character == "/", following == "*" {
                inBlockComment = true; index = text.index(after: next); continue
            } else if character == "\"" {
                inString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
            }
            if depth == 1, !inLineComment, !inBlockComment {
                if character == "\n" || character == ";" {
                    cases += caseLine(line)
                    line = ""
                } else if character != "}" {
                    line.append(character)
                }
            } else if depth > 1 {
                line = ""
            }
            index = next
        }
        cases += caseLine(line)
        return cases
    }

    /// The cases one line declares: `case feed`, `case feed, search`, `case feed = "home"`, `` case `default` ``.
    private static func caseLine(_ line: String) -> [DestinationCase] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("case ") else { return [] }
        let body = trimmed.dropFirst(5)
        var found: [DestinationCase] = []
        for part in body.split(separator: ",") {
            let pieces = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            let name = pieces[0].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { continue }
            var raw: String?
            if pieces.count == 2, pieces[1].hasPrefix("\""), pieces[1].hasSuffix("\""), pieces[1].count >= 2 {
                raw = String(pieces[1].dropFirst().dropLast())
            }
            found.append(DestinationCase(name: name, raw: raw))
        }
        return found
    }

    /// `url` relative to `root`, both read through their links (`/var` is `/private/var`, and a walk answers the
    /// second when it was given the first).
    private static func relative(_ url: URL, to root: URL) -> String {
        let base = root.resolvingSymlinksInPath().path + "/"
        let path = url.resolvingSymlinksInPath().path
        return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : url.lastPathComponent
    }

    /// Every `.swift` file under `root` but build output, checkouts and tests, in a stable order.
    private static func swiftFiles(under root: URL) -> [URL] {
        let skipped: Set<String> = [".build", ".git", ".swiftpm", "DerivedData", "Pods", "Carthage", "node_modules", "Tests", "UITests", "SourcePackages"]
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var files: [URL] = []
        for case let url as URL in walker {
            let name = url.lastPathComponent
            if skipped.contains(name) || name.hasSuffix(".xcodeproj") || name.hasSuffix(".xcworkspace") {
                walker.skipDescendants()
                continue
            }
            if url.pathExtension == "swift" { files.append(url) }
        }
        return files.sorted { $0.path < $1.path }
    }
}
