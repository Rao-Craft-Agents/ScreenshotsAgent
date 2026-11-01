import Foundation
import XCTest
@testable import ScreenshotsAgent

/// What a launch can ask of the app, read off its Swift: the destinations in order, the launch argument, mock mode.
final class LaunchScanTests: XCTestCase {
    func testGranitesDestinationsAreReadInOrder() throws {
        let folder = try Fixture.app(in: Fixture.folder())
        let scan = LaunchScan.scan(folder)
        XCTAssertEqual(scan.cases.map(\.name), ["recipes", "search", "settings"])
        XCTAssertEqual(scan.cases.map(\.argument), ["recipes", "search", "settings"])
        XCTAssertEqual(scan.file, "Shared/Utility/AppDestination.swift")
        XCTAssertTrue(scan.readsLaunchArgument)
        XCTAssertTrue(scan.readsMock, "MockMode in the client package is found")
    }

    func testCasesAreTheEnumsOwnAndNeverASwitchs() {
        let text = """
            enum AppDestination: String, CaseIterable {
                case feed = "home", search // the search page
                case `default`
                /* case hidden */
                case settings; case about

                var title: String {
                    switch self {
                    case .feed: "Feed"
                    case .search, .default: "Search"
                    default: "Other {"
                    }
                }
                static let note = "case quoted"
            }
            enum Other { case outside }
            """
        let cases = LaunchScan.enumCases(in: text)
        XCTAssertEqual(cases?.map(\.name), ["feed", "search", "default", "settings", "about"])
        XCTAssertEqual(cases?.first?.argument, "home", "a raw value is what `-destination` says")
        XCTAssertNil(LaunchScan.enumCases(in: "enum Destination { case a }"))
    }

    func testWhatCountsAsReadingTheLaunch() {
        XCTAssertTrue(LaunchScan.readsDestination(#"let page = UserDefaults.standard.string(forKey: "destination")"#))
        XCTAssertTrue(LaunchScan.readsDestination(#"if let index = CommandLine.arguments.firstIndex(of: "-destination") {}"#))
        XCTAssertFalse(LaunchScan.readsDestination(#"let destination = "feed""#))
        XCTAssertTrue(LaunchScan.readsMock(#"UserDefaults.standard.bool(forKey: "mock")"#))
        XCTAssertFalse(LaunchScan.readsMock("let mockup = 1"))
    }

    func testAnAppWithoutTheLaunchArgumentOrMocksIsSeenAsSuch() throws {
        let folder = try Fixture.app(in: Fixture.folder(), launchArgument: false, mock: false)
        let scan = LaunchScan.scan(folder)
        XCTAssertEqual(scan.cases.count, 3)
        XCTAssertFalse(scan.readsLaunchArgument)
        XCTAssertFalse(scan.readsMock)
    }
}
