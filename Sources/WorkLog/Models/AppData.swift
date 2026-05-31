import Foundation

struct AppData: Codable {
    var workExperiences: [WorkExperience] = []
    var interviewOpportunities: [InterviewOpportunity] = []
    var documents: [DocumentRecord] = []
    var dashboardInsightCache: DashboardInsightCache?
    var lastBackupDate: Date?
    var lastBackupPath: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct DashboardInsightCache: Codable, Equatable {
    var taskSnapshotHash: String = ""
    var insightText: String = ""
    var generatedAt: Date = Date()
    var taskCount: Int = 0
}
