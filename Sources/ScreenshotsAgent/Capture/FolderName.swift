import Foundation

/// A name made safe for a folder or a file and for a Markdown link: letters and digits kept, anything else one dash.
/// `iPad Pro 13-inch (M5)` is `iPad-Pro-13-inch-M5`.
enum FolderName {
    static func of(_ name: String) -> String {
        var result = ""
        var dash = false
        for character in name {
            if character.isASCII, character.isLetter || character.isNumber || character == "_" {
                if dash, !result.isEmpty { result.append("-") }
                result.append(character)
                dash = false
            } else {
                dash = true
            }
        }
        return result.isEmpty ? "screen" : result
    }
}
