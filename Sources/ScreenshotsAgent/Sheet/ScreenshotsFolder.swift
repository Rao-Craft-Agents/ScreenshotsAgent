//  WHAT: The screens a screenshots folder holds once a call's own are placed: the call's, and every one an earlier
//        capture left (`<device>/<appearance>/<destination>.png`) that the call did not replace. What the contact
//        sheet and the README show, so a capture of one page refreshes that page and keeps the rest.
//  PIN:  A STABLE ORDER. Devices by kind (iPhone, iPad, Mac) then folder, light before dark, destinations in the
//        app's own order: the same screens make the same README whatever a call asked for first, so a README with
//        nothing new is left alone.

import Foundation
import ImageIO

enum ScreenshotsFolder {
    /// `shots` and the earlier screens in `folder` they do not replace, in the stable order. `order` is the app's
    /// destinations in its own order; `names` the device names an earlier README gave its folders.
    static func merged(_ shots: [Shot], in folder: URL, order: [String], names: [String: String]) -> [Shot] {
        let replaced = Set(shots.map(\.relative))
        let kept = earlier(in: folder, names: names).filter { !replaced.contains($0.relative) }
        return (shots + kept).sorted { before($0, $1, order: order) }
    }

    /// The screens already in `folder`, read off its layout.
    static func earlier(in folder: URL, names: [String: String]) -> [Shot] {
        let manager = FileManager.default
        var shots: [Shot] = []
        for device in ((try? manager.contentsOfDirectory(atPath: folder.path)) ?? []).sorted() where !device.hasPrefix(".") {
            for appearance in ScreenshotsAppearance.allCases {
                let place = folder.appendingPathComponent(device).appendingPathComponent(appearance.rawValue)
                for file in ((try? manager.contentsOfDirectory(atPath: place.path)) ?? []).sorted() where file.hasSuffix(".png") {
                    let url = place.appendingPathComponent(file)
                    shots.append(Shot(device: names[device] ?? device.replacingOccurrences(of: "-", with: " "), kind: kind(of: url, in: device), folder: device,
                                      appearance: appearance, destination: String(file.dropLast(4)), staged: url))
                }
            }
        }
        return shots
    }

    /// The device names a README this agent wrote gives its folders, read off its images' `alt`:
    /// `<img src="iPad-Pro-13-inch-M5/dark/feed.png" … alt="Feed on iPad Pro 13-inch (M5), dark">`.
    static func names(fromReadme text: String) -> [String: String] {
        var names: [String: String] = [:]
        let pattern = #"<img src="([^/"]+)/(?:light|dark)/[^"]*" width="\d+" alt="[^"]* on (.+?), (?:light|dark)">"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return names }
        let range = NSRange(text.startIndex..., in: text)
        for match in expression.matches(in: text, range: range) {
            guard let folder = Range(match.range(at: 1), in: text), let name = Range(match.range(at: 2), in: text) else { continue }
            names[String(text[folder])] = String(text[name])
        }
        return names
    }

    /// What took a screen: the Mac, by its folder (a window may have any shape); else, by the screen's shape, an iPad
    /// (three to four) or an iPhone (taller), as a simulator captures them, upright.
    static func kind(of png: URL, in folder: String) -> String {
        guard folder != "Mac" else { return "Mac" }
        guard let source = CGImageSourceCreateWithURL(png as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double, let height = properties[kCGImagePropertyPixelHeight] as? Double,
              height > 0 else { return "iPhone" }
        return width / height > 0.6 ? "iPad" : "iPhone"
    }

    /// `destinations` in the app's `order`, any it does not know after, by name.
    static func ordered(_ destinations: [String], by order: [String]) -> [String] {
        destinations.sorted { a, b in
            let placeA = order.firstIndex(of: a) ?? order.count, placeB = order.firstIndex(of: b) ?? order.count
            return placeA != placeB ? placeA < placeB : a < b
        }
    }

    /// Whether `a` comes before `b`: by kind, folder, appearance, then the app's order of destinations.
    private static func before(_ a: Shot, _ b: Shot, order: [String]) -> Bool {
        let kinds = ["iPhone": 0, "iPad": 1, "Mac": 2]
        let kindA = kinds[a.kind] ?? 3, kindB = kinds[b.kind] ?? 3
        if kindA != kindB { return kindA < kindB }
        if a.folder != b.folder { return a.folder < b.folder }
        if a.appearance != b.appearance { return a.appearance == .light }
        let placeA = order.firstIndex(of: a.destination) ?? order.count, placeB = order.firstIndex(of: b.destination) ?? order.count
        if placeA != placeB { return placeA < placeB }
        return a.destination < b.destination
    }
}
