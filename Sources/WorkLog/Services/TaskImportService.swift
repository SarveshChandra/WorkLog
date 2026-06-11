import Foundation

enum TaskImportService {
    enum ImportError: LocalizedError, Equatable {
        case invalidJSON
        case invalidTaskEntry(Int)
        case noTasksFound

        var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "The selected file is not valid JSON."
            case let .invalidTaskEntry(index):
                return "Task \(index + 1) is missing usable task content."
            case .noTasksFound:
                return "The selected file does not contain any tasks to import."
            }
        }
    }

    static func decodeWorkExperiences(from url: URL) throws -> [WorkExperience] {
        try decodeWorkExperiences(from: Data(contentsOf: url))
    }

    static func decodeWorkExperiences(from data: Data) throws -> [WorkExperience] {
        if let appData = try? JSONCoders.decoder.decode(AppData.self, from: data),
           !appData.workExperiences.isEmpty {
            return appData.workExperiences
        }

        if let entries = try? JSONCoders.decoder.decode([WorkExperience].self, from: data),
           !entries.isEmpty {
            return entries
        }

        if let entry = try? JSONCoders.decoder.decode(WorkExperience.self, from: data),
           hasMeaningfulTaskContent(entry) {
            return [entry]
        }

        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportError.invalidJSON
        }

        let entries = try decodeFlexibleRoot(root)
        guard !entries.isEmpty else {
            throw ImportError.noTasksFound
        }
        return entries
    }

    private static func decodeFlexibleRoot(_ root: Any) throws -> [WorkExperience] {
        if let dictionary = root as? [String: Any] {
            let object = FlexibleObject(dictionary)
            let defaults = TaskDefaults(object: object)

            if let taskArray = object.array(forAnyKey: ["workExperiences", "tasks", "entries", "items"]) {
                return try taskArray.enumerated().map { index, rawTask in
                    try decodeTask(rawTask, defaults: defaults, index: index)
                }
            }

            let entry = try decodeTask(dictionary, defaults: .empty, index: 0)
            return [entry]
        }

        if let array = root as? [Any] {
            return try array.enumerated().map { index, rawTask in
                try decodeTask(rawTask, defaults: .empty, index: index)
            }
        }

        throw ImportError.invalidJSON
    }

    private static func decodeTask(_ rawTask: Any, defaults: TaskDefaults, index: Int) throws -> WorkExperience {
        if let taskTitle = normalizeShortText(rawTask as? String), !taskTitle.isEmpty {
            return makeWorkExperience(
                id: UUID(),
                company: defaults.company ?? "",
                designation: defaults.designation ?? "",
                role: defaults.role ?? "",
                projectProduct: defaults.projectProduct ?? "",
                team: defaults.team ?? "",
                feature: defaults.feature ?? "",
                task: taskTitle,
                tags: defaults.tags ?? "",
                startDate: defaults.startDate ?? Date(),
                endDate: defaults.endDate ?? defaults.startDate ?? Date(),
                usesDateLogic: defaults.usesDateLogic,
                subtasks: [],
                situation: defaults.situation ?? "",
                expectedResult: defaults.expectedResult ?? "",
                action: defaults.action ?? "",
                outcome: defaults.outcome ?? "",
                challenges: defaults.challenges ?? "",
                skillsUsed: defaults.skillsUsed ?? "",
                learning: defaults.learning ?? "",
                approach: defaults.approach ?? "",
                createdAt: defaults.createdAt,
                updatedAt: defaults.updatedAt
            )
        }

        guard let taskDictionary = rawTask as? [String: Any] else {
            throw ImportError.invalidTaskEntry(index)
        }

        let object = FlexibleObject(taskDictionary)
        let company = firstNonBlank(object.shortText(forAnyKey: ["company", "companyName", "organization", "org"]), defaults.company) ?? ""
        let designation = firstNonBlank(object.shortText(forAnyKey: ["designation", "jobTitle"]), defaults.designation) ?? ""
        let role = firstNonBlank(object.shortText(forAnyKey: ["role", "position"]), defaults.role) ?? ""
        let projectProduct = firstNonBlank(
            object.shortText(forAnyKey: ["projectProduct", "project", "product", "productProject"]),
            defaults.projectProduct
        ) ?? ""
        let team = firstNonBlank(object.shortText(forAnyKey: ["team", "squad", "group"]), defaults.team) ?? ""
        let feature = firstNonBlank(object.shortText(forAnyKey: ["feature", "module", "initiative"]), defaults.feature) ?? ""
        let task = firstNonBlank(object.shortText(forAnyKey: ["task", "title", "summary", "name"]), nil) ?? ""
        let tags = mergeListText(primary: object.value(forAnyKey: ["tags", "labels"]), fallback: defaults.tags)
        let skillsUsed = mergeListText(primary: object.value(forAnyKey: ["skillsUsed", "skills", "techStack", "technologies"]), fallback: defaults.skillsUsed)
        let situation = firstNonBlank(object.longText(forAnyKey: ["situation", "context"]), defaults.situation) ?? ""
        let expectedResult = firstNonBlank(object.longText(forAnyKey: ["expectedResult", "goal", "target", "successCriteria"]), defaults.expectedResult) ?? ""
        let action = firstNonBlank(object.longText(forAnyKey: ["action", "actions", "implementation"]), defaults.action) ?? ""
        let outcome = firstNonBlank(object.longText(forAnyKey: ["outcome", "impact", "result", "results"]), defaults.outcome) ?? ""
        let challenges = firstNonBlank(object.longText(forAnyKey: ["challenges", "challenge", "blockers", "risks"]), defaults.challenges) ?? ""
        let learning = firstNonBlank(object.longText(forAnyKey: ["learning", "learnings", "lessonsLearned"]), defaults.learning) ?? ""
        let approach = firstNonBlank(object.longText(forAnyKey: ["approach", "strategy"]), defaults.approach) ?? ""

        let taskStartDate = object.date(forAnyKey: ["startDate", "date", "from", "startedAt"])
        let taskEndDate = object.date(forAnyKey: ["endDate", "dueDate", "to", "completedAt"])
        let usesDateLogic = taskStartDate != nil || taskEndDate != nil || defaults.usesDateLogic
        let resolvedStartDate = taskStartDate
            ?? defaults.startDate
            ?? taskEndDate
            ?? defaults.endDate
            ?? Date()
        let resolvedEndDate = taskEndDate
            ?? defaults.endDate
            ?? resolvedStartDate

        let createdAt = object.date(forAnyKey: ["createdAt"]) ?? defaults.createdAt
        let updatedAt = object.date(forAnyKey: ["updatedAt", "modifiedAt"]) ?? defaults.updatedAt ?? createdAt
        let subtasks = decodeSubtasks(
            from: object.value(forAnyKey: ["subtasks", "planner", "checklist", "steps"]),
            fallbackDueDate: resolvedEndDate,
            minimumDueDate: resolvedStartDate,
            maximumDueDate: resolvedEndDate
        )

        let entry = makeWorkExperience(
            id: object.uuid(forAnyKey: ["id"]) ?? UUID(),
            company: company,
            designation: designation,
            role: role,
            projectProduct: projectProduct,
            team: team,
            feature: feature,
            task: task,
            tags: tags,
            startDate: resolvedStartDate,
            endDate: resolvedEndDate,
            usesDateLogic: usesDateLogic,
            subtasks: subtasks,
            situation: situation,
            expectedResult: expectedResult,
            action: action,
            outcome: outcome,
            challenges: challenges,
            skillsUsed: skillsUsed,
            learning: learning,
            approach: approach,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        guard hasMeaningfulTaskContent(entry) else {
            throw ImportError.invalidTaskEntry(index)
        }
        return entry
    }

    private static func decodeSubtasks(
        from rawValue: Any?,
        fallbackDueDate: Date,
        minimumDueDate: Date,
        maximumDueDate: Date
    ) -> [WorkExperienceSubtask] {
        guard let rawArray = rawValue as? [Any] else { return [] }

        return rawArray.enumerated().compactMap { index, rawSubtask in
            if let title = normalizeShortText(rawSubtask as? String), !title.isEmpty {
                return WorkExperienceSubtask(
                    title: title,
                    status: .todo,
                    dueDate: fallbackDueDate,
                    order: index
                )
            }

            guard let rawDictionary = rawSubtask as? [String: Any] else {
                return nil
            }

            let object = FlexibleObject(rawDictionary)
            let title = object.shortText(forAnyKey: ["title", "task", "name"]) ?? ""
            guard !title.isEmpty else { return nil }

            let dueDate = min(
                max(object.date(forAnyKey: ["dueDate", "date", "endDate"]) ?? fallbackDueDate, minimumDueDate),
                maximumDueDate
            )

            return WorkExperienceSubtask(
                id: object.uuid(forAnyKey: ["id"]) ?? UUID(),
                title: title,
                status: subtaskStatus(from: object.shortText(forAnyKey: ["status"])) ?? .todo,
                dueDate: dueDate,
                order: object.int(forAnyKey: ["order"]) ?? index
            )
        }
        .sorted { (lhs: WorkExperienceSubtask, rhs: WorkExperienceSubtask) in
            if lhs.order == rhs.order {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.order < rhs.order
        }
        .enumerated()
        .map { pair in
            var updatedSubtask = pair.element
            updatedSubtask.order = pair.offset
            return updatedSubtask
        }
    }

    private static func makeWorkExperience(
        id: UUID,
        company: String,
        designation: String,
        role: String,
        projectProduct: String,
        team: String,
        feature: String,
        task: String,
        tags: String,
        startDate: Date,
        endDate: Date,
        usesDateLogic: Bool,
        subtasks: [WorkExperienceSubtask],
        situation: String,
        expectedResult: String,
        action: String,
        outcome: String,
        challenges: String,
        skillsUsed: String,
        learning: String,
        approach: String,
        createdAt: Date?,
        updatedAt: Date?
    ) -> WorkExperience {
        let normalizedStartDate = startDate
        let normalizedEndDate = endDate < startDate ? startDate : endDate
        let resolvedCreatedAt = createdAt ?? Date()
        let resolvedUpdatedAt = updatedAt ?? resolvedCreatedAt

        return WorkExperience(
            id: id,
            company: company,
            designation: designation,
            role: role,
            projectProduct: projectProduct,
            team: team,
            feature: feature,
            task: task,
            tags: tags,
            startDate: normalizedStartDate,
            endDate: normalizedEndDate,
            usesDateLogic: usesDateLogic,
            subtasks: subtasks,
            situation: situation,
            expectedResult: expectedResult,
            action: action,
            outcome: outcome,
            challenges: challenges,
            skillsUsed: skillsUsed,
            learning: learning,
            approach: approach,
            createdAt: resolvedCreatedAt,
            updatedAt: resolvedUpdatedAt
        )
    }

    private static func hasMeaningfulTaskContent(_ entry: WorkExperience) -> Bool {
        !entry.task.isBlank
            || !entry.feature.isBlank
            || !entry.projectProduct.isBlank
            || !entry.situation.isBlank
            || !entry.expectedResult.isBlank
            || !entry.action.isBlank
            || !entry.outcome.isBlank
            || !entry.challenges.isBlank
            || !entry.skillsUsed.isBlank
            || !entry.learning.isBlank
            || !entry.approach.isBlank
            || !entry.subtasks.isEmpty
    }

    private static func firstNonBlank(_ values: String?...) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.isBlank
        } ?? nil
    }

    private static func mergeListText(primary: Any?, fallback: String?) -> String {
        let mergedValues = uniqueListValues(from: primary) + uniqueListValues(from: fallback)
        return joinedUniqueList(mergedValues)
    }

    private static func uniqueListValues(from rawValue: Any?) -> [String] {
        let values: [String]

        switch rawValue {
        case let string as String:
            values = string
                .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
                .map { normalizeShortText($0) ?? "" }
        case let array as [Any]:
            values = array.compactMap {
                if let string = $0 as? String {
                    return normalizeShortText(string)
                }
                if let number = $0 as? NSNumber {
                    return normalizeShortText(number.stringValue)
                }
                return nil
            }
        case let number as NSNumber:
            values = [number.stringValue]
        case .none:
            values = []
        default:
            values = []
        }

        var seen: Set<String> = []
        var uniqueValues: [String] = []

        for value in values {
            guard !value.isEmpty else { continue }
            let key = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(key).inserted else { continue }
            uniqueValues.append(value)
        }

        return uniqueValues
    }

    private static func joinedUniqueList(_ values: [String]) -> String {
        uniqueListValues(from: values).joined(separator: ", ")
    }

    private static func normalizeShortText(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let normalized = rawValue.collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizeLongText(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedKey(_ key: String) -> String {
        key.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }

    private static func parseDate(_ rawValue: Any?) -> Date? {
        switch rawValue {
        case let date as Date:
            return date
        case let string as String:
            if let parsedDate = JSONCoders.decoder.dateDecodingStrategyDecodedDate(from: string) {
                return parsedDate
            }
            return nil
        case let number as NSNumber:
            let timestamp = number.doubleValue
            let seconds = timestamp > 10_000_000_000 ? timestamp / 1_000 : timestamp
            return Date(timeIntervalSince1970: seconds)
        default:
            return nil
        }
    }

    private static func subtaskStatus(from rawValue: String?) -> WorkExperienceSubtaskStatus? {
        guard let rawValue else { return nil }
        switch normalizedKey(rawValue) {
        case "todo", "tod", "open", "notstarted":
            return .todo
        case "doing", "inprogress", "active":
            return .doing
        case "blocked", "stuck", "paused":
            return .blocked
        case "done", "complete", "completed", "closed":
            return .done
        default:
            return nil
        }
    }

    private struct TaskDefaults {
        var company: String?
        var designation: String?
        var role: String?
        var projectProduct: String?
        var team: String?
        var feature: String?
        var tags: String?
        var startDate: Date?
        var endDate: Date?
        var usesDateLogic = false
        var situation: String?
        var expectedResult: String?
        var action: String?
        var outcome: String?
        var challenges: String?
        var skillsUsed: String?
        var learning: String?
        var approach: String?
        var createdAt: Date?
        var updatedAt: Date?

        static let empty = TaskDefaults()

        init() {}

        init(object: FlexibleObject) {
            company = object.shortText(forAnyKey: ["company", "companyName", "organization", "org"])
            designation = object.shortText(forAnyKey: ["designation", "jobTitle"])
            role = object.shortText(forAnyKey: ["role", "position"])
            projectProduct = object.shortText(forAnyKey: ["projectProduct", "project", "product", "productProject"])
            team = object.shortText(forAnyKey: ["team", "squad", "group"])
            feature = object.shortText(forAnyKey: ["feature", "module", "initiative"])
            tags = joinedUniqueList(uniqueListValues(from: object.value(forAnyKey: ["tags", "labels"])))
            startDate = object.date(forAnyKey: ["startDate", "date", "from", "startedAt"])
            endDate = object.date(forAnyKey: ["endDate", "dueDate", "to", "completedAt"])
            usesDateLogic = startDate != nil || endDate != nil
            situation = object.longText(forAnyKey: ["situation", "context"])
            expectedResult = object.longText(forAnyKey: ["expectedResult", "goal", "target", "successCriteria"])
            action = object.longText(forAnyKey: ["action", "actions", "implementation"])
            outcome = object.longText(forAnyKey: ["outcome", "impact", "result", "results"])
            challenges = object.longText(forAnyKey: ["challenges", "challenge", "blockers", "risks"])
            skillsUsed = joinedUniqueList(uniqueListValues(from: object.value(forAnyKey: ["skillsUsed", "skills", "techStack", "technologies"])))
            learning = object.longText(forAnyKey: ["learning", "learnings", "lessonsLearned"])
            approach = object.longText(forAnyKey: ["approach", "strategy"])
            createdAt = object.date(forAnyKey: ["createdAt"])
            updatedAt = object.date(forAnyKey: ["updatedAt", "modifiedAt"])
        }
    }

    private struct FlexibleObject {
        private let normalizedValues: [String: Any]

        init(_ dictionary: [String: Any]) {
            var normalizedValues: [String: Any] = [:]
            for (key, value) in dictionary {
                normalizedValues[TaskImportService.normalizedKey(key)] = value
            }
            self.normalizedValues = normalizedValues
        }

        func value(forAnyKey keys: [String]) -> Any? {
            for key in keys {
                if let value = normalizedValues[TaskImportService.normalizedKey(key)] {
                    return value
                }
            }
            return nil
        }

        func shortText(forAnyKey keys: [String]) -> String? {
            TaskImportService.normalizeShortText(value(forAnyKey: keys) as? String)
        }

        func longText(forAnyKey keys: [String]) -> String? {
            if let value = value(forAnyKey: keys) as? String {
                return TaskImportService.normalizeLongText(value)
            }
            if let value = value(forAnyKey: keys) as? [String] {
                return TaskImportService.normalizeLongText(value.joined(separator: "\n"))
            }
            return nil
        }

        func date(forAnyKey keys: [String]) -> Date? {
            TaskImportService.parseDate(value(forAnyKey: keys))
        }

        func array(forAnyKey keys: [String]) -> [Any]? {
            value(forAnyKey: keys) as? [Any]
        }

        func int(forAnyKey keys: [String]) -> Int? {
            if let value = value(forAnyKey: keys) as? Int {
                return value
            }
            if let value = value(forAnyKey: keys) as? NSNumber {
                return value.intValue
            }
            if let value = value(forAnyKey: keys) as? String {
                return Int(value)
            }
            return nil
        }

        func uuid(forAnyKey keys: [String]) -> UUID? {
            if let value = value(forAnyKey: keys) as? UUID {
                return value
            }
            if let value = value(forAnyKey: keys) as? String {
                return UUID(uuidString: value)
            }
            return nil
        }
    }
}

private extension JSONDecoder {
    func dateDecodingStrategyDecodedDate(from value: String) -> Date? {
        let iso8601Formatters: [ISO8601DateFormatter] = [
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                return formatter
            }()
        ]

        for formatter in iso8601Formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        let shortDateFormatter = DateFormatter()
        shortDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        shortDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        shortDateFormatter.dateFormat = "yyyy-MM-dd"
        return shortDateFormatter.date(from: value)
    }
}
