import Foundation

enum InterviewStatus: String, CaseIterable, Codable, Identifiable {
    case invited = "Invited"
    case applied = "Applied"
    case interviewing = "Interviewing"
    case waiting = "Waiting"
    case offer = "Offer"
    case rejected = "Rejected"
    case withdrawn = "Withdrawn"
    case closed = "Closed"

    var id: String { rawValue }

    var isClosed: Bool {
        switch self {
        case .offer, .rejected, .withdrawn, .closed:
            true
        case .invited, .applied, .interviewing, .waiting:
            false
        }
    }
}

enum InterviewFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Active"
    case closed = "Closed"
    case eligibleAgain = "Eligible Again"

    var id: String { rawValue }
}

enum ReferralStatusOption: String, CaseIterable, Identifiable {
    case notApplicable = "Not Applicable"
    case toAsk = "To Ask"
    case requested = "Requested"
    case submitted = "Submitted"
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"

    var id: String { rawValue }
}

enum RoundOutcomeOption: String, CaseIterable, Identifiable {
    case upcoming = "Upcoming"
    case submitted = "Submitted"
    case completed = "Completed"
    case advanced = "Advanced"
    case offered = "Offered"
    case rejected = "Rejected"
    case withdrawn = "Withdrawn"
    case onHold = "On Hold"

    var id: String { rawValue }

    static let legacyPendingRawValue = "Pending"
    static let legacySelectedRawValue = "Selected"

    static func normalizedRawValue(
        _ rawValue: String,
        for round: InterviewRound,
        now: Date = Date()
    ) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.localizedCaseInsensitiveCompare(legacyPendingRawValue) == .orderedSame {
            if round.usesTime {
                return round.isScheduledInFuture(relativeTo: now) ? upcoming.rawValue : completed.rawValue
            }
            return round.isScheduledInPast(relativeTo: now) ? completed.rawValue : upcoming.rawValue
        }

        if trimmed.localizedCaseInsensitiveCompare(legacySelectedRawValue) == .orderedSame {
            return offered.rawValue
        }

        if let status = allCases.first(where: {
            $0.rawValue.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return status.rawValue
        }

        return trimmed
    }

    static func option(
        for rawValue: String,
        round: InterviewRound,
        now: Date = Date()
    ) -> RoundOutcomeOption? {
        let normalized = normalizedRawValue(rawValue, for: round, now: now)
        return allCases.first { $0.rawValue == normalized }
    }
}

struct InterviewRound: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var roundName: String = ""
    var interviewer: String = ""
    var result: String = ""
    var feedback: String = ""
    var includesTime: Bool?
    var calendarImportIdentifier: String?
    var calendarEventIdentifier: String?
    var calendarTitle: String?
    var calendarEndDate: Date?
    var calendarLocation: String?
    var calendarMeetingURL: String?
    var calendarAttendees: [String]?
    var calendarEventNotes: String?
    var calendarIsAllDay: Bool?

    var isImportedFromCalendar: Bool {
        !(calendarImportIdentifier?.isBlank ?? true)
    }

    var usesTime: Bool {
        includesTime ?? (isImportedFromCalendar && calendarIsAllDay == false)
    }

    func normalizedStatusValue(now: Date = Date()) -> String {
        RoundOutcomeOption.normalizedRawValue(result, for: self, now: now)
    }

    func statusOption(now: Date = Date()) -> RoundOutcomeOption? {
        RoundOutcomeOption.option(for: result, round: self, now: now)
    }

    func isScheduledInFuture(relativeTo now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        if usesTime {
            return date > now
        }
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
    }

    func isScheduledInPast(relativeTo now: Date = Date()) -> Bool {
        let calendar = Calendar.current
        if usesTime {
            return date < now
        }
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }

    mutating func normalizeLegacyStatus(now: Date = Date()) {
        let normalized = normalizedStatusValue(now: now)
        if normalized != result {
            result = normalized
        }
    }
}

struct InterviewOpportunity: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var company: String = ""
    var role: String = ""
    var source: String = ""
    var applicationLink: String = ""
    var status: InterviewStatus = .applied
    var stage: String = ""
    var appliedDate: Date = Date()
    var lastActivityDate: Date = Date()
    var nextAction: String = ""
    var nextActionDueDate: Date?
    var nextActionLinkedRoundID: UUID?
    var nextActionWasAutoGenerated: Bool = false
    var hasReferral: Bool = false
    var referralChannel: String = ""
    var referralProfileName: String = ""
    var referralEmail: String = ""
    var referralStatus: String = ""
    var referralNotes: String = ""
    var cooldownPeriodDays: Int?
    var cooldownUntil: Date?
    var techStack: String = ""
    var jobDescription: String = ""
    var contactOrInterviewer: String = ""
    var pocEmail: String = ""
    var pocNumber: String = ""
    var interviewRounds: [InterviewRound] = []
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        company: String = "",
        role: String = "",
        source: String = "",
        applicationLink: String = "",
        status: InterviewStatus = .applied,
        stage: String = "",
        appliedDate: Date = Date(),
        lastActivityDate: Date = Date(),
        nextAction: String = "",
        nextActionDueDate: Date? = nil,
        nextActionLinkedRoundID: UUID? = nil,
        nextActionWasAutoGenerated: Bool = false,
        hasReferral: Bool = false,
        referralChannel: String = "",
        referralProfileName: String = "",
        referralEmail: String = "",
        referralStatus: String = "",
        referralNotes: String = "",
        cooldownPeriodDays: Int? = nil,
        cooldownUntil: Date? = nil,
        techStack: String = "",
        jobDescription: String = "",
        contactOrInterviewer: String = "",
        pocEmail: String = "",
        pocNumber: String = "",
        interviewRounds: [InterviewRound] = [],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.company = company
        self.role = role
        self.source = source
        self.applicationLink = applicationLink
        self.status = status
        self.stage = stage
        self.appliedDate = appliedDate
        self.lastActivityDate = lastActivityDate
        self.nextAction = nextAction
        self.nextActionDueDate = nextActionDueDate
        self.nextActionLinkedRoundID = nextActionLinkedRoundID
        self.nextActionWasAutoGenerated = nextActionWasAutoGenerated
        self.hasReferral = hasReferral
        self.referralChannel = referralChannel
        self.referralProfileName = referralProfileName
        self.referralEmail = referralEmail
        self.referralStatus = referralStatus
        self.referralNotes = referralNotes
        self.cooldownPeriodDays = cooldownPeriodDays
        self.cooldownUntil = cooldownUntil
        self.techStack = techStack
        self.jobDescription = jobDescription
        self.contactOrInterviewer = contactOrInterviewer
        self.pocEmail = pocEmail
        self.pocNumber = pocNumber
        self.interviewRounds = interviewRounds
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case company
        case role
        case source
        case applicationLink
        case status
        case stage
        case appliedDate
        case lastActivityDate
        case nextAction
        case nextActionDueDate
        case nextActionLinkedRoundID
        case nextActionWasAutoGenerated
        case hasReferral
        case referralChannel
        case referralProfileName
        case referralEmail
        case referralStatus
        case referralNotes
        case cooldownPeriodDays
        case cooldownUntil
        case techStack
        case jobDescription
        case result
        case contactOrInterviewer
        case pocEmail
        case pocNumber
        case interviewRounds
        case notes
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        company = try container.decodeIfPresent(String.self, forKey: .company) ?? ""
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? ""
        applicationLink = try container.decodeIfPresent(String.self, forKey: .applicationLink) ?? ""
        status = try container.decodeIfPresent(InterviewStatus.self, forKey: .status) ?? .applied
        stage = try container.decodeIfPresent(String.self, forKey: .stage) ?? ""
        appliedDate = try container.decodeIfPresent(Date.self, forKey: .appliedDate) ?? Date()
        lastActivityDate = try container.decodeIfPresent(Date.self, forKey: .lastActivityDate) ?? appliedDate
        nextAction = try container.decodeIfPresent(String.self, forKey: .nextAction) ?? ""
        nextActionDueDate = try container.decodeIfPresent(Date.self, forKey: .nextActionDueDate)
        nextActionLinkedRoundID = try container.decodeIfPresent(UUID.self, forKey: .nextActionLinkedRoundID)
        nextActionWasAutoGenerated = try container.decodeIfPresent(Bool.self, forKey: .nextActionWasAutoGenerated)
            ?? false
        hasReferral = try container.decodeIfPresent(Bool.self, forKey: .hasReferral) ?? false
        referralChannel = try container.decodeIfPresent(String.self, forKey: .referralChannel) ?? ""
        referralProfileName = try container.decodeIfPresent(String.self, forKey: .referralProfileName) ?? ""
        referralEmail = try container.decodeIfPresent(String.self, forKey: .referralEmail) ?? ""
        referralStatus = try container.decodeIfPresent(String.self, forKey: .referralStatus) ?? ""
        referralNotes = try container.decodeIfPresent(String.self, forKey: .referralNotes) ?? ""
        cooldownPeriodDays = try container.decodeIfPresent(Int.self, forKey: .cooldownPeriodDays)
        cooldownUntil = try container.decodeIfPresent(Date.self, forKey: .cooldownUntil)
        techStack = try container.decodeIfPresent(String.self, forKey: .techStack) ?? ""
        jobDescription = try container.decodeIfPresent(String.self, forKey: .jobDescription) ?? ""
        contactOrInterviewer = try container.decodeIfPresent(String.self, forKey: .contactOrInterviewer) ?? ""
        pocEmail = try container.decodeIfPresent(String.self, forKey: .pocEmail) ?? ""
        pocNumber = try container.decodeIfPresent(String.self, forKey: .pocNumber) ?? ""
        interviewRounds = try container.decodeIfPresent([InterviewRound].self, forKey: .interviewRounds) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(company, forKey: .company)
        try container.encode(role, forKey: .role)
        try container.encode(source, forKey: .source)
        try container.encode(applicationLink, forKey: .applicationLink)
        try container.encode(status, forKey: .status)
        try container.encode(stage, forKey: .stage)
        try container.encode(appliedDate, forKey: .appliedDate)
        try container.encode(lastActivityDate, forKey: .lastActivityDate)
        try container.encode(nextAction, forKey: .nextAction)
        try container.encodeIfPresent(nextActionDueDate, forKey: .nextActionDueDate)
        try container.encodeIfPresent(nextActionLinkedRoundID, forKey: .nextActionLinkedRoundID)
        try container.encode(nextActionWasAutoGenerated, forKey: .nextActionWasAutoGenerated)
        try container.encode(hasReferral, forKey: .hasReferral)
        try container.encode(referralChannel, forKey: .referralChannel)
        try container.encode(referralProfileName, forKey: .referralProfileName)
        try container.encode(referralEmail, forKey: .referralEmail)
        try container.encode(referralStatus, forKey: .referralStatus)
        try container.encode(referralNotes, forKey: .referralNotes)
        try container.encodeIfPresent(cooldownPeriodDays, forKey: .cooldownPeriodDays)
        try container.encodeIfPresent(cooldownUntil, forKey: .cooldownUntil)
        try container.encode(techStack, forKey: .techStack)
        try container.encode(jobDescription, forKey: .jobDescription)
        try container.encode(contactOrInterviewer, forKey: .contactOrInterviewer)
        try container.encode(pocEmail, forKey: .pocEmail)
        try container.encode(pocNumber, forKey: .pocNumber)
        try container.encode(interviewRounds, forKey: .interviewRounds)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var isEligibleAgain: Bool {
        guard let cooldownEligibleDate else { return false }
        return Calendar.current.startOfDay(for: cooldownEligibleDate) <= Calendar.current.startOfDay(for: Date())
    }

    var cooldownEligibleDate: Date? {
        if let cooldownPeriodDays {
            return Calendar.current.date(byAdding: .day, value: cooldownPeriodDays, to: calculatedLastActivityDate)
        }
        return cooldownUntil
    }

    var applicationSource: String {
        Self.sourceName(for: applicationLink)
    }

    static func sourceName(for applicationLink: String, fallback: String = "") -> String {
        let trimmedLink = applicationLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else { return "" }

        let normalizedLink = trimmedLink.contains("://") ? trimmedLink : "https://\(trimmedLink)"
        guard let host = URL(string: normalizedLink)?.host?.lowercased() else {
            return ""
        }

        let compactHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let hostParts = compactHost.split(separator: ".").map(String.init)
        if matches(compactHost, domain: "naukri.com") { return "Naukri" }
        if matches(compactHost, domain: "cutshort.io") { return "Cutshort" }
        if matches(compactHost, domain: "linkedin.com") { return "LinkedIn" }
        if hostParts.contains("indeed") { return "Indeed" }
        if matches(compactHost, domain: "instahyre.com") { return "Instahyre" }
        if hostParts.contains("hirist") { return "Hirist" }
        if matches(compactHost, domain: "wellfound.com") || matches(compactHost, domain: "angel.co") { return "Wellfound" }
        if matches(compactHost, domain: "greenhouse.io")
            || matches(compactHost, domain: "lever.co")
            || matches(compactHost, domain: "workdayjobs.com")
            || matches(compactHost, domain: "myworkdayjobs.com")
            || matches(compactHost, domain: "ashbyhq.com")
            || matches(compactHost, domain: "smartrecruiters.com") {
            return "Careers Page"
        }

        return "Careers Page"
    }

    private static func matches(_ host: String, domain: String) -> Bool {
        host == domain || host.hasSuffix(".\(domain)")
    }

    var cooldownPeriodLabel: String {
        guard let cooldownPeriodDays else { return "" }
        return "\(cooldownPeriodDays) days"
    }

    var latestRound: InterviewRound? {
        interviewRounds.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.date == rhs.element.date {
                    return lhs.offset > rhs.offset
                }
                return lhs.element.date > rhs.element.date
            }
            .first?
            .element
    }

    var displayStatus: String {
        guard let latestRound else { return status.rawValue }
        let roundStatus = latestRound.normalizedStatusValue()
        return roundStatus.isBlank ? status.rawValue : roundStatus
    }

    var effectiveStatus: InterviewStatus {
        guard let latestRound,
              !latestRound.normalizedStatusValue().isBlank else {
            return status
        }

        switch latestRound.normalizedStatusValue().trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case RoundOutcomeOption.offered.rawValue.lowercased():
            return .offer
        case RoundOutcomeOption.rejected.rawValue.lowercased():
            return .rejected
        case RoundOutcomeOption.withdrawn.rawValue.lowercased():
            return .withdrawn
        case "closed":
            return .closed
        default:
            return .interviewing
        }
    }

    var effectiveStatusIsClosed: Bool {
        effectiveStatus.isClosed
    }

    var canAppearInEligibleAgain: Bool {
        if let latestRound,
           !latestRound.normalizedStatusValue().isBlank {
            switch latestRound.normalizedStatusValue().trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case RoundOutcomeOption.rejected.rawValue.lowercased(),
                 RoundOutcomeOption.withdrawn.rawValue.lowercased(),
                 "closed":
                return true
            default:
                return false
            }
        }

        switch status {
        case .waiting, .rejected, .withdrawn, .closed:
            return true
        case .invited, .applied, .interviewing, .offer:
            return false
        }
    }

    var canSetCooldownPeriod: Bool {
        canAppearInEligibleAgain
    }

    var calculatedLastActivityDate: Date {
        let roundDates = interviewRounds.map(\.date)
        return ([appliedDate, lastActivityDate] + roundDates).max() ?? appliedDate
    }

    var calculatedStage: String {
        if let latestRound,
           !latestRound.roundName.isBlank {
            return latestRound.roundName
        }

        let statusLabels = Set(InterviewStatus.allCases.map(\.rawValue))
        if !stage.isBlank && !statusLabels.contains(stage) && stage != "Closed" {
            return stage
        }

        return ""
    }

    var nextUpcomingRound: InterviewRound? {
        nextUpcomingRound(relativeTo: Date())
    }

    func nextUpcomingRound(relativeTo now: Date = Date()) -> InterviewRound? {
        interviewRounds
            .filter { $0.statusOption(now: now) == .upcoming }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.roundName.localizedCaseInsensitiveCompare(rhs.roundName) == .orderedAscending
                }
                return lhs.date < rhs.date
            }
            .first
    }

    var hasFollowUpRecord: Bool {
        !nextAction.isBlank || nextActionDueDate != nil
    }

    static func defaultManualFollowUpDueDate(now: Date = Date()) -> Date {
        now.addingTimeInterval(3_600)
    }

    func hasCurrentFollowUp(relativeTo now: Date = Date()) -> Bool {
        guard hasFollowUpRecord,
              !effectiveStatusIsClosed,
              let dueDate = nextActionDueDate else {
            return false
        }

        if let linkedRoundID = nextActionLinkedRoundID,
           let linkedRound = interviewRounds.first(where: { $0.id == linkedRoundID }),
           linkedRound.statusOption(now: now) != .upcoming {
            return false
        }

        return dueDate > now
    }

    var currentNextAction: String {
        hasCurrentFollowUp() ? nextAction : ""
    }

    var currentNextActionDueDate: Date? {
        hasCurrentFollowUp() ? nextActionDueDate : nil
    }

    var referralSummary: String {
        guard hasReferral else { return "" }
        if !referralStatus.isBlank {
            return referralStatus
        }
        if !referralProfileName.isBlank {
            return referralProfileName
        }
        if !referralChannel.isBlank {
            return referralChannel
        }
        return "Yes"
    }

    mutating func normalizeDerivedFields(now: Date = Date()) {
        source = applicationSource

        for index in interviewRounds.indices {
            interviewRounds[index].normalizeLegacyStatus(now: now)
        }

        if !hasFollowUpRecord {
            nextActionLinkedRoundID = nil
            nextActionWasAutoGenerated = false
        }

        if let cooldownPeriodDays {
            self.cooldownPeriodDays = max(cooldownPeriodDays, 0)
            cooldownUntil = nil
        }
        lastActivityDate = calculatedLastActivityDate
    }

    var needsFollowUp: Bool {
        hasCurrentFollowUp()
    }

    var searchText: String {
        [
            company,
            role,
            applicationSource,
            applicationLink,
            status.rawValue,
            displayStatus,
            stage,
            nextAction,
            referralChannel,
            referralProfileName,
            referralEmail,
            referralStatus,
            referralNotes,
            techStack,
            jobDescription,
            contactOrInterviewer,
            pocEmail,
            pocNumber,
            notes,
            interviewRounds.map {
                [
                    $0.roundName,
                    $0.interviewer,
                    $0.normalizedStatusValue(),
                    $0.feedback,
                    $0.calendarTitle ?? "",
                    $0.calendarLocation ?? "",
                    $0.calendarMeetingURL ?? "",
                    $0.calendarAttendees?.joined(separator: " ") ?? "",
                    $0.calendarEventNotes ?? ""
                ]
                .joined(separator: " ")
            }
            .joined(separator: " ")
        ]
        .joined(separator: " ")
    }

    var tableSearchText: String {
        [
            company,
            role,
            applicationSource,
            displayStatus,
            calculatedStage,
            currentNextAction,
            referralSummary,
            latestRound?.interviewer ?? "",
            latestRound?.normalizedStatusValue() ?? ""
        ]
        .joined(separator: " ")
    }
}
