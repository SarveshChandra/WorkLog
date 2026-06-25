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
                    result: RoundOutcomeOption.completed.rawValue,
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

    func testLegacyPendingRoundNormalizesBySchedule() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let futureRound = InterviewRound(
            date: now.addingTimeInterval(7_200),
            roundName: "Technical",
            interviewer: "Panel",
            result: RoundOutcomeOption.legacyPendingRawValue,
            feedback: "",
            includesTime: true
        )
        let pastRound = InterviewRound(
            date: now.addingTimeInterval(-7_200),
            roundName: "Manager",
            interviewer: "Hiring manager",
            result: RoundOutcomeOption.legacyPendingRawValue,
            feedback: "",
            includesTime: true
        )

        XCTAssertEqual(futureRound.normalizedStatusValue(now: now), RoundOutcomeOption.upcoming.rawValue)
        XCTAssertEqual(pastRound.normalizedStatusValue(now: now), RoundOutcomeOption.completed.rawValue)
    }

    func testLegacySelectedRoundNormalizesToOffered() {
        let round = InterviewRound(
            date: Date(timeIntervalSince1970: 1_790_000_000),
            roundName: "Final",
            interviewer: "Panel",
            result: RoundOutcomeOption.legacySelectedRawValue,
            feedback: "",
            includesTime: true
        )

        XCTAssertEqual(round.normalizedStatusValue(), RoundOutcomeOption.offered.rawValue)
    }

    func testManualFollowUpExpiresByDueTime() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let opportunity = InterviewOpportunity(
            status: .interviewing,
            nextAction: "Follow up with recruiter",
            nextActionDueDate: now.addingTimeInterval(-60)
        )

        XCTAssertFalse(opportunity.hasCurrentFollowUp(relativeTo: now))
    }

    func testManualFollowUpDefaultDueTimeStaysActiveAfterToggle() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let dueDate = InterviewOpportunity.defaultManualFollowUpDueDate(now: now)
        let opportunity = InterviewOpportunity(
            status: .interviewing,
            nextAction: "Follow up with recruiter",
            nextActionDueDate: dueDate
        )

        XCTAssertEqual(dueDate, now.addingTimeInterval(3_600))
        XCTAssertTrue(opportunity.hasCurrentFollowUp(relativeTo: now))
    }

    func testSavingUpcomingRoundAddsFollowUpWhenMissing() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let futureRoundDate = now.addingTimeInterval(7_200)
        let existing = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .interviewing,
            appliedDate: now,
            lastActivityDate: now,
            createdAt: now,
            updatedAt: now
        )
        let draft = InterviewOpportunity(
            id: existing.id,
            company: existing.company,
            role: existing.role,
            status: existing.status,
            appliedDate: existing.appliedDate,
            lastActivityDate: existing.lastActivityDate,
            interviewRounds: [
                InterviewRound(
                    date: futureRoundDate,
                    roundName: "Technical",
                    interviewer: "Panel",
                    result: RoundOutcomeOption.upcoming.rawValue,
                    feedback: "",
                    includesTime: true
                )
            ],
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt
        )

        let updated = try AppStore.updatedInterviewOpportunity(existing: existing, draft: draft, now: now)

        XCTAssertEqual(updated.nextAction, "Prepare for Technical")
        XCTAssertEqual(updated.nextActionDueDate, futureRoundDate)
        XCTAssertEqual(updated.nextActionLinkedRoundID, updated.interviewRounds.first?.id)
        XCTAssertTrue(updated.nextActionWasAutoGenerated)
        XCTAssertTrue(updated.hasCurrentFollowUp(relativeTo: now))
    }

    func testSavingUpcomingRoundReplacesExpiredManualFollowUp() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let futureRoundDate = now.addingTimeInterval(7_200)
        let existing = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .interviewing,
            appliedDate: now,
            lastActivityDate: now,
            nextAction: "Old manual follow-up",
            nextActionDueDate: now.addingTimeInterval(-60),
            createdAt: now,
            updatedAt: now
        )
        let draft = InterviewOpportunity(
            id: existing.id,
            company: existing.company,
            role: existing.role,
            status: existing.status,
            appliedDate: existing.appliedDate,
            lastActivityDate: existing.lastActivityDate,
            nextAction: existing.nextAction,
            nextActionDueDate: existing.nextActionDueDate,
            interviewRounds: [
                InterviewRound(
                    date: futureRoundDate,
                    roundName: "Technical",
                    interviewer: "Panel",
                    result: RoundOutcomeOption.upcoming.rawValue,
                    feedback: "",
                    includesTime: true
                )
            ],
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt
        )

        let updated = try AppStore.updatedInterviewOpportunity(existing: existing, draft: draft, now: now)

        XCTAssertEqual(updated.nextAction, "Prepare for Technical")
        XCTAssertEqual(updated.nextActionDueDate, futureRoundDate)
        XCTAssertEqual(updated.nextActionLinkedRoundID, updated.interviewRounds.first?.id)
        XCTAssertTrue(updated.nextActionWasAutoGenerated)
    }

    func testSavingCompletedRoundDeactivatesLinkedAutoFollowUp() throws {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let staleRound = InterviewRound(
            date: now.addingTimeInterval(-3_600),
            roundName: "Technical",
            interviewer: "Panel",
            result: RoundOutcomeOption.upcoming.rawValue,
            feedback: "",
            includesTime: true
        )
        let existing = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .interviewing,
            appliedDate: now.addingTimeInterval(-86_400),
            lastActivityDate: now.addingTimeInterval(-3_600),
            nextAction: "Prepare for Technical",
            nextActionDueDate: staleRound.date,
            nextActionLinkedRoundID: staleRound.id,
            nextActionWasAutoGenerated: true,
            interviewRounds: [staleRound],
            createdAt: now,
            updatedAt: now
        )
        var completedRound = staleRound
        completedRound.result = RoundOutcomeOption.completed.rawValue
        let draft = InterviewOpportunity(
            id: existing.id,
            company: existing.company,
            role: existing.role,
            status: existing.status,
            appliedDate: existing.appliedDate,
            lastActivityDate: existing.lastActivityDate,
            nextAction: existing.nextAction,
            nextActionDueDate: existing.nextActionDueDate,
            nextActionLinkedRoundID: existing.nextActionLinkedRoundID,
            nextActionWasAutoGenerated: existing.nextActionWasAutoGenerated,
            interviewRounds: [completedRound],
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt
        )

        let updated = try AppStore.updatedInterviewOpportunity(existing: existing, draft: draft, now: now)

        XCTAssertEqual(updated.nextAction, "Prepare for Technical")
        XCTAssertEqual(updated.nextActionDueDate, staleRound.date)
        XCTAssertFalse(updated.hasCurrentFollowUp(relativeTo: now))
    }

    func testSavingUpcomingRoundRejectsPastTimedSchedule() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let existing = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .interviewing,
            appliedDate: now,
            lastActivityDate: now,
            createdAt: now,
            updatedAt: now
        )
        let draft = InterviewOpportunity(
            id: existing.id,
            company: existing.company,
            role: existing.role,
            status: existing.status,
            appliedDate: existing.appliedDate,
            lastActivityDate: existing.lastActivityDate,
            interviewRounds: [
                InterviewRound(
                    date: now.addingTimeInterval(-3_600),
                    roundName: "Final",
                    interviewer: "Hiring panel",
                    result: RoundOutcomeOption.upcoming.rawValue,
                    feedback: "",
                    includesTime: true
                )
            ],
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt
        )

        XCTAssertThrowsError(
            try AppStore.updatedInterviewOpportunity(existing: existing, draft: draft, now: now)
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Final is marked Upcoming, so its date and time must be in the future."
            )
        }
    }

    func testSavingCompletedRoundRejectsFutureTimedSchedule() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let existing = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .interviewing,
            appliedDate: now,
            lastActivityDate: now,
            createdAt: now,
            updatedAt: now
        )
        let draft = InterviewOpportunity(
            id: existing.id,
            company: existing.company,
            role: existing.role,
            status: existing.status,
            appliedDate: existing.appliedDate,
            lastActivityDate: existing.lastActivityDate,
            interviewRounds: [
                InterviewRound(
                    date: now.addingTimeInterval(3_600),
                    roundName: "Take-home review",
                    interviewer: "Platform team",
                    result: RoundOutcomeOption.completed.rawValue,
                    feedback: "",
                    includesTime: true
                )
            ],
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt
        )

        XCTAssertThrowsError(
            try AppStore.updatedInterviewOpportunity(existing: existing, draft: draft, now: now)
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Take-home review is scheduled in the future, so its status must be Upcoming."
            )
        }
    }

    func testSavingRoundRejectsUnsupportedStatus() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let existing = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .interviewing,
            appliedDate: now,
            lastActivityDate: now,
            createdAt: now,
            updatedAt: now
        )
        let draft = InterviewOpportunity(
            id: existing.id,
            company: existing.company,
            role: existing.role,
            status: existing.status,
            appliedDate: existing.appliedDate,
            lastActivityDate: existing.lastActivityDate,
            interviewRounds: [
                InterviewRound(
                    date: now.addingTimeInterval(-3_600),
                    roundName: "Final",
                    interviewer: "Hiring panel",
                    result: "Maybe Later",
                    feedback: "",
                    includesTime: true
                )
            ],
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt
        )

        XCTAssertThrowsError(
            try AppStore.updatedInterviewOpportunity(existing: existing, draft: draft, now: now)
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Final has an unsupported status. Choose one of the available round statuses."
            )
        }
    }

    func testShouldRenameDocumentCompanyDirectoryOnlyForNonEmptyToNonEmptyChanges() {
        XCTAssertTrue(
            AppStore.shouldRenameDocumentCompanyDirectory(from: "Altimetrik", to: "New Altimetrik")
        )

        XCTAssertTrue(
            AppStore.shouldRenameDocumentCompanyDirectory(from: "altimetrik", to: "Altimetrik")
        )

        XCTAssertFalse(
            AppStore.shouldRenameDocumentCompanyDirectory(from: "Altimetrik", to: "")
        )

        XCTAssertFalse(
            AppStore.shouldRenameDocumentCompanyDirectory(from: "", to: "Altimetrik")
        )

        XCTAssertFalse(
            AppStore.shouldRenameDocumentCompanyDirectory(from: "Altimetrik", to: "Altimetrik")
        )
    }

    func testCalendarInterviewImportGroupsRoundsAndPreservesEventDetails() {
        let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
        let secondDate = Date(timeIntervalSince1970: 1_800_604_800)
        let events = [
            CalendarInterviewEvent(
                importIdentifier: "event-1|1800000000",
                eventIdentifier: "event-1",
                calendarTitle: "Recruiting",
                title: "Technical Interview - Acme - Senior iOS Engineer",
                startDate: firstDate,
                endDate: firstDate.addingTimeInterval(3_600),
                isAllDay: false,
                location: "Zoom",
                meetingURL: "https://zoom.example/interview",
                attendees: ["Asha Recruiter"],
                notes: "Discuss architecture and concurrency."
            ),
            CalendarInterviewEvent(
                importIdentifier: "event-2|1800604800",
                eventIdentifier: "event-2",
                calendarTitle: "Recruiting",
                title: "Final Round - Acme - Senior iOS Engineer",
                startDate: secondDate,
                endDate: secondDate.addingTimeInterval(5_400),
                isAllDay: false,
                location: "Office",
                meetingURL: "",
                attendees: ["Hiring Panel"],
                notes: "Final panel."
            )
        ]

        let result = CalendarInterviewImporter.merge(
            events: events,
            into: [],
            now: Date(timeIntervalSince1970: 1_790_000_000)
        )

        XCTAssertEqual(result.createdOpportunityCount, 1)
        XCTAssertEqual(result.importedRoundCount, 2)
        XCTAssertEqual(result.opportunities.count, 1)
        XCTAssertEqual(result.opportunities[0].company, "Acme")
        XCTAssertEqual(result.opportunities[0].role, "Senior iOS Engineer")
        XCTAssertEqual(result.opportunities[0].interviewRounds.count, 2)
        XCTAssertEqual(result.opportunities[0].interviewRounds[0].calendarLocation, "Zoom")
        XCTAssertEqual(result.opportunities[0].interviewRounds[0].calendarMeetingURL, "https://zoom.example/interview")
        XCTAssertEqual(result.opportunities[0].interviewRounds[0].calendarEventNotes, "Discuss architecture and concurrency.")
        XCTAssertEqual(result.opportunities[0].interviewRounds[0].result, RoundOutcomeOption.upcoming.rawValue)
        XCTAssertTrue(result.opportunities[0].interviewRounds[0].usesTime)
        XCTAssertEqual(result.opportunities[0].nextAction, "Prepare for \(result.opportunities[0].interviewRounds[0].roundName)")
        XCTAssertEqual(result.opportunities[0].nextActionDueDate, result.opportunities[0].interviewRounds[0].date)
        XCTAssertEqual(result.opportunities[0].nextActionLinkedRoundID, result.opportunities[0].interviewRounds[0].id)
        XCTAssertTrue(result.opportunities[0].nextActionWasAutoGenerated)
    }

    func testCalendarInterviewReimportIsDeduplicated() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let startDate = Date(timeIntervalSince1970: 1_800_000_000)
        let event = CalendarInterviewEvent(
            importIdentifier: "event-1|1800000000",
            eventIdentifier: "event-1",
            calendarTitle: "Interviews",
            title: "Acme - Senior iOS Engineer Interview",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3_600),
            isAllDay: false,
            location: "",
            meetingURL: "",
            attendees: [],
            notes: ""
        )
        let firstImport = CalendarInterviewImporter.merge(events: [event], into: [], now: now)
        XCTAssertEqual(firstImport.opportunities[0].company, "Acme")
        XCTAssertEqual(firstImport.opportunities[0].role, "Senior iOS Engineer")
        let secondImport = CalendarInterviewImporter.merge(
            events: [event],
            into: firstImport.opportunities,
            now: now
        )

        XCTAssertEqual(secondImport.importedRoundCount, 0)
        XCTAssertEqual(secondImport.updatedRoundCount, 0)
        XCTAssertEqual(secondImport.unchangedRoundCount, 1)
        XCTAssertEqual(secondImport.opportunities[0].interviewRounds.count, 1)

        var rescheduledEvent = event
        rescheduledEvent.importIdentifier = "event-1|1800086400"
        rescheduledEvent.startDate = startDate.addingTimeInterval(86_400)
        rescheduledEvent.endDate = startDate.addingTimeInterval(90_000)
        let rescheduledImport = CalendarInterviewImporter.merge(
            events: [rescheduledEvent],
            into: secondImport.opportunities,
            now: now
        )

        XCTAssertEqual(rescheduledImport.importedRoundCount, 0)
        XCTAssertEqual(rescheduledImport.updatedRoundCount, 1)
        XCTAssertEqual(rescheduledImport.opportunities[0].interviewRounds.count, 1)
        XCTAssertEqual(rescheduledImport.opportunities[0].interviewRounds[0].date, rescheduledEvent.startDate)
        XCTAssertEqual(rescheduledImport.opportunities[0].interviewRounds[0].result, RoundOutcomeOption.upcoming.rawValue)
    }

    func testCalendarInterviewReimportReconcilesScheduleStatusAndFollowUp() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let futureDate = now.addingTimeInterval(7_200)
        let pastDate = now.addingTimeInterval(-7_200)
        let event = CalendarInterviewEvent(
            importIdentifier: "event-1|\(futureDate.timeIntervalSince1970)",
            eventIdentifier: "event-1",
            calendarTitle: "Interviews",
            title: "Acme - Senior iOS Engineer Interview",
            startDate: futureDate,
            endDate: futureDate.addingTimeInterval(3_600),
            isAllDay: false,
            location: "",
            meetingURL: "",
            attendees: [],
            notes: ""
        )

        let firstImport = CalendarInterviewImporter.merge(events: [event], into: [], now: now)
        XCTAssertEqual(firstImport.opportunities[0].interviewRounds[0].result, RoundOutcomeOption.upcoming.rawValue)
        XCTAssertTrue(firstImport.opportunities[0].hasCurrentFollowUp(relativeTo: now))

        var pastEvent = event
        pastEvent.importIdentifier = "event-1|\(pastDate.timeIntervalSince1970)"
        pastEvent.startDate = pastDate
        pastEvent.endDate = pastDate.addingTimeInterval(3_600)
        let pastImport = CalendarInterviewImporter.merge(
            events: [pastEvent],
            into: firstImport.opportunities,
            now: now
        )

        XCTAssertEqual(pastImport.updatedRoundCount, 1)
        XCTAssertEqual(pastImport.opportunities[0].interviewRounds[0].result, RoundOutcomeOption.completed.rawValue)
        XCTAssertFalse(pastImport.opportunities[0].hasCurrentFollowUp(relativeTo: now))

        var futureEvent = pastEvent
        futureEvent.importIdentifier = "event-1|\(futureDate.addingTimeInterval(3_600).timeIntervalSince1970)"
        futureEvent.startDate = futureDate.addingTimeInterval(3_600)
        futureEvent.endDate = futureDate.addingTimeInterval(7_200)
        let futureImport = CalendarInterviewImporter.merge(
            events: [futureEvent],
            into: pastImport.opportunities,
            now: now
        )

        XCTAssertEqual(futureImport.updatedRoundCount, 1)
        XCTAssertEqual(futureImport.opportunities[0].interviewRounds[0].result, RoundOutcomeOption.upcoming.rawValue)
        XCTAssertEqual(
            futureImport.opportunities[0].nextActionLinkedRoundID,
            futureImport.opportunities[0].interviewRounds[0].id
        )
        XCTAssertTrue(futureImport.opportunities[0].nextActionWasAutoGenerated)
    }

    func testEligibleAgainFilteringResetsCompanyWhenNewInterviewEntryExists() {
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_700_500_000)

        let olderEligibleOpportunity = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .rejected,
            appliedDate: olderDate,
            lastActivityDate: olderDate,
            nextAction: "Reapply later",
            cooldownPeriodDays: 30,
            interviewRounds: [
                InterviewRound(
                    date: olderDate,
                    roundName: "Final",
                    interviewer: "Manager",
                    result: RoundOutcomeOption.rejected.rawValue,
                    feedback: ""
                )
            ],
            createdAt: olderDate,
            updatedAt: olderDate
        )

        let newerInterviewOpportunity = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .interviewing,
            appliedDate: newerDate,
            lastActivityDate: newerDate,
            interviewRounds: [
                InterviewRound(
                    date: newerDate,
                    roundName: "Screen",
                    interviewer: "Recruiter",
                    result: RoundOutcomeOption.completed.rawValue,
                    feedback: ""
                )
            ],
            createdAt: newerDate,
            updatedAt: newerDate
        )

        let otherEligibleOpportunity = InterviewOpportunity(
            company: "Beta",
            role: "Backend Engineer",
            status: .withdrawn,
            appliedDate: olderDate,
            lastActivityDate: olderDate,
            cooldownPeriodDays: 45,
            interviewRounds: [
                InterviewRound(
                    date: olderDate,
                    roundName: "Recruiter screen",
                    interviewer: "Recruiter",
                    result: RoundOutcomeOption.withdrawn.rawValue,
                    feedback: ""
                )
            ],
            createdAt: olderDate,
            updatedAt: olderDate
        )

        let latestIDsByCompany = AppStore.latestOpportunityIDsByCompany(
            in: [olderEligibleOpportunity, newerInterviewOpportunity, otherEligibleOpportunity]
        )

        XCTAssertEqual(latestIDsByCompany["acme"], newerInterviewOpportunity.id)

        let filtered = AppStore.filteredOpportunities(
            in: [olderEligibleOpportunity, newerInterviewOpportunity, otherEligibleOpportunity],
            search: "",
            filter: .eligibleAgain
        )

        XCTAssertEqual(filtered.map(\.company), ["Beta"])
    }

    func testFilteredOpportunitiesSortByStartDateDescending() {
        let oldestStart = Date(timeIntervalSince1970: 1_700_000_000)
        let middleStart = Date(timeIntervalSince1970: 1_700_100_000)
        let newestStart = Date(timeIntervalSince1970: 1_700_200_000)

        let oldestOpportunity = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .applied,
            appliedDate: oldestStart,
            lastActivityDate: newestStart,
            nextAction: "Follow up soon",
            nextActionDueDate: oldestStart,
            createdAt: oldestStart,
            updatedAt: oldestStart
        )

        let newestOpportunity = InterviewOpportunity(
            company: "Beta",
            role: "Backend Engineer",
            status: .waiting,
            appliedDate: newestStart,
            lastActivityDate: middleStart,
            nextAction: "",
            createdAt: newestStart,
            updatedAt: newestStart
        )

        let middleOpportunity = InterviewOpportunity(
            company: "Gamma",
            role: "Platform Engineer",
            status: .rejected,
            appliedDate: middleStart,
            lastActivityDate: oldestStart,
            cooldownPeriodDays: 30,
            createdAt: middleStart,
            updatedAt: middleStart
        )

        let filtered = AppStore.filteredOpportunities(
            in: [oldestOpportunity, newestOpportunity, middleOpportunity],
            search: "",
            filter: .all
        )

        XCTAssertEqual(filtered.map(\.company), ["Beta", "Gamma", "Acme"])
    }

    func testFilteredOpportunitiesIgnoreHiddenDetailFieldsForTableSearch() {
        let hiddenMatch = InterviewOpportunity(
            company: "Acme",
            role: "iOS Engineer",
            status: .applied,
            jobDescription: "Distributed systems and event streaming",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let visibleMatch = InterviewOpportunity(
            company: "Distributed Systems Inc",
            role: "Backend Engineer",
            status: .applied,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let filtered = AppStore.filteredOpportunities(
            in: [hiddenMatch, visibleMatch],
            search: "distributed systems",
            filter: .all
        )

        XCTAssertEqual(filtered.map(\.company), ["Distributed Systems Inc"])
    }

    func testFilteredDocumentsIgnoreHiddenNotesForTableSearch() {
        let hiddenMatch = DocumentRecord(
            name: "Resume.pdf",
            kind: .resume,
            company: "Acme",
            notes: "Distributed systems architecture"
        )
        let visibleMatch = DocumentRecord(
            name: "Distributed Systems Resume.pdf",
            kind: .resume,
            company: "Beta"
        )

        let filtered = AppStore.filteredDocuments(in: [hiddenMatch, visibleMatch], search: "distributed systems")

        XCTAssertEqual(filtered.map(\.displayFileName), ["Distributed Systems Resume.pdf"])
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
        let storedNames = try fileManager.contentsOfDirectory(
            at: service.documentsDirectory,
            includingPropertiesForKeys: nil
        )
        .map(\.lastPathComponent)
        XCTAssertFalse(storedNames.contains("Resume.pdf"))
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

    func testUpdateDocumentMovesFileIntoCompanyDirectoryAndPreservesDuplicateNameAcrossDirectories() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let service = DocumentStorageService(baseDirectory: tempRoot)
        try fileManager.createDirectory(at: service.documentsDirectory, withIntermediateDirectories: true)

        let rootURL = service.documentsDirectory.appendingPathComponent("Resume.pdf")
        let betaDirectory = service.documentsDirectory.appendingPathComponent("Beta", isDirectory: true)
        try fileManager.createDirectory(at: betaDirectory, withIntermediateDirectories: true)
        let betaURL = betaDirectory.appendingPathComponent("Resume.pdf")

        try Data("root".utf8).write(to: rootURL, options: [.atomic])
        try Data("beta".utf8).write(to: betaURL, options: [.atomic])

        let document = DocumentRecord(
            name: "Resume.pdf",
            kind: .resume,
            version: "",
            company: "",
            notes: "",
            originalFileName: "Resume.pdf",
            storedFileName: "Resume.pdf"
        )

        let updated = try service.updateDocument(document, desiredFileName: "Resume.pdf", company: "Acme")

        XCTAssertEqual(updated.company, "Acme")
        XCTAssertEqual(updated.name, "Resume.pdf")
        XCTAssertEqual(updated.storedFileName, "Acme/Resume.pdf")
        XCTAssertTrue(fileManager.fileExists(atPath: service.documentsDirectory.appendingPathComponent("Acme/Resume.pdf").path))
        XCTAssertTrue(fileManager.fileExists(atPath: betaURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: rootURL.path))
    }

    func testUpdateDocumentRejectsDuplicateNameInSameDirectory() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let service = DocumentStorageService(baseDirectory: tempRoot)
        let acmeDirectory = service.documentsDirectory.appendingPathComponent("Acme", isDirectory: true)
        try fileManager.createDirectory(at: acmeDirectory, withIntermediateDirectories: true)

        let existingURL = acmeDirectory.appendingPathComponent("Resume.pdf")
        let documentURL = acmeDirectory.appendingPathComponent("Offer.pdf")
        try Data("resume".utf8).write(to: existingURL, options: [.atomic])
        try Data("offer".utf8).write(to: documentURL, options: [.atomic])

        let document = DocumentRecord(
            name: "Offer.pdf",
            kind: .offerLetter,
            version: "",
            company: "Acme",
            notes: "",
            originalFileName: "Offer.pdf",
            storedFileName: "Acme/Offer.pdf"
        )

        XCTAssertThrowsError(
            try service.updateDocument(document, desiredFileName: "Resume.pdf", company: "Acme")
        ) { error in
            guard case let DocumentStorageError.duplicateNameInDirectory(fileName, company) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(fileName, "Resume.pdf")
            XCTAssertEqual(company, "Acme")
        }
    }

    func testRecordsForExistingFilesRecoverCompanyDirectories() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let service = DocumentStorageService(baseDirectory: tempRoot)
        let acmeDirectory = service.documentsDirectory.appendingPathComponent("Acme", isDirectory: true)
        try fileManager.createDirectory(at: acmeDirectory, withIntermediateDirectories: true)

        let nestedURL = acmeDirectory.appendingPathComponent("Resume.pdf")
        try Data("resume".utf8).write(to: nestedURL, options: [.atomic])

        let recovered = try service.recordsForExistingFiles(excluding: [])
        XCTAssertEqual(recovered.count, 1)
        XCTAssertEqual(recovered[0].company, "Acme")
        XCTAssertEqual(recovered[0].name, "Resume.pdf")
        XCTAssertEqual(recovered[0].storedFileName, "Acme/Resume.pdf")
    }

    func testDocumentKindDisplayNamesCoverBroaderCareerDocuments() {
        XCTAssertEqual(DocumentKind.appointmentLetter.displayName, "Joining / Appointment Letter")
        XCTAssertEqual(DocumentKind.salary.displayName, "Payslip / Salary")
    }

    func testImportDocumentInfersCoverLetterAndAppointmentLetterKinds() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let service = DocumentStorageService(baseDirectory: tempRoot)

        let coverLetterURL = tempRoot.appendingPathComponent("Senior_iOS_Cover_Letter.pdf")
        let joiningLetterURL = tempRoot.appendingPathComponent("Altimetrik_Joining_Letter.pdf")
        try Data("cover".utf8).write(to: coverLetterURL, options: [.atomic])
        try Data("joining".utf8).write(to: joiningLetterURL, options: [.atomic])

        let importedCoverLetter = try service.importDocument(from: coverLetterURL)
        let importedJoiningLetter = try service.importDocument(from: joiningLetterURL)

        XCTAssertEqual(importedCoverLetter.kind, .coverLetter)
        XCTAssertEqual(importedJoiningLetter.kind, .appointmentLetter)
    }

    func testUpdateDocumentsForCompanyRenameMovesEntireDirectory() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let service = DocumentStorageService(baseDirectory: tempRoot)
        let acmeDirectory = service.documentsDirectory.appendingPathComponent("Acme", isDirectory: true)
        try fileManager.createDirectory(at: acmeDirectory, withIntermediateDirectories: true)

        let resumeURL = acmeDirectory.appendingPathComponent("Resume.pdf")
        let offerURL = acmeDirectory.appendingPathComponent("Offer.pdf")
        try Data("resume".utf8).write(to: resumeURL, options: [.atomic])
        try Data("offer".utf8).write(to: offerURL, options: [.atomic])

        let documents = [
            DocumentRecord(
                name: "Resume.pdf",
                kind: .resume,
                version: "",
                company: "Acme",
                notes: "",
                originalFileName: "Resume.pdf",
                storedFileName: "Acme/Resume.pdf"
            ),
            DocumentRecord(
                name: "Offer.pdf",
                kind: .offerLetter,
                version: "",
                company: "Acme",
                notes: "",
                originalFileName: "Offer.pdf",
                storedFileName: "Acme/Offer.pdf"
            )
        ]

        let updated = try service.updateDocumentsForCompanyRename(
            documents,
            from: "Acme",
            to: "Beta"
        )

        XCTAssertEqual(updated.map(\.company), ["Beta", "Beta"])
        XCTAssertEqual(updated.map(\.storedFileName), ["Beta/Resume.pdf", "Beta/Offer.pdf"])
        XCTAssertFalse(fileManager.fileExists(atPath: acmeDirectory.path))
        XCTAssertTrue(fileManager.fileExists(atPath: service.documentsDirectory.appendingPathComponent("Beta/Resume.pdf").path))
        XCTAssertTrue(fileManager.fileExists(atPath: service.documentsDirectory.appendingPathComponent("Beta/Offer.pdf").path))
    }

    func testUpdateDocumentsForCompanyRenameRejectsDuplicateTrackedPathsWithoutCrashing() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let service = DocumentStorageService(baseDirectory: tempRoot)
        let acmeDirectory = service.documentsDirectory.appendingPathComponent("Acme", isDirectory: true)
        try fileManager.createDirectory(at: acmeDirectory, withIntermediateDirectories: true)

        let resumeURL = acmeDirectory.appendingPathComponent("Resume.pdf")
        try Data("resume".utf8).write(to: resumeURL, options: [.atomic])

        let documents = [
            DocumentRecord(
                id: UUID(),
                name: "Resume.pdf",
                kind: .resume,
                version: "",
                company: "Acme",
                notes: "",
                originalFileName: "Resume.pdf",
                storedFileName: "Acme/Resume.pdf"
            ),
            DocumentRecord(
                id: UUID(),
                name: "Resume.pdf",
                kind: .resume,
                version: "",
                company: "Acme",
                notes: "",
                originalFileName: "Resume.pdf",
                storedFileName: "Acme/Resume.pdf"
            )
        ]

        XCTAssertThrowsError(
            try service.updateDocumentsForCompanyRename(documents, from: "Acme", to: "Beta")
        ) { error in
            guard case let DocumentStorageError.duplicateNameInDirectory(fileName, company) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(fileName, "Resume.pdf")
            XCTAssertEqual(company, "Beta")
        }
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

    func testWorkLogPlaceholderValuesIdentifyFallbackLabels() {
        XCTAssertTrue("Unknown".isWorkLogPlaceholderValue)
        XCTAssertTrue("Untitled subtask".isWorkLogPlaceholderValue)
        XCTAssertTrue("No subtasks yet. Use Edit to add a simple checklist.".isWorkLogPlaceholderValue)
        XCTAssertTrue("Ready".isWorkLogPlaceholderValue)
        XCTAssertFalse("Ready for review".isWorkLogPlaceholderValue)
        XCTAssertFalse("No task dates are set. Duration, overdue, and due-date logic stay off until you enable dates.".isWorkLogPlaceholderValue)
        XCTAssertFalse("Set a cooldown-eligible status first".isWorkLogPlaceholderValue)
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

    func testTaskImportServiceKeepsUndatedImportedTasksDateLogicOff() throws {
        let json = """
        {
          "tasks": [
            "Imported checklist task"
          ]
        }
        """

        let imported = try TaskImportService.decodeWorkExperiences(from: Data(json.utf8))

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported.first?.task, "Imported checklist task")
        XCTAssertEqual(imported.first?.usesDateLogic, false)
        XCTAssertEqual(imported.first?.durationText, "Unknown")
    }

    func testTaskImportServiceAppliesRootDefaultsToFlexibleTaskImport() throws {
        let json = """
        {
          "company": "Acme",
          "designation": "Senior Engineer",
          "role": "Platform",
          "project": "Migration",
          "team": "Core",
          "feature": "Task import",
          "tags": ["High Impact", "Automation"],
          "skills": ["Swift", "JSON"],
          "startDate": "2026-06-01",
          "endDate": "2026-06-05",
          "tasks": [
            {
              "title": "Import prepared task list",
              "subtasks": [
                { "title": "Review JSON", "status": "done", "dueDate": "2026-05-30" },
                { "title": "Import tasks", "status": "in progress", "dueDate": "2026-06-08" }
              ]
            }
          ]
        }
        """

        let imported = try TaskImportService.decodeWorkExperiences(from: Data(json.utf8))

        XCTAssertEqual(imported.count, 1)
        let entry = try XCTUnwrap(imported.first)
        XCTAssertEqual(entry.company, "Acme")
        XCTAssertEqual(entry.designation, "Senior Engineer")
        XCTAssertEqual(entry.role, "Platform")
        XCTAssertEqual(entry.projectProduct, "Migration")
        XCTAssertEqual(entry.team, "Core")
        XCTAssertEqual(entry.feature, "Task import")
        XCTAssertEqual(entry.tags, "High Impact, Automation")
        XCTAssertEqual(entry.skillsUsed, "Swift, JSON")
        XCTAssertTrue(entry.usesDateLogic)
        XCTAssertEqual(entry.orderedSubtasks.map(\.status), [.done, .doing])
        XCTAssertEqual(entry.orderedSubtasks.first?.dueDate, entry.startDate)
        XCTAssertEqual(entry.orderedSubtasks.last?.dueDate, entry.endDate)
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

    func testUpdatedWorkExperiencePreservesIdentityAndNormalizesDraftBeforeSave() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let now = Date(timeIntervalSince1970: 1_700_259_200)
        let existing = WorkExperience(
            id: UUID(),
            company: "Acme",
            task: "Existing task",
            startDate: createdAt,
            endDate: createdAt,
            usesDateLogic: true,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let normalizedDay = Date(timeIntervalSince1970: 1_700_086_400)
        let draft = WorkExperience(
            id: UUID(),
            company: "Acme",
            task: "Updated task",
            startDate: normalizedDay,
            endDate: createdAt,
            usesDateLogic: true,
            subtasks: [
                WorkExperienceSubtask(
                    title: "Follow-up",
                    status: .todo,
                    dueDate: createdAt,
                    order: 0
                )
            ],
            createdAt: now,
            updatedAt: now
        )

        let updated = AppStore.updatedWorkExperience(existing: existing, draft: draft, now: now)

        XCTAssertEqual(updated.id, existing.id)
        XCTAssertEqual(updated.createdAt, existing.createdAt)
        XCTAssertEqual(updated.updatedAt, now)
        XCTAssertEqual(updated.startDate, normalizedDay)
        XCTAssertEqual(updated.endDate, normalizedDay)
        XCTAssertEqual(updated.orderedSubtasks.first?.dueDate, normalizedDay)
        XCTAssertEqual(updated.task, "Updated task")
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

    func testFilteredWorkExperiencesIgnoreHiddenNarrativeFieldsForTableSearch() {
        let hiddenMatch = WorkExperience(
            company: "Acme",
            task: "Planner task",
            expectedResult: "Distributed systems rollout"
        )
        let visibleMatch = WorkExperience(
            company: "Distributed Systems Co",
            task: "Release checklist"
        )

        let filtered = AppStore.filteredWorkExperiences(
            in: [hiddenMatch, visibleMatch],
            search: "distributed systems"
        )

        XCTAssertEqual(filtered.map(\.company), ["Distributed Systems Co"])
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
            subtasks: [
                WorkExperienceSubtask(title: "Capture rollout risks", status: .done, order: 0),
                WorkExperienceSubtask(title: "Confirm sign-off path", status: .doing, order: 1)
            ],
            situation: "Need a rollout plan",
            action: "Defined the implementation slices",
            outcome: "Rollout plan is ready for review"
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
            startDate: twoDaysAgo,
            endDate: yesterday,
            situation: "Need a rollout plan",
            action: "Defined the implementation slices",
            outcome: ""
        )
        let incompleteNotDueYet = WorkExperience(
            task: "Planner task",
            startDate: yesterday,
            endDate: tomorrow,
            situation: "Need a rollout plan",
            action: "Defined the implementation slices",
            outcome: ""
        )
        let overdueComplete = WorkExperience(
            task: "Planner task",
            startDate: twoDaysAgo,
            endDate: yesterday,
            situation: "Need a rollout plan",
            action: "Defined the implementation slices",
            outcome: "Rollout plan is ready for review"
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
