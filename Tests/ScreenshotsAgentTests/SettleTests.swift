import Foundation
import XCTest
@testable import ScreenshotsAgent

/// Waiting for a screen: two looks in a row that match, never on the blank launch screen, and a cap.
final class SettleTests: XCTestCase {
    private actor Looks {
        var frames: [Data]
        var index = 0
        init(_ frames: [Data]) { self.frames = frames }
        func next() -> Data {
            defer { index += 1 }
            return frames[min(index, frames.count - 1)]
        }
    }

    func testTheLaunchScreenIsNeverTakenForTheApp() async throws {
        let blank = Frames.screen(dark: false), page = Frames.screen(page: "recipes", dark: false)
        let looks = Looks([blank, blank, blank, page, page])
        let outcome = try await Settle(cap: 30, first: 0, pause: 0).wait { await looks.next() }
        XCTAssertTrue(outcome.settled)
        XCTAssertEqual(outcome.frame, page)
        XCTAssertEqual(outcome.looks, 5, "three blank looks matched each other and were passed over")
    }

    func testAScreenThatKeepsMovingIsKeptAtTheCap() async throws {
        let frames = (0..<500).map { Frames.screen(page: "spinner \($0)", dark: true) }
        let looks = Looks(frames)
        let started = Date()
        let outcome = try await Settle(cap: 0.3, first: 0, pause: 0.02).wait { await looks.next() }
        XCTAssertFalse(outcome.settled)
        XCTAssertFalse(outcome.blank)
        XCTAssertLessThan(Date().timeIntervalSince(started), 3)
    }

    func testBlankAndDarkAtAGlance() {
        XCTAssertTrue(FrameLook.isBlank(Frames.screen(dark: false)), "a status bar over one colour is the launch screen")
        XCTAssertTrue(FrameLook.isBlank(Frames.screen(dark: true)))
        XCTAssertTrue(FrameLook.isBlank(Frames.screen(dark: true, logo: true)), "a boot logo or a launch screen's mark is a splash")
        XCTAssertFalse(FrameLook.isBlank(Frames.screen(page: "settings", dark: false)))
        XCTAssertFalse(FrameLook.isBlank(Data("not a png".utf8)))
        XCTAssertTrue(FrameLook.isDark(Frames.screen(page: "settings", dark: true)))
        XCTAssertFalse(FrameLook.isDark(Frames.screen(page: "settings", dark: false)))
    }
}
