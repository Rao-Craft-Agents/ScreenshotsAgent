//  WHAT: The contact sheet: every screen of a call on one image, a row a device in one appearance, a column a
//        destination, each row and screen labelled; what a design review looks at first and a README opens with.
//  PIN:  DRAWN WITH WHAT THE MAC HAS. CoreGraphics, ImageIO and CoreText: no window, no main thread, no resource.
//  PIN:  THE SCREEN'S OWN SHAPE. A simulator's screenshot carries its rounded corners as transparency, so the sheet
//        draws each as the device shows it, with a soft shadow, on a neutral ground that suits light and dark.

import CoreGraphics
import CoreText
import Foundation
import ImageIO

struct ContactSheet {
    /// One row: a device in one appearance, its screens in destination order.
    struct Row: Sendable, Equatable {
        var title: String
        var shots: [Shot]
    }

    /// The app's name, over everything.
    var title: String
    /// One line under it: how many screens, on what, in which appearances.
    var subtitle: String
    var rows: [Row]
    /// Each screen's height, in pixels.
    var screenHeight: CGFloat = 640
    /// The most screens on one line of a row; more wrap.
    var columns = 6

    private let margin: CGFloat = 72
    private let gap: CGFloat = 36
    private let rowGap: CGFloat = 60

    /// The shots grouped into rows, a device and appearance each, in the order they were captured.
    static func rows(_ shots: [Shot]) -> [Row] {
        var rows: [Row] = []
        for shot in shots {
            let title = "\(shot.device) · \(shot.appearance.title)"
            if let index = rows.firstIndex(where: { $0.title == title }) {
                rows[index].shots.append(shot)
            } else {
                rows.append(Row(title: title, shots: [shot]))
            }
        }
        return rows
    }

    /// The sheet as a PNG. Throws when an image cannot be read or the sheet cannot be encoded.
    func render() throws -> Data {
        let titleFont = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 46, nil)
        let subtitleFont = CTFontCreateWithName("HelveticaNeue" as CFString, 26, nil)
        let rowFont = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 28, nil)
        let captionFont = CTFontCreateWithName("HelveticaNeue" as CFString, 24, nil)

        // Every image read and sized first: the sheet's size follows from them.
        var lines: [(title: String?, cells: [(image: CGImage, width: CGFloat, caption: String)])] = []
        for row in rows {
            var cells: [(image: CGImage, width: CGFloat, caption: String)] = []
            for shot in row.shots {
                guard let source = CGImageSourceCreateWithURL(shot.staged as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.height > 0 else {
                    throw ContactSheetError.unreadable(shot.relative)
                }
                let width = (CGFloat(image.width) / CGFloat(image.height) * screenHeight).rounded()
                cells.append((image, width, Caption.title(of: shot.destination)))
            }
            for start in stride(from: 0, to: cells.count, by: max(columns, 1)) {
                lines.append((start == 0 ? row.title : nil, Array(cells[start..<min(start + columns, cells.count)])))
            }
        }
        let rowLabel: CGFloat = 44, captionSpace: CGFloat = 50
        let header: CGFloat = 60 + 40 + 44
        let contentWidth = lines.map { line in line.cells.reduce(0) { $0 + $1.width } + gap * CGFloat(max(line.cells.count - 1, 0)) }.max() ?? 0
        let width = Int((margin * 2 + max(contentWidth, 900)).rounded())
        var height = margin + header
        for line in lines { height += (line.title == nil ? 0 : rowLabel) + screenHeight + captionSpace + rowGap }
        height += margin - rowGap
        let pixelHeight = Int(height.rounded())

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ContactSheetError.unencodable }
        let sheetHeight = CGFloat(pixelHeight)
        context.setFillColor(CGColor(srgbRed: 0.955, green: 0.955, blue: 0.965, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: pixelHeight))
        let primary = CGColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        let secondary = CGColor(srgbRed: 0.42, green: 0.42, blue: 0.45, alpha: 1)

        // Positions are measured from the top; CoreGraphics counts from the bottom, so each is turned on the way in.
        var top = margin
        draw(title, font: titleFont, color: primary, x: margin, top: top, in: context, sheetHeight: sheetHeight, width: CGFloat(width) - margin * 2)
        top += 60
        draw(subtitle, font: subtitleFont, color: secondary, x: margin, top: top, in: context, sheetHeight: sheetHeight, width: CGFloat(width) - margin * 2)
        top += 40 + 44
        for line in lines {
            if let title = line.title {
                draw(title, font: rowFont, color: primary, x: margin, top: top, in: context, sheetHeight: sheetHeight, width: CGFloat(width) - margin * 2)
                top += rowLabel
            }
            var x = margin
            for cell in line.cells {
                let frame = CGRect(x: x, y: sheetHeight - top - screenHeight, width: cell.width, height: screenHeight)
                context.saveGState()
                context.setShadow(offset: CGSize(width: 0, height: -8), blur: 28, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.18))
                context.interpolationQuality = .high
                context.draw(cell.image, in: frame)
                context.restoreGState()
                draw(cell.caption, font: captionFont, color: secondary, x: x, top: top + screenHeight + 14, in: context, sheetHeight: sheetHeight,
                     width: cell.width, centered: true)
                x += cell.width + gap
            }
            top += screenHeight + captionSpace + rowGap
        }

        guard let image = context.makeImage() else { throw ContactSheetError.unencodable }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else {
            throw ContactSheetError.unencodable
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ContactSheetError.unencodable }
        return data as Data
    }

    /// One line of text whose top is `top` pixels from the sheet's top, cut with an ellipsis to `width`.
    private func draw(_ text: String, font: CTFont, color: CGColor, x: CGFloat, top: CGFloat, in context: CGContext, sheetHeight: CGFloat,
                      width: CGFloat, centered: Bool = false) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let full = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let ellipsis = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: attributes))
        let line = CTLineCreateTruncatedLine(full, Double(width), .end, ellipsis) ?? full
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let measured = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        context.textPosition = CGPoint(x: centered ? x + max(0, (width - measured) / 2) : x, y: sheetHeight - top - ascent)
        CTLineDraw(line, context)
    }
}
