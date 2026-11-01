import Foundation

/// How a person reads a destination's case: `recipes` is `Recipes`, `pinnedPosts` is `Pinned Posts`.
enum Caption {
    static func title(of name: String) -> String {
        var words: [String] = []
        var word = ""
        for character in name {
            if character == "_" || character == "-" || character == " " {
                if !word.isEmpty { words.append(word); word = "" }
            } else if character.isUppercase, let last = word.last, last.isLowercase || last.isNumber {
                words.append(word)
                word = String(character)
            } else {
                word.append(character)
            }
        }
        if !word.isEmpty { words.append(word) }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
