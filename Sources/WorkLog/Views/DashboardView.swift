import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var appleIntelligenceState: AppleIntelligenceInsightState = .idle

    private var insights: TaskInsights {
        TaskInsights(entries: store.data.workExperiences)
    }

    private var highlights: DashboardHighlights {
        DashboardHighlights(
            workExperiences: store.data.workExperiences,
            interviewOpportunities: store.data.interviewOpportunities
        )
    }

    private var dashboardInsightTrigger: String {
        let entries = store.data.workExperiences
        let latestUpdate = entries.map(\.updatedAt.timeIntervalSince1970).max() ?? 0
        return "\(entries.count)|\(latestUpdate)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.data.workExperiences.isEmpty && store.data.interviewOpportunities.isEmpty {
                EmptyDetailView(
                    title: "No dashboard data yet",
                    message: "Add Tasks or Interview Tracker entries first. Dashboard summaries appear here after data exists.",
                    systemImage: "chart.bar.doc.horizontal"
                )
            } else {
                ViewThatFits(in: .vertical) {
                    dashboardContent

                    ScrollView {
                        dashboardContent
                            .padding(.bottom, 28)
                    }
                }
                .task(id: dashboardInsightTrigger) {
                    await updateAppleIntelligenceInsights()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            dashboardSummarySections

            if !store.data.workExperiences.isEmpty {
                unifiedInsights
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dashboardSummarySections: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 300), spacing: 18, alignment: .top),
                GridItem(.flexible(minimum: 300), spacing: 18, alignment: .top),
                GridItem(.flexible(minimum: 300), spacing: 18, alignment: .top)
            ],
            alignment: .leading,
            spacing: 18
        ) {
            DashboardCard(
                title: "Incomplete Tasks",
                systemImage: "checklist"
            ) {
                if highlights.incompleteTasks.isEmpty {
                    DashboardEmptyState(text: "No incomplete tasks right now.")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(highlights.incompleteTasks) { item in
                            DashboardTaskRow(item: item)
                        }
                    }
                }
            }

            DashboardCard(
                title: "Upcoming Rounds",
                systemImage: "calendar.badge.clock"
            ) {
                if highlights.upcomingRounds.isEmpty {
                    DashboardEmptyState(text: "No upcoming rounds scheduled.")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(highlights.upcomingRounds) { item in
                            DashboardRoundRow(item: item)
                        }
                    }
                }
            }

            DashboardCard(
                title: "Follow-up Actions",
                systemImage: "bell.badge"
            ) {
                if highlights.followUpActions.isEmpty {
                    DashboardEmptyState(text: "No active follow-up actions.")
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(highlights.followUpActions) { item in
                            DashboardFollowUpRow(item: item)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unifiedInsights: some View {
        let generatedSections = GeneratedInsightSections(text: appleIntelligenceText)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                if let statusMessage = appleIntelligenceMessage {
                    if appleIntelligenceState.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(appleIntelligenceStatusText)
                    .font(.callout)
                    .foregroundStyle(.workLogHeaderText)
            }

            insightGrid(generatedSections: generatedSections)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insightGrid(generatedSections: GeneratedInsightSections) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 360), spacing: 18),
                GridItem(.flexible(minimum: 360), spacing: 18)
            ],
            alignment: .leading,
            spacing: 18
        ) {
            InsightSection(title: "Task Quality", systemImage: "checklist", generatedItems: generatedSections.taskQuality, fallbackItems: insights.taskQualitySignals)
            InsightSection(title: "Achievement Finder", systemImage: "star", generatedItems: generatedSections.achievementFinder, fallbackItems: insights.achievementSignals)
            InsightSection(title: "Skill Growth", systemImage: "chart.line.uptrend.xyaxis", generatedItems: generatedSections.skillGrowth, fallbackItems: insights.skillGrowthSignals)
            InsightSection(title: "Challenge Patterns", systemImage: "exclamationmark.triangle", generatedItems: generatedSections.challengePatterns, fallbackItems: insights.challengePatternSignals)
        }
    }

    private var appleIntelligenceText: String? {
        switch appleIntelligenceState {
        case .generated(let text, _, _):
            return text
        case .loading(let previous), .unavailable(_, let previous), .failed(_, let previous):
            return previous?.insightText
        case .idle:
            return nil
        }
    }

    private var appleIntelligenceStatusText: String {
        switch appleIntelligenceState {
        case .generated(_, let generatedAt, let isCached):
            let cacheLabel = isCached ? "Cached" : "Updated"
            if let generatedAt {
                return "\(cacheLabel) \(AppDateFormatters.statusDateTime.string(from: generatedAt))"
            }
            return cacheLabel
        case .loading(let previous):
            return previous == nil ? "Analyzing" : "Refreshing"
        case .unavailable(_, let previous), .failed(_, let previous):
            return previous == nil ? "Local fallback" : "Last generated insight"
        case .idle:
            return "Preparing"
        }
    }

    private var appleIntelligenceMessage: String? {
        switch appleIntelligenceState {
        case .idle:
            return "Preparing insights..."
        case .loading(let previous):
            return previous == nil ? "Analyzing Tasks on device..." : "Refreshing generated insights; showing last generated and local insights."
        case .unavailable(let message, let previous), .failed(let message, let previous):
            return previous == nil ? "\(message) Showing local insights." : "\(message) Showing last generated and local insights."
        case .generated:
            return nil
        }
    }

    @MainActor
    private func updateAppleIntelligenceInsights() async {
        let entries = store.data.workExperiences
        let previousCache = store.data.dashboardInsightCache
        let snapshotHash = await Task.detached(priority: .utility) {
            TaskSnapshotHasher.hash(for: entries)
        }.value

        if let cache = store.cachedDashboardInsight(for: snapshotHash) {
            appleIntelligenceState = .generated(cache.insightText, generatedAt: cache.generatedAt, isCached: true)
            return
        }

        appleIntelligenceState = .loading(previous: previousCache)

        let result = await AppleIntelligenceTaskAnalyzer.analyze(entries: entries)
        switch result {
        case .generated(let text, _, _):
            let generatedAt = Date()
            store.cacheDashboardInsight(
                taskSnapshotHash: snapshotHash,
                insightText: text,
                taskCount: entries.count,
                generatedAt: generatedAt
            )
            appleIntelligenceState = .generated(text, generatedAt: generatedAt, isCached: false)
        case .unavailable(let message, _):
            appleIntelligenceState = .unavailable(message, previous: previousCache)
        case .failed(let message, _):
            appleIntelligenceState = .failed(message, previous: previousCache)
        case .idle, .loading:
            appleIntelligenceState = result
        }
    }
}

private enum AppleIntelligenceInsightState: Equatable {
    case idle
    case loading(previous: DashboardInsightCache? = nil)
    case generated(String, generatedAt: Date?, isCached: Bool)
    case unavailable(String, previous: DashboardInsightCache?)
    case failed(String, previous: DashboardInsightCache?)

    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        if case .idle = self {
            return true
        }
        return false
    }
}

private struct GeneratedInsightSections {
    var taskQuality: [String] = []
    var achievementFinder: [String] = []
    var skillGrowth: [String] = []
    var challengePatterns: [String] = []

    init(text: String?) {
        guard let text, !text.isBlank else { return }
        var currentSection: InsightKind?

        for line in Self.lines(from: text) {
            if let section = InsightKind(rawHeading: line) {
                currentSection = section
                continue
            }

            guard let currentSection else { continue }
            append(Self.insightText(line), to: currentSection)
        }
    }

    private mutating func append(_ value: String, to section: InsightKind) {
        guard Self.isUsableInsight(value) else { return }
        switch section {
        case .taskQuality:
            taskQuality.append(value)
        case .achievementFinder:
            achievementFinder.append(value)
        case .skillGrowth:
            skillGrowth.append(value)
        case .challengePatterns:
            challengePatterns.append(value)
        }
    }

    private static func lines(from value: String) -> [String] {
        normalized(value)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func normalized(_ value: String) -> String {
        var result = value
            .replacingOccurrences(of: "## ", with: "")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for heading in ["Task Quality:", "Achievement Finder:", "Skill Growth:", "Challenge Patterns:"] {
            result = result.replacingOccurrences(of: heading, with: "\n\n\(heading)\n")
        }

        return result
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func insightText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "*•- "))
    }

    private static func isUsableInsight(_ value: String) -> Bool {
        let words = value
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .filter { !$0.isEmpty }
        return words.count >= 6 && value.contains(" ")
    }
}

private enum InsightKind {
    case taskQuality
    case achievementFinder
    case skillGrowth
    case challengePatterns

    init?(rawHeading: String) {
        let normalized = rawHeading
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            .lowercased()

        switch normalized {
        case "task quality":
            self = .taskQuality
        case "achievement finder":
            self = .achievementFinder
        case "skill growth":
            self = .skillGrowth
        case "challenge patterns":
            self = .challengePatterns
        default:
            return nil
        }
    }
}

private enum AppleIntelligenceTaskAnalyzer {
    static func analyze(entries: [WorkExperience]) async -> AppleIntelligenceInsightState {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return await FoundationModelsTaskAnalyzer.analyze(entries: entries)
        }
        return .unavailable("Apple Intelligence requires macOS 26 or later.", previous: nil)
        #else
        return .unavailable("Apple Intelligence is unavailable in this build because the Foundation Models framework is not present.", previous: nil)
        #endif
    }
}

private enum TaskSnapshotHasher {
    private static let insightVersion = "dashboard-insights-v9-optional-task-dates"

    static func hash(for entries: [WorkExperience]) -> String {
        stableHash("\(insightVersion)\u{1D}\(snapshot(for: entries))")
    }

    private static func snapshot(for entries: [WorkExperience]) -> String {
        entries
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { entry in
                [
                    entry.id.uuidString,
                    entry.company,
                    entry.designation,
                    entry.role,
                    entry.projectProduct,
                    entry.team,
                    entry.feature,
                    entry.task,
                    entry.tags,
                    entry.usesDateLogic ? String(entry.startDate.timeIntervalSince1970) : "undated",
                    entry.usesDateLogic ? String(entry.effectiveEndDate.timeIntervalSince1970) : "undated",
                    entry.plannerStatus.rawValue,
                    entry.plannerProgressText,
                    entry.plannerSnapshotText,
                    entry.usesDateLogic ? (entry.hasDateRange ? "range" : "single-day") : "undated",
                    entry.situation,
                    entry.challenges,
                    entry.skillsUsed,
                    entry.action,
                    entry.outcome,
                    entry.learning,
                    String(entry.updatedAt.timeIntervalSince1970)
                ]
                .joined(separator: "\u{1F}")
            }
            .joined(separator: "\u{1E}")
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }

        return String(format: "%016llx", hash)
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private enum FoundationModelsTaskAnalyzer {
    private static let taskSnapshotCharacterBudget = 5_000

    static func analyze(entries: [WorkExperience]) async -> AppleIntelligenceInsightState {
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            return .unavailable(unavailableMessage(for: reason), previous: nil)
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt(for: entries))
            return .generated(response.content.trimmingCharacters(in: .whitespacesAndNewlines), generatedAt: nil, isCached: false)
        } catch {
            return .failed("Apple Intelligence could not generate Dashboard insights: \(error.localizedDescription)", previous: nil)
        }
    }

    private static let instructions = """
    You analyze a private work-log dashboard inside a macOS app.
    You only have read-only access to synthesized task data.
    Be specific, practical, and useful for career growth.
    Do not claim to edit, update, save, or rewrite any task data.
    """

    private static func prompt(for entries: [WorkExperience]) -> String {
        """
        Analyze the dashboard data below. Return plain text only.
        Do not use Markdown, # headings, ** bold markers, tables, or code blocks.

        Required format, with each section label on its own line and exactly 4 concrete bullet lines per section:
        Task Quality:
        - ...
        - ...
        - ...
        - ...
        Achievement Finder:
        - ...
        - ...
        - ...
        - ...
        Skill Growth:
        - ...
        - ...
        - ...
        - ...
        Challenge Patterns:
        - ...
        - ...
        - ...
        - ...

        Rules:
        - Read-only analysis only.
        - Use the portfolio summary plus task lines together.
        - Mention actual task names, tags, skills, challenges, outcomes, or learnings when useful.
        - Do not write generic praise about the company, engineers, or industry.
        - Do not output single words, role names, company names, or field values as standalone insights.
        - Every bullet must be a useful sentence with 8 to 18 words.
        - Do not invent data.
        - Keep the full answer under 320 words.

        Portfolio summary:
        \(portfolioSummary(from: entries))

        Task lines:
        \(taskSnapshot(from: entries, characterBudget: taskSnapshotCharacterBudget))
        """
    }

    private static func portfolioSummary(from entries: [WorkExperience]) -> String {
        let insights = TaskInsights(entries: entries)
        let sorted = sortedEntries(entries)
        let datedCount = entries.filter(\.usesDateLogic).count
        let missingOutcomeCount = entries.filter { $0.outcome.isBlank }.count
        let missingLearningCount = entries.filter { $0.learning.isBlank }.count
        let missingSkillsCount = entries.filter { $0.skillsUsed.isBlank }.count
        let missingChallengeCount = entries.filter { $0.challenges.isBlank }.count
        let recentTaskTitles = sorted
            .prefix(4)
            .map { compact(displayValue($0.task, empty: "Untitled task"), limit: 34) }
            .joined(separator: "; ")
        let achievementSignals = insights.achievementSignals
            .prefix(3)
            .map { compact($0, limit: 90) }
            .joined(separator: " || ")

        return [
            "Totals: tasks=\(entries.count), recent30d=\(recentEntriesCount(in: entries)), dated=\(datedCount), undated=\(entries.count - datedCount), completeNarratives=\(insights.completeTaskCount).",
            "Coverage gaps: outcome=\(missingOutcomeCount), learning=\(missingLearningCount), skills=\(missingSkillsCount), challenge=\(missingChallengeCount).",
            "Top skills: \(topTerms(from: entries.flatMap { WorkExperienceSkillOptions.skills(in: $0.skillsUsed) }, limit: 5)).",
            "Top tags: \(topTerms(from: entries.flatMap { WorkExperienceTagOptions.tags(in: $0.tags) }, limit: 5)).",
            "Achievement signals: \(achievementSignals.isEmpty ? "None yet." : "\(achievementSignals).")",
            "Most recent tasks: \(recentTaskTitles.isEmpty ? "None yet." : "\(recentTaskTitles).")"
        ].joined(separator: "\n")
    }

    private static func taskSnapshot(from entries: [WorkExperience], characterBudget: Int) -> String {
        let sorted = sortedEntries(entries)
        let detailedLines = sorted.enumerated().map { index, entry in
            detailedTaskLine(index: index + 1, entry: entry)
        }
        let detailedSnapshot = detailedLines.joined(separator: "\n")
        if detailedSnapshot.count <= characterBudget {
            return detailedSnapshot
        }

        let compactLines = sorted.enumerated().map { index, entry in
            compactTaskLine(index: index + 1, entry: entry)
        }
        let compactSnapshot = compactLines.joined(separator: "\n")
        if compactSnapshot.count <= characterBudget {
            return compactSnapshot
        }

        return rolledUpTaskSnapshot(from: sorted, characterBudget: characterBudget)
    }

    private static func rolledUpTaskSnapshot(from entries: [WorkExperience], characterBudget: Int) -> String {
        var visibleLines: [String] = []

        for (index, entry) in entries.enumerated() {
            let candidateLines = visibleLines + [compactTaskLine(index: index + 1, entry: entry)]
            let remainingEntries = Array(entries.dropFirst(candidateLines.count))
            let candidateSnapshot = snapshotText(lines: candidateLines, rolledUpEntries: remainingEntries)

            guard candidateSnapshot.count <= characterBudget else {
                break
            }

            visibleLines = candidateLines
        }

        let rolledUpEntries = Array(entries.dropFirst(visibleLines.count))
        return snapshotText(lines: visibleLines, rolledUpEntries: rolledUpEntries)
    }

    private static func snapshotText(lines: [String], rolledUpEntries: [WorkExperience]) -> String {
        var parts = lines
        if !rolledUpEntries.isEmpty {
            parts.append(rolledUpTaskSummary(for: rolledUpEntries))
        }
        return parts.joined(separator: "\n")
    }

    private static func rolledUpTaskSummary(for entries: [WorkExperience]) -> String {
        let recentTitles = sortedEntries(entries)
            .prefix(3)
            .map { compact(displayValue($0.task, empty: "Untitled task"), limit: 28) }
            .joined(separator: "; ")

        return [
            "RollupCount=\(entries.count)",
            "RecentTitles=\(recentTitles.isEmpty ? "None" : recentTitles)",
            "TopSkills=\(topTerms(from: entries.flatMap { WorkExperienceSkillOptions.skills(in: $0.skillsUsed) }, limit: 4))",
            "TopTags=\(topTerms(from: entries.flatMap { WorkExperienceTagOptions.tags(in: $0.tags) }, limit: 4))",
            "MissingOutcome=\(entries.filter { $0.outcome.isBlank }.count)",
            "MissingLearning=\(entries.filter { $0.learning.isBlank }.count)"
        ].joined(separator: " | ")
    }

    private static func detailedTaskLine(index: Int, entry: WorkExperience) -> String {
        [
            taskLabel(for: index),
            "Co=\(compact(displayValue(entry.company), limit: 16))",
            "Focus=\(compact(focus(for: entry), limit: 28))",
            "Task=\(compact(displayValue(entry.task, empty: "Untitled task"), limit: 42))",
            "Tags=\(compact(displayValue(entry.tags), limit: 26))",
            "Skills=\(compact(displayValue(entry.skillsUsed), limit: 26))",
            "Outcome=\(compact(displayValue(entry.outcome), limit: 34))",
            "Challenge=\(compact(displayValue(entry.challenges), limit: 28))"
        ].joined(separator: " | ")
    }

    private static func compactTaskLine(index: Int, entry: WorkExperience) -> String {
        [
            taskLabel(for: index),
            "Task=\(compact(displayValue(entry.task, empty: "Untitled task"), limit: 34))",
            "Tags=\(compact(displayValue(entry.tags), limit: 18))",
            "Skills=\(compact(displayValue(entry.skillsUsed), limit: 18))",
            "Outcome=\(compact(displayValue(entry.outcome), limit: 26))",
            "Challenge=\(compact(displayValue(entry.challenges), limit: 22))"
        ].joined(separator: " | ")
    }

    private static func sortedEntries(_ entries: [WorkExperience]) -> [WorkExperience] {
        entries.sorted { lhs, rhs in
            if lhs.sortDate == rhs.sortDate {
                if lhs.usesDateLogic && rhs.usesDateLogic, lhs.startDate != rhs.startDate {
                    return lhs.startDate > rhs.startDate
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.sortDate > rhs.sortDate
        }
    }

    private static func recentEntriesCount(in entries: [WorkExperience]) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return entries.filter { $0.sortDate >= cutoff }.count
    }

    private static func topTerms(from values: [String], limit: Int) -> String {
        let counts = values
            .filter { !$0.isBlank }
            .reduce(into: [String: Int]()) { result, value in
                result[value, default: 0] += 1
            }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .prefix(limit)

        guard !counts.isEmpty else { return "None" }
        return counts.map { "\($0.key) (\($0.value))" }.joined(separator: ", ")
    }

    private static func taskLabel(for index: Int) -> String {
        String(format: "T%02d", index)
    }

    private static func focus(for entry: WorkExperience) -> String {
        let values = [entry.projectProduct, entry.feature]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? "Unspecified" : values.joined(separator: " / ")
    }

    private static func displayValue(_ value: String, empty: String = "None") -> String {
        value.isBlank ? empty : value
    }

    private static func compact(_ value: String, limit: Int) -> String {
        let normalized = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard normalized.count > limit else { return normalized }
        let index = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<index]) + "..."
    }

    private static func unavailableMessage(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled on this Mac."
        case .deviceNotEligible:
            return "This Mac is not eligible for Apple Intelligence."
        case .modelNotReady:
            return "Apple Intelligence is not ready yet. The on-device model may still be downloading."
        @unknown default:
            return "Apple Intelligence is unavailable on this Mac."
        }
    }
}
#endif

private struct InsightSection: View {
    var title: String
    var systemImage: String
    var generatedItems: [String]
    var fallbackItems: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.workLogHeaderText)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(generatedItems.enumerated()), id: \.offset) { _, item in
                        InsightRow(text: item, source: .generated)
                    }
                    ForEach(Array(fallbackItems.enumerated()), id: \.offset) { _, item in
                        InsightRow(text: item, source: .fallback)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)
        }
        .frame(height: 340, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.03), radius: 6, y: 1)
    }
}

private struct InsightRow: View {
    var text: String
    var source: InsightSource

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            switch source {
            case .generated:
                Image(systemName: "apple.logo")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 9)
                    .padding(.top, 4)
            case .fallback:
                Circle()
                    .fill(.secondary)
                    .frame(width: 4.5, height: 4.5)
                    .frame(width: 9)
                    .padding(.top, 7)
            }

            Text(text)
                .font(.body)
                .lineSpacing(3)
                .foregroundStyle(text.workLogDisplayColor())
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum InsightSource {
    case generated
    case fallback
}

private struct TaskInsights {
    let entries: [WorkExperience]

    var totalTasks: Int {
        entries.count
    }

    var completeTaskCount: Int {
        entries.filter(isComplete).count
    }

    var achievementCandidateCount: Int {
        achievementCandidates.count
    }

    var uniqueSkillCount: Int {
        uniqueSkills.count
    }

    var challengeSignalCount: Int {
        entries.filter(hasChallengeSignal).count
    }

    var qualityCoverageText: String {
        percentage(completeTaskCount, of: totalTasks)
    }

    var topAchievementText: String {
        achievementCandidates.first?.entry.task.nonBlankValue ?? "No strong candidate yet"
    }

    var topSkillText: String {
        topSkills.first?.name ?? "No skills captured yet"
    }

    var topChallengeText: String {
        topChallengeTags.first?.name ?? "No repeated challenge yet"
    }

    var taskQualitySignals: [String] {
        var signals: [String] = []

        signals.append("\(completeTaskCount) of \(totalTasks) tasks have situation, challenge, skills, action, outcome, and learning captured.")

        appendMissingCount(&signals, title: "outcome", count: entries.filter(\.outcome.isBlank).count)
        appendMissingCount(&signals, title: "learning", count: entries.filter(\.learning.isBlank).count)
        appendMissingCount(&signals, title: "skills used", count: entries.filter(\.skillsUsed.isBlank).count)

        let vagueOutcomes = entries.filter { !$0.outcome.isBlank && isVagueOutcome($0.outcome) }.count
        if vagueOutcomes > 0 {
            signals.append("\(vagueOutcomes) task\(pluralSuffix(vagueOutcomes)) have short or vague outcomes. These are good candidates for manual refinement.")
        }

        if signals.count == 1 && completeTaskCount == totalTasks {
            signals.append("Task quality is strong across the current data set.")
        }

        return signals
    }

    var achievementSignals: [String] {
        let candidates = achievementCandidates.prefix(4)
        guard !candidates.isEmpty else {
            return ["No strong achievement candidates yet. Positive tags plus specific outcomes will make this section more useful."]
        }

        return candidates.map { candidate in
            "\(candidate.entry.task.nonBlankValue): \(candidate.reasons.joined(separator: ", "))."
        }
    }

    var skillGrowthSignals: [String] {
        var signals: [String] = []

        if topSkills.isEmpty {
            signals.append("No skills are captured yet.")
        } else {
            signals.append("Most repeated skills: \(topSkills.prefix(5).map(\.name).joined(separator: ", ")).")
        }

        let highImpactSkills = topSkills(in: achievementCandidates.map(\.entry)).prefix(4)
        if !highImpactSkills.isEmpty {
            signals.append("Skills tied to strongest tasks: \(highImpactSkills.map(\.name).joined(separator: ", ")).")
        }

        let recentSkillNames = topSkills(in: recentEntries).prefix(4).map(\.name)
        if !recentSkillNames.isEmpty {
            signals.append("Recently used skills: \(recentSkillNames.joined(separator: ", ")).")
        }

        return signals
    }

    var challengePatternSignals: [String] {
        var signals: [String] = []

        if topChallengeTags.isEmpty {
            signals.append("No repeated challenge tags yet.")
        } else {
            signals.append("Top challenge tags: \(topChallengeTags.prefix(4).map { "\($0.name) (\($0.count))" }.joined(separator: ", ")).")
        }

        let challengeTasks = entries.filter { !$0.challenges.isBlank }
        signals.append("\(percentage(challengeTasks.count, of: totalTasks)) of tasks include challenge notes.")

        let challengeWithoutLearning = entries.filter { hasChallengeSignal($0) && $0.learning.isBlank }.count
        if challengeWithoutLearning > 0 {
            signals.append("\(challengeWithoutLearning) challenge-heavy task\(pluralSuffix(challengeWithoutLearning)) are missing learning notes.")
        }

        let delayOrDebtCount = entries.filter { entry in
            let values = tags(for: entry)
            return values.contains("Delay / Blocker") || values.contains("Technical Debt")
        }.count
        if delayOrDebtCount > 0 {
            signals.append("\(delayOrDebtCount) task\(pluralSuffix(delayOrDebtCount)) involve delay, blockers, or technical debt.")
        }

        return signals
    }

    private var recentEntries: [WorkExperience] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return entries.filter { $0.sortDate >= cutoff }
    }

    private var uniqueSkills: [String] {
        Array(Set(entries.flatMap { WorkExperienceSkillOptions.skills(in: $0.skillsUsed) })).sorted()
    }

    private var topSkills: [(name: String, count: Int)] {
        topSkills(in: entries)
    }

    private var topChallengeTags: [(name: String, count: Int)] {
        entries
            .flatMap(tags)
            .filter { challengeTags.contains($0) }
            .reduce(into: [String: Int]()) { counts, tag in
                counts[tag, default: 0] += 1
            }
            .map { (name: $0.key, count: $0.value) }
            .sorted(by: rankedBefore)
    }

    private var achievementCandidates: [AchievementCandidate] {
        entries
            .map(candidate)
            .filter { $0.score >= 3 }
            .sorted {
                if $0.score == $1.score {
                    return $0.entry.sortDate > $1.entry.sortDate
                }
                return $0.score > $1.score
            }
    }

    private var challengeTags: Set<String> {
        [
            "Delay / Blocker",
            "Challenging Task",
            "Incident / Production Issue",
            "Technical Debt"
        ]
    }

    private func isComplete(_ entry: WorkExperience) -> Bool {
        !entry.situation.isBlank
            && !entry.challenges.isBlank
            && !entry.skillsUsed.isBlank
            && !entry.action.isBlank
            && !entry.outcome.isBlank
            && !entry.learning.isBlank
    }

    private func hasChallengeSignal(_ entry: WorkExperience) -> Bool {
        !entry.challenges.isBlank || tags(for: entry).contains { challengeTags.contains($0) }
    }

    private func candidate(for entry: WorkExperience) -> AchievementCandidate {
        let positiveTags = tags(for: entry).filter(WorkExperienceTagOptions.isPositive)
        var score = positiveTags.count * 2
        var reasons: [String] = []

        if !positiveTags.isEmpty {
            reasons.append(positiveTags.prefix(2).joined(separator: ", "))
        }
        if hasMeasurableOutcome(entry.outcome) {
            score += 3
            reasons.append("measurable outcome")
        }
        if !entry.challenges.isBlank && !entry.action.isBlank {
            score += 1
            reasons.append("clear challenge and action")
        }
        if !entry.skillsUsed.isBlank {
            score += 1
            reasons.append("skills captured")
        }

        return AchievementCandidate(entry: entry, score: score, reasons: reasons)
    }

    private func hasMeasurableOutcome(_ outcome: String) -> Bool {
        let lowercased = outcome.lowercased()
        let hasNumber = lowercased.rangeOfCharacter(from: .decimalDigits) != nil
        let metricWords = [
            "reduced",
            "increased",
            "improved",
            "cut",
            "shortened",
            "faster",
            "slower",
            "saved",
            "reduced",
            "%"
        ]
        return hasNumber || metricWords.contains { lowercased.contains($0) }
    }

    private func isVagueOutcome(_ outcome: String) -> Bool {
        splitWords(outcome).count < 7 && !hasMeasurableOutcome(outcome)
    }

    private func topSkills(in entries: [WorkExperience]) -> [(name: String, count: Int)] {
        entries
            .flatMap { WorkExperienceSkillOptions.skills(in: $0.skillsUsed) }
            .reduce(into: [String: Int]()) { counts, skill in
                counts[skill, default: 0] += 1
            }
            .map { (name: $0.key, count: $0.value) }
            .sorted(by: rankedBefore)
    }

    private func tags(for entry: WorkExperience) -> [String] {
        WorkExperienceTagOptions.tags(in: entry.tags)
    }

    private func rankedBefore(_ lhs: (name: String, count: Int), _ rhs: (name: String, count: Int)) -> Bool {
        if lhs.count == rhs.count {
            return lhs.name < rhs.name
        }
        return lhs.count > rhs.count
    }

    private func appendMissingCount(_ signals: inout [String], title: String, count: Int) {
        guard count > 0 else { return }
        signals.append("\(count) task\(pluralSuffix(count)) are missing \(title).")
    }

    private func percentage(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(value) / Double(total) * 100).rounded()))%"
    }

    private func pluralSuffix(_ count: Int) -> String {
        count == 1 ? "" : "s"
    }

    private func splitWords(_ value: String) -> [String] {
        value
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
}

private struct DashboardHighlights {
    var incompleteTasks: [DashboardTaskSummary]
    var upcomingRounds: [DashboardRoundSummary]
    var followUpActions: [DashboardFollowUpSummary]

    init(
        workExperiences: [WorkExperience],
        interviewOpportunities: [InterviewOpportunity],
        now: Date = Date()
    ) {
        incompleteTasks = Self.sortedWorkExperiences(workExperiences)
            .filter { !$0.isCompleteForTaskList }
            .map(DashboardTaskSummary.init)

        upcomingRounds = interviewOpportunities
            .flatMap { opportunity in
                opportunity.interviewRounds.compactMap { round in
                    let isSameDayUpcoming = round.statusOption(now: now) == .upcoming
                        && Calendar.current.isDate(round.date, inSameDayAs: now)
                    guard round.isScheduledInFuture(relativeTo: now) || isSameDayUpcoming else {
                        return nil
                    }
                    return DashboardRoundSummary(opportunity: opportunity, round: round)
                }
            }
            .sorted { lhs, rhs in
                if lhs.scheduleDate != rhs.scheduleDate {
                    return lhs.scheduleDate < rhs.scheduleDate
                }
                if lhs.company != rhs.company {
                    return lhs.company.localizedCaseInsensitiveCompare(rhs.company) == .orderedAscending
                }
                if lhs.roundName != rhs.roundName {
                    return lhs.roundName.localizedCaseInsensitiveCompare(rhs.roundName) == .orderedAscending
                }
                return lhs.id < rhs.id
            }

        followUpActions = interviewOpportunities
            .compactMap { opportunity in
                guard opportunity.hasCurrentFollowUp(relativeTo: now),
                      let dueDate = opportunity.currentNextActionDueDate else {
                    return nil
                }
                return DashboardFollowUpSummary(opportunity: opportunity, dueDate: dueDate)
            }
            .sorted { lhs, rhs in
                if lhs.dueDate != rhs.dueDate {
                    return lhs.dueDate < rhs.dueDate
                }
                if lhs.company != rhs.company {
                    return lhs.company.localizedCaseInsensitiveCompare(rhs.company) == .orderedAscending
                }
                if lhs.action != rhs.action {
                    return lhs.action.localizedCaseInsensitiveCompare(rhs.action) == .orderedAscending
                }
                return lhs.id < rhs.id
            }
    }

    var isEmpty: Bool {
        incompleteTasks.isEmpty && upcomingRounds.isEmpty && followUpActions.isEmpty
    }

    private static func sortedWorkExperiences(_ entries: [WorkExperience]) -> [WorkExperience] {
        entries.sorted { lhs, rhs in
            if lhs.sortDate == rhs.sortDate {
                if lhs.usesDateLogic && rhs.usesDateLogic, lhs.startDate != rhs.startDate {
                    return lhs.startDate > rhs.startDate
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.sortDate > rhs.sortDate
        }
    }
}

private struct DashboardTaskSummary: Identifiable {
    let id: UUID
    let title: String
    let context: String
    let status: WorkExperienceSubtaskStatus
    let progressText: String
    let pendingSubtasks: [DashboardPendingSubtask]

    init(entry: WorkExperience) {
        id = entry.id
        title = entry.task.nonBlankValue
        context = Self.contextSummary(for: entry)
        status = entry.plannerStatus
        progressText = entry.plannerProgressText
        pendingSubtasks = entry.orderedSubtasks
            .filter { !$0.status.isDone }
            .map { DashboardPendingSubtask(subtask: $0, usesDateLogic: entry.usesDateLogic) }
    }

    private static func contextSummary(for entry: WorkExperience) -> String {
        let values = [entry.company, entry.projectProduct, entry.feature]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? "Company not set" : values.joined(separator: " • ")
    }
}

private struct DashboardPendingSubtask: Identifiable {
    let id: UUID
    let title: String
    let status: WorkExperienceSubtaskStatus
    let dueText: String?

    init(subtask: WorkExperienceSubtask, usesDateLogic: Bool) {
        id = subtask.id
        title = subtask.displayTitle
        status = subtask.status
        dueText = usesDateLogic ? AppDateFormatters.short(subtask.dueDate) : nil
    }
}

private struct DashboardRoundSummary: Identifiable {
    let id: String
    let company: String
    let role: String
    let roundName: String
    let interviewer: String
    let scheduleText: String
    let scheduleDate: Date
    let usesTime: Bool
    let badgeText: String
    let badgeTint: Color

    init(opportunity: InterviewOpportunity, round: InterviewRound) {
        id = "\(opportunity.id.uuidString)-\(round.id.uuidString)"
        company = opportunity.company.isBlank ? "Untitled company" : opportunity.company
        role = opportunity.role.isBlank ? "Role not set" : opportunity.role
        roundName = round.roundName.isBlank ? "Round" : round.roundName
        interviewer = round.interviewer.isBlank ? "Not set" : round.interviewer
        scheduleDate = round.date
        usesTime = round.usesTime
        scheduleText = round.usesTime
            ? AppDateFormatters.calendarDateTime.string(from: round.date)
            : AppDateFormatters.short(round.date)
        badgeText = "Upcoming"
        badgeTint = .workLogIconGreen
    }
}

private struct DashboardFollowUpSummary: Identifiable {
    let id: String
    let company: String
    let role: String
    let action: String
    let dueDate: Date
    let dueText: String
    let linkedRoundName: String
    let badgeText: String
    let badgeTint: Color

    init(opportunity: InterviewOpportunity, dueDate: Date) {
        id = opportunity.id.uuidString
        company = opportunity.company.isBlank ? "Untitled company" : opportunity.company
        role = opportunity.role.isBlank ? "Role not set" : opportunity.role
        action = opportunity.currentNextAction.isBlank ? "Not set" : opportunity.currentNextAction
        self.dueDate = dueDate
        dueText = AppDateFormatters.calendarDateTime.string(from: dueDate)
        if let linkedRoundID = opportunity.nextActionLinkedRoundID,
           let roundName = opportunity.interviewRounds.first(where: { $0.id == linkedRoundID })?.roundName,
           !roundName.isBlank {
            linkedRoundName = roundName
        } else {
            linkedRoundName = ""
        }
        badgeText = "Follow-up"
        badgeTint = .workLogDoingYellow
    }
}

private struct DashboardCard<Content: View>: View {
    var title: String
    var systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.workLogHeaderText)
            }

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)
        }
        .frame(height: 320, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.03), radius: 6, y: 1)
    }
}

private struct DashboardEmptyState: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(text.workLogDisplayColor(isSecondary: true))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DashboardTaskRow: View {
    var item: DashboardTaskSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.workLogHeaderText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                DashboardBadge(text: item.status.rawValue, tint: item.status.dashboardTint)
            }

            Text(item.progressText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if item.pendingSubtasks.isEmpty {
                DashboardEmptyState(text: "No pending subtasks.")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(item.pendingSubtasks) { subtask in
                        DashboardPendingSubtaskRow(subtask: subtask)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}

private struct DashboardPendingSubtaskRow: View {
    var subtask: DashboardPendingSubtask

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: subtask.status.dashboardSystemImage)
                .foregroundStyle(subtask.status.dashboardTint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(subtask.title)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let dueText = subtask.dueText {
                    Text("Due \(dueText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DashboardRoundRow: View {
    var item: DashboardRoundSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.company)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.workLogHeaderText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                DashboardBadge(text: item.badgeText, tint: item.badgeTint)
            }

            Text(item.roundName)
                .font(.callout)
                .foregroundStyle(.primary)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(item.scheduleText, systemImage: item.usesTime ? "calendar.badge.clock" : "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Text(item.interviewer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}

private struct DashboardFollowUpRow: View {
    var item: DashboardFollowUpSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.company)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.workLogHeaderText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                DashboardBadge(text: item.badgeText, tint: item.badgeTint)
            }

            Text(item.action)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(item.dueText, systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                if !item.linkedRoundName.isBlank {
                    Text(item.linkedRoundName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}

private struct DashboardBadge: View {
    var text: String
    var tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct AchievementCandidate {
    let entry: WorkExperience
    let score: Int
    let reasons: [String]
}

private extension WorkExperienceSubtaskStatus {
    var dashboardSystemImage: String {
        switch self {
        case .todo:
            return "circle"
        case .doing:
            return "play.circle.fill"
        case .blocked:
            return "exclamationmark.triangle.fill"
        case .done:
            return "checkmark.circle.fill"
        }
    }

    var dashboardTint: Color {
        switch self {
        case .todo:
            return .secondary
        case .doing:
            return .workLogDoingYellow
        case .blocked:
            return .orange
        case .done:
            return .workLogIconGreen
        }
    }
}

private extension String {
    var nonBlankValue: String {
        isBlank ? "Untitled task" : self
    }
}
