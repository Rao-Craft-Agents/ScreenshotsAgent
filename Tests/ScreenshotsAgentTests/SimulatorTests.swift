import Foundation
import XCTest
@testable import ScreenshotsAgent

/// The simulators a call captures on, and the status bar they show.
final class SimulatorTests: XCTestCase {
    private func catalog() throws -> SimulatorCatalog { try SimulatorCatalog.decode(Data(Fixture.catalog.utf8)) }

    func testOnlyAvailableiPhonesAndiPadsAreRead() throws {
        let devices = try catalog().devices
        XCTAssertEqual(Set(devices.map(\.udid)), ["PHONE-PRO", "PHONE-MAX", "PHONE-17", "PAD-PRO", "PAD-MINI", "PHONE-17-OLD"],
                       "no watch, no unavailable runtime")
        let pro = try XCTUnwrap(devices.first { $0.udid == "PHONE-PRO" })
        XCTAssertEqual(pro.model, [19, 2])
        XCTAssertEqual(pro.runtimeVersion, [27, 0])
        XCTAssertTrue(pro.booted)
        XCTAssertEqual(pro.family, "iPhone")
    }

    func testTheNewestIsTheLinesFirstModelOnTheNewestRuntime() throws {
        let catalog = try catalog()
        XCTAssertEqual(catalog.newest("iPhone")?.name, "iPhone 18 Pro", "the Pro before the Pro Max of one generation")
        XCTAssertEqual(catalog.newest("ipad")?.name, "iPad Pro 13-inch (M5)")
        XCTAssertEqual(catalog.named("iphone 17")?.udid, "PHONE-17", "a name on the newest runtime")
        XCTAssertEqual(catalog.named("PHONE-17-OLD")?.runtime, "iOS 26.2", "a UDID names one device")
    }

    func testOfTwoAlikeTheBootedOneThenTheStockOne() {
        func device(_ name: String, booted: Bool) -> SimulatorDevice {
            SimulatorDevice(udid: name, name: name, type: "iPhone 18 Pro", family: "iPhone", model: [19, 2], runtime: "iOS 27.0", runtimeVersion: [27, 0], booted: booted)
        }
        XCTAssertTrue(device("Screenshots Test iPhone", booted: true).isNewer(than: device("iPhone 18 Pro", booted: false)))
        XCTAssertTrue(device("iPhone 18 Pro", booted: false).isNewer(than: device("Screenshots Test iPhone", booted: false)))
    }

    func testWhatACallAsksIsPicked() throws {
        let catalog = try catalog()
        let standard = DevicePick.pick(nil, from: catalog)
        XCTAssertEqual(standard.simulators.map(\.name), ["iPhone 18 Pro", "iPad Pro 13-inch (M5)"])
        XCTAssertFalse(standard.mac)

        let asked = DevicePick.pick(["iPad mini (A17 Pro)", "iPhone", "iPhone 18 Pro", "Mac"], from: catalog)
        XCTAssertEqual(asked.simulators.map(\.name), ["iPad mini (A17 Pro)", "iPhone 18 Pro"], "in the order asked, each once")
        XCTAssertTrue(asked.mac)
        XCTAssertEqual(DevicePick.pick(["mac"], from: catalog).simulators, [], "the Mac alone")

        let unknown = DevicePick.pick(["iPhone 99", "Pixel"], from: catalog)
        XCTAssertEqual(unknown.problems.count, 2, "every name that is not installed, at once")
        XCTAssertTrue(unknown.problems[0].hasPrefix("no simulator is named `iPhone 99`: this Mac has iPhone 18 Pro, iPhone 18 Pro Max, iPhone 17"), unknown.problems[0])
    }

    func testAMissingFamilyIsRefusedWhenAskedAndNotedWhenDefault() throws {
        let phonesOnly = Fixture.catalog.replacingOccurrences(of: "\"productFamily\": \"iPad\"", with: "\"productFamily\": \"Apple TV\"")
        let catalog = try SimulatorCatalog.decode(Data(phonesOnly.utf8))
        let standard = DevicePick.pick([], from: catalog)
        XCTAssertEqual(standard.simulators.map(\.name), ["iPhone 18 Pro"])
        XCTAssertEqual(standard.notes, ["no iPad simulator is installed, so none was captured on one"])
        XCTAssertTrue(standard.problems.isEmpty)
        XCTAssertEqual(DevicePick.pick(["iPad"], from: catalog).problems.count, 1)
    }

    func testTheStatusBarReads941InTheDevicesZone() throws {
        let pacific = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertEqual(StatusBar.time(zone: pacific), "2007-01-09T09:41:00.000-08:00")
        XCTAssertEqual(StatusBar.time(zone: try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))), "2007-01-09T09:41:00.000+05:30")
        let overrides = StatusBar.overrides(zone: pacific)
        XCTAssertEqual(overrides.last, ["--time", "2007-01-09T09:41:00.000-08:00"], "the time on its own, last: with the bars it keeps today's weekday")
        let bars = try XCTUnwrap(overrides.first)
        for (flag, value) in [("--batteryState", "discharging"), ("--batteryLevel", "100"), ("--wifiBars", "3"), ("--cellularBars", "4"), ("--operatorName", "")] {
            XCTAssertEqual(bars[try XCTUnwrap(bars.firstIndex(of: flag)) + 1], value, flag)
        }
        XCTAssertFalse(bars.contains("--time"))
    }

    func testTheMacIsForcedIntoEachAppearanceForItAlone() {
        XCTAssertEqual(MacCapture.appearance(.light), ["-NSRequiresAquaSystemAppearance", "YES"], "a light AppleInterfaceStyle leaves a dark Mac's app dark")
        XCTAssertEqual(MacCapture.appearance(.dark), ["-AppleInterfaceStyle", "Dark"])
    }

    func testOverridesAreReadOffTheListing() {
        XCTAssertFalse(StatusBar.hasOverrides("Current Status Bar Overrides:\n=============================\n"))
        XCTAssertTrue(StatusBar.hasOverrides("Current Status Bar Overrides:\n=============================\nTime: 9:41 \nDataNetworkType: 11\n"))
        XCTAssertEqual(DeviceRequest.parse(" My Mac "), .mac)
        XCTAssertEqual(DeviceRequest.parse("IPAD"), .newest("iPad"))
    }
}
