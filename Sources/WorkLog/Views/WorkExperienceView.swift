import SwiftUI

struct WorkExperienceView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var selectedTag = ""
    @State private var isEditing = false

    private var entries: [WorkExperience] {
        let searchResults = store.filteredWorkExperiences(search: searchText)
        guard !selectedTag.isEmpty else { return searchResults }
        return searchResults.filter { entry in
            tags(in: entry.tags).contains(selectedTag)
        }
    }

    private var availableTags: [String] {
        let savedTags = store.data.workExperiences.flatMap { tags(in: $0.tags) }
        let customTags = savedTags.filter { !WorkExperienceTagOptions.all.contains($0) }
        return WorkExperienceTagOptions.all + customTags.uniqued()
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedWorkID },
            set: { newValue in
                store.selectedWorkID = newValue
                isEditing = false
            }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            PageHeader(
                title: "Tasks",
                subtitle: "Log essential work details, situation, challenges, action, outcome, and learning."
            ) {
                SearchField(placeholder: "Search tasks", text: searchBinding)
                Picker("Tags", selection: tagFilterBinding) {
                    Text("All Tags").tag("")
                    ForEach(availableTags, id: \.self) { tag in
                        Text(tag).tag(tag)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(selectedTag.isEmpty ? .secondary : .workLogSkyBlue)
                .frame(width: 180)
                .opacity(selectedTag.isEmpty ? 0.62 : 1)

                Button {
                    searchText = ""
                    selectedTag = ""
                    store.addWorkExperience()
                    isEditing = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 0) {
                Table(entries, selection: selectionBinding) {
                    TableColumn("Company") { entry in
                        WorkExperienceTableText(entry.company)
                    }
                    .width(min: 200, ideal: 240)

                    TableColumn("Designation") { entry in
                        WorkExperienceTableText(entry.designation)
                    }
                    .width(min: 220, ideal: 260)

                    TableColumn("Role") { entry in
                        WorkExperienceTableText(entry.role)
                    }
                    .width(min: 220, ideal: 260)

                    TableColumn("Product / Project") { entry in
                        WorkExperienceTableText(entry.projectProduct)
                    }
                    .width(min: 240, ideal: 280)

                    TableColumn("Team") { entry in
                        WorkExperienceTableText(entry.team)
                    }
                    .width(min: 180, ideal: 220)

                    TableColumn("Feature") { entry in
                        WorkExperienceTableText(entry.feature)
                    }
                    .width(min: 220, ideal: 260)

                    TableColumn("Task") { entry in
                        WorkExperienceTableText(entry.task.isBlank ? "Untitled task" : entry.task)
                    }
                    .width(min: 320, ideal: 420)

                    TableColumn("Tags") { entry in
                        WorkExperienceTagText(entry.tags, lineLimit: 1)
                            .frame(height: WorkExperienceTableText.rowHeight, alignment: .center)
                    }
                    .width(min: 300, ideal: 400)

                    TableColumn("Date") { entry in
                        WorkExperienceTableText(AppDateFormatters.short(entry.date))
                    }
                    .width(min: 110, ideal: 120)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .background(TableHeaderFontInstaller().frame(width: 0, height: 0))
                .id(store.selectedWorkID == nil ? "tasks-table-full" : "tasks-table-detail")

                if let id = store.selectedWorkID,
                   let binding = store.bindingForWorkExperience(id: id) {
                    Divider()

                    WorkExperienceDetailView(
                        entry: binding,
                        isEditing: $isEditing
                    ) {
                        store.deleteSelectedWorkExperience()
                        isEditing = false
                    }
                    .id(id)
                    .frame(minWidth: 360, idealWidth: 430, maxWidth: 560)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .onReceive(store.$data) { _ in
            reconcileSelection()
        }
    }

    private var tagFilterBinding: Binding<String> {
        Binding(
            get: { selectedTag },
            set: { newValue in
                selectedTag = newValue
                reconcileSelection()
            }
        )
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { searchText },
            set: { newValue in
                searchText = newValue
                reconcileSelection()
            }
        )
    }

    private func reconcileSelection() {
        guard let selectedID = store.selectedWorkID else { return }
        guard !entries.contains(where: { $0.id == selectedID }) else { return }
        store.selectedWorkID = entries.first?.id
        isEditing = false
    }

    private func tags(in value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct WorkExperienceDetailView: View {
    @Binding var entry: WorkExperience
    @Binding var isEditing: Bool
    var onDelete: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()

                    Button {
                        isEditing.toggle()
                    } label: {
                        Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                if isEditing {
                    WorkExperienceEditForm(entry: $entry)
                } else {
                    WorkExperienceReadOnlyView(entry: entry)
                }
            }
            .padding(18)
        }
        .confirmationDialog(
            "Delete this work log?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected work experience entry.")
        }
    }
}

private struct WorkExperienceReadOnlyView: View {
    var entry: WorkExperience

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReadOnlyDetailField(title: "Company", value: entry.company)
            ReadOnlyDetailField(title: "Designation", value: entry.designation)
            ReadOnlyDetailField(title: "Role", value: entry.role)
            ReadOnlyDetailField(title: "Product / Project", value: entry.projectProduct)
            ReadOnlyDetailField(title: "Team", value: entry.team)
            ReadOnlyDetailField(title: "Feature", value: entry.feature)
            ReadOnlyDetailField(title: "Task", value: entry.task)
            ReadOnlyTagsField(value: entry.tags)
            ReadOnlyDetailField(title: "Date", value: AppDateFormatters.short(entry.date), hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Situation", value: entry.situation, isLong: true)
            ReadOnlyDetailField(title: "Challenges", value: entry.challenges, isLong: true)
            ReadOnlyDetailField(title: "Skills Used", value: entry.skillsUsed, isLong: true)
            ReadOnlyDetailField(title: "Action", value: entry.action, isLong: true)
            ReadOnlyDetailField(title: "Outcome", value: entry.outcome, isLong: true)
            ReadOnlyDetailField(title: "Learning", value: entry.learning, isLong: true)
        }
    }
}

private struct ReadOnlyTagsField: View {
    var value: String

    var body: some View {
        if !value.isBlank {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tags")
                    .font(.caption)
                    .foregroundStyle(.workLogHeaderText)
                WorkExperienceTagText(value)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct WorkExperienceTagText: View {
    var value: String
    var lineLimit: Int

    private var tags: [String] {
        WorkExperienceTagOptions.tags(in: value)
    }

    init(_ value: String, lineLimit: Int = 2) {
        self.value = value
        self.lineLimit = lineLimit
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                if index > 0 {
                    Text(", ")
                }
                tagText(tag)
            }
        }
        .lineLimit(lineLimit)
    }

    @ViewBuilder
    private func tagText(_ tag: String) -> some View {
        if WorkExperienceTagOptions.isPositive(tag) {
            Text(tag)
                .fontWeight(.bold)
        } else {
            Text(tag)
        }
    }
}

private struct WorkExperienceTableText: View {
    static let rowHeight: CGFloat = 28

    var value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        Text(value)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: Self.rowHeight, alignment: .center)
    }
}

private struct WorkExperienceEditForm: View {
    @Binding var entry: WorkExperience

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkFieldRow(title: "Company") {
                TextField("Company", text: $entry.company)
            }

            WorkFieldRow(title: "Designation") {
                TextField("Designation", text: $entry.designation)
            }

            WorkFieldRow(title: "Role") {
                TextField("Role", text: $entry.role)
            }

            WorkFieldRow(title: "Product / Project") {
                TextField("Product or project", text: $entry.projectProduct)
            }

            WorkFieldRow(title: "Team") {
                TextField("Team", text: $entry.team)
            }

            WorkFieldRow(title: "Feature") {
                TextField("Feature", text: $entry.feature)
            }

            WorkFieldRow(title: "Task") {
                TextField("Task", text: $entry.task)
            }

            WorkFieldRow(title: "Tags") {
                MultiSelectTagMenu(tags: $entry.tags)
            }

            WorkFieldRow(title: "Date") {
                DatePicker("", selection: $entry.date, displayedComponents: .date)
                    .labelsHidden()
            }

            LabeledTextEditor(title: "Situation", text: $entry.situation, minHeight: 80)
            LabeledTextEditor(title: "Challenges", text: $entry.challenges, minHeight: 80)
            LabeledTextEditor(title: "Skills Used", text: $entry.skillsUsed, minHeight: 70)
            LabeledTextEditor(title: "Action", text: $entry.action, minHeight: 80)
            LabeledTextEditor(title: "Outcome", text: $entry.outcome, minHeight: 80)
            LabeledTextEditor(title: "Learning", text: $entry.learning, minHeight: 80)
        }
    }
}

private struct WorkFieldRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.workLogHeaderText)
            content
        }
    }
}

private struct MultiSelectTagMenu: View {
    @Binding var tags: String

    private var selectedTags: [String] {
        tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var allOptions: [String] {
        let customTags = selectedTags.filter { !WorkExperienceTagOptions.all.contains($0) }
        return WorkExperienceTagOptions.all + customTags
    }

    var body: some View {
        Menu {
            ForEach(allOptions, id: \.self) { tag in
                Button {
                    toggle(tag)
                } label: {
                    Label(tag, systemImage: selectedTags.contains(tag) ? "checkmark" : "circle")
                }
            }

            if !selectedTags.isEmpty {
                Divider()
                Button("Clear Tags") {
                    tags = ""
                }
            }
        } label: {
            HStack {
                Text(tags.isBlank ? "Select tags" : tags)
                    .lineLimit(2)
                    .foregroundStyle(tags.isBlank ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private func toggle(_ tag: String) {
        var values = selectedTags
        if let index = values.firstIndex(of: tag) {
            values.remove(at: index)
        } else {
            values.append(tag)
        }
        tags = values.joined(separator: ", ")
    }
}

enum WorkExperienceTagOptions {
    static let all = [
        "Performance Improvement",
        "High Impact",
        "Delay / Blocker",
        "Challenging Task",
        "Automation",
        "Bug Fix",
        "Incident / Production Issue",
        "Cross-team Work",
        "Customer Impact",
        "Process Improvement",
        "Technical Debt",
        "Architecture / Design",
        "Leadership",
        "Mentoring",
        "Documentation",
        "Team Enablement",
        "Learning / Upskilling"
    ]

    static let positiveTags: Set<String> = [
        "Performance Improvement",
        "High Impact",
        "Automation",
        "Bug Fix",
        "Cross-team Work",
        "Customer Impact",
        "Process Improvement",
        "Architecture / Design",
        "Leadership",
        "Mentoring",
        "Documentation",
        "Learning / Upskilling",
        "Team Enablement"
    ]

    static func tags(in value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func isPositive(_ tag: String) -> Bool {
        positiveTags.contains(tag)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
