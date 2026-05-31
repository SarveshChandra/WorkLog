import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case workExperience = "Tasks"
    case interviewTracker = "Interview Tracker"
    case documents = "Documents"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard:
            "chart.bar.doc.horizontal"
        case .workExperience:
            "briefcase"
        case .interviewTracker:
            "person.text.rectangle"
        case .documents:
            "doc.text"
        case .settings:
            "gearshape"
        }
    }
}
