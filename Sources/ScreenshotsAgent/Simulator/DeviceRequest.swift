import Foundation

/// One entry of a call's `devices`: a family's newest simulator, a simulator by name or UDID, or the Mac app.
enum DeviceRequest: Sendable, Equatable {
    /// The newest installed simulator of a family: `iPhone`, `iPad`.
    case newest(String)
    /// A simulator by its name or UDID: `iPhone 18 Pro`.
    case named(String)
    /// The app's Mac build, captured in a window on this Mac.
    case mac

    /// What a call asks for when it names no device: an iPhone and an iPad.
    static let standard: [DeviceRequest] = [.newest("iPhone"), .newest("iPad")]

    /// Reads one entry: `iPhone` and `iPad` (any case) are a family; `Mac`, `macOS` and `My Mac` are the Mac app.
    static func parse(_ text: String) -> DeviceRequest {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        switch trimmed.lowercased() {
        case "iphone": return .newest("iPhone")
        case "ipad": return .newest("iPad")
        case "mac", "macos", "my mac", "mac app": return .mac
        default: return .named(trimmed)
        }
    }
}
