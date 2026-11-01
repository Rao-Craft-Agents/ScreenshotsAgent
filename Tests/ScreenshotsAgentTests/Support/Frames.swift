import CoreGraphics
import Foundation
import ImageIO

/// PNGs drawn for tests: a screen with a status bar, blank (the launch screen) or with a page's marks on it.
enum Frames {
    /// A phone-shaped frame, light or dark: a status bar at the top, and a page's title and rows placed by `page`, so
    /// two pages never draw alike; with no page, blank, or a `logo` in the middle.
    static func screen(page: String? = nil, dark: Bool, width: Int = 120, height: Int = 260, logo: Bool = false) -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let ground: CGFloat = dark ? 0 : 1, ink: CGFloat = dark ? 1 : 0
        context.setFillColor(CGColor(srgbRed: ground, green: ground, blue: ground, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(srgbRed: ink, green: ink, blue: ink, alpha: 1))
        // The status bar: the clock and the battery, in the top twentieth.
        context.fill(CGRect(x: 8, y: height - 10, width: 18, height: 5))
        context.fill(CGRect(x: width - 22, y: height - 10, width: 14, height: 5))
        if let page {
            let seed = page.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            context.fill(CGRect(x: 8, y: height - 40, width: 30 + seed % 60, height: 10))
            for row in 0..<(2 + seed % 5) {
                context.fill(CGRect(x: 8, y: height - 70 - row * 22, width: width - 16 - (seed * (row + 1)) % 40, height: 6))
            }
        }
        if page == nil, logo {
            // A boot logo or a launch screen's mark: a small shape in the middle and nothing else.
            context.fill(CGRect(x: width / 2 - 8, y: height / 2 - 10, width: 16, height: 20))
        }
        let image = context.makeImage()!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
