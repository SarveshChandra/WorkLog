import Foundation

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var collapsedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
