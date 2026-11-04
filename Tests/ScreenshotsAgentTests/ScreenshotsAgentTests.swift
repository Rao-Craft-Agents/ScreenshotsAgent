import Foundation
import GraniteAgents
import XCTest
@testable import ScreenshotsAgent

/// The package as an app finds it: by its record, with the schema a model is shown and the guide a host prompts with.
final class ScreenshotsAgentTests: XCTestCase {
    /// A refusal says whose it is: the call's, a build's, a device's; what it makes is a screen and a sheet.
    func testARefusalSaysWhoseItIsAndWhatItMakes() {
        XCTAssertEqual(ScreenshotsError.refused(["no scheme"]).refusal, AgentRefusal(.call, ["no scheme"]))
        XCTAssertEqual(ScreenshotsError.build("Margin-iOS", "x.swift:1: error").refusal.kind, .build)
        XCTAssertEqual(ScreenshotsError.device("boot", "timed out").refusal.kind, .device)
        XCTAssertEqual(ScreenshotsError.nothing("every launch ended").refusal.kind, .device)
        XCTAssertEqual(ScreenshotsAgent.makes.map(\.kind), ["screen", "sheet"])
        XCTAssertEqual(AnyAgentPackage(ScreenshotsAgent.self).makes, ScreenshotsAgent.makes)
    }

    func testTheRecordIsFoundWithNothingListed() throws {
        let screenshots = try XCTUnwrap(GraniteRoster.discovered().package("screenshots"), "the record is in this test binary")
        XCTAssertEqual(screenshots.module, "ScreenshotsAgent")
        XCTAssertEqual(screenshots.summary, ScreenshotsAgent.summary)
        XCTAssertEqual(screenshots.lanes, 1, "one call at a time: two would switch a simulator's appearance under each other")
    }

    func testTheSchemaIsWhatAModelIsShown() {
        let screenshots = AnyAgentPackage(ScreenshotsAgent.self)
        XCTAssertEqual(screenshots.schema, .object([
            .init(name: "scheme", schema: .string, required: false),
            .init(name: "devices", schema: .array(.string), required: false),
            .init(name: "appearances", schema: .array(.choice(["light", "dark"])), required: false),
            .init(name: "destinations", schema: .array(.string), required: false),
            .init(name: "arguments", schema: .array(.string), required: false),
            .init(name: "settle", schema: .integer, required: false),
            .init(name: "into", schema: .string, required: false),
            .init(name: "directory", schema: .string, required: false),
        ]))
        XCTAssertTrue(screenshots.takesDirectory)
        XCTAssertEqual(Set(screenshots.fields.keys), ["scheme", "devices", "appearances", "destinations", "arguments", "settle", "into"],
                       "a note beside every field the model sees")
        XCTAssertTrue(ScreenshotsAgent.word.range(of: "^[a-z][a-z0-9]{1,31}$", options: .regularExpression) != nil)
    }

    func testTheGuideTeachesEveryModeWithACall() {
        let guide = AnyAgentPackage(ScreenshotsAgent.self).guide
        for word in ["{}", #""devices": ["iPhone 18 Pro"]"#, #""appearances": ["dark"]"#, #""destinations": ["#, #""arguments": ["#, "\"Mac\"",
                     "-mock YES", "-destination", "AppDestination", "Resources/Screenshots", "sheet.png", "README.md", "settle", "9:41",
                     "$granite", "$mocks", "refused"] {
            XCTAssertTrue(guide.contains(word), "the guide says \(word)")
        }
        XCTAssertFalse(guide.lowercased().contains("loom"), "examples come from another domain than the family's target")
    }

    /// The call as a host makes it, JSON in: a folder with no Xcode project is refused with the reason, and nothing
    /// is written.
    func testACallThroughTheRosterRefusesAFolderWithNoProject() async throws {
        let folder = try Fixture.folder()
        let input = try JSONSerialization.data(withJSONObject: ["devices": ["iPhone 18 Pro"], "directory": folder.path])
        do {
            _ = try await AnyAgentPackage(ScreenshotsAgent.self).perform(input, host: AgentHost(directory: folder.path, ask: "screenshots of the app"))
            XCTFail("a folder with no project has nothing to capture")
        } catch {
            // The host reports the run's failure with the package's own sentence.
            XCTAssertTrue("\(error)".contains("\(folder.path) has no Xcode project"), "\(error)")
            XCTAssertTrue("\(error)".contains("nothing was captured"), "\(error)")
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [], "nothing written")
    }

    /// A choice the schema does not offer is refused before anything runs, by the host's decoding.
    func testAnAppearanceThatIsNotAChoiceIsRefused() async throws {
        let folder = try Fixture.folder()
        let input = try JSONSerialization.data(withJSONObject: ["appearances": ["sepia"], "directory": folder.path])
        do {
            _ = try await AnyAgentPackage(ScreenshotsAgent.self).perform(input)
            XCTFail("sepia is not an appearance")
        } catch let error as AgentPackageError {
            XCTAssertTrue(error.description.contains("screenshots could not read its input"), error.description)
        }
    }
}

/// A host that names its folder only in `AgentHost`, as one calling over the wire may.
final class HostFolderTests: XCTestCase {
    func testTheHostsFolderIsUsedWhenTheInputHasNone() async throws {
        let folder = try Fixture.folder()
        let input = try JSONSerialization.data(withJSONObject: ["appearances": ["dark"]])
        do {
            _ = try await AnyAgentPackage(ScreenshotsAgent.self).perform(input, host: AgentHost(directory: folder.path))
            XCTFail("the host's folder has no project")
        } catch {
            XCTAssertTrue("\(error)".contains("\(folder.path) has no Xcode project"), "the host's folder was read: \(error)")
        }
    }

    func testTheProcesssFolderIsUsedWhenNeitherSaysOne() {
        XCTAssertEqual(AgentFiles(directory: nil).root.path, AgentFiles.resolvingParents(FileManager.default.currentDirectoryPath))
    }
}
