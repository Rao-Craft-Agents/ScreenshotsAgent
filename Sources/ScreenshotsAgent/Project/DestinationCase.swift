import Foundation

/// One screen a launch opens: an `AppDestination` case, with what `-destination` must say to open it, or the screen the
/// app opens on by itself when the project cannot be asked for one.
struct DestinationCase: Sendable, Equatable, Hashable {
    /// The case's name, `recipes`: what its image is named by.
    var name: String
    /// What `-destination` says to open it: the case's raw value (its name, or `"home"` in `case feed = "home"`);
    /// nil for the screen the app opens on by itself.
    var argument: String?

    init(name: String, raw: String? = nil) {
        self.name = name
        self.argument = raw ?? name
    }

    /// The screen the app opens on with no `-destination`: what a project without one is captured as.
    static let launch: DestinationCase = {
        var page = DestinationCase(name: "launch")
        page.argument = nil
        return page
    }()
}
