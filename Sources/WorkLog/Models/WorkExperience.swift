import Foundation

struct WorkExperienceSubtask: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String = ""
    var status: WorkExperienceSubtaskStatus = .todo
    var dueDate: Date = Date()
    var order: Int = 0
    fileprivate var needsDueDateBackfill = false

    init(
        id: UUID = UUID(),
        title: String = "",
        status: WorkExperienceSubtaskStatus = .todo,
        dueDate: Date = Date(),
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.dueDate = dueDate
        self.order = order
    }

    static func == (lhs: WorkExperienceSubtask, rhs: WorkExperienceSubtask) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.status == rhs.status
            && lhs.dueDate == rhs.dueDate
            && lhs.order == rhs.order
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(status)
        hasher.combine(dueDate)
        hasher.combine(order)
    }

    var displayTitle: String {
        title.isBlank ? "Untitled subtask" : title
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case dueDate
        case order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        status = try container.decodeIfPresent(WorkExperienceSubtaskStatus.self, forKey: .status) ?? .todo
        let hasDueDate = container.contains(.dueDate)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate) ?? Date()
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        needsDueDateBackfill = !hasDueDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(status, forKey: .status)
        try container.encode(dueDate, forKey: .dueDate)
        try container.encode(order, forKey: .order)
    }
}

enum WorkExperienceSubtaskStatus: String, Codable, CaseIterable, Hashable {
    case todo = "Todo"
    case doing = "Doing"
    case blocked = "Blocked"
    case done = "Done"

    var isDone: Bool {
        self == .done
    }
}

struct WorkExperience: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var company: String = ""
    var designation: String = ""
    var role: String = ""
    var projectProduct: String = ""
    var team: String = ""
    var feature: String = ""
    var task: String = ""
    var tags: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var usesDateLogic: Bool = false
    var subtasks: [WorkExperienceSubtask] = []
    var situation: String = ""
    var expectedResult: String = ""
    var action: String = ""
    var outcome: String = ""
    var challenges: String = ""
    var skillsUsed: String = ""
    var learning: String = ""
    var approach: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        company: String = "",
        designation: String = "",
        role: String = "",
        projectProduct: String = "",
        team: String = "",
        feature: String = "",
        task: String = "",
        tags: String = "",
        startDate: Date = Date(),
        endDate: Date = Date(),
        usesDateLogic: Bool? = nil,
        subtasks: [WorkExperienceSubtask] = [],
        situation: String = "",
        expectedResult: String = "",
        action: String = "",
        outcome: String = "",
        challenges: String = "",
        skillsUsed: String = "",
        learning: String = "",
        approach: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.company = company
        self.designation = designation
        self.role = role
        self.projectProduct = projectProduct
        self.team = team
        self.feature = feature
        self.task = task
        self.tags = tags
        let normalizedRange = Self.normalizedDateRange(start: startDate, end: endDate)
        let resolvedCreatedAt = createdAt
        let resolvedUpdatedAt = updatedAt
        let resolvedUsesDateLogic = usesDateLogic ?? Self.inferredUsesDateLogic(
            hasStoredDateFields: true,
            start: normalizedRange.start,
            end: normalizedRange.end,
            createdAt: resolvedCreatedAt,
            updatedAt: resolvedUpdatedAt
        )
        self.startDate = normalizedRange.start
        self.endDate = normalizedRange.end
        self.usesDateLogic = resolvedUsesDateLogic
        self.subtasks = Self.normalizedSubtasks(
            subtasks,
            fallbackDueDate: resolvedUsesDateLogic ? normalizedRange.end : nil,
            minimumDueDate: resolvedUsesDateLogic ? normalizedRange.start : nil,
            maximumDueDate: resolvedUsesDateLogic ? normalizedRange.end : nil
        )
        self.situation = situation
        self.expectedResult = expectedResult
        self.action = action
        self.outcome = outcome
        self.challenges = challenges
        self.skillsUsed = skillsUsed
        self.learning = learning
        self.approach = approach
        self.createdAt = resolvedCreatedAt
        self.updatedAt = resolvedUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case company
        case designation
        case role
        case projectProduct
        case team
        case feature
        case task
        case tags
        case startDate
        case endDate
        case usesDateLogic
        case subtasks
        case date
        case situation
        case expectedResult
        case action
        case outcome
        case impact
        case challenges
        case skillsUsed
        case learning
        case approach
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        company = try container.decodeIfPresent(String.self, forKey: .company) ?? ""
        designation = try container.decodeIfPresent(String.self, forKey: .designation) ?? ""
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? ""
        projectProduct = try container.decodeIfPresent(String.self, forKey: .projectProduct) ?? ""
        team = try container.decodeIfPresent(String.self, forKey: .team) ?? ""
        feature = try container.decodeIfPresent(String.self, forKey: .feature) ?? ""
        task = try container.decodeIfPresent(String.self, forKey: .task) ?? ""
        tags = try container.decodeIfPresent(String.self, forKey: .tags) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        let legacyDate = try container.decodeIfPresent(Date.self, forKey: .date)
        let decodedStartDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? legacyDate ?? Date()
        let decodedEndDate = try container.decodeIfPresent(Date.self, forKey: .endDate) ?? decodedStartDate
        let normalizedRange = Self.normalizedDateRange(start: decodedStartDate, end: decodedEndDate)
        let hasStoredDateFields = container.contains(.startDate) || container.contains(.endDate) || container.contains(.date)
        startDate = normalizedRange.start
        endDate = normalizedRange.end
        usesDateLogic = try container.decodeIfPresent(Bool.self, forKey: .usesDateLogic)
            ?? Self.inferredUsesDateLogic(
                hasStoredDateFields: hasStoredDateFields,
                start: normalizedRange.start,
                end: normalizedRange.end,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        subtasks = Self.normalizedSubtasks(
            try container.decodeIfPresent([WorkExperienceSubtask].self, forKey: .subtasks) ?? [],
            fallbackDueDate: usesDateLogic ? normalizedRange.end : nil,
            minimumDueDate: usesDateLogic ? normalizedRange.start : nil,
            maximumDueDate: usesDateLogic ? normalizedRange.end : nil
        )
        situation = try container.decodeIfPresent(String.self, forKey: .situation) ?? ""
        expectedResult = try container.decodeIfPresent(String.self, forKey: .expectedResult) ?? ""
        action = try container.decodeIfPresent(String.self, forKey: .action) ?? ""
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome)
            ?? container.decodeIfPresent(String.self, forKey: .impact)
            ?? ""
        challenges = try container.decodeIfPresent(String.self, forKey: .challenges) ?? ""
        skillsUsed = try container.decodeIfPresent(String.self, forKey: .skillsUsed) ?? ""
        learning = try container.decodeIfPresent(String.self, forKey: .learning) ?? ""
        approach = try container.decodeIfPresent(String.self, forKey: .approach) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(company, forKey: .company)
        try container.encode(designation, forKey: .designation)
        try container.encode(role, forKey: .role)
        try container.encode(projectProduct, forKey: .projectProduct)
        try container.encode(team, forKey: .team)
        try container.encode(feature, forKey: .feature)
        try container.encode(task, forKey: .task)
        try container.encode(tags, forKey: .tags)
        let normalizedRange = Self.normalizedDateRange(start: startDate, end: endDate)
        try container.encode(normalizedRange.start, forKey: .startDate)
        try container.encode(normalizedRange.end, forKey: .endDate)
        try container.encode(usesDateLogic, forKey: .usesDateLogic)
        try container.encode(
            Self.normalizedSubtasks(
                subtasks,
                fallbackDueDate: usesDateLogic ? normalizedRange.end : nil,
                minimumDueDate: usesDateLogic ? normalizedRange.start : nil,
                maximumDueDate: usesDateLogic ? normalizedRange.end : nil
            ),
            forKey: .subtasks
        )
        try container.encode(normalizedRange.start, forKey: .date)
        try container.encode(situation, forKey: .situation)
        try container.encode(expectedResult, forKey: .expectedResult)
        try container.encode(action, forKey: .action)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(challenges, forKey: .challenges)
        try container.encode(skillsUsed, forKey: .skillsUsed)
        try container.encode(learning, forKey: .learning)
        try container.encode(approach, forKey: .approach)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var searchText: String {
        [
            company,
            designation,
            role,
            projectProduct,
            team,
            feature,
            task,
            tags,
            subtasks.map(\.displayTitle).joined(separator: " "),
            situation,
            expectedResult,
            challenges,
            skillsUsed,
            action,
            outcome,
            learning,
            approach
        ]
        .joined(separator: " ")
    }

    var tableSearchText: String {
        [
            company,
            designation,
            role,
            projectProduct,
            team,
            feature,
            task,
            tags
        ]
        .joined(separator: " ")
    }

    var dateSummaryText: String {
        usesDateLogic ? AppDateFormatters.range(start: startDate, end: endDate) : "Unknown"
    }

    var durationText: String {
        usesDateLogic ? AppDateFormatters.duration(start: startDate, end: endDate) : "Unknown"
    }

    var effectiveEndDate: Date {
        usesDateLogic ? endDate : updatedAt
    }

    var sortDate: Date {
        effectiveEndDate
    }

    var hasDateRange: Bool {
        usesDateLogic && !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }

    var orderedSubtasks: [WorkExperienceSubtask] {
        Self.normalizedSubtasks(
            subtasks,
            fallbackDueDate: usesDateLogic ? endDate : nil,
            minimumDueDate: usesDateLogic ? startDate : nil,
            maximumDueDate: usesDateLogic ? endDate : nil
        )
    }

    var totalSubtaskCount: Int {
        orderedSubtasks.count
    }

    var completedSubtaskCount: Int {
        orderedSubtasks.filter { $0.status.isDone }.count
    }

    var plannerStatus: WorkExperienceSubtaskStatus {
        guard !orderedSubtasks.isEmpty else { return .todo }
        if completedSubtaskCount == totalSubtaskCount {
            return .done
        }
        if orderedSubtasks.contains(where: { $0.status == .blocked }) {
            return .blocked
        }
        if orderedSubtasks.contains(where: { $0.status == .doing }) || completedSubtaskCount > 0 {
            return .doing
        }
        return .todo
    }

    var nextSubtask: WorkExperienceSubtask? {
        orderedSubtasks.first { !$0.status.isDone }
    }

    var plannerProgressText: String {
        guard totalSubtaskCount > 0 else { return "No subtasks yet" }
        return "\(completedSubtaskCount) of \(totalSubtaskCount) done"
    }

    var plannerNextStepText: String? {
        nextSubtask?.displayTitle
    }

    var plannerListSummary: String {
        guard totalSubtaskCount > 0 else { return "No plan yet" }
        let summary = "\(plannerStatus.rawValue) | \(completedSubtaskCount)/\(totalSubtaskCount)"
        guard let nextSubtask else {
            return summary
        }
        return "\(summary) | \(nextSubtask.displayTitle)"
    }

    var plannerSnapshotText: String {
        guard totalSubtaskCount > 0 else { return "No subtasks" }
        return orderedSubtasks
            .map { subtask in
                if usesDateLogic {
                    return "\(subtask.order + 1). \(subtask.status.rawValue), due \(AppDateFormatters.short(subtask.dueDate)): \(subtask.displayTitle)"
                }
                return "\(subtask.order + 1). \(subtask.status.rawValue): \(subtask.displayTitle)"
            }
            .joined(separator: "; ")
    }

    var hasCompleteSTARFields: Bool {
        !task.isBlank
            && !situation.isBlank
            && !action.isBlank
            && !outcome.isBlank
    }

    var hasCompletedAllSubtasks: Bool {
        totalSubtaskCount == 0 || completedSubtaskCount == totalSubtaskCount
    }

    var isCompleteForTaskList: Bool {
        hasCompleteSTARFields && hasCompletedAllSubtasks
    }

    var isOverdueForTaskList: Bool {
        isOverdueForTaskList(referenceDate: Date())
    }

    func isOverdueForTaskList(referenceDate: Date) -> Bool {
        guard usesDateLogic, !isCompleteForTaskList else { return false }

        let calendar = Calendar.current
        let dueDay = calendar.startOfDay(for: endDate)
        let today = calendar.startOfDay(for: referenceDate)
        return dueDay < today
    }

    mutating func normalizeDateRange() {
        let normalizedRange = Self.normalizedDateRange(start: startDate, end: endDate)
        startDate = normalizedRange.start
        endDate = normalizedRange.end
    }

    mutating func normalizePlannerSubtasks() {
        subtasks = Self.normalizedSubtasks(
            subtasks,
            fallbackDueDate: usesDateLogic ? endDate : nil,
            minimumDueDate: usesDateLogic ? startDate : nil,
            maximumDueDate: usesDateLogic ? endDate : nil
        )
    }

    mutating func setDateLogicEnabled(_ isEnabled: Bool, anchorDate: Date = Date()) {
        guard usesDateLogic != isEnabled else { return }
        if isEnabled && Self.looksLikePlaceholderDateRange(
            start: startDate,
            end: endDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        ) {
            let anchoredDay = Calendar.current.startOfDay(for: anchorDate)
            startDate = anchoredDay
            endDate = anchoredDay
        }
        usesDateLogic = isEnabled
        normalizeDateRange()
        normalizePlannerSubtasks()
    }

    mutating func reindexPlannerSubtasksInCurrentOrder() {
        subtasks = subtasks.enumerated().map { index, subtask in
            var updatedSubtask = subtask
            updatedSubtask.order = index
            return updatedSubtask
        }
    }

    private static func normalizedDateRange(start: Date, end: Date) -> (start: Date, end: Date) {
        if end < start {
            return (start, start)
        }

        return (start, end)
    }

    private static func inferredUsesDateLogic(
        hasStoredDateFields: Bool,
        start: Date,
        end: Date,
        createdAt: Date,
        updatedAt: Date
    ) -> Bool {
        guard hasStoredDateFields else { return false }
        return !looksLikePlaceholderDateRange(
            start: start,
            end: end,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func looksLikePlaceholderDateRange(
        start: Date,
        end: Date,
        createdAt: Date,
        updatedAt: Date
    ) -> Bool {
        guard Calendar.current.isDate(start, inSameDayAs: end) else { return false }
        let matchesCreationTime = abs(start.timeIntervalSince(createdAt)) < 120
        let matchesUpdateTime = abs(end.timeIntervalSince(updatedAt)) < 120
        return matchesCreationTime && matchesUpdateTime
    }

    private static func normalizedSubtasks(
        _ subtasks: [WorkExperienceSubtask],
        fallbackDueDate: Date? = nil,
        minimumDueDate: Date? = nil,
        maximumDueDate: Date? = nil
    ) -> [WorkExperienceSubtask] {
        subtasks
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.order == rhs.element.order {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.order < rhs.element.order
            }
            .enumerated()
            .map { normalizedIndex, pair in
                var subtask = pair.element
                subtask.order = normalizedIndex
                if subtask.needsDueDateBackfill {
                    subtask.dueDate = fallbackDueDate ?? subtask.dueDate
                    subtask.needsDueDateBackfill = false
                }
                if let minimumDueDate, subtask.dueDate < minimumDueDate {
                    subtask.dueDate = minimumDueDate
                }
                if let maximumDueDate, subtask.dueDate > maximumDueDate {
                    subtask.dueDate = maximumDueDate
                }
                return subtask
            }
    }
}

enum WorkExperienceSkillOptions {
    static func skills(in value: String) -> [String] {
        uniqueSkills(
            from: value.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
        )
    }

    static func joined(_ skills: [String]) -> String {
        uniqueSkills(from: skills).joined(separator: ", ")
    }

    static func merged(existing: [String], selected: [String]) -> [String] {
        let selectedSkills = uniqueSkills(from: selected)
        let selectedKeys = Set(selectedSkills.map(skillKey(for:)))
        let remainingSkills = uniqueSkills(from: existing)
            .filter { !selectedKeys.contains(skillKey(for: $0)) }
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        return selectedSkills + remainingSkills
    }

    static func contains(_ skills: [String], candidate: String) -> Bool {
        let candidateKey = skillKey(for: candidate)
        return skills.contains { skillKey(for: $0) == candidateKey }
    }

    static func normalize(_ skill: String) -> String {
        skill
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func uniqueSkills(from rawSkills: [String]) -> [String] {
        var seen: Set<String> = []
        var unique: [String] = []

        for rawSkill in rawSkills {
            let normalizedSkill = normalize(rawSkill)
            guard !normalizedSkill.isEmpty else { continue }

            let key = skillKey(for: normalizedSkill)
            guard seen.insert(key).inserted else { continue }
            unique.append(normalizedSkill)
        }

        return unique
    }

    private static func skillKey(for skill: String) -> String {
        normalize(skill).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
