import Foundation
import XCTest
@testable import ScreenshotsAgent

/// A whole call against a Mac whose tools answer in memory: what it launches, what it writes, and how it leaves the
/// simulators.
final class CaptureRunTests: XCTestCase {
    private func capture(_ input: ScreenshotsAgent.Input = .init(), in app: URL, with fake: FakeCommands, mayRecord: Bool = false) async throws -> ScreenshotsResult {
        var input = input
        input.directory = app.path
        let derived = try Fixture.folder()
        return try await CaptureRun(commands: fake, first: 0, pause: 0, mayRecordScreen: { mayRecord }, derivedRoot: derived).capture(input)
    }

    func testEveryScreenIsWrittenWithTheSheetAndTheReadme() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let result = try await capture(in: app, with: FakeCommands())
        let folder = app.appendingPathComponent("Resources/Screenshots")
        XCTAssertEqual(result.devices, ["iPhone 18 Pro", "iPad Pro 13-inch (M5)"], "the newest iPhone and iPad")
        XCTAssertEqual(result.appearances, [.light, .dark])
        XCTAssertEqual(result.destinations, ["recipes", "search", "settings"])
        XCTAssertEqual(result.screens, 12)
        XCTAssertEqual(result.path, folder.appendingPathComponent("sheet.png").path)
        XCTAssertEqual(result.paths.count, 14, "twelve screens, the sheet and the README")
        XCTAssertTrue(result.notes.isEmpty, "\(result.notes)")
        XCTAssertEqual(Set(result.paths.map { String($0.dropFirst(folder.path.count + 1)) }).count, 14)
        for path in result.paths {
            XCTAssertTrue(path.hasPrefix(folder.path), path)
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), path)
        }
        for device in ["iPhone-18-Pro", "iPad-Pro-13-inch-M5"] {
            for appearance in ["light", "dark"] {
                var seen: Set<Data> = []
                for destination in result.destinations {
                    let png = try Data(contentsOf: folder.appendingPathComponent("\(device)/\(appearance)/\(destination).png"))
                    XCTAssertFalse(FrameLook.isBlank(png), "\(device)/\(appearance)/\(destination) is the page, not the launch screen")
                    XCTAssertEqual(FrameLook.isDark(png), appearance == "dark", "\(device)/\(appearance)/\(destination)")
                    XCTAssertTrue(seen.insert(png).inserted, "each destination shows its own screen")
                }
            }
        }
        let readme = try String(contentsOf: folder.appendingPathComponent("README.md"), encoding: .utf8)
        XCTAssertTrue(readme.contains("![Every screen of Cookbook, labelled](sheet.png)"))
        XCTAssertTrue(readme.contains("| | Recipes | Search | Settings |"))
        XCTAssertTrue(readme.contains(#"<img src="iPad-Pro-13-inch-M5/dark/settings.png" width="320" alt="Settings on iPad Pro 13-inch (M5), dark">"#))
    }

    func testEveryLaunchAsksForMockDataAndItsPage() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let fake = FakeCommands()
        _ = try await capture(.init(devices: ["iPhone 18 Pro"], appearances: [.dark], arguments: ["-signedIn", "YES"]), in: app, with: fake)
        let launches = fake.simctl("launch")
        XCTAssertEqual(launches.map { Array($0.suffix(6)) }, ["recipes", "search", "settings"].map { ["-mock", "YES", "-destination", $0, "-signedIn", "YES"] })
        XCTAssertTrue(launches.allSatisfy { $0.contains("--terminate-running-process") && $0.contains("com.example.cookbook") })
        let build = try XCTUnwrap(fake.lines.first { $0.starts(with: ["xcrun", "xcodebuild"]) })
        XCTAssertTrue(build.joined(separator: " ").contains("-scheme Cookbook-iOS -configuration Debug -destination id=PHONE-PRO"), "\(build)")
        XCTAssertEqual(fake.simctl("io").count, 1 + 12, "a look at the home screen, then four a screen: the launch screen twice (matching, and passed over), then the page twice")
    }

    func testOnlyWhatItBootedIsShutDownAndEveryDeviceIsLeftAsFound() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let fake = FakeCommands()
        fake.overridden = ["PAD-PRO"]
        let result = try await capture(in: app, with: fake)
        XCTAssertEqual(fake.simctl("boot").map(\.last), ["PAD-PRO"], "the booted iPhone is used as it is")
        XCTAssertEqual(fake.simctl("shutdown").map(\.last), ["PAD-PRO"], "only what the call booted is shut down")
        let bootIndex = try XCTUnwrap(fake.lines.firstIndex { $0.contains("boot") })
        let buildIndex = try XCTUnwrap(fake.lines.firstIndex { $0.contains("xcodebuild") })
        XCTAssertLessThan(bootIndex, buildIndex, "the iPad boots while the app builds")
        XCTAssertEqual(fake.appearance("PHONE-PRO"), "light", "put back after the dark screens")
        XCTAssertEqual(fake.appearance("PAD-PRO"), "light")
        XCTAssertEqual(fake.simctl("status_bar").filter { $0.last == "clear" }.map { $0[3] }, ["PHONE-PRO"],
                       "a status bar with overrides of its own is never cleared")
        XCTAssertEqual(fake.simctl("status_bar").filter { $0[4] == "override" }.map { "\($0[3]) \($0[5])" },
                       ["PHONE-PRO --dataNetwork", "PHONE-PRO --time", "PAD-PRO --dataNetwork", "PAD-PRO --time"], "the bars, then the time on its own")
        let pad = try XCTUnwrap(fake.lines.firstIndex { $0.contains("PAD-PRO") && $0.contains("--time") })
        let padLook = try XCTUnwrap(fake.lines.firstIndex { $0.contains("PAD-PRO") && $0.contains("io") })
        XCTAssertLessThan(padLook, pad, "the bar is set once the home screen shows, never on the boot logo")
        XCTAssertEqual(result.notes, ["iPad Pro 13-inch (M5) had status bar overrides of its own; the 9:41 bar replaced them"])
        XCTAssertFalse(fake.lines.contains { $0.contains("Simulator.app") || $0.first == "open" }, "Simulator.app is never opened")
    }

    func testABuildThatFailsWritesNothingAndShutsDownWhatItBooted() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let fake = FakeCommands()
        fake.buildFails = true
        do {
            _ = try await capture(in: app, with: fake)
            XCTFail("the build failed")
        } catch let error as ScreenshotsError {
            guard case .build(let scheme, let lines) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(scheme, "Cookbook-iOS")
            XCTAssertTrue(lines.contains("error: cannot find 'Recipe' in scope"), lines)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.appendingPathComponent("Resources").path), "nothing written")
        XCTAssertEqual(fake.simctl("shutdown").map(\.last), ["PAD-PRO"])
        XCTAssertTrue(fake.simctl("launch").isEmpty)
    }

    func testARefusalNamesEveryProblemAndRunsNothing() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let fake = FakeCommands()
        do {
            _ = try await capture(.init(devices: ["iPhone 99"], destinations: ["feed", "search"], arguments: ["-destination", "x"], settle: 0), in: app, with: fake)
            XCTFail("four problems")
        } catch let error as ScreenshotsError {
            guard case .refused(let problems) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(problems.count, 4, "\(problems)")
            XCTAssertTrue(problems.contains("the app has no destination `feed`: its destinations are `recipes`, `search`, `settings`"), "\(problems)")
            XCTAssertTrue(error.description.hasPrefix("4 problems, so nothing was captured:"))
        }
        XCTAssertEqual(fake.lines, [["xcrun", "simctl", "list", "--json"]], "nothing built, booted or launched")
    }

    func testACaptureOfOnePageRefreshesItAndKeepsTheRest() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let everything = try await capture(.init(devices: ["iPhone", "iPad"]), in: app, with: FakeCommands())
        XCTAssertEqual(everything.screens, 12)
        let folder = app.appendingPathComponent("Resources/Screenshots")
        let readme = try String(contentsOf: folder.appendingPathComponent("README.md"), encoding: .utf8)
        let one = try await capture(.init(devices: ["iPad"], appearances: [.dark], destinations: ["settings"]), in: app, with: FakeCommands())
        XCTAssertEqual(one.paths.map { String($0.dropFirst(folder.path.count + 1)) }, ["iPad-Pro-13-inch-M5/dark/settings.png", "sheet.png"],
                       "the same twelve screens make the same README, so only the page and the sheet are written")
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("README.md"), encoding: .utf8), readme)
        XCTAssertEqual(one.notes, ["the sheet and the README also show 11 screens an earlier capture left in Resources/Screenshots"])
        let shown = ScreenshotsFolder.merged([], in: folder, order: ["recipes", "search", "settings"], names: ScreenshotsFolder.names(fromReadme: readme))
        XCTAssertEqual(shown.count, 12)
        XCTAssertEqual(Array(Set(shown.map(\.device))).sorted(), ["iPad Pro 13-inch (M5)", "iPhone 18 Pro"], "names read back from the README's images")
        XCTAssertEqual(shown.first?.relative, "iPhone-18-Pro/light/recipes.png", "iPhones first, light first, the app's order")
        XCTAssertEqual(shown.first { $0.folder == "iPad-Pro-13-inch-M5" }?.kind, "iPad", "an earlier screen's kind is read off its shape")
    }

    func testARepeatedCaptureAnswersImagesAlone() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let input = ScreenshotsAgent.Input(devices: ["iPhone"], appearances: [.light])
        let first = try await capture(input, in: app, with: FakeCommands())
        let again = try await capture(input, in: app, with: FakeCommands())
        XCTAssertTrue(first.paths.contains { $0.hasSuffix("/README.md") })
        XCTAssertFalse(again.paths.contains { $0.hasSuffix("/README.md") }, "the README did not change, so it is not rewritten")
        XCTAssertTrue(again.paths.allSatisfy { $0.hasSuffix(".png") }, "a host builds nothing after images alone")
    }

    func testAnAppThatCannotBeAskedForAPageIsCapturedOnItsFirstScreen() async throws {
        let app = try Fixture.app(in: Fixture.folder(), launchArgument: false, mock: false)
        let fake = FakeCommands()
        let result = try await capture(.init(devices: ["iPhone 18 Pro"], appearances: [.light]), in: app, with: fake)
        XCTAssertEqual(result.destinations, ["launch"])
        XCTAssertTrue(result.paths.contains { $0.hasSuffix("Resources/Screenshots/iPhone-18-Pro/light/launch.png") })
        XCTAssertFalse(fake.simctl("launch")[0].contains("-destination"))
        XCTAssertTrue(fake.simctl("launch")[0].suffix(2) == ["-mock", "YES"])
        XCTAssertEqual(result.notes.count, 2, "\(result.notes)")
        XCTAssertTrue(result.notes[0].contains("has no `launchArgument`"), result.notes[0])
        XCTAssertTrue(result.notes[1].contains("does not read `-mock YES`"), result.notes[1])
    }

    func testTheMacIsSkippedWithANoteWhenTheScreenMayNotBeRecorded() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let fake = FakeCommands()
        let result = try await capture(.init(devices: ["iPhone", "Mac"], appearances: [.light], into: "Docs/Screens"), in: app, with: fake)
        XCTAssertEqual(result.notes.count, 1)
        XCTAssertTrue(result.notes[0].hasPrefix("the Mac app was not captured: this process may not record the screen"), result.notes[0])
        XCTAssertFalse(fake.lines.contains { $0.contains("platform=macOS") }, "nothing built for a Mac it may not read")
        XCTAssertTrue(result.paths.allSatisfy { $0.hasPrefix(app.appendingPathComponent("Docs/Screens").path) }, "into a folder the call names")
        do {
            _ = try await capture(.init(devices: ["Mac"]), in: app, with: FakeCommands())
            XCTFail("the Mac alone, unreadable, captures nothing")
        } catch let error as ScreenshotsError {
            XCTAssertTrue(error.description.hasPrefix("no screen was captured: the Mac app was not captured"), error.description)
        }
    }

    func testAnAppThatQuitsAtLaunchIsNeverKeptAsItsScreen() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let ended = Process()
        ended.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try ended.run()
        ended.waitUntilExit()
        let fake = FakeCommands()
        fake.pid = ended.processIdentifier
        do {
            _ = try await capture(.init(devices: ["iPhone"], appearances: [.light], destinations: ["search"]), in: app, with: fake)
            XCTFail("the app quit")
        } catch let error as ScreenshotsError {
            XCTAssertTrue(error.description.contains("the app quit before its screen settled"), error.description)
        }
        XCTAssertEqual(fake.simctl("shutdown").count, 0)
        XCTAssertEqual(fake.simctl("terminate").count, 1, "the device is still left as found")
    }

    func testACancelledCallStillLeavesTheDevicesAsFound() async throws {
        let app = try Fixture.app(in: Fixture.folder())
        let fake = FakeCommands()
        fake.buildSeconds = 30
        let derived = try Fixture.folder()
        let call = Task {
            try await CaptureRun(commands: fake, first: 0, pause: 0, mayRecordScreen: { false }, derivedRoot: derived)
                .capture(.init(directory: app.path))
        }
        while !fake.lines.contains(where: { $0.contains("xcodebuild") }) { try await Task.sleep(nanoseconds: 10_000_000) }
        call.cancel()
        do {
            _ = try await call.value
            XCTFail("cancelled")
        } catch is CancellationError {}
        XCTAssertEqual(fake.simctl("shutdown").map(\.last), ["PAD-PRO"], "the iPad booted for the call is shut down")
    }
}
