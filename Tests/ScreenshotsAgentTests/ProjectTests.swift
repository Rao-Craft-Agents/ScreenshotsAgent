import Foundation
import XCTest
@testable import ScreenshotsAgent

/// The Xcode project found in the host's folder, and the schemes that build its apps.
final class ProjectTests: XCTestCase {
    func testGranitesProjectAndItsSchemes() throws {
        let folder = try Fixture.app(in: Fixture.folder())
        let project = try AppProject.find(in: folder)
        XCTAssertEqual(project.name, "Cookbook")
        XCTAssertEqual(project.xcodebuildTarget, ["-project", folder.appendingPathComponent("Cookbook.xcodeproj").path])
        XCTAssertEqual(try project.iOSScheme(nil), "Cookbook-iOS")
        XCTAssertEqual(try project.iOSScheme("Cookbook-iOS"), "Cookbook-iOS")
        XCTAssertEqual(project.macScheme(besides: "Cookbook-iOS"), "Cookbook-macOS")
        XCTAssertEqual(project.scheme("Cookbook-iOS"), SchemeFile(product: "Cookbook.app", configuration: "Debug"))
    }

    func testASchemeTheProjectDoesNotHaveIsRefusedWithTheOnesItHas() throws {
        let project = try AppProject.find(in: Fixture.app(in: Fixture.folder()))
        XCTAssertThrowsError(try project.iOSScheme("Recipes")) { error in
            XCTAssertEqual(error as? ScreenshotsError, .refused(["the project has no scheme `Recipes`: its schemes are `Cookbook-iOS`, `Cookbook-macOS`"]))
        }
    }

    func testAWorkspaceWinsAndSeveralProjectsAreRefused() throws {
        let folder = try Fixture.app(in: Fixture.folder())
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Cookbook.xcworkspace"), withIntermediateDirectories: true)
        XCTAssertEqual(try AppProject.find(in: folder).xcodebuildTarget.first, "-workspace")
        XCTAssertEqual(try AppProject.find(in: folder).iOSScheme(nil), "Cookbook-iOS", "the project's shared schemes are the workspace's too")

        let two = try Fixture.folder()
        try Fixture.app(in: two, name: "One")
        try Fixture.app(in: two, name: "Two")
        XCTAssertThrowsError(try AppProject.find(in: two)) { error in
            XCTAssertTrue("\(error)".contains("several Xcode projects (One.xcodeproj, Two.xcodeproj)"), "\(error)")
        }
    }

    func testAOneSchemeProjectBuildsBothPlatformsByIt() throws {
        let folder = try Fixture.folder()
        let schemes = folder.appendingPathComponent("Greeter.xcodeproj/xcshareddata/xcschemes")
        try FileManager.default.createDirectory(at: schemes, withIntermediateDirectories: true)
        try Fixture.scheme(product: "Greeter.app", configuration: "Beta").write(to: schemes.appendingPathComponent("Greeter.xcscheme"), atomically: true, encoding: .utf8)
        let project = try AppProject.find(in: folder)
        XCTAssertEqual(try project.iOSScheme(nil), "Greeter")
        XCTAssertEqual(project.macScheme(besides: "Greeter"), "Greeter")
        XCTAssertEqual(project.scheme("Greeter")?.configuration, "Beta", "the Run action's configuration, not the Profile action's")
    }

    func testTheBuildLinesAndProducts() throws {
        let folder = try Fixture.app(in: Fixture.folder())
        let project = try AppProject.find(in: folder)
        let derived = AppBuild.derivedData(for: project, under: folder.appendingPathComponent("derived"))
        XCTAssertTrue(derived.lastPathComponent.hasPrefix("Cookbook-"))
        XCTAssertEqual(derived, AppBuild.derivedData(for: project, under: folder.appendingPathComponent("derived")), "the same folder every call")
        let log = folder.appendingPathComponent("build.log")
        let simulator = AppBuild.command(project: project, scheme: "Cookbook-iOS", configuration: "Debug", target: .simulator(udid: "PHONE"), derived: derived, log: log)
        XCTAssertEqual(Array(simulator.arguments.prefix(2)), ["xcrun", "xcodebuild"])
        for part in ["-scheme Cookbook-iOS", "-configuration Debug", "-destination id=PHONE", "-skipMacroValidation", "CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build"] {
            XCTAssertTrue(simulator.arguments.joined(separator: " ").contains(part), part)
        }
        let mac = AppBuild.command(project: project, scheme: "Cookbook-macOS", configuration: "Debug", target: .mac, derived: derived, log: log)
        XCTAssertTrue(mac.arguments.joined(separator: " ").contains("-destination platform=macOS"))
        XCTAssertFalse(mac.arguments.contains("CODE_SIGN_IDENTITY=-"), "the Mac app signs as its project says")

        let products = folder.appendingPathComponent("products")
        for name in ["Cookbook.app", "CookbookUITests-Runner.app"] {
            try FileManager.default.createDirectory(at: products.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        XCTAssertEqual(AppBuild.product(in: products, named: "Cookbook.app", scheme: "Cookbook-iOS")?.lastPathComponent, "Cookbook.app")
        XCTAssertEqual(AppBuild.product(in: products, named: nil, scheme: "Cookbook-iOS")?.lastPathComponent, "Cookbook.app")
        XCTAssertEqual(AppBuild.digest("a\nerror: one\nb\nerror: one\nerror: two", log: log), "error: one\nerror: two\n(the whole log: \(log.path))")
    }
}
