import Foundation

/// What a scheme runs, read off its `.xcscheme`: the app its Run action launches and the configuration it builds.
struct SchemeFile: Sendable, Equatable {
    /// The product the Run action launches: `Cookbook.app`; nil when the scheme runs nothing.
    var product: String?
    /// The configuration the Run action builds: `Debug` unless the scheme says otherwise.
    var configuration: String

    /// Reads a scheme's text; a scheme with no Run action reads as `Debug` with no product.
    static func read(_ text: String) -> SchemeFile {
        guard let start = text.range(of: "<LaunchAction"), let end = text.range(of: "</LaunchAction>", range: start.upperBound..<text.endIndex) else {
            return SchemeFile(product: nil, configuration: "Debug")
        }
        let launch = String(text[start.lowerBound..<end.upperBound])
        let configuration = attribute("buildConfiguration", in: launch) ?? "Debug"
        var product: String?
        if let runnable = launch.range(of: "<BuildableProductRunnable") {
            let rest = String(launch[runnable.lowerBound...])
            product = attribute("BuildableName", in: rest)
        }
        return SchemeFile(product: product, configuration: configuration)
    }

    /// The scheme at `url`, or nil when it cannot be read.
    static func read(at url: URL) -> SchemeFile? {
        (try? String(contentsOf: url, encoding: .utf8)).map(read)
    }

    /// The first `name = "value"` in `text`.
    private static func attribute(_ name: String, in text: String) -> String? {
        guard let range = text.range(of: #"\b"# + name + #"\s*=\s*"([^"]*)""#, options: .regularExpression) else { return nil }
        let match = String(text[range])
        guard let open = match.firstIndex(of: "\"") else { return nil }
        let value = match[match.index(after: open)...].dropLast()
        return value.isEmpty ? nil : String(value)
    }
}
