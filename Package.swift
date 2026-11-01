// swift-tools-version:6.0
// ScreenshotsAgent: an app's screens captured on a headless iOS simulator, on mock data, in light and dark, on phone
// and tablet sizes, as a Granite agent package. An app that links it finds the `screenshots` agent through Granite's
// roster, with nothing listed by hand.

import PackageDescription

let package = Package(
    name: "ScreenshotsAgent",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ScreenshotsAgent", targets: ["ScreenshotsAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/riteshpakala/Granite.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "ScreenshotsAgent",
            dependencies: [.product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(
            name: "ScreenshotsAgentTests",
            dependencies: ["ScreenshotsAgent", .product(name: "GraniteAgents", package: "Granite")],
            swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
