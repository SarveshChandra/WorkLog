import Foundation

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
    var date: Date = Date()
    var situation: String = ""
    var action: String = ""
    var outcome: String = ""
    var challenges: String = ""
    var skillsUsed: String = ""
    var learning: String = ""
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
        date: Date = Date(),
        situation: String = "",
        action: String = "",
        outcome: String = "",
        challenges: String = "",
        skillsUsed: String = "",
        learning: String = "",
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
        self.date = date
        self.situation = situation
        self.action = action
        self.outcome = outcome
        self.challenges = challenges
        self.skillsUsed = skillsUsed
        self.learning = learning
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
        case date
        case situation
        case action
        case outcome
        case impact
        case challenges
        case skillsUsed
        case learning
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
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        situation = try container.decodeIfPresent(String.self, forKey: .situation) ?? ""
        action = try container.decodeIfPresent(String.self, forKey: .action) ?? ""
        outcome = try container.decodeIfPresent(String.self, forKey: .outcome)
            ?? container.decodeIfPresent(String.self, forKey: .impact)
            ?? ""
        challenges = try container.decodeIfPresent(String.self, forKey: .challenges) ?? ""
        skillsUsed = try container.decodeIfPresent(String.self, forKey: .skillsUsed) ?? ""
        learning = try container.decodeIfPresent(String.self, forKey: .learning) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
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
        try container.encode(date, forKey: .date)
        try container.encode(situation, forKey: .situation)
        try container.encode(action, forKey: .action)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(challenges, forKey: .challenges)
        try container.encode(skillsUsed, forKey: .skillsUsed)
        try container.encode(learning, forKey: .learning)
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
            situation,
            challenges,
            skillsUsed,
            action,
            outcome,
            learning
        ]
        .joined(separator: " ")
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
