//  WHAT: An app's screens captured for design review and README media, as a Granite agent package: the app built for
//        the iOS simulator by its scheme, launched on a headless simulator once a destination (`-mock YES
//        -destination <case>`), each screen kept once it settles, in light and dark, on an iPhone and an iPad (and
//        the Mac when asked); written as PNGs, a labelled contact sheet and a README table, and answered.
//  IN:   Input: the scheme, the devices, the appearances, the destinations, extra launch arguments, the settle cap,
//        the folder.
//  OUT:  ScreenshotsResult: every image written, the sheet, the README when it changed, what was captured, and notes.
//  PIN:  NOTHING ON THE PERSON'S SCREEN. Simulators boot headless and Simulator.app is never opened; the Mac app,
//        which can only be read on screen, is captured only when asked and only when the process may already record
//        the screen.
//  PIN:  NO MODEL. What is captured follows from the project and the call; nothing is asked of the host's model.
//  PIN:  ONE CALL AT A TIME (`lanes` 1). Two calls would switch one simulator's appearance under each other.

import Foundation
import GraniteAgents

public struct ScreenshotsAgent: GraniteAgentPackage {
    public struct Input: Codable, Sendable {
        /// The scheme that builds the iOS app; the project's `<App>-iOS` when left out.
        public var scheme: String?
        /// Where to capture: a simulator's name (`iPhone 18 Pro`), `iPhone` or `iPad` for the newest installed, `Mac`
        /// for the Mac app; the newest iPhone and iPad when left out.
        public var devices: [String]?
        /// The appearances to capture in; light and dark when left out.
        public var appearances: [ScreenshotsAppearance]?
        /// The pages to open, as the project's `AppDestination` cases; every case when left out.
        public var destinations: [String]?
        /// Launch arguments every launch adds after `-mock YES -destination <case>`.
        public var arguments: [String]?
        /// The most seconds to wait for a screen to stop changing; 15 when left out.
        public var settle: Int?
        /// The folder the images go in, relative to the project; `Resources/Screenshots` when left out.
        public var into: String?
        /// The host's folder.
        public var directory: String?

        public init(scheme: String? = nil, devices: [String]? = nil, appearances: [ScreenshotsAppearance]? = nil, destinations: [String]? = nil,
                    arguments: [String]? = nil, settle: Int? = nil, into: String? = nil, directory: String? = nil) {
            self.scheme = scheme; self.devices = devices; self.appearances = appearances; self.destinations = destinations
            self.arguments = arguments; self.settle = settle; self.into = into; self.directory = directory
        }
    }

    public typealias Event = ScreenshotsFrame
    public typealias Output = ScreenshotsResult
    public typealias Compute = Void

    public static let word = "screenshots"
    /// What it makes: pictures of the app's screens, and the sheet that shows them together.
    public static let makes = [
        AgentMake(kind: "screen", what: "a picture of one of the app's screens on a simulator or the Mac, light or dark",
                  into: ["Resources/Screenshots/*"], never: "code"),
        AgentMake(kind: "sheet", what: "every screen captured on one labelled image, and the README that lists them",
                  into: ["Resources/Screenshots/sheet.png", "Resources/Screenshots/README.md"]),
    ]
    public static let summary = "captures an app's screens on a headless iOS simulator — every destination, on mock data, in light and dark, on an iPhone and an iPad — as PNGs, a labelled contact sheet and a README table."
    public static let lanes: Int? = 1
    public static let fields = [
        "scheme": "the scheme that builds the iOS app; the project's `<App>-iOS` when left out",
        "devices": "where to capture: simulator names like `iPhone 18 Pro`, or `iPhone` and `iPad` for the newest installed, and `Mac` for the Mac app (its window shows on this Mac while it is captured); the newest iPhone and iPad when left out",
        "appearances": "light, dark, or both; both when left out",
        "destinations": "the pages to open, as the app's AppDestination cases (`feed`, `settings`); every case when left out",
        "arguments": "launch arguments every launch adds after `-mock YES -destination <case>`, such as `[\"-signedIn\", \"YES\"]`",
        "settle": "the most seconds to wait for a screen to stop changing before it is kept; 15 when left out",
        "into": "the folder for the images, relative to the project; Resources/Screenshots when left out",
    ]
    public static let guide = #"""
        Tag screenshots for pictures of an app's screens: a design review, a README, the docs. Call it without building or reading the app first: it finds the scheme and the pages itself and names every picture it wrote. It builds the iOS app by its scheme, launches it on a headless simulator (nothing opens on screen) once a destination with `-mock YES -destination <case>`, waits until the screen stops changing, and keeps it, in light and dark, with the status bar at 9:41. It writes Resources/Screenshots/<device>/<appearance>/<destination>.png, a labelled contact sheet (sheet.png) and a README.md table of every screen in that folder, so a call for one page refreshes it and keeps the rest. A first call builds the app (minutes); later calls build only what changed. It asks no model.

        Every screen, on the newest iPhone and iPad: {}

        One phone, dark only, two pages: {"devices": ["iPhone 18 Pro"], "appearances": ["dark"], "destinations": ["feed", "settings"]}

        Signed in, with the Mac app too: {"devices": ["iPhone", "iPad", "Mac"], "arguments": ["-signedIn", "YES"]}

        The pages are the cases of the app's AppDestination, which `$granite` navigation writes with the `-destination` launch argument it reads; an app without them is captured on the screen it opens on. Mock data comes from `-mock YES`, which `$mocks` makes the app read. `devices` names installed simulators; `iPhone` and `iPad` pick the newest. The Mac app is captured only when this process may record the screen, and its window shows (behind your work) while it is. `settle` raises the wait for a screen that animates. A call it cannot honour (no Xcode project, a device or page that does not exist) is refused with every reason and nothing is written. Not for UI tests (`$tests`) or for drawing app icons (`$assets`).
        """#

    public static func output(from events: [ScreenshotsFrame]) -> ScreenshotsResult? { events.compactMap(\.result).last }

    public init() {}

    public func run(_ input: Input, context: Context) -> AsyncThrowingStream<ScreenshotsFrame, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // The folder is the input's, else the host's, else the process's (AgentFiles): a host calling
                    // over the wire may say it only in `AgentHost`.
                    var input = input
                    if input.directory == nil { input.directory = context.host.directory }
                    let run = CaptureRun(note: context.host.note, yield: { continuation.yield($0) })
                    let result = try await run.capture(input)
                    continuation.yield(.written(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
