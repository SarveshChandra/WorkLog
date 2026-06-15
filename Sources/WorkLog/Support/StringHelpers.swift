import Foundation

private let workLogPlaceholderDisplayValues: Set<String> = [
    "no backup found.",
    "no company selected",
    "no matching companies",
    "no plan yet",
    "no repeated challenge yet",
    "no skills captured yet",
    "no strong candidate yet",
    "no subtasks",
    "no subtasks yet.",
    "no task data yet",
    "not backed up yet",
    "not set",
    "preparing",
    "preparing insights...",
    "ready",
    "role not set",
    "select tags",
    "unknown"
]

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var collapsedWhitespace: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    var isWorkLogPlaceholderValue: Bool {
        let normalized = collapsedWhitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return false }
        if normalized.hasPrefix("untitled ") {
            return true
        }
        if normalized.hasPrefix("no subtasks yet") {
            return true
        }
        return workLogPlaceholderDisplayValues.contains(normalized)
    }
}
