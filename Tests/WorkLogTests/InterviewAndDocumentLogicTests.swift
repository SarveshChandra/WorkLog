import XCTest
@testable import WorkLog

final class InterviewAndDocumentLogicTests: XCTestCase {
    private let fileManager = FileManager.default

    @MainActor
    func testDemoDataSeedingOnlyRunsWhenDataFileIsMissingAndStateIsEmpty() {
        XCTAssertTrue(
            AppStore.shouldSeedDemoDataOnLaunch(
                dataFileExists: false,
                data: AppData(),
                allowsDemoData: true
            )
        )

        XCTAssertFalse(
            AppStore.shouldSeedDemoDataOnLaunch(
                dataFileExists: true,
                data: AppData(),
                allowsDemoData: true
            )
        )

        XCTAssertFalse(
            AppStore.shouldSeedDemoDataOnLaunch(
                dataFileExists: false,
                data: AppData(
                    workExperiences: [WorkExperience(company: "User Entry")],
                    interviewOpportunities: [],
                    documents: []
                ),
                allowsDemoData: true
            )
        )

        XCTAssertFalse(
            AppStore.shouldSeedDemoDataOnLaunch(
                dataFileExists: false,
                data: AppData(),
                allowsDemoData: false
            )
        )
    }

    func testCooldownEditingRequiresCooldownEligibleStatus() {
        var pendingRoundOpportunity = InterviewOpportunity(
            status: .interviewing,
            interviewRounds: [
                InterviewRound(
                    date: Date(),
                    roundName: "Technical",
                    interviewer: "Panel",
                    result: RoundOutcomeOption.pending.rawValue,
                    feedback: ""
                )
            ]
        )

        XCTAssertFalse(pendingRoundOpportunity.canSetCooldownPeriod)

        pendingRoundOpportunity.interviewRounds[0].result = RoundOutcomeOption.rejected.rawValue
        XCTAssertTrue(pendingRoundOpportunity.canSetCooldownPeriod)

        let waitingOpportunity = InterviewOpportunity(status: .waiting)
        XCTAssertTrue(waitingOpportunity.canSetCooldownPeriod)
    }

    func testRenameDocumentAllowsCaseOnlyRenameAndPreservesOriginalFileName() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let service = DocumentStorageService(baseDirectory: tempRoot)
        try fileManager.createDirectory(at: service.documentsDirectory, withIntermediateDirectories: true)

        let originalURL = service.documentsDirectory.appendingPathComponent("Resume.pdf")
        try Data("resume".utf8).write(to: originalURL, options: [.atomic])

        let document = DocumentRecord(
            name: "Resume.pdf",
            kind: .resume,
            version: "",
            company: "",
            notes: "",
            originalFileName: "Resume.pdf",
            storedFileName: "Resume.pdf"
        )

        let renamed = try service.renameDocument(document, to: "resume")

        XCTAssertEqual(renamed.storedFileName, "resume.pdf")
        XCTAssertEqual(renamed.name, "resume.pdf")
        XCTAssertEqual(renamed.originalFileName, "Resume.pdf")
        XCTAssertTrue(fileManager.fileExists(atPath: service.documentsDirectory.appendingPathComponent("resume.pdf").path))
        XCTAssertFalse(fileManager.fileExists(atPath: originalURL.path))
    }

    func testRecordsForExistingFilesTreatsCaseOnlyFileNameMatchesAsExisting() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let service = DocumentStorageService(baseDirectory: tempRoot)
        try fileManager.createDirectory(at: service.documentsDirectory, withIntermediateDirectories: true)

        let diskURL = service.documentsDirectory.appendingPathComponent("resume.pdf")
        try Data("resume".utf8).write(to: diskURL, options: [.atomic])

        let recovered = try service.recordsForExistingFiles(excluding: ["Resume.pdf"])
        XCTAssertTrue(recovered.isEmpty)
    }

    func testSkillOptionsNormalizeDeduplicateAndJoin() {
        let parsed = WorkExperienceSkillOptions.skills(
            in: " Swift,Combine\nSwift ;  async loading ; COMBINE "
        )

        XCTAssertEqual(parsed, ["Swift", "Combine", "async loading"])
        XCTAssertEqual(
            WorkExperienceSkillOptions.joined(parsed + ["Swift"]),
            "Swift, Combine, async loading"
        )
    }

    func testSkillOptionsMergeKeepsSelectedSkillsAheadOfKnownOptions() {
        let merged = WorkExperienceSkillOptions.merged(
            existing: ["Combine", "Swift", "Profiling", "swift"],
            selected: ["Async Loading", "swift"]
        )

        XCTAssertEqual(merged, ["Async Loading", "swift", "Combine", "Profiling"])
    }

    func testAvailableCompaniesMergeTrimDeduplicateAndSortAcrossTasksAndDocuments() {
        let companies = AppStore.availableCompanies(
            in: AppData(
                workExperiences: [
                    WorkExperience(company: "  Zebra Labs  "),
                    WorkExperience(company: "acme"),
                    WorkExperience(company: "")
                ],
                interviewOpportunities: [],
                documents: [
                    DocumentRecord(company: "Acme"),
                    DocumentRecord(company: "Blue   Ocean"),
                    DocumentRecord(company: " ")
                ]
            )
        )

        XCTAssertEqual(companies, ["Acme", "Blue Ocean", "Zebra Labs"])
    }

    func testAvailableWorkExperienceOptionsMergeTrimDeduplicateAndSort() {
        let designations = AppStore.availableWorkExperienceOptions(
            in: AppData(
                workExperiences: [
                    WorkExperience(designation: "ios engineer"),
                    WorkExperience(designation: "  Staff   Engineer  "),
                    WorkExperience(designation: "iOS Engineer"),
                    WorkExperience(designation: "")
                ]
            ),
            for: \.designation
        )

        XCTAssertEqual(designations, ["iOS Engineer", "Staff Engineer"])
    }

    func testWorkExperienceLegacyDateDecodesIntoStartDate() throws {
        let legacyDate = Date(timeIntervalSince1970: 1_700_000_000)
        let json = """
        {
          "company": "Acme",
          "date": "2023-11-14T22:13:20Z"
        }
        """

        let decoded = try JSONCoders.decoder.decode(WorkExperience.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.company, "Acme")
        XCTAssertEqual(decoded.startDate, legacyDate)
        XCTAssertEqual(decoded.endDate, legacyDate)
    }

    func testWorkExperienceDateRangeNormalizesEarlierEndDate() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let earlierEndDate = Date(timeIntervalSince1970: 1_699_900_000)

        let entry = WorkExperience(
            company: "Acme",
            startDate: startDate,
            endDate: earlierEndDate
        )

        XCTAssertEqual(entry.startDate, startDate)
        XCTAssertEqual(entry.endDate, startDate)
        XCTAssertFalse(entry.hasDateRange)
        XCTAssertEqual(entry.sortDate, startDate)
    }

    func testLegacySubtaskDueDateBackfillsFromTaskDueDate() throws {
        let taskDueDate = Date(timeIntervalSince1970: 1_700_086_400)
        let json = """
        {
          "task": "Planner task",
          "startDate": "2023-11-14T22:13:20Z",
          "endDate": "2023-11-15T22:13:20Z",
          "subtasks": [
            {
              "title": "Legacy subtask",
              "status": "Todo",
              "order": 0
            }
          ]
        }
        """

        let decoded = try JSONCoders.decoder.decode(WorkExperience.self, from: Data(json.utf8))

        XCTAssertEqual(decoded.orderedSubtasks.first?.dueDate, taskDueDate)
    }

    func testWorkExperienceClampsSubtaskDueDateToParentDueDate() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let parentDueDate = Date(timeIntervalSince1970: 1_700_086_400)
        let laterSubtaskDueDate = Date(timeIntervalSince1970: 1_700_172_800)

        let entry = WorkExperience(
            task: "Planner task",
            startDate: startDate,
            endDate: parentDueDate,
            subtasks: [
                WorkExperienceSubtask(
                    title: "Late subtask",
                    status: .todo,
                    dueDate: laterSubtaskDueDate,
                    order: 0
                )
            ]
        )

        XCTAssertEqual(entry.orderedSubtasks.first?.dueDate, parentDueDate)
    }

    func testNormalizePlannerSubtasksClampsDueDatesWhenParentDueDateMovesEarlier() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let originalDueDate = Date(timeIntervalSince1970: 1_700_172_800)
        let earlierParentDueDate = Date(timeIntervalSince1970: 1_700_086_400)

        var entry = WorkExperience(
            task: "Planner task",
            startDate: startDate,
            endDate: originalDueDate,
            subtasks: [
                WorkExperienceSubtask(
                    title: "Late subtask",
                    status: .todo,
                    dueDate: originalDueDate,
                    order: 0
                )
            ]
        )

        entry.endDate = earlierParentDueDate
        entry.normalizePlannerSubtasks()

        XCTAssertEqual(entry.orderedSubtasks.first?.dueDate, earlierParentDueDate)
    }

    func testWorkExperienceClampsSubtaskDueDateToParentStartDate() {
        let parentStartDate = Date(timeIntervalSince1970: 1_700_086_400)
        let parentDueDate = Date(timeIntervalSince1970: 1_700_172_800)
        let earlierSubtaskDueDate = Date(timeIntervalSince1970: 1_700_000_000)

        let entry = WorkExperience(
            task: "Planner task",
            startDate: parentStartDate,
            endDate: parentDueDate,
            subtasks: [
                WorkExperienceSubtask(
                    title: "Early subtask",
                    status: .todo,
                    dueDate: earlierSubtaskDueDate,
                    order: 0
                )
            ]
        )

        XCTAssertEqual(entry.orderedSubtasks.first?.dueDate, parentStartDate)
    }

    func testNormalizePlannerSubtasksClampsDueDatesWhenParentStartDateMovesLater() {
        let originalStartDate = Date(timeIntervalSince1970: 1_700_000_000)
        let originalDueDate = Date(timeIntervalSince1970: 1_700_172_800)
        let laterParentStartDate = Date(timeIntervalSince1970: 1_700_086_400)

        var entry = WorkExperience(
            task: "Planner task",
            startDate: originalStartDate,
            endDate: originalDueDate,
            subtasks: [
                WorkExperienceSubtask(
                    title: "Early subtask",
                    status: .todo,
                    dueDate: originalStartDate,
                    order: 0
                )
            ]
        )

        entry.startDate = laterParentStartDate
        entry.normalizeDateRange()
        entry.normalizePlannerSubtasks()

        XCTAssertEqual(entry.orderedSubtasks.first?.dueDate, laterParentStartDate)
    }

    func testDateRangeFormatterCollapsesSingleDayAndShowsRange() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let endDate = Date(timeIntervalSince1970: 1_700_172_800)

        XCTAssertEqual(
            AppDateFormatters.range(start: startDate, end: nil),
            AppDateFormatters.short(startDate)
        )
        XCTAssertEqual(
            AppDateFormatters.range(start: startDate, end: endDate),
            "\(AppDateFormatters.short(startDate)) to \(AppDateFormatters.short(endDate))"
        )
    }

    func testDurationFormatterShowsInclusiveDayCount() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let endDate = Date(timeIntervalSince1970: 1_700_172_800)

        XCTAssertEqual(AppDateFormatters.duration(start: startDate, end: nil), "1 day")
        XCTAssertEqual(AppDateFormatters.duration(start: startDate, end: startDate), "1 day")
        XCTAssertEqual(AppDateFormatters.duration(start: startDate, end: endDate), "3 days")
    }

    func testDateFormatterHidesYearForCurrentYearDates() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentYearDate = Calendar.current.date(from: DateComponents(year: currentYear, month: 6, day: 9))
        let olderDate = Calendar.current.date(from: DateComponents(year: currentYear - 1, month: 6, day: 9))

        XCTAssertNotNil(currentYearDate)
        XCTAssertNotNil(olderDate)
        XCTAssertFalse(AppDateFormatters.short(currentYearDate).contains(String(currentYear)))
        XCTAssertTrue(AppDateFormatters.short(olderDate).contains(String(currentYear - 1)))
    }

    func testWorkExperiencePlannerInfersStatusProgressAndNextStep() {
        let entry = WorkExperience(
            task: "Planner task",
            subtasks: [
                WorkExperienceSubtask(title: "Capture current state", status: .done, order: 0),
                WorkExperienceSubtask(title: "Wait for design input", status: .blocked, order: 1),
                WorkExperienceSubtask(title: "Update implementation plan", status: .todo, order: 2)
            ]
        )

        XCTAssertEqual(entry.plannerStatus, .blocked)
        XCTAssertEqual(entry.plannerProgressText, "1 of 3 done")
        XCTAssertEqual(entry.plannerNextStepText, "Wait for design input")
        XCTAssertEqual(entry.plannerListSummary, "Blocked | 1/3 | Wait for design input")
    }

    func testWorkExperiencePlannerNormalizesSubtaskOrderAndSearchText() {
        let entry = WorkExperience(
            task: "Planner task",
            subtasks: [
                WorkExperienceSubtask(title: "Second step", status: .todo, order: 4),
                WorkExperienceSubtask(title: "First step", status: .done, order: 1)
            ]
        )

        XCTAssertEqual(entry.orderedSubtasks.map(\.title), ["First step", "Second step"])
        XCTAssertEqual(entry.orderedSubtasks.map(\.order), [0, 1])
        XCTAssertTrue(entry.searchText.localizedCaseInsensitiveContains("Second step"))
    }

    func testWorkExperienceSearchTextIncludesExpectedResultAndApproach() {
        let entry = WorkExperience(
            task: "Planner task",
            situation: "Need a rollout summary",
            expectedResult: "Align owners on the target outcome",
            action: "Captured the implementation slices",
            outcome: "Plan is ready",
            approach: "Break the work into stages before assigning subtasks."
        )

        XCTAssertTrue(entry.searchText.localizedCaseInsensitiveContains("Align owners on the target outcome"))
        XCTAssertTrue(entry.searchText.localizedCaseInsensitiveContains("Break the work into stages"))
    }

    func testWorkExperiencePlannerReindexPreservesCurrentArrayOrder() {
        var entry = WorkExperience(
            task: "Planner task",
            subtasks: [
                WorkExperienceSubtask(title: "First step", status: .todo, order: 0),
                WorkExperienceSubtask(title: "Second step", status: .todo, order: 1),
                WorkExperienceSubtask(title: "Third step", status: .todo, order: 2)
            ]
        )

        let movedSubtask = entry.subtasks.remove(at: 2)
        entry.subtasks.insert(movedSubtask, at: 0)
        entry.reindexPlannerSubtasksInCurrentOrder()

        XCTAssertEqual(entry.subtasks.map(\.title), ["Third step", "First step", "Second step"])
        XCTAssertEqual(entry.subtasks.map(\.order), [0, 1, 2])
        XCTAssertEqual(entry.orderedSubtasks.map(\.title), ["Third step", "First step", "Second step"])
    }

    func testWorkExperienceCompletionRequiresSTARFieldsWhenNoSubtasksExist() {
        let incomplete = WorkExperience(
            task: "Write status update",
            situation: "Need a concise weekly summary",
            action: "Drafted the main update",
            outcome: ""
        )
        let complete = WorkExperience(
            task: "Write status update",
            situation: "Need a concise weekly summary",
            action: "Drafted the main update",
            outcome: "Published the final summary"
        )

        XCTAssertFalse(incomplete.hasCompleteSTARFields)
        XCTAssertFalse(incomplete.isCompleteForTaskList)
        XCTAssertTrue(complete.hasCompleteSTARFields)
        XCTAssertTrue(complete.isCompleteForTaskList)
    }

    func testWorkExperienceCompletionRequiresAllSubtasksWhenPresent() {
        let entry = WorkExperience(
            task: "Planner task",
            situation: "Need a rollout plan",
            action: "Defined the implementation slices",
            outcome: "Rollout plan is ready for review",
            subtasks: [
                WorkExperienceSubtask(title: "Capture rollout risks", status: .done, order: 0),
                WorkExperienceSubtask(title: "Confirm sign-off path", status: .doing, order: 1)
            ]
        )

        XCTAssertTrue(entry.hasCompleteSTARFields)
        XCTAssertFalse(entry.hasCompletedAllSubtasks)
        XCTAssertFalse(entry.isCompleteForTaskList)
        XCTAssertEqual(entry.plannerStatus, .doing)
    }

    func testWorkExperienceOverdueForTaskListRequiresIncompletePastDueTask() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: startOfToday)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: startOfToday)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!

        let overdueIncomplete = WorkExperience(
            task: "Planner task",
            situation: "Need a rollout plan",
            action: "Defined the implementation slices",
            outcome: "",
            startDate: twoDaysAgo,
            endDate: yesterday
        )
        let incompleteNotDueYet = WorkExperience(
            task: "Planner task",
            situation: "Need a rollout plan",
            action: "Defined the implementation slices",
            outcome: "",
            startDate: yesterday,
            endDate: tomorrow
        )
        let overdueComplete = WorkExperience(
            task: "Planner task",
            situation: "Need a rollout plan",
            action: "Defined the implementation slices",
            outcome: "Rollout plan is ready for review",
            startDate: twoDaysAgo,
            endDate: yesterday
        )

        XCTAssertTrue(overdueIncomplete.isOverdueForTaskList(referenceDate: startOfToday))
        XCTAssertFalse(incompleteNotDueYet.isOverdueForTaskList(referenceDate: startOfToday))
        XCTAssertFalse(overdueComplete.isOverdueForTaskList(referenceDate: startOfToday))
    }

    func testDemoDataFactorySeedsLongSubtasksForMockPlannerData() {
        let releaseChecklistTask = DemoDataFactory.makeData().workExperiences.first {
            $0.task == "Built release checklist automation"
        }

        XCTAssertNotNil(releaseChecklistTask)
        XCTAssertEqual(releaseChecklistTask?.plannerStatus, .doing)
        XCTAssertEqual(releaseChecklistTask?.plannerProgressText, "2 of 3 done")
        XCTAssertTrue(releaseChecklistTask?.orderedSubtasks.contains(where: { $0.title.count > 100 }) == true)
        XCTAssertTrue(releaseChecklistTask?.plannerListSummary.contains("Doing | 2/3 |") == true)
        let dueDates = releaseChecklistTask?.orderedSubtasks.map(\.dueDate) ?? []
        XCTAssertEqual(dueDates, dueDates.sorted())
        XCTAssertTrue(
            releaseChecklistTask.map { task in
                guard let finalSubtaskDueDate = task.orderedSubtasks.last?.dueDate else { return false }
                return Calendar.current.isDate(finalSubtaskDueDate, inSameDayAs: task.endDate)
            } == true
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("WorkLogLogicTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
