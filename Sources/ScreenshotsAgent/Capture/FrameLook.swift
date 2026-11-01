//  WHAT: What a captured frame looks like at a glance: whether it is blank (one colour from under the status bar to
//        above the home indicator, a small mark in the middle aside), which is what a launch screen and the boot logo
//        are, and a frame is never settled on; and whether it is dark.
//  PIN:  A SPLASH HOLDS STILL. A launch screen shows for a second or more while the app starts, and a booting device
//        shows its logo after `bootstatus` says it is done, so two looks in a row can match on either; a settle that
//        took one for the app would capture every destination as the same splash.

import CoreGraphics
import Foundation
import ImageIO

enum FrameLook {
    /// Whether `png` is one colour, give or take `tolerance` a channel: the top tenth (the status bar, a window's
    /// title bar), the bottom twelfth (the home indicator), the transparent corners and a mark in the middle (a third
    /// of each side, where a logo sits) left out.
    static func isBlank(_ png: Data, tolerance: Int = 4) -> Bool {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return false }
        let width = 24
        let height = max(8, Int((Double(image.height) / Double(max(image.width, 1)) * Double(width)).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return false }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        // A bitmap context's memory holds the top row first: the top tenth and the bottom twelfth are left out.
        let low = Int(Double(height) * 0.10), high = Int(Double(height) * 0.92)
        let mark = (columns: Int(Double(width) * 0.3)..<Int(Double(width) * 0.7), rows: Int(Double(height) * 0.35)..<Int(Double(height) * 0.65))
        var first: (Int, Int, Int)?
        for row in low..<max(low + 1, high) {
            for column in 1..<(width - 1) where !(mark.rows.contains(row) && mark.columns.contains(column)) {
                let offset = (row * width + column) * 4
                guard pixels[offset + 3] > 250 else { continue }
                let pixel = (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
                guard let reference = first else { first = pixel; continue }
                if abs(pixel.0 - reference.0) > tolerance || abs(pixel.1 - reference.1) > tolerance || abs(pixel.2 - reference.2) > tolerance {
                    return false
                }
            }
        }
        return first != nil
    }

    /// Whether `png` is mostly dark: the mean brightness of its middle under a third. How a dark capture is checked.
    static func isDark(_ png: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 16, height: 32, bitsPerComponent: 8, bytesPerRow: 64, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 32))
        guard let data = context.data else { return false }
        let pixels = data.bindMemory(to: UInt8.self, capacity: 16 * 32 * 4)
        var total = 0, count = 0
        for row in 3..<29 {
            for column in 1..<15 {
                let offset = (row * 16 + column) * 4
                guard pixels[offset + 3] > 250 else { continue }
                total += Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])
                count += 3
            }
        }
        return count > 0 && Double(total) / Double(count) < 255.0 / 3
    }
}
