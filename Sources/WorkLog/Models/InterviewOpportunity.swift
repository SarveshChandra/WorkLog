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
    case pending = "Pending"
    case submitted = "Submitted"
    case completed = "Completed"
    case advanced = "Advanced"
    case selected = "Selected"
    case offered = "Offered"
    case rejected = "Rejected"
    case withdrawn = "Withdrawn"
    case onHold = "On Hold"

    var id: String { rawValue }
}

struct InterviewRound: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var roundName: String = ""
    var interviewer: String = ""
    var result: String = ""
    var feedback: String = ""
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
        return latestRound.result.isBlank ? status.rawValue : latestRound.result
    }

    var effectiveStatus: InterviewStatus {
        guard let latestRound,
              !latestRound.result.isBlank else {
            return status
        }

        switch latestRound.result.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case RoundOutcomeOption.offered.rawValue.lowercased(),
             RoundOutcomeOption.selected.rawValue.lowercased():
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
           !latestRound.result.isBlank {
            switch latestRound.result.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
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

    var hasRoundOutcome: Bool {
        interviewRounds.contains { !$0.result.isBlank }
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

    mutating func normalizeDerivedFields() {
        source = applicationSource

        if let cooldownPeriodDays {
            self.cooldownPeriodDays = max(cooldownPeriodDays, 0)
            cooldownUntil = nil
        }
        lastActivityDate = calculatedLastActivityDate
    }

    var needsFollowUp: Bool {
        (!nextAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nextActionDueDate != nil) && !effectiveStatusIsClosed
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
            interviewRounds.map { [$0.roundName, $0.interviewer, $0.result, $0.feedback].joined(separator: " ") }.joined(separator: " ")
        ]
        .joined(separator: " ")
    }
}
