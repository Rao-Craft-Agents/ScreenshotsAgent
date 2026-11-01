import Foundation

/// Why a contact sheet could not be made.
enum ContactSheetError: Error, Equatable, CustomStringConvertible {
    /// A screen's PNG could not be read: where it would go.
    case unreadable(String)
    /// The sheet could not be drawn or encoded.
    case unencodable

    var description: String {
        switch self {
        case .unreadable(let path): return "the screenshot \(path) could not be read for the contact sheet"
        case .unencodable: return "the contact sheet could not be drawn"
        }
    }
}
