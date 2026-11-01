//  WHAT: The status bar a screenshot shows: 9:41 on Tuesday, January 9 (Apple's), full Wi-Fi and cellular bars, a
//        full battery with no charging bolt, no carrier; and whether a device already had overrides of its own.
//  PIN:  9:41 IN THE DEVICE'S OWN ZONE. `--time` takes an ISO date, which also sets the date an iPad shows; it is
//        written with this Mac's offset for that day, so the clock reads 9:41 and not 9:41 in another zone.
//  PIN:  THE TIME ON ITS OWN. Given in one override with the bars and the battery, `--time` sets the date but keeps
//        today's day of the week (an iPad shows "Sun Jan 9"); so the bars go first and the time alone after.

import Foundation

enum StatusBar {
    /// The overrides, in the order they are given: the bars and the battery, then the time on its own.
    static func overrides(zone: TimeZone = .current) -> [[String]] {
        [["--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3", "--cellularMode", "active", "--cellularBars", "4",
          "--operatorName", "", "--batteryState", "discharging", "--batteryLevel", "100"],
         ["--time", time(zone: zone)]]
    }

    /// 2007-01-09 at 9:41 in `zone`, as ISO 8601 with fractions, the form `simctl` accepts.
    static func time(zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let date = calendar.date(from: DateComponents(year: 2007, month: 1, day: 9, hour: 9, minute: 41)) ?? Date(timeIntervalSince1970: 1_168_364_460)
        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let offset = String(format: "%@%02d:%02d", sign, abs(seconds) / 3600, abs(seconds) % 3600 / 60)
        return "2007-01-09T09:41:00.000" + offset
    }

    /// Whether `simctl status_bar <udid> list` shows overrides: any line after its `====` rule.
    static func hasOverrides(_ listing: String) -> Bool {
        let lines = listing.split(separator: "\n", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let rule = lines.firstIndex(where: { !$0.isEmpty && $0.allSatisfy { $0 == "=" } }) else { return false }
        return lines[(rule + 1)...].contains { !$0.isEmpty }
    }
}
