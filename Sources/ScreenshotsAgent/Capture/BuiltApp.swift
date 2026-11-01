import Foundation

/// An app built for a capture: its bundle, its identifier and its executable's name.
struct BuiltApp: Sendable, Equatable {
    /// The `.app` bundle.
    var bundle: URL
    /// `CFBundleIdentifier`: what `simctl launch` opens.
    var identifier: String
    /// `CFBundleExecutable`: what a Mac launch runs, inside `Contents/MacOS`.
    var executable: String

    /// The bundle at `url`, read off its Info.plist (`Info.plist` on iOS, `Contents/Info.plist` on the Mac).
    static func read(_ url: URL) -> BuiltApp? {
        let candidates = [url.appendingPathComponent("Info.plist"), url.appendingPathComponent("Contents/Info.plist")]
        for plist in candidates {
            guard let data = try? Data(contentsOf: plist),
                  let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let identifier = info["CFBundleIdentifier"] as? String else { continue }
            let executable = info["CFBundleExecutable"] as? String ?? url.deletingPathExtension().lastPathComponent
            return BuiltApp(bundle: url, identifier: identifier, executable: executable)
        }
        return nil
    }
}
