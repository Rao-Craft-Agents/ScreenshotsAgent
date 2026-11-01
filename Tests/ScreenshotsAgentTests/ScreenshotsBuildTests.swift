import Foundation
import GraniteAgents
import XCTest
@testable import ScreenshotsAgent

/// The agent run for real, as Craft calls it: an app made through the family's installed runners (a granite project, a
/// network client package, a service that loads from the client's `.preview`, a list, a search and a settings page,
/// navigation with three destinations), captured on a simulator of the test's own in light and dark, and the images
/// read back. Gated (`SCREENSHOTS_BUILD=1`): a first build fetches Granite and takes minutes.
final class ScreenshotsBuildTests: XCTestCase {
    func testAnAppMadeByTheFamilyIsCapturedOnEveryDestination() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENSHOTS_BUILD"] == "1", "set SCREENSHOTS_BUILD=1 to capture an app for real")
        for agent in ["GraniteAgent", "NetworkAgent"] {
            try XCTSkipUnless(Runner.executable(agent) != nil, "\(agent) is not installed on this Mac's shelf")
        }
        let folder = try Fixture.folder()
        let app = folder.appendingPathComponent("Cookbook")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        try makeTheApp(in: app)

        let simulator = try TestSimulator.create(named: "Screenshots Test iPhone")
        defer { simulator.delete() }
        XCTAssertEqual(try simulator.state(), "Shutdown")

        let input = try JSONSerialization.data(withJSONObject: ["devices": [simulator.udid], "directory": app.path])
        let notes = NoteLog()
        let started = Date()
        let answer = try await AnyAgentPackage(ScreenshotsAgent.self).perform(input, host: AgentHost(directory: app.path, ask: "screenshots of every page",
                                                                                                         note: { notes.add($0) }))
        let result = try JSONDecoder().decode(ScreenshotsResult.self, from: answer)
        let seconds = Int(Date().timeIntervalSince(started))
        print("screenshots: \(seconds) s, notes: \(notes.all), folder: \(app.appendingPathComponent("Resources/Screenshots").path)")

        XCTAssertEqual(try simulator.state(), "Shutdown", "the call booted the simulator, so it shut it down")
        XCTAssertEqual(result.destinations, ["recipes", "search", "settings"])
        XCTAssertEqual(result.screens, 6)
        XCTAssertEqual(result.paths.count, 8, "six screens, the sheet, the README")
        XCTAssertTrue(result.notes.contains { $0.contains("does not read `-mock YES`") }, "the fixture loads from .preview, not MockMode: \(result.notes)")
        let screens = app.appendingPathComponent("Resources/Screenshots/Screenshots-Test-iPhone")
        let titles = ["recipes": "Recipes", "search": "Search", "settings": "Settings"]
        for appearance in ["light", "dark"] {
            for destination in result.destinations {
                let png = try Data(contentsOf: screens.appendingPathComponent("\(appearance)/\(destination).png"))
                XCTAssertEqual(FrameLook.isDark(png), appearance == "dark", "\(appearance)/\(destination)")
                let lines = try ScreenText.lines(png)
                XCTAssertTrue(lines.contains { $0.text.contains("9:41") && $0.top < 0.06 }, "\(appearance)/\(destination): the status bar says 9:41: \(lines)")
                // The page's own title, large, under the status bar: the destination's screen, not the launch screen.
                XCTAssertTrue(lines.contains { $0.text == titles[destination]! && $0.top > 0.06 && $0.top < 0.2 },
                              "\(appearance)/\(destination) shows its own page: \(lines.map(\.text))")
                if destination == "recipes" { XCTAssertTrue(lines.contains { $0.text == "Sample title" }, "the list loaded the preview client's recipe") }
                if destination == "settings" { XCTAssertTrue(lines.contains { $0.text == "Restore Defaults" }) }
            }
        }
        let sheet = try XCTUnwrap(result.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sheet))
        // Vision reads the sheet's middle dot as a bullet.
        let sheetText = try ScreenText.lines(Data(contentsOf: URL(fileURLWithPath: sheet))).map { $0.text.replacingOccurrences(of: "•", with: "·") }
        for label in ["Cookbook", "Screenshots Test iPhone · Light", "Screenshots Test iPhone · Dark", "Recipes", "Search", "Settings"] {
            XCTAssertTrue(sheetText.contains { $0.contains(label) }, "the sheet is labelled \(label): \(sheetText)")
        }

        // Again for one page, as a person would after a change, with the folder said only by the host: an incremental
        // build, the page and the sheet rewritten, and the README, whose table is the same, left alone.
        let again = try JSONDecoder().decode(ScreenshotsResult.self, from: try await AnyAgentPackage(ScreenshotsAgent.self).perform(
            try JSONSerialization.data(withJSONObject: ["devices": ["Screenshots Test iPhone"], "appearances": ["dark"], "destinations": ["settings"]]),
            host: AgentHost(directory: app.path)))
        XCTAssertEqual(again.paths.map { URL(fileURLWithPath: $0).lastPathComponent }, ["settings.png", "sheet.png"])
        XCTAssertEqual(again.notes.filter { $0.contains("earlier capture") }.count, 1, "\(again.notes)")
        XCTAssertEqual(try simulator.state(), "Shutdown")
        print("screenshots again: \(again.notes)")

        // What a passing run leaves is only build products under the temporary folder: they go.
        if testRun?.totalFailureCount == 0 {
            try? FileManager.default.removeItem(at: AppBuild.derivedData(for: try AppProject.find(in: app), under: CaptureRun().derivedRoot))
        }
    }

    /// The app, made call by call through the installed runners, as the family's agents make one in Craft.
    private func makeTheApp(in app: URL) throws {
        try Runner.call("GraniteAgent", word: "granite", input: ["make": "project", "name": "Cookbook", "bundleId": "com.example.cookbook"], in: app)
        try Runner.call("NetworkAgent", word: "network", input: [
            "name": "RecipeKit", "baseURL": "https://api.recipes.example",
            "entities": [#"Recipe "a dish someone saved": id String, title String, minutes Int = 30, summary String?"#],
            "endpoints": [#"GET /v1/recipes?page -> [Recipe] as recipes paged "the newest recipes first""#],
        ], in: app)
        try Runner.call("GraniteAgent", word: "granite", input: [
            "make": "service", "type": "Recipes", "state": ["recipes [Recipe] = []"],
            "events": [#"load(page Int) -> recipes = RecipeClient.preview.recipes(page: page) "loads one page""#],
        ], in: app)
        // The row views name `Recipe`, which lives in the kit: granite is told to import it.
        try Runner.call("GraniteAgent", word: "granite", input: [
            "make": "component", "type": "RecipeList", "layout": "list", "relays": ["recipes: RecipesService"], "imports": ["RecipeKit"],
            "shows": ["items = recipes.state.recipes", #"title = "Recipes""#, #"empty = "No recipes yet""#],
            "actions": ["refresh = try await recipes.load(page: 1)"],
        ], in: app)
        try Runner.call("GraniteAgent", word: "granite", input: [
            "make": "component", "type": "RecipeSearch", "layout": "search", "relays": ["recipes: RecipesService"], "imports": ["RecipeKit"],
            "shows": ["items = recipes.state.recipes", #"title = "Search""#, #"empty = "Find a recipe by its name""#],
            "actions": ["search(text String) = try await recipes.load(page: 1)"],
        ], in: app)
        try Runner.call("GraniteAgent", word: "granite", input: [
            "make": "component", "type": "Settings", "layout": "settings", "relays": ["config: ConfigService"],
            "shows": [#""Appearance/Theme" = config.state.appearance"#, #""Usage/Launches" = config.state.launches"#],
            "actions": [#"restore "Restore Defaults" = config.set(.reset)"#],
        ], in: app)
        try Runner.call("GraniteAgent", word: "granite", input: [
            "make": "navigation", "style": "adaptive",
            "destinations": [#"recipes: RecipeList "Recipes" book"#, #"search: RecipeSearch "Search" magnifyingglass"#, #"settings: Settings "Settings" gearshape"#],
        ], in: app)
    }
}
