import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import ScreenshotsAgent

/// The contact sheet, the README and the names they use.
final class SheetTests: XCTestCase {
    private func shots(device: String = "iPhone 18 Pro", kind: String = "iPhone", destinations: [String], in folder: URL) throws -> [Shot] {
        var shots: [Shot] = []
        for appearance in ScreenshotsAppearance.allCases {
            for destination in destinations {
                let file = folder.appendingPathComponent("\(device)-\(appearance.rawValue)-\(destination).png")
                try Frames.screen(page: destination, dark: appearance == .dark).write(to: file)
                shots.append(Shot(device: device, kind: kind, folder: FolderName.of(device), appearance: appearance, destination: destination, staged: file))
            }
        }
        return shots
    }

    private func size(_ png: Data) throws -> (Int, Int) {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return (image.width, image.height)
    }

    func testTheSheetHasARowADeviceAndAppearance() throws {
        let folder = try Fixture.folder()
        let shots = try shots(destinations: ["recipes", "search", "settings"], in: folder)
        let rows = ContactSheet.rows(shots)
        XCTAssertEqual(rows.map(\.title), ["iPhone 18 Pro · Light", "iPhone 18 Pro · Dark"])
        XCTAssertEqual(rows.map { $0.shots.map(\.destination) }, [["recipes", "search", "settings"], ["recipes", "search", "settings"]])
        let png = try ContactSheet(title: "Cookbook", subtitle: "6 screens · iPhone 18 Pro · light and dark", rows: rows).render()
        let (width, height) = try size(png)
        // Three screens 640 high (295 wide at a 120 × 260 frame's shape) and two gaps, inside the margins; two rows.
        XCTAssertEqual(width, 72 * 2 + 3 * 295 + 2 * 36)
        XCTAssertEqual(height, 72 + 144 + 2 * (44 + 640 + 50 + 60) - 60 + 72)
        XCTAssertFalse(FrameLook.isBlank(png))
    }

    func testAWideRowWraps() throws {
        let folder = try Fixture.folder()
        let shots = try shots(destinations: (1...8).map { "page\($0)" }, in: folder).filter { $0.appearance == .light }
        let png = try ContactSheet(title: "Cookbook", subtitle: "", rows: ContactSheet.rows(shots)).render()
        let (width, height) = try size(png)
        XCTAssertEqual(width, 72 * 2 + 6 * 295 + 5 * 36, "six screens a line")
        XCTAssertEqual(height, 72 + 144 + (44 + 640 + 50 + 60) + (640 + 50 + 60) - 60 + 72, "the row goes on under its label")
    }

    func testAnUnreadableScreenIsSaid() throws {
        let missing = Shot(device: "iPhone", kind: "iPhone", folder: "iPhone", appearance: .light, destination: "feed", staged: URL(fileURLWithPath: "/nonexistent.png"))
        XCTAssertThrowsError(try ContactSheet(title: "A", subtitle: "", rows: ContactSheet.rows([missing])).render()) { error in
            XCTAssertEqual(error as? ContactSheetError, .unreadable("iPhone/light/feed.png"))
        }
    }

    func testTheReadmeIsATableADevice() throws {
        let folder = try Fixture.folder()
        var shots = try shots(destinations: ["recipes", "pinnedPosts"], in: folder)
        shots += try self.shots(device: "Mac", kind: "Mac", destinations: ["recipes"], in: folder).filter { $0.appearance == .dark }
        let text = ScreenshotsReadme.text(app: "Cookbook", shots: shots, destinations: ["recipes", "pinnedPosts"], appearances: [.light, .dark], mock: true)
        XCTAssertTrue(text.hasPrefix("# Cookbook screenshots\n\nEvery destination of Cookbook on mock data (`-mock YES`), captured"))
        XCTAssertFalse(ScreenshotsReadme.text(app: "Cookbook", shots: shots, destinations: ["recipes"], appearances: [.light], mock: false).contains("mock data"),
                       "an app that does not read -mock is not said to show mock data")
        XCTAssertTrue(text.contains("\n## iPhone 18 Pro\n\n| | Recipes | Pinned Posts |\n| --- | --- | --- |\n| Light | <img src=\"iPhone-18-Pro/light/recipes.png\" width=\"220\""))
        XCTAssertTrue(text.contains("\n## Mac\n\n| | Recipes | Pinned Posts |\n| --- | --- | --- |\n| Dark | <img src=\"Mac/dark/recipes.png\" width=\"420\" alt=\"Recipes on Mac, dark\"> |  |\n"),
                      "a screen not captured is an empty cell, and an appearance with none is no row")
        XCTAssertEqual(text, ScreenshotsReadme.text(app: "Cookbook", shots: shots, destinations: ["recipes", "pinnedPosts"], appearances: [.light, .dark], mock: true))
    }

    func testNamesForFoldersAndCaptions() {
        XCTAssertEqual(FolderName.of("iPad Pro 13-inch (M5)"), "iPad-Pro-13-inch-M5")
        XCTAssertEqual(FolderName.of("iPhone 18 Pro"), "iPhone-18-Pro")
        XCTAssertEqual(FolderName.of("Ünïcode ✨"), "n-code")
        XCTAssertEqual(FolderName.of("✨"), "screen")
        XCTAssertEqual(Caption.title(of: "pinnedPosts"), "Pinned Posts")
        XCTAssertEqual(Caption.title(of: "recent_items"), "Recent Items")
        XCTAssertEqual(Caption.title(of: "settings"), "Settings")
        let twins = [
            SimulatorDevice(udid: "A", name: "iPhone 17", type: "iPhone 17", family: "iPhone", model: [18, 3], runtime: "iOS 27.0", runtimeVersion: [27, 0], booted: false),
            SimulatorDevice(udid: "B", name: "iPhone 17", type: "iPhone 17", family: "iPhone", model: [18, 3], runtime: "iOS 26.2", runtimeVersion: [26, 2], booted: false),
        ]
        XCTAssertEqual(CaptureRun.folders(for: twins), ["iPhone-17-iOS-27-0", "iPhone-17-iOS-26-2"])
    }
}
