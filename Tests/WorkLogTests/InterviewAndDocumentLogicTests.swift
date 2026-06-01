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

    private func makeTemporaryDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("WorkLogLogicTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
