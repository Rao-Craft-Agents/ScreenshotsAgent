import Foundation

enum Fixture {
    /// A folder of its own for one test, removed with the process's temporary files.
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("screenshots-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// An app as `granite` lays one out: `<name>.xcodeproj` with its two shared schemes, `AppDestination` with three
    /// destinations and the launch argument, and, when `mock`, the `MockMode` the `mocks` agent writes.
    @discardableResult
    static func app(in folder: URL, name: String = "Cookbook", launchArgument: Bool = true, mock: Bool = true) throws -> URL {
        let schemes = folder.appendingPathComponent("\(name).xcodeproj/xcshareddata/xcschemes")
        try FileManager.default.createDirectory(at: schemes, withIntermediateDirectories: true)
        try "// a project file\n".write(to: folder.appendingPathComponent("\(name).xcodeproj/project.pbxproj"), atomically: true, encoding: .utf8)
        try scheme(product: "\(name).app").write(to: schemes.appendingPathComponent("\(name)-iOS.xcscheme"), atomically: true, encoding: .utf8)
        try scheme(product: "\(name).app").write(to: schemes.appendingPathComponent("\(name)-macOS.xcscheme"), atomically: true, encoding: .utf8)
        let utility = folder.appendingPathComponent("Shared/Utility")
        try FileManager.default.createDirectory(at: utility, withIntermediateDirectories: true)
        var destination = destinations
        if !launchArgument {
            destination = destination.replacingOccurrences(of: launchArgumentText, with: "")
        }
        try destination.write(to: utility.appendingPathComponent("AppDestination.swift"), atomically: true, encoding: .utf8)
        if mock {
            let mocks = folder.appendingPathComponent("Packages/RecipeKit/Sources/RecipeKit/Mocks")
            try FileManager.default.createDirectory(at: mocks, withIntermediateDirectories: true)
            try """
                import Foundation

                public enum MockMode {
                    public static var isOn: Bool { UserDefaults.standard.bool(forKey: "mock") }
                }

                """.write(to: mocks.appendingPathComponent("MockMode.swift"), atomically: true, encoding: .utf8)
        }
        return folder
    }

    /// A scheme as Xcode shares one: a Run action that launches `product` in Debug.
    static func scheme(product: String, configuration: String = "Debug") -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme LastUpgradeVersion = "2700" version = "1.7">
           <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
              <BuildActionEntries>
                 <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES">
                    <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "A1" BuildableName = "\(product)" BlueprintName = "App" ReferencedContainer = "container:App.xcodeproj">
                    </BuildableReference>
                 </BuildActionEntry>
              </BuildActionEntries>
           </BuildAction>
           <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "">
              <Testables>
                 <TestableReference skipped = "NO">
                    <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "A2" BuildableName = "AppTests.xctest" BlueprintName = "AppTests" ReferencedContainer = "container:App.xcodeproj">
                    </BuildableReference>
                 </TestableReference>
              </Testables>
           </TestAction>
           <LaunchAction buildConfiguration = "\(configuration)" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" launchStyle = "0">
              <BuildableProductRunnable runnableDebuggingMode = "0">
                 <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "A1" BuildableName = "\(product)" BlueprintName = "App" ReferencedContainer = "container:App.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </LaunchAction>
           <ProfileAction buildConfiguration = "Release">
              <BuildableProductRunnable runnableDebuggingMode = "0">
                 <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "A1" BuildableName = "Other.app" BlueprintName = "App" ReferencedContainer = "container:App.xcodeproj">
                 </BuildableReference>
              </BuildableProductRunnable>
           </ProfileAction>
        </Scheme>

        """
    }

    static let launchArgumentText = """
            /// The destination a launch asks for with `-destination <name>`: how UI tests and screenshots open a page.
            static var launchArgument: AppDestination? {
                UserDefaults.standard.string(forKey: "destination").flatMap(AppDestination.init(rawValue:))
            }

        """

    /// `AppDestination` as `granite` navigation writes it.
    static let destinations = """
        import SwiftUI

        /// The places the app goes: what its tab bar and its sidebar list, each with its title, its symbol and its page.
        enum AppDestination: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
            case recipes
            case search
            case settings

            var id: Self { self }

        \(launchArgumentText)    /// The destination's name, as the tab bar and the sidebar show it.
            var title: String {
                switch self {
                case .recipes: String(localized: "Recipes")
                case .search: String(localized: "Search")
                case .settings: String(localized: "Settings")
                }
            }

            /// The page it shows.
            @MainActor @ViewBuilder
            var view: some View {
                switch self {
                case .recipes: RecipeList()
                case .search: RecipeSearch()
                case .settings: Settings()
                }
            }
        }

        """

    /// `xcrun simctl list --json` on a Mac with a booted iPhone 18 Pro, other iPhones and iPads shut down, an older
    /// runtime, a watch, and a runtime that is no longer available.
    static let catalog = #"""
        {
          "devicetypes": [
            {"productFamily": "iPhone", "identifier": "type.iPhone-18-Pro", "modelIdentifier": "iPhone19,2", "name": "iPhone 18 Pro"},
            {"productFamily": "iPhone", "identifier": "type.iPhone-18-Pro-Max", "modelIdentifier": "iPhone19,3", "name": "iPhone 18 Pro Max"},
            {"productFamily": "iPhone", "identifier": "type.iPhone-17", "modelIdentifier": "iPhone18,3", "name": "iPhone 17"},
            {"productFamily": "iPhone", "identifier": "type.iPhone-16", "modelIdentifier": "iPhone17,3", "name": "iPhone 16"},
            {"productFamily": "iPad", "identifier": "type.iPad-Pro-13-inch-M5", "modelIdentifier": "iPad17,4", "name": "iPad Pro 13-inch (M5)"},
            {"productFamily": "iPad", "identifier": "type.iPad-mini-A17-Pro", "modelIdentifier": "iPad16,1", "name": "iPad mini (A17 Pro)"},
            {"productFamily": "Apple Watch", "identifier": "type.Watch-11", "modelIdentifier": "Watch8,1", "name": "Apple Watch Series 11 (46mm)"}
          ],
          "runtimes": [
            {"identifier": "runtime.iOS-27-0", "version": "27.0", "name": "iOS 27.0", "platform": "iOS", "isAvailable": true},
            {"identifier": "runtime.iOS-26-2", "version": "26.2", "name": "iOS 26.2", "platform": "iOS", "isAvailable": true},
            {"identifier": "runtime.watchOS-27-0", "version": "27.0", "name": "watchOS 27.0", "platform": "watchOS", "isAvailable": true},
            {"identifier": "runtime.iOS-25-0", "version": "25.0", "name": "iOS 25.0", "platform": "iOS", "isAvailable": false}
          ],
          "devices": {
            "runtime.iOS-27-0": [
              {"udid": "PHONE-PRO", "name": "iPhone 18 Pro", "state": "Booted", "isAvailable": true, "deviceTypeIdentifier": "type.iPhone-18-Pro"},
              {"udid": "PHONE-MAX", "name": "iPhone 18 Pro Max", "state": "Shutdown", "isAvailable": true, "deviceTypeIdentifier": "type.iPhone-18-Pro-Max"},
              {"udid": "PHONE-17", "name": "iPhone 17", "state": "Shutdown", "isAvailable": true, "deviceTypeIdentifier": "type.iPhone-17"},
              {"udid": "PAD-PRO", "name": "iPad Pro 13-inch (M5)", "state": "Shutdown", "isAvailable": true, "deviceTypeIdentifier": "type.iPad-Pro-13-inch-M5"},
              {"udid": "PAD-MINI", "name": "iPad mini (A17 Pro)", "state": "Shutdown", "isAvailable": true, "deviceTypeIdentifier": "type.iPad-mini-A17-Pro"}
            ],
            "runtime.iOS-26-2": [
              {"udid": "PHONE-17-OLD", "name": "iPhone 17", "state": "Shutdown", "isAvailable": true, "deviceTypeIdentifier": "type.iPhone-17"}
            ],
            "runtime.watchOS-27-0": [
              {"udid": "WATCH", "name": "Apple Watch Series 11 (46mm)", "state": "Shutdown", "isAvailable": true, "deviceTypeIdentifier": "type.Watch-11"}
            ],
            "runtime.iOS-25-0": [
              {"udid": "PHONE-16-GONE", "name": "iPhone 16", "state": "Shutdown", "isAvailable": false, "deviceTypeIdentifier": "type.iPhone-16"}
            ]
          },
          "pairs": {}
        }
        """#
}
