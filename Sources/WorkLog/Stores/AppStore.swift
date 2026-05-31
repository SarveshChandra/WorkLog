import AppKit
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var data: AppData
    @Published var selectedSection: AppSection = .dashboard
    @Published var selectedWorkID: UUID?
    @Published var selectedOpportunityID: UUID?
    @Published var selectedDocumentID: UUID?
    @Published var interviewFilter: InterviewFilter = .all
    @Published var statusMessage: String = ""
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.themeDefaultsKey)
        }
    }

    private let persistence: DataPersistenceService
    private let backupService: BackupService
    private let documentService: DocumentStorageService
    private static let themeDefaultsKey = "WorkLog.theme"

    init() {
        let persistence = DataPersistenceService()
        self.persistence = persistence
        self.backupService = BackupService(fallbackBaseDirectory: persistence.appSupportDirectory)
        self.documentService = DocumentStorageService(baseDirectory: persistence.appSupportDirectory)
        self.theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: Self.themeDefaultsKey) ?? "") ?? .system

        do {
            self.data = try persistence.load()
            self.statusMessage = "Loaded \(AppDateFormatters.statusDateTime.string(from: Date()))"
        } catch {
            self.data = AppData()
            self.statusMessage = "Started with a new data file. \(error.localizedDescription)"
        }

        seedDemoDataIfNeeded()
        migrateDemoWorkExperienceFieldsIfNeeded()
        migrateDemoInterviewFieldsIfNeeded()
        addMissingDemoSamplesIfNeeded()
        migrateCooldownPeriodsIfNeeded()
        syncDiskDocumentsIfNeeded()
        refreshDocumentMetadataIfNeeded()
        performDailyBackupIfNeeded()
    }

    var dataFilePath: String {
        persistence.dataFileURL.path
    }

    var documentsDirectoryPath: String {
        documentService.documentsDirectory.path
    }

    var backupDirectoryPath: String {
        let roots = backupService.backupRoots()
        guard !roots.isEmpty else { return "Unavailable" }
        return roots.map(\.path).joined(separator: "\n")
    }

    func addWorkExperience() {
        let entry = WorkExperience()
        data.workExperiences.insert(entry, at: 0)
        selectedWorkID = entry.id
        selectedSection = .workExperience
        save()
    }

    func deleteSelectedWorkExperience() {
        guard let selectedWorkID else { return }
        data.workExperiences.removeAll { $0.id == selectedWorkID }
        self.selectedWorkID = nil
        save()
    }

    func bindingForWorkExperience(id: UUID) -> Binding<WorkExperience>? {
        Binding(
            get: {
                self.data.workExperiences.first { $0.id == id } ?? WorkExperience()
            },
            set: { newValue in
                guard let index = self.data.workExperiences.firstIndex(where: { $0.id == id }) else { return }
                var updated = newValue
                updated.updatedAt = Date()
                self.data.workExperiences[index] = updated
                self.save()
            }
        )
    }

    func filteredWorkExperiences(search: String) -> [WorkExperience] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = data.workExperiences.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.date > rhs.date
        }

        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.searchText.localizedCaseInsensitiveContains(query) }
    }

    func cachedDashboardInsight(for taskSnapshotHash: String) -> DashboardInsightCache? {
        guard let cache = data.dashboardInsightCache,
              cache.taskSnapshotHash == taskSnapshotHash,
              !cache.insightText.isBlank else {
            return nil
        }
        return cache
    }

    func cacheDashboardInsight(taskSnapshotHash: String, insightText: String, taskCount: Int, generatedAt: Date = Date()) {
        data.dashboardInsightCache = DashboardInsightCache(
            taskSnapshotHash: taskSnapshotHash,
            insightText: insightText,
            generatedAt: generatedAt,
            taskCount: taskCount
        )

        do {
            try persistence.save(data)
            statusMessage = "Updated Dashboard insights at \(AppDateFormatters.statusDateTime.string(from: generatedAt))"
        } catch {
            statusMessage = "Dashboard insight cache failed: \(error.localizedDescription)"
        }
    }

    func addInterviewOpportunity() {
        var opportunity = InterviewOpportunity()
        opportunity.stage = ""
        data.interviewOpportunities.insert(opportunity, at: 0)
        selectedOpportunityID = opportunity.id
        selectedSection = .interviewTracker
        save()
    }

    func deleteSelectedInterviewOpportunity() {
        guard let selectedOpportunityID else { return }
        data.interviewOpportunities.removeAll { $0.id == selectedOpportunityID }
        self.selectedOpportunityID = nil
        save()
    }

    func bindingForOpportunity(id: UUID) -> Binding<InterviewOpportunity>? {
        Binding(
            get: {
                self.data.interviewOpportunities.first { $0.id == id } ?? InterviewOpportunity()
            },
            set: { newValue in
                guard let index = self.data.interviewOpportunities.firstIndex(where: { $0.id == id }) else { return }
                var updated = newValue
                updated.updatedAt = Date()
                updated.normalizeDerivedFields()
                self.data.interviewOpportunities[index] = updated
                self.save()
            }
        )
    }

    func filteredOpportunities(search: String) -> [InterviewOpportunity] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let latestOpportunityIDsByCompany = latestOpportunityIDsByCompany()

        let filteredByView = data.interviewOpportunities.filter { opportunity in
            switch interviewFilter {
            case .all:
                true
            case .active:
                !opportunity.effectiveStatusIsClosed
            case .eligibleAgain:
                isEligibleAgainLatestOpportunity(opportunity, latestOpportunityIDsByCompany: latestOpportunityIDsByCompany)
            case .closed:
                opportunity.effectiveStatusIsClosed
            }
        }

        let filteredBySearch = query.isEmpty
            ? filteredByView
            : filteredByView.filter { $0.searchText.localizedCaseInsensitiveContains(query) }

        return filteredBySearch.sorted { lhs, rhs in
            switch interviewFilter {
            case .all, .active:
                return Self.sortByActionThenActivity(lhs, rhs)
            case .eligibleAgain:
                return Self.sortByEligibilityThenActivity(lhs, rhs)
            case .closed:
                return Self.sortByActivity(lhs, rhs)
            }
        }
    }

    private static func sortByActionThenActivity(_ lhs: InterviewOpportunity, _ rhs: InterviewOpportunity) -> Bool {
        switch (lhs.nextActionDueDate, rhs.nextActionDueDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return sortByActivity(lhs, rhs)
        }
    }

    private static func sortByEligibilityThenActivity(_ lhs: InterviewOpportunity, _ rhs: InterviewOpportunity) -> Bool {
        switch (lhs.cooldownEligibleDate, rhs.cooldownEligibleDate) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return sortByActivity(lhs, rhs)
        }
    }

    private static func sortByActivity(_ lhs: InterviewOpportunity, _ rhs: InterviewOpportunity) -> Bool {
        if lhs.calculatedLastActivityDate != rhs.calculatedLastActivityDate {
            return lhs.calculatedLastActivityDate > rhs.calculatedLastActivityDate
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    private func isEligibleAgainLatestOpportunity(
        _ opportunity: InterviewOpportunity,
        latestOpportunityIDsByCompany: [String: UUID]
    ) -> Bool {
        guard opportunity.isEligibleAgain else { return false }
        guard opportunity.canAppearInEligibleAgain else { return false }

        let companyKey = Self.normalizedCompanyKey(opportunity.company)
        guard !companyKey.isEmpty else { return true }

        return latestOpportunityIDsByCompany[companyKey] == opportunity.id
    }

    private func latestOpportunityIDsByCompany() -> [String: UUID] {
        var latestByCompany: [String: InterviewOpportunity] = [:]

        for opportunity in data.interviewOpportunities {
            let companyKey = Self.normalizedCompanyKey(opportunity.company)
            guard !companyKey.isEmpty else { continue }

            guard let currentLatest = latestByCompany[companyKey] else {
                latestByCompany[companyKey] = opportunity
                continue
            }

            if Self.isMoreRecentOpportunity(opportunity, than: currentLatest) {
                latestByCompany[companyKey] = opportunity
            }
        }

        return latestByCompany.mapValues(\.id)
    }

    private static func normalizedCompanyKey(_ company: String) -> String {
        company
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private static func isMoreRecentOpportunity(_ lhs: InterviewOpportunity, than rhs: InterviewOpportunity) -> Bool {
        if lhs.calculatedLastActivityDate != rhs.calculatedLastActivityDate {
            return lhs.calculatedLastActivityDate > rhs.calculatedLastActivityDate
        }

        if lhs.appliedDate != rhs.appliedDate {
            return lhs.appliedDate > rhs.appliedDate
        }

        return lhs.updatedAt > rhs.updatedAt
    }

    func importDocument() {
        let panel = NSOpenPanel()
        panel.title = "Import Documents"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        var imported: [DocumentRecord] = []
        for url in panel.urls {
            do {
                imported.append(try documentService.importDocument(from: url))
            } catch {
                statusMessage = "Could not import \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }

        guard !imported.isEmpty else { return }
        data.documents.insert(contentsOf: imported, at: 0)
        selectedDocumentID = imported.first?.id
        selectedSection = .documents
        save()
    }

    func deleteSelectedDocument() {
        guard let selectedDocumentID,
              let document = data.documents.first(where: { $0.id == selectedDocumentID }) else { return }

        do {
            let fileURL = documentService.fileURL(for: document)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }

            data.documents.removeAll { $0.id == selectedDocumentID }
            self.selectedDocumentID = nil
            save()
        } catch {
            statusMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func bindingForDocument(id: UUID) -> Binding<DocumentRecord>? {
        Binding(
            get: {
                self.data.documents.first { $0.id == id } ?? DocumentRecord()
            },
            set: { newValue in
                guard let index = self.data.documents.firstIndex(where: { $0.id == id }) else { return }
                var updated = newValue
                let userVersion = updated.version
                updated.updatedAt = Date()
                self.documentService.persistVersionMetadata(userVersion, for: updated)
                updated = self.documentService.refreshMetadata(for: updated, loadVersionMetadata: !userVersion.isBlank)
                updated.version = userVersion
                self.data.documents[index] = updated
                self.save()
            }
        )
    }

    func renameDocument(id: UUID, to newFileName: String) {
        guard let index = data.documents.firstIndex(where: { $0.id == id }) else { return }
        do {
            let renamed = try documentService.renameDocument(data.documents[index], to: newFileName)
            data.documents[index] = renamed
            save()
        } catch {
            statusMessage = "Rename failed: \(error.localizedDescription)"
        }
    }

    func filteredDocuments(search: String) -> [DocumentRecord] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = data.documents.sorted { lhs, rhs in
            let leftCompany = lhs.company.trimmingCharacters(in: .whitespacesAndNewlines)
            let rightCompany = rhs.company.trimmingCharacters(in: .whitespacesAndNewlines)

            // Group by company (non-empty first), then sort by modified/created dates.
            switch (leftCompany.isEmpty, rightCompany.isEmpty) {
            case (false, true):
                return true
            case (true, false):
                return false
            default:
                break
            }

            if leftCompany != rightCompany {
                return leftCompany.localizedCaseInsensitiveCompare(rightCompany) == .orderedAscending
            }

            let leftModified = lhs.fileModifiedAt ?? Date.distantPast
            let rightModified = rhs.fileModifiedAt ?? Date.distantPast
            if leftModified != rightModified {
                return leftModified > rightModified
            }

            let leftCreated = lhs.fileCreatedAt ?? Date.distantPast
            let rightCreated = rhs.fileCreatedAt ?? Date.distantPast
            if leftCreated != rightCreated {
                return leftCreated > rightCreated
            }

            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }

            return lhs.displayFileName.localizedCaseInsensitiveCompare(rhs.displayFileName) == .orderedAscending
        }

        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.searchText.localizedCaseInsensitiveContains(query) }
    }

    func openDocument(_ document: DocumentRecord) {
        documentService.open(document)
    }

    func revealDocument(_ document: DocumentRecord) {
        documentService.reveal(document)
    }

    func fileURL(for document: DocumentRecord) -> URL {
        documentService.fileURL(for: document)
    }

    private func refreshDocumentMetadataIfNeeded() {
        guard !data.documents.isEmpty else { return }
        var didChange = false
        for index in data.documents.indices {
            let refreshed = documentService.refreshMetadata(for: data.documents[index])
            if refreshed != data.documents[index] {
                data.documents[index] = refreshed
                didChange = true
            }
        }
        if didChange {
            save()
        }
    }

    private func syncDiskDocumentsIfNeeded() {
        let storedFileNames = Set(data.documents.map(\.storedFileName))
        do {
            let recovered = try documentService.recordsForExistingFiles(excluding: storedFileNames)
            guard !recovered.isEmpty else { return }
            data.documents.append(contentsOf: recovered)
            statusMessage = "Added \(recovered.count) document file\(recovered.count == 1 ? "" : "s") found on disk."
            save()
        } catch {
            statusMessage = "Document folder sync failed: \(error.localizedDescription)"
        }
    }

    func backupNow() {
        do {
            let result = try backupService.createBackup(data: data, documentsDirectory: documentService.documentsDirectory)
            data.lastBackupDate = result.date
            data.lastBackupPath = result.backupURLs.map(\.path).joined(separator: "\n")
            try persistence.save(data)
            statusMessage = "Backed up to \(result.usedICloudDrive ? "both iCloud backup paths" : "local backup folder") at \(AppDateFormatters.statusDateTime.string(from: result.date))"
        } catch {
            statusMessage = "Backup failed: \(error.localizedDescription)"
        }
    }

    func restoreLatestBackup() {
        let alert = NSAlert()
        alert.messageText = "Restore latest backup?"
        alert.informativeText = "This will replace the app data and mirror the Documents folder from the newest Work Log backup. Current document files not present in that backup will be removed."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            guard let latestBackup = try backupService.latestBackup() else {
                statusMessage = "No backup found."
                return
            }
            data = try backupService.restore(from: latestBackup, documentsDirectory: documentService.documentsDirectory)
            syncDiskDocumentsIfNeeded()
            refreshDocumentMetadataIfNeeded()
            try persistence.save(data)
            statusMessage = "Restored \(latestBackup.lastPathComponent)"
        } catch {
            statusMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func exportJSON() {
        let panel = NSSavePanel()
        panel.title = "Export Work Log Data"
        panel.nameFieldStringValue = "work-log-export.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoded = try JSONCoders.encoder.encode(data)
            try encoded.write(to: url, options: [.atomic])
            statusMessage = "Exported JSON to \(url.path)"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func openBackupFolder() {
        if let url = try? backupService.backupRoot() {
            NSWorkspace.shared.open(url)
        }
    }

    func openDataFolder() {
        NSWorkspace.shared.open(persistence.appSupportDirectory)
    }

    private func save() {
        data.updatedAt = Date()
        do {
            try persistence.save(data)
            statusMessage = "Saved \(AppDateFormatters.statusDateTime.string(from: Date()))"
            performDailyBackupIfNeeded()
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func performDailyBackupIfNeeded() {
        do {
            guard let result = try backupService.backupIfNeeded(data: data, documentsDirectory: documentService.documentsDirectory) else {
                return
            }
            data.lastBackupDate = result.date
            data.lastBackupPath = result.backupURLs.map(\.path).joined(separator: "\n")
            try persistence.save(data)
            statusMessage = "Daily backup completed at \(AppDateFormatters.statusDateTime.string(from: result.date))"
        } catch {
            statusMessage = "Daily backup failed: \(error.localizedDescription)"
        }
    }

    private func seedDemoDataIfNeeded() {
        let hasNoRecords = data.workExperiences.isEmpty
            && data.interviewOpportunities.isEmpty
            && data.documents.isEmpty

        guard hasNoRecords else {
            try? documentService.createDemoDocumentsIfNeeded(for: data.documents)
            return
        }

        data = DemoDataFactory.makeData()
        selectedWorkID = data.workExperiences.first?.id

        do {
            try documentService.createDemoDocumentsIfNeeded(for: data.documents)
            try persistence.save(data)
            statusMessage = "Loaded demo data for testing."
        } catch {
            try? persistence.save(data)
            statusMessage = "Loaded demo rows, but demo documents failed: \(error.localizedDescription)"
        }
    }

    private func migrateCooldownPeriodsIfNeeded() {
        var changed = false

        for index in data.interviewOpportunities.indices {
            guard data.interviewOpportunities[index].cooldownPeriodDays == nil,
                  let cooldownUntil = data.interviewOpportunities[index].cooldownUntil else {
                continue
            }

            let start = Calendar.current.startOfDay(for: data.interviewOpportunities[index].lastActivityDate)
            let end = Calendar.current.startOfDay(for: cooldownUntil)
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0

            data.interviewOpportunities[index].cooldownPeriodDays = max(days, 0)
            data.interviewOpportunities[index].cooldownUntil = nil
            changed = true
        }

        if changed {
            do {
                try persistence.save(data)
                statusMessage = "Migrated cooldown dates to cooldown periods."
            } catch {
                statusMessage = "Cooldown migration failed: \(error.localizedDescription)"
            }
        }
    }

    private func addMissingDemoSamplesIfNeeded() {
        let hasExistingDemoData = data.workExperiences.contains { work in
            work.company == "Acme Systems"
                && [
                    "Reduced dashboard load time",
                    "Built release checklist automation",
                    "Documented onboarding flow"
                ].contains(work.task)
        } || data.interviewOpportunities.contains { opportunity in
            [
                "Northstar Labs",
                "Cloudlane",
                "FinGrid",
                "DesignOps Studio"
            ].contains(opportunity.company)
        }

        guard hasExistingDemoData else { return }

        let latestDemoData = DemoDataFactory.makeData()
        let existingTasks = Set(data.workExperiences.map(\.task))
        let missingWorkExperiences = latestDemoData.workExperiences.filter { !existingTasks.contains($0.task) }

        let existingOpportunities = Set(data.interviewOpportunities.map { "\($0.company)|\($0.role)" })
        let missingOpportunities = latestDemoData.interviewOpportunities.filter {
            !existingOpportunities.contains("\($0.company)|\($0.role)")
        }

        let existingDocuments = Set(data.documents.map(\.storedFileName))
        let missingDocuments = latestDemoData.documents.filter { !existingDocuments.contains($0.storedFileName) }

        guard !missingWorkExperiences.isEmpty || !missingOpportunities.isEmpty || !missingDocuments.isEmpty else { return }

        data.workExperiences.append(contentsOf: missingWorkExperiences)
        data.interviewOpportunities.append(contentsOf: missingOpportunities)
        data.documents.append(contentsOf: missingDocuments)

        do {
            try documentService.createDemoDocumentsIfNeeded(for: data.documents)
            try persistence.save(data)
            statusMessage = "Added more demo data for testing."
        } catch {
            statusMessage = "Could not add new demo data: \(error.localizedDescription)"
        }
    }

    private func migrateDemoWorkExperienceFieldsIfNeeded() {
        var changed = false

        for index in data.workExperiences.indices {
            let task = data.workExperiences[index].task

            guard data.workExperiences[index].company.isBlank,
                  data.workExperiences[index].designation.isBlank,
                  data.workExperiences[index].role.isBlank else {
                continue
            }

            switch task {
            case "Reduced dashboard load time":
                data.workExperiences[index].company = "Acme Systems"
                data.workExperiences[index].designation = "Senior Software Engineer"
                data.workExperiences[index].role = "macOS Platform Engineer"
                data.workExperiences[index].tags = "Performance Improvement, High Impact, Cross-team Work"
                data.workExperiences[index].situation = "Weekly reporting users were waiting too long for the dashboard to become usable."
                data.workExperiences[index].action = "Profiled the load path, removed over-fetching, added pagination, and cached stable summary data."
                changed = true
            case "Built release checklist automation":
                data.workExperiences[index].company = "Acme Systems"
                data.workExperiences[index].designation = "Software Engineer"
                data.workExperiences[index].role = "Developer Experience Engineer"
                data.workExperiences[index].tags = "Automation, Process Improvement, High Impact"
                data.workExperiences[index].situation = "Release readiness checks were spread across docs, chat, and manual memory."
                data.workExperiences[index].action = "Built a lightweight checklist validator for release owners and connected it to CI checks."
                changed = true
            case "Documented onboarding flow":
                data.workExperiences[index].company = "Acme Systems"
                data.workExperiences[index].designation = "Software Engineer"
                data.workExperiences[index].role = "Product Engineer"
                data.workExperiences[index].tags = "Documentation, Team Enablement"
                data.workExperiences[index].situation = "New engineers had to piece together setup steps from multiple sources."
                data.workExperiences[index].action = "Mapped the onboarding flow, validated it with a new joiner, and documented ownership boundaries."
                changed = true
            default:
                continue
            }
        }

        if changed {
            do {
                try persistence.save(data)
                statusMessage = "Updated demo work logs for the latest Work Experience fields."
            } catch {
                statusMessage = "Work log demo migration failed: \(error.localizedDescription)"
            }
        }
    }

    private func migrateDemoInterviewFieldsIfNeeded() {
        var changed = false

        for index in data.interviewOpportunities.indices {
            switch data.interviewOpportunities[index].company {
            case "Northstar Labs":
                if data.interviewOpportunities[index].applicationLink.isBlank {
                    data.interviewOpportunities[index].applicationLink = "https://www.linkedin.com/jobs/view/northstar-labs-senior-macos-engineer"
                    changed = true
                }
                if data.interviewOpportunities[index].jobDescription.isBlank {
                    data.interviewOpportunities[index].jobDescription = "Own native macOS features for an analytics product, improve table-heavy workflows, and collaborate with product teams on performance-sensitive UI."
                    changed = true
                }
                if data.interviewOpportunities[index].pocEmail.isBlank {
                    data.interviewOpportunities[index].pocEmail = "priya.s@northstar.example"
                    changed = true
                }
                if data.interviewOpportunities[index].referralEmail.isBlank {
                    data.interviewOpportunities[index].referralEmail = "aarav.mehta@example.com"
                    changed = true
                }
                if data.interviewOpportunities[index].referralStatus == "Referral submitted" {
                    data.interviewOpportunities[index].referralStatus = "Submitted"
                    changed = true
                }
                if data.interviewOpportunities[index].pocNumber.isBlank {
                    data.interviewOpportunities[index].pocNumber = "+91 98765 43210"
                    changed = true
                }
            case "Cloudlane":
                if data.interviewOpportunities[index].applicationLink.isBlank {
                    data.interviewOpportunities[index].applicationLink = "https://www.naukri.com/job-listings-backend-platform-engineer-cloudlane"
                    changed = true
                }
                if data.interviewOpportunities[index].jobDescription.isBlank {
                    data.interviewOpportunities[index].jobDescription = "Build platform APIs and internal services for distributed infrastructure teams, with focus on reliability and operational tooling."
                    changed = true
                }
                if data.interviewOpportunities[index].pocEmail.isBlank {
                    data.interviewOpportunities[index].pocEmail = "careers@cloudlane.example"
                    changed = true
                }
                if data.interviewOpportunities[index].pocNumber.isBlank {
                    data.interviewOpportunities[index].pocNumber = "+91 99887 76655"
                    changed = true
                }
                if data.interviewOpportunities[index].referralStatus.isBlank {
                    data.interviewOpportunities[index].referralStatus = "Not Applicable"
                    changed = true
                }
            case "FinGrid":
                if data.interviewOpportunities[index].applicationLink.isBlank {
                    data.interviewOpportunities[index].applicationLink = "https://jobs.lever.co/fingrid/ios-macos-engineer"
                    changed = true
                }
                if data.interviewOpportunities[index].jobDescription.isBlank {
                    data.interviewOpportunities[index].jobDescription = "Develop regulated financial mobile and desktop workflows with strong data handling, accessibility, and release quality expectations."
                    changed = true
                }
                if data.interviewOpportunities[index].pocEmail.isBlank {
                    data.interviewOpportunities[index].pocEmail = "rohan.p@fingrid.example"
                    changed = true
                }
                if data.interviewOpportunities[index].referralEmail.isBlank {
                    data.interviewOpportunities[index].referralEmail = "neha.kapoor@example.com"
                    changed = true
                }
                if data.interviewOpportunities[index].referralStatus == "Referral used" {
                    data.interviewOpportunities[index].referralStatus = "Accepted"
                    changed = true
                }
                if data.interviewOpportunities[index].pocNumber.isBlank {
                    data.interviewOpportunities[index].pocNumber = "+91 90909 11223"
                    changed = true
                }
            case "DesignOps Studio":
                if data.interviewOpportunities[index].applicationLink.isBlank {
                    data.interviewOpportunities[index].applicationLink = "https://cutshort.io/job/tools-engineer-designops-studio"
                    changed = true
                }
                if data.interviewOpportunities[index].jobDescription.isBlank {
                    data.interviewOpportunities[index].jobDescription = "Build internal tools and design-system automation across native apps, web tooling, and Figma plugin workflows."
                    changed = true
                }
                if data.interviewOpportunities[index].referralStatus.isBlank {
                    data.interviewOpportunities[index].referralStatus = "To Ask"
                    changed = true
                }
                if data.interviewOpportunities[index].nextAction == "Find referral contact" {
                    data.interviewOpportunities[index].nextAction = "Find referral PoC"
                    changed = true
                }
            default:
                continue
            }

            let calculatedSource = data.interviewOpportunities[index].applicationSource
            if data.interviewOpportunities[index].source != calculatedSource {
                data.interviewOpportunities[index].source = calculatedSource
                changed = true
            }
        }

        if changed {
            do {
                try persistence.save(data)
                statusMessage = "Updated demo interview tracker data."
            } catch {
                statusMessage = "Interview demo migration failed: \(error.localizedDescription)"
            }
        }
    }

}
