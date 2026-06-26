import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum InterviewOpportunitySaveError: LocalizedError {
    case roundValidation(String)

    var errorDescription: String? {
        switch self {
        case .roundValidation(let message):
            return message
        }
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published var data: AppData
    @Published var selectedSection: AppSection = .dashboard
    @Published var selectedWorkID: UUID?
    @Published var selectedOpportunityID: UUID?
    @Published var selectedDocumentID: UUID?
    @Published var interviewFilter: InterviewFilter = .all
    @Published var statusMessage: String = ""
    @Published var calendarInterviewImportMessage: String = ""
    @Published var isImportingCalendarInterviews = false
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: Self.themeDefaultsKey)
        }
    }

    private let persistence: DataPersistenceService
    private let backupService: BackupService
    private let documentService: DocumentStorageService
    private let calendarInterviewService = AppleCalendarInterviewService()
    private static let themeDefaultsKey = "WorkLog.theme"

    init() {
        let persistence = DataPersistenceService()
        self.persistence = persistence
        self.backupService = BackupService(fallbackBaseDirectory: persistence.appSupportDirectory)
        self.documentService = DocumentStorageService(baseDirectory: persistence.appSupportDirectory)
        self.theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: Self.themeDefaultsKey) ?? "") ?? .system
        let dataFileExistsAtLaunch = FileManager.default.fileExists(atPath: persistence.dataFileURL.path)

        do {
            self.data = try persistence.load()
            self.statusMessage = "Loaded \(AppDateFormatters.statusDateTime.string(from: Date()))"
        } catch {
            self.data = AppData()
            self.statusMessage = "Started with a new data file. \(error.localizedDescription)"
        }

        seedDemoDataIfNeeded(
            shouldSeedDemoData: Self.shouldSeedDemoDataOnLaunch(
                dataFileExists: dataFileExistsAtLaunch,
                data: data,
                allowsDemoData: AppRuntimeConfiguration.allowsDemoData
            )
        )
        migrateDemoWorkExperienceFieldsIfNeeded()
        migrateDemoInterviewFieldsIfNeeded()
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

    var availableCompanyOptions: [String] {
        Self.availableCompanies(in: data)
    }

    func availableWorkExperienceOptions(for keyPath: KeyPath<WorkExperience, String>) -> [String] {
        Self.availableWorkExperienceOptions(in: data, for: keyPath)
    }

    nonisolated static func availableCompanies(in data: AppData) -> [String] {
        availableNormalizedOptions(data.workExperiences.map(\.company) + data.documents.map(\.company))
    }

    nonisolated static func availableWorkExperienceOptions(
        in data: AppData,
        for keyPath: KeyPath<WorkExperience, String>
    ) -> [String] {
        availableNormalizedOptions(data.workExperiences.map { $0[keyPath: keyPath] })
    }

    nonisolated private static func availableNormalizedOptions(_ values: [String]) -> [String] {
        var uniqueValuesByKey: [String: String] = [:]

        for value in values {
            let normalizedKey = normalizedDropdownOptionKey(value)
            guard !normalizedKey.isEmpty else { continue }
            let displayValue = normalizedDropdownOptionDisplay(value)
            if let existingDisplayValue = uniqueValuesByKey[normalizedKey] {
                uniqueValuesByKey[normalizedKey] = preferredDropdownOptionDisplay(
                    existing: existingDisplayValue,
                    candidate: displayValue
                )
            } else {
                uniqueValuesByKey[normalizedKey] = displayValue
            }
        }

        return uniqueValuesByKey.values.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    nonisolated static func shouldRenameDocumentCompanyDirectory(from oldCompany: String, to newCompany: String) -> Bool {
        let normalizedOldCompany = oldCompany.collapsedWhitespace
        let normalizedNewCompany = newCompany.collapsedWhitespace
        return !normalizedOldCompany.isEmpty
            && !normalizedNewCompany.isEmpty
            && normalizedOldCompany != normalizedNewCompany
    }

    func addWorkExperience() {
        let entry = WorkExperience(usesDateLogic: false)
        data.workExperiences.insert(entry, at: 0)
        selectedWorkID = entry.id
        selectedSection = .workExperience
        save()
    }

    func importWorkExperiences() {
        let panel = NSOpenPanel()
        panel.title = "Import Tasks"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        var imported: [WorkExperience] = []
        for url in panel.urls {
            do {
                imported.append(contentsOf: try TaskImportService.decodeWorkExperiences(from: url))
            } catch {
                statusMessage = "Could not import \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }

        guard !imported.isEmpty else { return }
        data.workExperiences.insert(contentsOf: imported, at: 0)
        selectedWorkID = imported.first?.id
        selectedSection = .workExperience
        save()
        statusMessage = "Imported \(imported.count) task\(imported.count == 1 ? "" : "s")."
    }

    func deleteSelectedWorkExperience() {
        guard let selectedWorkID else { return }
        data.workExperiences.removeAll { $0.id == selectedWorkID }
        self.selectedWorkID = nil
        save()
    }

    func workExperience(id: UUID) -> WorkExperience? {
        data.workExperiences.first { $0.id == id }
    }

    func saveWorkExperienceEdits(id: UUID, draft: WorkExperience) {
        guard let index = data.workExperiences.firstIndex(where: { $0.id == id }) else { return }
        let existing = data.workExperiences[index]
        let updated = Self.updatedWorkExperience(existing: existing, draft: draft)
        data.workExperiences[index] = updated
        save()
    }

    nonisolated static func updatedWorkExperience(
        existing: WorkExperience,
        draft: WorkExperience,
        now: Date = Date()
    ) -> WorkExperience {
        var updated = draft
        updated.id = existing.id
        updated.createdAt = existing.createdAt
        updated.updatedAt = now
        updated.normalizeDateRange()
        updated.normalizePlannerSubtasks()
        return updated
    }

    func filteredWorkExperiences(search: String) -> [WorkExperience] {
        Self.filteredWorkExperiences(in: data.workExperiences, search: search)
    }

    nonisolated static func filteredWorkExperiences(in workExperiences: [WorkExperience], search: String) -> [WorkExperience] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return workExperiences }
        return workExperiences.filter { $0.tableSearchText.localizedCaseInsensitiveContains(query) }
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

    func importInterviewsFromAppleCalendar() {
        guard !isImportingCalendarInterviews else { return }
        isImportingCalendarInterviews = true
        calendarInterviewImportMessage = "Reading interview events from Apple Calendar..."
        statusMessage = calendarInterviewImportMessage

        calendarInterviewService.fetchInterviewEvents { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isImportingCalendarInterviews = false

                switch result {
                case .failure(let error):
                    let message = "Calendar import failed: \(error.localizedDescription)"
                    self.calendarInterviewImportMessage = message
                    self.statusMessage = message
                case .success(let events):
                    self.finishCalendarInterviewImport(events)
                }
            }
        }
    }

    private func finishCalendarInterviewImport(_ events: [CalendarInterviewEvent]) {
        guard !events.isEmpty else {
            let message = "No interview events were found in Apple Calendars between 2000 and 2100."
            calendarInterviewImportMessage = message
            statusMessage = message
            return
        }

        let result = CalendarInterviewImporter.merge(
            events: events,
            into: data.interviewOpportunities
        )
        let changedRoundCount = result.importedRoundCount + result.updatedRoundCount

        guard changedRoundCount > 0 else {
            let message = "Found \(result.matchedEventCount) Calendar interview event\(result.matchedEventCount == 1 ? "" : "s"); all are already imported."
            calendarInterviewImportMessage = message
            statusMessage = message
            return
        }

        do {
            let backup = try backupService.createBackup(
                data: data,
                documentsDirectory: documentService.documentsDirectory
            )
            data.lastBackupDate = backup.date
            data.lastBackupPath = backup.backupURLs.map(\.path).joined(separator: "\n")
        } catch {
            let message = "Calendar import stopped because the safety backup failed: \(error.localizedDescription)"
            calendarInterviewImportMessage = message
            statusMessage = message
            return
        }

        data.interviewOpportunities = result.opportunities
        selectedOpportunityID = result.importedOpportunityIDs.first
        selectedSection = .interviewTracker
        interviewFilter = .all
        save()

        var summaryParts: [String] = []
        if result.importedRoundCount > 0 {
            summaryParts.append("imported \(result.importedRoundCount) round\(result.importedRoundCount == 1 ? "" : "s")")
        }
        if result.updatedRoundCount > 0 {
            summaryParts.append("updated \(result.updatedRoundCount) round\(result.updatedRoundCount == 1 ? "" : "s")")
        }
        if result.unchangedRoundCount > 0 {
            summaryParts.append("left \(result.unchangedRoundCount) unchanged")
        }
        if result.createdOpportunityCount > 0 {
            summaryParts.append("created \(result.createdOpportunityCount) opportunit\(result.createdOpportunityCount == 1 ? "y" : "ies")")
        }
        let message = "Apple Calendar import complete: \(summaryParts.joined(separator: ", "))."
        calendarInterviewImportMessage = message
        statusMessage = message
    }

    func deleteSelectedInterviewOpportunity() {
        guard let selectedOpportunityID else { return }
        data.interviewOpportunities.removeAll { $0.id == selectedOpportunityID }
        self.selectedOpportunityID = nil
        save()
    }

    func opportunity(id: UUID) -> InterviewOpportunity? {
        data.interviewOpportunities.first { $0.id == id }
    }

    func saveInterviewEdits(id: UUID, draft: InterviewOpportunity) throws {
        guard let index = data.interviewOpportunities.firstIndex(where: { $0.id == id }) else { return }

        do {
            let existing = data.interviewOpportunities[index]
            let updated = try Self.updatedInterviewOpportunity(existing: existing, draft: draft)
            data.interviewOpportunities[index] = updated
            save()
        } catch {
            statusMessage = "Interview save failed: \(error.localizedDescription)"
            throw error
        }
    }

    nonisolated static func updatedInterviewOpportunity(
        existing: InterviewOpportunity,
        draft: InterviewOpportunity,
        now: Date = Date()
    ) throws -> InterviewOpportunity {
        var updated = draft
        updated.id = existing.id
        updated.createdAt = existing.createdAt
        updated.updatedAt = now
        updated.normalizeDerivedFields(now: now)

        try validateInterviewRounds(updated.interviewRounds, now: now)
        reconcileFollowUp(on: &updated, existing: existing)
        ensureUpcomingRoundFollowUp(on: &updated, now: now)

        return updated
    }

    nonisolated private static func validateInterviewRounds(_ rounds: [InterviewRound], now: Date) throws {
        for round in rounds {
            let roundLabel = round.roundName.isBlank ? "This round" : round.roundName
            let normalizedStatus = round.normalizedStatusValue(now: now)

            guard !normalizedStatus.isBlank else {
                throw InterviewOpportunitySaveError.roundValidation(
                    "\(roundLabel) needs a round status before it can be saved."
                )
            }

            guard let status = round.statusOption(now: now) else {
                throw InterviewOpportunitySaveError.roundValidation(
                    "\(roundLabel) has an unsupported status. Choose one of the available round statuses."
                )
            }

            if status == .upcoming, round.isScheduledInPast(relativeTo: now) {
                let scheduleLabel = round.usesTime ? "date and time" : "date"
                throw InterviewOpportunitySaveError.roundValidation(
                    "\(roundLabel) is marked Upcoming, so its \(scheduleLabel) must be in the future."
                )
            }

            if status != .upcoming, round.isScheduledInFuture(relativeTo: now) {
                throw InterviewOpportunitySaveError.roundValidation(
                    "\(roundLabel) is scheduled in the future, so its status must be Upcoming."
                )
            }
        }
    }

    nonisolated private static func reconcileFollowUp(
        on opportunity: inout InterviewOpportunity,
        existing: InterviewOpportunity
    ) {
        guard opportunity.hasFollowUpRecord else {
            opportunity.nextActionLinkedRoundID = nil
            opportunity.nextActionWasAutoGenerated = false
            return
        }

        if existing.nextActionWasAutoGenerated, followUpWasManuallyChanged(existing: existing, updated: opportunity) {
            opportunity.nextActionLinkedRoundID = nil
            opportunity.nextActionWasAutoGenerated = false
        }

        if opportunity.nextActionWasAutoGenerated,
           let linkedRoundID = opportunity.nextActionLinkedRoundID,
           !opportunity.interviewRounds.contains(where: { $0.id == linkedRoundID }) {
            opportunity.nextActionLinkedRoundID = nil
        }
    }

    nonisolated private static func followUpWasManuallyChanged(
        existing: InterviewOpportunity,
        updated: InterviewOpportunity
    ) -> Bool {
        existing.nextAction != updated.nextAction
            || existing.nextActionDueDate != updated.nextActionDueDate
    }

    nonisolated private static func ensureUpcomingRoundFollowUp(on opportunity: inout InterviewOpportunity, now: Date) {
        guard let upcomingRound = opportunity.nextUpcomingRound(relativeTo: now) else {
            return
        }

        if opportunity.nextActionWasAutoGenerated,
           opportunity.nextActionLinkedRoundID == upcomingRound.id,
           opportunity.hasFollowUpRecord {
            applyAutoGeneratedFollowUp(on: &opportunity, for: upcomingRound)
            return
        }

        if opportunity.hasCurrentFollowUp(relativeTo: now) {
            return
        }

        applyAutoGeneratedFollowUp(on: &opportunity, for: upcomingRound)
    }

    nonisolated private static func applyAutoGeneratedFollowUp(
        on opportunity: inout InterviewOpportunity,
        for upcomingRound: InterviewRound
    ) {
        let roundLabel = upcomingRound.roundName.isBlank ? "interview" : upcomingRound.roundName
        opportunity.nextAction = "Prepare for \(roundLabel)"
        opportunity.nextActionDueDate = upcomingRound.date
        opportunity.nextActionLinkedRoundID = upcomingRound.id
        opportunity.nextActionWasAutoGenerated = true
    }

    func filteredOpportunities(search: String, filter: InterviewFilter? = nil) -> [InterviewOpportunity] {
        Self.filteredOpportunities(
            in: data.interviewOpportunities,
            search: search,
            filter: filter ?? interviewFilter
        )
    }

    nonisolated static func filteredOpportunities(
        in opportunities: [InterviewOpportunity],
        search: String,
        filter: InterviewFilter
    ) -> [InterviewOpportunity] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let latestOpportunityIDsByCompany = latestOpportunityIDsByCompany(in: opportunities)

        let filteredByView = opportunities.filter { opportunity in
            switch filter {
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
            : filteredByView.filter { $0.tableSearchText.localizedCaseInsensitiveContains(query) }

        return filteredBySearch.sorted { lhs, rhs in
            Self.sortByStartDateDescending(lhs, rhs)
        }
    }

    nonisolated private static func sortByStartDateDescending(_ lhs: InterviewOpportunity, _ rhs: InterviewOpportunity) -> Bool {
        if lhs.appliedDate != rhs.appliedDate {
            return lhs.appliedDate > rhs.appliedDate
        }
        if lhs.calculatedLastActivityDate != rhs.calculatedLastActivityDate {
            return lhs.calculatedLastActivityDate > rhs.calculatedLastActivityDate
        }
        return lhs.updatedAt > rhs.updatedAt
    }

    nonisolated private static func isEligibleAgainLatestOpportunity(
        _ opportunity: InterviewOpportunity,
        latestOpportunityIDsByCompany: [String: UUID]
    ) -> Bool {
        guard opportunity.isEligibleAgain else { return false }
        guard opportunity.canAppearInEligibleAgain else { return false }

        let companyKey = Self.normalizedCompanyKey(opportunity.company)
        guard !companyKey.isEmpty else { return true }

        return latestOpportunityIDsByCompany[companyKey] == opportunity.id
    }

    nonisolated static func latestOpportunityIDsByCompany(in opportunities: [InterviewOpportunity]) -> [String: UUID] {
        var latestByCompany: [String: InterviewOpportunity] = [:]

        for opportunity in opportunities {
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

    nonisolated private static func normalizedCompanyKey(_ company: String) -> String {
        company.collapsedWhitespace.lowercased()
    }

    nonisolated private static func normalizedDropdownOptionKey(_ value: String) -> String {
        value.collapsedWhitespace.lowercased()
    }

    nonisolated private static func normalizedDropdownOptionDisplay(_ value: String) -> String {
        value.collapsedWhitespace
    }

    nonisolated private static func preferredDropdownOptionDisplay(existing: String, candidate: String) -> String {
        if existing == existing.lowercased(), candidate != candidate.lowercased() {
            return candidate
        }
        return existing
    }

    nonisolated private static func isMoreRecentOpportunity(_ lhs: InterviewOpportunity, than rhs: InterviewOpportunity) -> Bool {
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

    func saveDocumentEdits(id: UUID, draft: DocumentRecord, desiredFileName: String) throws {
        guard let index = data.documents.firstIndex(where: { $0.id == id }) else { return }

        let existing = data.documents[index]
        let existingCompany = existing.company.collapsedWhitespace
        let trimmedCompany = draft.company.collapsedWhitespace
        let requestedFileName = desiredFileName.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let timestamp = Date()

            if Self.shouldRenameDocumentCompanyDirectory(from: existingCompany, to: trimmedCompany) {
                let affectedIndices = data.documents.indices.filter {
                    data.documents[$0].company.collapsedWhitespace.localizedCaseInsensitiveCompare(existingCompany) == .orderedSame
                }

                let movedDocuments = try documentService.updateDocumentsForCompanyRename(
                    affectedIndices.map { data.documents[$0] },
                    from: existingCompany,
                    to: trimmedCompany,
                    selectedDocumentID: existing.id,
                    selectedDesiredFileName: requestedFileName
                )
                let movedByID = Dictionary(uniqueKeysWithValues: movedDocuments.map { ($0.id, $0) })

                for affectedIndex in affectedIndices {
                    let original = data.documents[affectedIndex]
                    guard var moved = movedByID[original.id] else { continue }

                    if original.id == existing.id {
                        let userVersion = draft.version
                        moved.kind = draft.kind
                        moved.version = userVersion
                        moved.notes = draft.notes
                        moved.originalFileName = existing.originalFileName
                        moved.createdAt = existing.createdAt
                        moved.updatedAt = timestamp
                        documentService.persistVersionMetadata(userVersion, for: moved)
                        moved = documentService.refreshMetadata(for: moved, loadVersionMetadata: !userVersion.isBlank)
                        moved.version = userVersion
                    } else {
                        moved.updatedAt = timestamp
                    }

                    data.documents[affectedIndex] = moved
                }

                save()
                return
            }

            let stored = try documentService.updateDocument(
                existing,
                desiredFileName: requestedFileName,
                company: trimmedCompany
            )

            var updated = draft
            let userVersion = updated.version
            updated.id = existing.id
            updated.company = trimmedCompany
            updated.name = stored.name
            updated.originalFileName = existing.originalFileName
            updated.storedFileName = stored.storedFileName
            updated.fileSizeBytes = stored.fileSizeBytes
            updated.fileCreatedAt = stored.fileCreatedAt
            updated.fileModifiedAt = stored.fileModifiedAt
            updated.createdAt = existing.createdAt
            updated.updatedAt = timestamp

            documentService.persistVersionMetadata(userVersion, for: updated)
            updated = documentService.refreshMetadata(for: updated, loadVersionMetadata: !userVersion.isBlank)
            updated.version = userVersion

            data.documents[index] = updated
            save()
        } catch {
            statusMessage = "Document save failed: \(error.localizedDescription)"
            throw error
        }
    }

    func filteredDocuments(search: String) -> [DocumentRecord] {
        Self.filteredDocuments(in: data.documents, search: search)
    }

    nonisolated static func filteredDocuments(in documents: [DocumentRecord], search: String) -> [DocumentRecord] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let sorted = documents.sorted { lhs, rhs in
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
        return sorted.filter { $0.tableSearchText.localizedCaseInsensitiveContains(query) }
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

    nonisolated static func shouldSeedDemoDataOnLaunch(dataFileExists: Bool, data: AppData, allowsDemoData: Bool) -> Bool {
        guard allowsDemoData else { return false }
        guard !dataFileExists else { return false }
        return data.workExperiences.isEmpty
            && data.interviewOpportunities.isEmpty
            && data.documents.isEmpty
    }

    private func seedDemoDataIfNeeded(shouldSeedDemoData: Bool) {
        guard shouldSeedDemoData else {
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

    private func migrateDemoWorkExperienceFieldsIfNeeded() {
        var changed = false

        for index in data.workExperiences.indices {
            guard let demoEntry = DemoDataFactory.demoWorkExperience(for: data.workExperiences[index].task) else {
                continue
            }
            changed = mergeMissingDemoWorkExperienceFields(
                at: index,
                from: demoEntry
            ) || changed
        }

        if changed {
            do {
                try persistence.save(data)
                statusMessage = "Updated demo work logs for the latest task fields, planner subtasks, and due dates."
            } catch {
                statusMessage = "Work log demo migration failed: \(error.localizedDescription)"
            }
        }
    }

    private func mergeMissingDemoWorkExperienceFields(at index: Int, from demoEntry: WorkExperience) -> Bool {
        var entry = data.workExperiences[index]
        var changed = false

        func fill(_ keyPath: WritableKeyPath<WorkExperience, String>, with value: String) {
            guard entry[keyPath: keyPath].isBlank, !value.isBlank else { return }
            entry[keyPath: keyPath] = value
            changed = true
        }

        if entry.subtasks.isEmpty, !demoEntry.subtasks.isEmpty {
            entry.subtasks = demoEntry.subtasks
            changed = true
        } else if shouldRefreshDemoSubtaskDueDates(entry, using: demoEntry) {
            entry.subtasks = plannerSubtasksWithGeneratedDueDates(entry.subtasks, endingOn: entry.endDate)
            changed = true
        }

        fill(\.company, with: demoEntry.company)
        fill(\.designation, with: demoEntry.designation)
        fill(\.role, with: demoEntry.role)
        fill(\.projectProduct, with: demoEntry.projectProduct)
        fill(\.team, with: demoEntry.team)
        fill(\.feature, with: demoEntry.feature)
        fill(\.tags, with: demoEntry.tags)
        fill(\.situation, with: demoEntry.situation)
        fill(\.expectedResult, with: demoEntry.expectedResult)
        fill(\.action, with: demoEntry.action)
        fill(\.outcome, with: demoEntry.outcome)
        fill(\.challenges, with: demoEntry.challenges)
        fill(\.skillsUsed, with: demoEntry.skillsUsed)
        fill(\.learning, with: demoEntry.learning)
        fill(\.approach, with: demoEntry.approach)

        if changed {
            data.workExperiences[index] = entry
        }

        return changed
    }

    private func shouldRefreshDemoSubtaskDueDates(
        _ entry: WorkExperience,
        using demoEntry: WorkExperience
    ) -> Bool {
        let entrySubtasks = entry.orderedSubtasks
        let demoSubtasks = demoEntry.orderedSubtasks
        guard !entrySubtasks.isEmpty,
              entrySubtasks.count == demoSubtasks.count,
              entrySubtasks.map(\.displayTitle) == demoSubtasks.map(\.displayTitle) else {
            return false
        }

        return entrySubtasks.allSatisfy { subtask in
            Calendar.current.isDate(subtask.dueDate, inSameDayAs: entry.endDate)
        }
    }

    private func plannerSubtasksWithGeneratedDueDates(
        _ subtasks: [WorkExperienceSubtask],
        endingOn taskDueDate: Date
    ) -> [WorkExperienceSubtask] {
        let finalIndex = max(subtasks.count - 1, 0)
        return subtasks.enumerated().map { index, subtask in
            var updatedSubtask = subtask
            updatedSubtask.dueDate = Calendar.current.date(
                byAdding: .day,
                value: index - finalIndex,
                to: taskDueDate
            ) ?? taskDueDate
            return updatedSubtask
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
