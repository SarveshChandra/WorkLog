import EventKit
import Foundation

struct CalendarInterviewEvent: Hashable {
    var importIdentifier: String
    var eventIdentifier: String
    var calendarTitle: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String
    var meetingURL: String
    var attendees: [String]
    var notes: String
}

struct CalendarInterviewImportResult {
    var opportunities: [InterviewOpportunity]
    var matchedEventCount: Int
    var importedRoundCount: Int
    var updatedRoundCount: Int
    var unchangedRoundCount: Int
    var createdOpportunityCount: Int
    var importedOpportunityIDs: [UUID]
}

enum CalendarInterviewImportError: LocalizedError {
    case accessDenied
    case unavailableDateRange

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was not granted. Enable Work Log in System Settings > Privacy & Security > Calendars, then import again."
        case .unavailableDateRange:
            return "Work Log could not create the Apple Calendar search range."
        }
    }
}

final class AppleCalendarInterviewService {
    private let eventStore = EKEventStore()
    private let queue = DispatchQueue(label: "WorkLog.AppleCalendarInterviewImport", qos: .userInitiated)

    func fetchInterviewEvents(completion: @escaping (Result<[CalendarInterviewEvent], Error>) -> Void) {
        queue.async { [self] in
            requestAccess { accessResult in
                switch accessResult {
                case .failure(let error):
                    completion(.failure(error))
                case .success(false):
                    completion(.failure(CalendarInterviewImportError.accessDenied))
                case .success(true):
                    self.queue.async { [self] in
                        do {
                            completion(.success(try loadInterviewEvents()))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    private func requestAccess(completion: @escaping (Result<Bool, Error>) -> Void) {
        let accessCompletion: EKEventStoreRequestAccessCompletionHandler = { granted, error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(granted))
            }
        }

        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents(completion: accessCompletion)
        } else {
            eventStore.requestAccess(to: .event, completion: accessCompletion)
        }
    }

    private func loadInterviewEvents() throws -> [CalendarInterviewEvent] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let rangeStart = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)),
              let rangeEnd = calendar.date(from: DateComponents(year: 2101, month: 1, day: 1)) else {
            throw CalendarInterviewImportError.unavailableDateRange
        }

        var eventsByIdentifier: [String: CalendarInterviewEvent] = [:]
        var chunkStart = rangeStart

        while chunkStart < rangeEnd {
            guard let proposedEnd = calendar.date(byAdding: .year, value: 4, to: chunkStart) else {
                throw CalendarInterviewImportError.unavailableDateRange
            }
            let chunkEnd = min(proposedEnd, rangeEnd)
            let predicate = eventStore.predicateForEvents(withStart: chunkStart, end: chunkEnd, calendars: nil)

            eventStore.enumerateEvents(matching: predicate) { event, _ in
                guard event.status != .canceled else { return }

                let candidate = Self.makeCandidate(from: event)
                guard CalendarInterviewImporter.isInterviewEvent(candidate) else { return }
                eventsByIdentifier[candidate.importIdentifier] = candidate
            }

            chunkStart = chunkEnd
        }

        return eventsByIdentifier.values.sorted {
            if $0.startDate == $1.startDate {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.startDate < $1.startDate
        }
    }

    private static func makeCandidate(from event: EKEvent) -> CalendarInterviewEvent {
        let participantNames = participantNames(from: event)
        let notes = event.notes ?? ""
        let location = event.location ?? ""
        let meetingURL = event.url?.absoluteString
            ?? firstWebURL(in: [location, notes].joined(separator: "\n"))
            ?? ""
        let externalIdentifier = event.calendarItemExternalIdentifier
        let stableEventIdentifier = externalIdentifier?.isBlank == false
            ? externalIdentifier ?? event.calendarItemIdentifier
            : event.calendarItemIdentifier
        let importIdentifier = [
            stableEventIdentifier,
            String(Int(event.startDate.timeIntervalSince1970))
        ]
        .joined(separator: "|")

        return CalendarInterviewEvent(
            importIdentifier: importIdentifier,
            eventIdentifier: event.eventIdentifier ?? event.calendarItemIdentifier,
            calendarTitle: event.calendar.title,
            title: event.title ?? "Interview",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            location: location,
            meetingURL: meetingURL,
            attendees: participantNames,
            notes: notes
        )
    }

    private static func participantNames(from event: EKEvent) -> [String] {
        var values: [String] = []
        if let organizer = event.organizer, !organizer.isCurrentUser {
            values.append(participantLabel(organizer))
        }
        values.append(contentsOf: (event.attendees ?? [])
            .filter { !$0.isCurrentUser }
            .map(participantLabel))

        var seen: Set<String> = []
        return values.filter { value in
            let key = value.collapsedWhitespace.lowercased()
            guard !key.isEmpty, seen.insert(key).inserted else { return false }
            return true
        }
    }

    private static func participantLabel(_ participant: EKParticipant) -> String {
        if let name = participant.name?.collapsedWhitespace, !name.isBlank {
            return name
        }
        return participant.url.absoluteString
            .replacingOccurrences(of: "mailto:", with: "", options: [.caseInsensitive, .anchored])
            .removingPercentEncoding
            ?? participant.url.absoluteString
    }

    private static func firstWebURL(in value: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return detector.firstMatch(in: value, options: [], range: range)?.url?.absoluteString
    }
}

enum CalendarInterviewImporter {
    private static let interviewKeywords = [
        "interview",
        "screening",
        "phone screen",
        "recruiter screen",
        "technical round",
        "coding round",
        "machine coding",
        "system design",
        "hr round",
        "manager round",
        "final round",
        "panel round",
        "onsite",
        "coding assessment",
        "technical assessment",
        "hiring discussion",
        "technical discussion",
        "recruiter call"
    ]

    private static let roundNames = [
        "Hiring Manager Interview",
        "Technical Interview",
        "Coding Interview",
        "Panel Interview",
        "Onsite Interview",
        "Recruiter Screen",
        "Phone Screen",
        "Machine Coding",
        "System Design",
        "Technical Round",
        "Coding Round",
        "Manager Round",
        "Final Round",
        "HR Interview",
        "HR Round",
        "Screening",
        "Interview"
    ]

    static func isInterviewEvent(_ event: CalendarInterviewEvent) -> Bool {
        if event.calendarTitle.localizedCaseInsensitiveContains("interview") {
            return true
        }

        let searchableText = [event.title, event.notes]
            .joined(separator: " ")
            .collapsedWhitespace
            .lowercased()
        return interviewKeywords.contains { searchableText.contains($0) }
    }

    static func merge(
        events: [CalendarInterviewEvent],
        into existingOpportunities: [InterviewOpportunity],
        now: Date = Date()
    ) -> CalendarInterviewImportResult {
        var opportunities = existingOpportunities
        var importedRoundCount = 0
        var updatedRoundCount = 0
        var unchangedRoundCount = 0
        var createdOpportunityCount = 0
        var importedOpportunityIDs: [UUID] = []

        for event in events.sorted(by: eventSort) {
            if let roundLocation = findRound(for: event, in: opportunities) {
                let existingRound = opportunities[roundLocation.opportunityIndex]
                    .interviewRounds[roundLocation.roundIndex]
                let refreshedRound = refreshedRound(existingRound, from: event, now: now)

                if refreshedRound == existingRound {
                    let opportunityBeforeFollowUp = opportunities[roundLocation.opportunityIndex]
                    opportunities[roundLocation.opportunityIndex].ensureUpcomingRoundFollowUps(relativeTo: now)
                    if opportunities[roundLocation.opportunityIndex] == opportunityBeforeFollowUp {
                        unchangedRoundCount += 1
                    } else {
                        opportunities[roundLocation.opportunityIndex].updatedAt = now
                        updatedRoundCount += 1
                    }
                } else {
                    opportunities[roundLocation.opportunityIndex]
                        .interviewRounds[roundLocation.roundIndex] = refreshedRound
                    opportunities[roundLocation.opportunityIndex].updatedAt = now
                    opportunities[roundLocation.opportunityIndex].normalizeDerivedFields(now: now)
                    opportunities[roundLocation.opportunityIndex].ensureUpcomingRoundFollowUps(relativeTo: now)
                    updatedRoundCount += 1
                }
                importedOpportunityIDs.append(opportunities[roundLocation.opportunityIndex].id)
                continue
            }

            let identity = parsedIdentity(from: event.title)
            let opportunityIndex: Int
            if let matchingIndex = matchingOpportunityIndex(
                company: identity.company,
                role: identity.role,
                in: opportunities
            ) {
                opportunityIndex = matchingIndex
            } else {
                let opportunity = InterviewOpportunity(
                    company: identity.company,
                    role: identity.role,
                    status: .interviewing,
                    stage: identity.roundName,
                    appliedDate: event.startDate,
                    lastActivityDate: event.startDate,
                    contactOrInterviewer: event.attendees.first ?? "",
                    createdAt: now,
                    updatedAt: now
                )
                opportunities.insert(opportunity, at: 0)
                opportunityIndex = 0
                createdOpportunityCount += 1
            }

            let importedRound = makeRound(from: event, identity: identity, now: now)
            opportunities[opportunityIndex].interviewRounds.append(importedRound)
            if opportunities[opportunityIndex].contactOrInterviewer.isBlank,
               let firstAttendee = event.attendees.first {
                opportunities[opportunityIndex].contactOrInterviewer = firstAttendee
            }
            opportunities[opportunityIndex].status = .interviewing
            opportunities[opportunityIndex].updatedAt = now
            opportunities[opportunityIndex].normalizeDerivedFields(now: now)
            opportunities[opportunityIndex].ensureUpcomingRoundFollowUps(relativeTo: now)
            importedRoundCount += 1
            importedOpportunityIDs.append(opportunities[opportunityIndex].id)
        }

        var seenOpportunityIDs: Set<UUID> = []
        let uniqueImportedOpportunityIDs = importedOpportunityIDs.filter {
            seenOpportunityIDs.insert($0).inserted
        }

        return CalendarInterviewImportResult(
            opportunities: opportunities,
            matchedEventCount: events.count,
            importedRoundCount: importedRoundCount,
            updatedRoundCount: updatedRoundCount,
            unchangedRoundCount: unchangedRoundCount,
            createdOpportunityCount: createdOpportunityCount,
            importedOpportunityIDs: uniqueImportedOpportunityIDs
        )
    }

    private static func eventSort(_ lhs: CalendarInterviewEvent, _ rhs: CalendarInterviewEvent) -> Bool {
        if lhs.startDate == rhs.startDate {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return lhs.startDate < rhs.startDate
    }

    private static func findRound(
        for event: CalendarInterviewEvent,
        in opportunities: [InterviewOpportunity]
    ) -> (opportunityIndex: Int, roundIndex: Int)? {
        for opportunityIndex in opportunities.indices {
            if let roundIndex = opportunities[opportunityIndex].interviewRounds.firstIndex(where: {
                $0.calendarImportIdentifier == event.importIdentifier
            }) {
                return (opportunityIndex, roundIndex)
            }
        }

        let eventIdentifierMatches = opportunities.indices.flatMap { opportunityIndex in
            opportunities[opportunityIndex].interviewRounds.indices.compactMap { roundIndex in
                opportunities[opportunityIndex].interviewRounds[roundIndex].calendarEventIdentifier == event.eventIdentifier
                    ? (opportunityIndex, roundIndex)
                    : nil
            }
        }
        return eventIdentifierMatches.count == 1 ? eventIdentifierMatches[0] : nil
    }

    private static func refreshedRound(
        _ existingRound: InterviewRound,
        from event: CalendarInterviewEvent,
        now: Date
    ) -> InterviewRound {
        var round = existingRound
        let identity = parsedIdentity(from: event.title)
        round.date = event.startDate
        round.roundName = identity.roundName
        if !event.attendees.isEmpty {
            round.interviewer = event.attendees.joined(separator: ", ")
        }
        round.calendarImportIdentifier = event.importIdentifier
        round.calendarEventIdentifier = event.eventIdentifier
        round.calendarTitle = event.calendarTitle
        round.calendarEndDate = event.endDate
        round.calendarLocation = nilIfBlank(event.location)
        round.calendarMeetingURL = nilIfBlank(event.meetingURL)
        round.calendarAttendees = event.attendees.isEmpty ? nil : event.attendees
        round.calendarEventNotes = nilIfBlank(event.notes)
        round.calendarIsAllDay = event.isAllDay
        round.includesTime = event.isAllDay ? false : true
        round.result = reconciledStatus(for: round, previousStatus: existingRound.result, now: now)
        return round
    }

    private static func makeRound(
        from event: CalendarInterviewEvent,
        identity: (company: String, role: String, roundName: String),
        now: Date
    ) -> InterviewRound {
        var round = InterviewRound(
            date: event.startDate,
            roundName: identity.roundName,
            interviewer: event.attendees.joined(separator: ", "),
            result: "",
            feedback: "",
            includesTime: event.isAllDay ? false : true,
            calendarImportIdentifier: event.importIdentifier,
            calendarEventIdentifier: event.eventIdentifier,
            calendarTitle: event.calendarTitle,
            calendarEndDate: event.endDate,
            calendarLocation: nilIfBlank(event.location),
            calendarMeetingURL: nilIfBlank(event.meetingURL),
            calendarAttendees: event.attendees.isEmpty ? nil : event.attendees,
            calendarEventNotes: nilIfBlank(event.notes),
            calendarIsAllDay: event.isAllDay
        )
        round.result = scheduledStatus(for: round, now: now).rawValue
        return round
    }

    private static func scheduledStatus(for round: InterviewRound, now: Date) -> RoundOutcomeOption {
        round.isScheduledInPast(relativeTo: now) ? .completed : .upcoming
    }

    private static func reconciledStatus(
        for round: InterviewRound,
        previousStatus: String,
        now: Date
    ) -> String {
        let scheduledStatus = scheduledStatus(for: round, now: now)
        if scheduledStatus == .upcoming {
            return scheduledStatus.rawValue
        }

        let previousOption = RoundOutcomeOption.option(for: previousStatus, round: round, now: now)
        if previousOption == nil || previousOption == .upcoming || previousOption == .completed {
            return scheduledStatus.rawValue
        }
        return round.normalizedStatusValue(now: now)
    }

    private static func matchingOpportunityIndex(
        company: String,
        role: String,
        in opportunities: [InterviewOpportunity]
    ) -> Int? {
        let companyKey = normalizedKey(company)
        let roleKey = normalizedKey(role)
        guard !companyKey.isEmpty else { return nil }

        if !roleKey.isEmpty,
           let exactMatch = opportunities.firstIndex(where: {
               normalizedKey($0.company) == companyKey && normalizedKey($0.role) == roleKey
           }) {
            return exactMatch
        }

        let companyMatches = opportunities.indices.filter {
            normalizedKey(opportunities[$0].company) == companyKey
        }
        if roleKey.isEmpty, companyMatches.count == 1 {
            return companyMatches[0]
        }
        return nil
    }

    private static func parsedIdentity(from rawTitle: String) -> (company: String, role: String, roundName: String) {
        let title = rawTitle.collapsedWhitespace
        let roundName = detectedRoundName(in: title)
        var workingTitle = title

        for prefix in [
            "Hiring Manager Interview", "Technical Interview", "Coding Interview",
            "Panel Interview", "Onsite Interview", "Recruiter Screen", "Phone Screen",
            "Technical Round", "Coding Round", "Manager Round", "Final Round",
            "HR Interview", "HR Round", "Screening", "Interview"
        ] {
            workingTitle = removeCaseInsensitivePrefix(prefix, from: workingTitle)
        }
        workingTitle = workingTitle.trimmingCharacters(in: CharacterSet(charactersIn: ":-–—| "))

        if let atRange = workingTitle.range(of: " at ", options: .caseInsensitive) {
            let role = cleanIdentityComponent(String(workingTitle[..<atRange.lowerBound]))
            let company = cleanIdentityComponent(String(workingTitle[atRange.upperBound...]))
            return (company, role, roundName)
        }
        if let atRange = workingTitle.range(of: " @ ", options: .caseInsensitive) {
            let role = cleanIdentityComponent(String(workingTitle[..<atRange.lowerBound]))
            let company = cleanIdentityComponent(String(workingTitle[atRange.upperBound...]))
            return (company, role, roundName)
        }
        if let withRange = workingTitle.range(of: "with ", options: [.caseInsensitive, .anchored]) {
            let company = cleanIdentityComponent(String(workingTitle[withRange.upperBound...]))
            return (company, "", roundName)
        }

        let separators = [" | ", " — ", " – ", " - ", ": "]
        for separator in separators where workingTitle.contains(separator) {
            let parts = workingTitle.components(separatedBy: separator)
                .map(\.collapsedWhitespace)
                .filter { !$0.isBlank }
            guard parts.count >= 2 else { continue }
            let first = cleanIdentityComponent(parts[0])
            let remainder = cleanIdentityComponent(parts.dropFirst().joined(separator: " - "))
            if looksLikeRole(first), !looksLikeRole(remainder) {
                return (remainder, first, roundName)
            }
            if looksLikeRole(remainder), !looksLikeRole(first) {
                return (first, remainder, roundName)
            }
            return (first, remainder, roundName)
        }

        let suffixes = [" Interview", " Screening", " Round"]
        for suffix in suffixes where workingTitle.lowercased().hasSuffix(suffix.lowercased()) {
            let company = String(workingTitle.dropLast(suffix.count)).collapsedWhitespace
            if !company.isBlank {
                return (company, "", roundName)
            }
        }

        if looksLikeRole(workingTitle) {
            return ("", workingTitle, roundName)
        }
        return (workingTitle, "", roundName)
    }

    private static func detectedRoundName(in title: String) -> String {
        roundNames.first(where: { title.localizedCaseInsensitiveContains($0) }) ?? "Calendar Interview"
    }

    private static func removeCaseInsensitivePrefix(_ prefix: String, from value: String) -> String {
        guard value.lowercased().hasPrefix(prefix.lowercased()) else { return value }
        return String(value.dropFirst(prefix.count)).collapsedWhitespace
    }

    private static func cleanIdentityComponent(_ value: String) -> String {
        var result = value.collapsedWhitespace
            .trimmingCharacters(in: CharacterSet(charactersIn: ":-–—| "))
        for suffix in [" Interview", " Screening", " Round"]
        where result.lowercased().hasSuffix(suffix.lowercased()) {
            result = String(result.dropLast(suffix.count)).collapsedWhitespace
        }
        return result
    }

    private static func looksLikeRole(_ value: String) -> Bool {
        let normalized = value.lowercased()
        let roleTerms = [
            "engineer", "developer", "architect", "manager", "designer", "analyst",
            "consultant", "specialist", "director", "lead", "qa", "sre", "devops",
            "backend", "frontend", "full stack", "ios", "macos", "android", "data",
            "product", "program", "project", "security", "support"
        ]
        return roleTerms.contains { normalized.contains($0) }
    }

    private static func normalizedKey(_ value: String) -> String {
        value.collapsedWhitespace.lowercased()
    }

    private static func nilIfBlank(_ value: String) -> String? {
        value.isBlank ? nil : value
    }
}
