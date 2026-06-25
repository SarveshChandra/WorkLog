import Foundation

enum DocumentKind: String, CaseIterable, Codable, Identifiable {
    case resume = "Resume"
    case coverLetter = "Cover Letter"
    case offerLetter = "Offer Letter"
    case appointmentLetter = "Appointment Letter"
    case relievingLetter = "Relieving Letter"
    case experienceLetter = "Experience Letter"
    case certificate = "Certificate"
    case salary = "Salary"
    case other = "Other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appointmentLetter:
            return "Joining / Appointment Letter"
        case .salary:
            return "Payslip / Salary"
        default:
            return rawValue
        }
    }
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
        let fallbackStoredName = URL(fileURLWithPath: storedFileName).lastPathComponent
        let raw = name.isBlank ? originalFileName : name
        return raw.isBlank ? fallbackStoredName : raw
    }

    var searchText: String {
        [
            displayFileName,
            kind.displayName,
            kind.rawValue,
            version,
            company,
            notes,
            originalFileName
        ]
        .joined(separator: " ")
    }

    var tableSearchText: String {
        [
            displayFileName,
            kind.displayName,
            kind.rawValue,
            company
        ]
        .joined(separator: " ")
    }
}
