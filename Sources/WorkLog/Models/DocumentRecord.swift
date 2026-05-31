import Foundation

enum DocumentKind: String, CaseIterable, Codable, Identifiable {
    case resume = "Resume"
    case offerLetter = "Offer Letter"
    case relievingLetter = "Relieving Letter"
    case experienceLetter = "Experience Letter"
    case certificate = "Certificate"
    case salary = "Salary"
    case other = "Other"

    var id: String { rawValue }
}

struct DocumentRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var kind: DocumentKind = .other
    var version: String = ""
    var company: String = ""
    var notes: String = ""
    var originalFileName: String = ""
    var storedFileName: String = ""
    var fileSizeBytes: Int64 = 0
    var fileCreatedAt: Date?
    var fileModifiedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var displayFileName: String {
        let raw = name.isBlank ? originalFileName : name
        return raw.isBlank ? originalFileName : raw
    }

    var searchText: String {
        [
            displayFileName,
            kind.rawValue,
            version,
            company,
            notes,
            originalFileName
        ]
        .joined(separator: " ")
    }
}
