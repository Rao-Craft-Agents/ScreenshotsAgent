//  WHAT: The screenshots folder's README: the contact sheet, then a table a device (a row an appearance, a column a
//        destination), each cell the image at a width that suits it; what the `docs` agent or a README embeds.
//  PIN:  THE SAME CALL, THE SAME TEXT. Nothing in it changes with the time or the run, so a capture repeated finds it
//        unchanged and leaves it be.

import Foundation

enum ScreenshotsReadme {
    /// The README for `shots` of `app`, links relative to the screenshots folder; `mock` says the app ran on mock data.
    static func text(app: String, shots: [Shot], destinations: [String], appearances: [ScreenshotsAppearance], mock: Bool) -> String {
        var devices: [(name: String, kind: String)] = []
        for shot in shots where !devices.contains(where: { $0.name == shot.device }) { devices.append((shot.device, shot.kind)) }
        let titles = destinations.map(Caption.title(of:))
        var text = """
            # \(app) screenshots

            Every destination of \(app)\(mock ? " on mock data (`-mock YES`)" : ""), captured by the `screenshots` agent \
            on a headless simulator, in \(appearances.map(\.rawValue).joined(separator: " and ")), with the status bar at 9:41.

            ![Every screen of \(app), labelled](sheet.png)

            """
        for device in devices {
            let width = device.kind == "Mac" ? 420 : device.kind == "iPad" ? 320 : 220
            text += "\n## \(device.name)\n\n"
            text += "| | " + titles.joined(separator: " | ") + " |\n"
            text += "| --- |" + String(repeating: " --- |", count: titles.count) + "\n"
            for appearance in appearances {
                let cells = destinations.enumerated().map { index, destination -> String in
                    guard let shot = shots.first(where: { $0.device == device.name && $0.appearance == appearance && $0.destination == destination }) else { return "" }
                    return "<img src=\"\(shot.relative)\" width=\"\(width)\" alt=\"\(titles[index]) on \(device.name), \(appearance.rawValue)\">"
                }
                guard cells.contains(where: { !$0.isEmpty }) else { continue }
                text += "| \(appearance.title) | " + cells.joined(separator: " | ") + " |\n"
            }
        }
        return text
    }
}
