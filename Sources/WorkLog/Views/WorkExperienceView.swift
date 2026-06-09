import AppKit
import SwiftUI

struct WorkExperienceView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var selectedTag = ""
    @State private var isEditing = false
    @State private var taskListReferenceDay = Calendar.current.startOfDay(for: Date())

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

    private var availableSkills: [String] {
        WorkExperienceSkillOptions.merged(
            existing: store.data.workExperiences.flatMap { WorkExperienceSkillOptions.skills(in: $0.skillsUsed) },
            selected: []
        )
    }

    private var rowHighlights: [TableRowHighlight] {
        entries.map { entry in
            if entry.isOverdueForTaskList(referenceDate: taskListReferenceDay) {
                return .overdue
            }
            if !entry.isCompleteForTaskList {
                return .pending
            }
            return .none
        }
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
                subtitle: "Plan work with subtasks and capture situation, challenges, action, outcome, and learning."
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
                        WorkExperienceTableCell {
                            WorkExperienceTableText(entry.company)
                        }
                    }
                    .width(min: 200, ideal: 240)

                    TableColumn("Designation") { entry in
                        WorkExperienceTableCell {
                            WorkExperienceTableText(entry.designation)
                        }
                    }
                    .width(min: 220, ideal: 260)

                    TableColumn("Role") { entry in
                        WorkExperienceTableCell {
                            WorkExperienceTableText(entry.role)
                        }
                    }
                    .width(min: 220, ideal: 260)

                    TableColumn("Product / Project") { entry in
                        WorkExperienceTableCell {
                            WorkExperienceTableText(entry.projectProduct)
                        }
                    }
                    .width(min: 240, ideal: 280)

                    TableColumn("Team") { entry in
                        WorkExperienceTableCell {
                            WorkExperienceTableText(entry.team)
                        }
                    }
                    .width(min: 180, ideal: 220)

                    TableColumn("Feature") { entry in
                        WorkExperienceTableCell {
                            WorkExperienceTableText(entry.feature)
                        }
                    }
                    .width(min: 220, ideal: 260)

                    TableColumn("Task") { entry in
                        WorkExperienceTableCell {
                            WorkExperienceTableText(entry.task.isBlank ? "Untitled task" : entry.task)
                        }
                    }
                    .width(min: 320, ideal: 420)

                    TableColumn("Duration") { entry in
                        WorkExperienceTableCell {
                            WorkExperienceTableText(AppDateFormatters.duration(start: entry.startDate, end: entry.endDate))
                        }
                    }
                    .width(min: 110, ideal: 130)

                    TableColumn("Tags") { entry in
                        WorkExperienceTableCell {
                            WorkExperienceTagText(entry.tags, lineLimit: 1)
                        }
                    }
                    .width(min: 300, ideal: 400)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .background(
                    TableHeaderFontInstaller(
                        rowHighlights: rowHighlights
                    )
                    .frame(width: 0, height: 0)
                )
                .id(store.selectedWorkID == nil ? "tasks-table-full" : "tasks-table-detail")

                if let id = store.selectedWorkID,
                   let binding = store.bindingForWorkExperience(id: id) {
                    Divider()

                    WorkExperienceDetailView(
                        entry: binding,
                        isEditing: $isEditing,
                        availableSkillOptions: availableSkills
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
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshTaskListReferenceDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshTaskListReferenceDay()
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

    private func refreshTaskListReferenceDay(referenceDate: Date = Date()) {
        taskListReferenceDay = Calendar.current.startOfDay(for: referenceDate)
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
    var availableSkillOptions: [String]
    var onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    @State private var selectedTab: WorkExperienceDetailTab = .overview

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

                Picker("Detail", selection: $selectedTab) {
                    ForEach(WorkExperienceDetailTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .tint(.workLogSkyBlue)

                if isEditing {
                    WorkExperienceEditForm(
                        entry: $entry,
                        availableSkillOptions: availableSkillOptions,
                        selectedTab: selectedTab
                    )
                } else {
                    WorkExperienceReadOnlyView(entry: entry, selectedTab: selectedTab)
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

private enum WorkExperienceDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case subtasks = "Subtasks"

    var id: String { rawValue }
}

private struct WorkExperienceReadOnlyView: View {
    var entry: WorkExperience
    var selectedTab: WorkExperienceDetailTab

    private var formattedSkillsUsed: String {
        let skills = WorkExperienceSkillOptions.skills(in: entry.skillsUsed)
        return skills.isEmpty ? entry.skillsUsed : WorkExperienceSkillOptions.joined(skills)
    }

    var body: some View {
        switch selectedTab {
        case .overview:
            VStack(alignment: .leading, spacing: 14) {
                ReadOnlyDetailField(title: "Company", value: entry.company)
                ReadOnlyDetailField(title: "Designation", value: entry.designation)
                ReadOnlyDetailField(title: "Role", value: entry.role)
                ReadOnlyDetailField(title: "Product / Project", value: entry.projectProduct)
                ReadOnlyDetailField(title: "Team", value: entry.team)
                ReadOnlyDetailField(title: "Feature", value: entry.feature)
                ReadOnlyDetailField(title: "Situation", value: entry.situation, isLong: true)
                ReadOnlyDetailField(title: "Task", value: entry.task)
                ReadOnlyDetailField(title: "Expected Result", value: entry.expectedResult, isLong: true)
                ReadOnlyDetailField(title: "Challenges", value: entry.challenges, isLong: true)
                ReadOnlyDetailField(title: "Action", value: entry.action, isLong: true)
                ReadOnlyDetailField(title: "Skills Used", value: formattedSkillsUsed, isLong: true)
                ReadOnlyDetailField(title: "Outcome", value: entry.outcome, isLong: true)
                ReadOnlyDetailField(title: "Learning", value: entry.learning, isLong: true)
                ReadOnlyTagsField(value: entry.tags)
                ReadOnlyDetailField(
                    title: "Dates",
                    value: AppDateFormatters.range(start: entry.startDate, end: entry.endDate),
                    hideWhenEmpty: false
                )
            }
        case .subtasks:
            VStack(alignment: .leading, spacing: 14) {
                WorkExperiencePlannerReadOnlySection(entry: entry)
            }
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
            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, alignment: .leading)
    }
}

private struct WorkExperienceTableCell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct WorkExperienceEditForm: View {
    @Binding var entry: WorkExperience
    var availableSkillOptions: [String]
    var selectedTab: WorkExperienceDetailTab

    var body: some View {
        switch selectedTab {
        case .overview:
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

                LabeledTextEditor(title: "Situation", text: $entry.situation, minHeight: 80)
                WorkFieldRow(title: "Task") {
                    TextField("Task", text: $entry.task)
                }
                LabeledTextEditor(title: "Expected Result", text: $entry.expectedResult, minHeight: 80)
                LabeledTextEditor(title: "Challenges", text: $entry.challenges, minHeight: 80)
                LabeledTextEditor(title: "Action", text: $entry.action, minHeight: 80)
                WorkFieldRow(title: "Skills Used") {
                    MultiSelectSkillPicker(
                        skills: $entry.skillsUsed,
                        allKnownSkills: availableSkillOptions
                    )
                }
                LabeledTextEditor(title: "Outcome", text: $entry.outcome, minHeight: 80)
                LabeledTextEditor(title: "Learning", text: $entry.learning, minHeight: 80)
                WorkFieldRow(title: "Tags") {
                    MultiSelectTagMenu(tags: $entry.tags)
                }
                WorkExperienceDateRangeEditor(entry: $entry)
            }
        case .subtasks:
            VStack(alignment: .leading, spacing: 14) {
                WorkExperiencePlannerEditor(entry: $entry)
            }
        }
    }
}

private struct WorkExperiencePlannerReadOnlySection: View {
    var entry: WorkExperience

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WorkExperiencePlannerPaneSection {
                ReadOnlyDetailField(title: "Approach", value: entry.approach, isLong: true)
            }

            WorkExperiencePlannerPaneSection {
                WorkExperiencePlannerSummaryView(
                    entry: entry,
                    emptyMessage: "No subtasks yet. Use Edit to add a simple checklist."
                )

                if !entry.orderedSubtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entry.orderedSubtasks) { subtask in
                            WorkExperiencePlannerReadOnlyRow(subtask: subtask)
                        }
                    }
                }
            }

            WorkExperiencePlannerPaneSection {
                ReadOnlyDetailField(title: "Expected Result", value: entry.expectedResult, isLong: true)
            }
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

private struct WorkExperiencePlannerEditor: View {
    @Binding var entry: WorkExperience
    @State private var newSubtaskTitle = ""

    private var trimmedDraftTitle: String {
        newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WorkExperiencePlannerPaneSection {
                LabeledTextEditor(title: "Approach", text: $entry.approach, minHeight: 90)
            }

            WorkExperiencePlannerPaneSection {
                WorkExperiencePlannerSummaryView(
                    entry: entry,
                    emptyMessage: "Add subtasks to turn this task into a simple checklist."
                )

                if entry.subtasks.isEmpty {
                    Text("No subtasks yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(entry.subtasks.indices), id: \.self) { index in
                            WorkExperiencePlannerSubtaskRow(
                                subtask: $entry.subtasks[index],
                                minimumDueDate: entry.startDate,
                                maximumDueDate: entry.endDate,
                                canMoveUp: index > 0,
                                canMoveDown: index < entry.subtasks.count - 1,
                                onMoveUp: { moveSubtask(from: index, direction: -1) },
                                onMoveDown: { moveSubtask(from: index, direction: 1) },
                                onDelete: { deleteSubtask(at: index) }
                            )
                        }
                    }
                }
            }

            WorkExperiencePlannerPaneSection {
                VStack(alignment: .leading, spacing: 10) {
                    WorkExperiencePlannerTextEditor(
                        placeholder: "Add subtask",
                        text: $newSubtaskTitle,
                        minHeight: 72
                    )

                    HStack {
                        Spacer()
                        Button {
                            addSubtask()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(trimmedDraftTitle.isEmpty)
                    }
                }
            }

            WorkExperiencePlannerPaneSection {
                ReadOnlyDetailField(title: "Expected Result", value: entry.expectedResult, isLong: true)
            }
        }
    }

    private func addSubtask() {
        guard !trimmedDraftTitle.isEmpty else { return }

        entry.subtasks.append(
            WorkExperienceSubtask(
                title: trimmedDraftTitle,
                status: .todo,
                dueDate: entry.endDate,
                order: entry.subtasks.count
            )
        )
        entry.reindexPlannerSubtasksInCurrentOrder()
        newSubtaskTitle = ""
    }

    private func moveSubtask(from index: Int, direction: Int) {
        let destination = index + direction
        guard entry.subtasks.indices.contains(index),
              entry.subtasks.indices.contains(destination) else {
            return
        }

        let subtask = entry.subtasks.remove(at: index)
        entry.subtasks.insert(subtask, at: destination)
        entry.reindexPlannerSubtasksInCurrentOrder()
    }

    private func deleteSubtask(at index: Int) {
        guard entry.subtasks.indices.contains(index) else { return }
        entry.subtasks.remove(at: index)
        entry.reindexPlannerSubtasksInCurrentOrder()
    }
}

private struct WorkExperiencePlannerPaneSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06))
        }
    }
}

private struct WorkExperiencePlannerSummaryView: View {
    var entry: WorkExperience
    var emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                WorkExperiencePlannerStatusChip(status: entry.plannerStatus)
                Text(entry.plannerProgressText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if entry.totalSubtaskCount == 0 {
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if entry.plannerStatus == .done {
                Text("All subtasks are done.")
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            } else if let nextStep = entry.plannerNextStepText {
                Text("Next step: \(nextStep)")
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                EmptyView()
            }
        }
    }
}

private struct WorkExperiencePlannerReadOnlyRow: View {
    var subtask: WorkExperienceSubtask

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(subtask.order + 1).")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

            Image(systemName: subtask.status.systemImage)
                .foregroundStyle(subtask.status.tint)
                .frame(width: 16)

            Text(subtask.displayTitle)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Text("Due \(AppDateFormatters.short(subtask.dueDate))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct WorkExperiencePlannerSubtaskRow: View {
    @Binding var subtask: WorkExperienceSubtask
    var minimumDueDate: Date
    var maximumDueDate: Date
    var canMoveUp: Bool
    var canMoveDown: Bool
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onDelete: () -> Void

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { min(max(subtask.dueDate, minimumDueDate), maximumDueDate) },
            set: { newValue in
                subtask.dueDate = min(max(newValue, minimumDueDate), maximumDueDate)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("\(subtask.order + 1).")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .trailing)

                Menu {
                    ForEach(WorkExperienceSubtaskStatus.allCases, id: \.self) { status in
                        Button {
                            subtask.status = status
                        } label: {
                            Label(status.rawValue, systemImage: status.systemImage)
                        }
                    }
                } label: {
                    WorkExperiencePlannerStatusChip(status: subtask.status)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveUp ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.35))
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveDown ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.35))
                .disabled(!canMoveDown)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
            }

            WorkExperiencePlannerTextEditor(
                placeholder: "Subtask",
                text: $subtask.title,
                minHeight: 78
            )

            HStack {
                Text("Due")
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker(
                    "",
                    selection: dueDateBinding,
                    in: minimumDueDate...maximumDueDate,
                    displayedComponents: .date
                )
                    .labelsHidden()
            }
            .font(.caption)
        }
    }
}

private struct WorkExperiencePlannerTextEditor: View {
    var placeholder: String
    @Binding var text: String
    var minHeight: CGFloat

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 12)
            }

            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: minHeight)
                .padding(4)
                .scrollContentBackground(.hidden)
        }
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary)
        }
    }
}

private struct WorkExperiencePlannerStatusChip: View {
    var status: WorkExperienceSubtaskStatus

    var body: some View {
        Label(status.rawValue, systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct WorkExperienceDateRangeEditor: View {
    @Binding var entry: WorkExperience

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { entry.startDate },
            set: { newValue in
                entry.startDate = newValue
                entry.normalizeDateRange()
                entry.normalizePlannerSubtasks()
            }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { entry.endDate },
            set: { newValue in
                entry.endDate = newValue
                entry.normalizeDateRange()
                entry.normalizePlannerSubtasks()
            }
        )
    }

    var body: some View {
        WorkFieldRow(title: "Dates") {
            VStack(alignment: .leading, spacing: 10) {
                datePickerRow(title: "Start", selection: startDateBinding)
                datePickerRow(title: "Due", selection: endDateBinding)

                Text(AppDateFormatters.range(start: entry.startDate, end: entry.endDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func datePickerRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
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

private struct MultiSelectSkillPicker: View {
    @Binding var skills: String
    var allKnownSkills: [String]

    @State private var isPresented = false
    @State private var searchText = ""

    private var selectedSkills: [String] {
        WorkExperienceSkillOptions.skills(in: skills)
    }

    private var availableOptions: [String] {
        WorkExperienceSkillOptions.merged(existing: allKnownSkills, selected: selectedSkills)
    }

    private var filteredOptions: [String] {
        let query = WorkExperienceSkillOptions.normalize(searchText)
        guard !query.isEmpty else { return availableOptions }
        return availableOptions.filter { skill in
            skill.localizedCaseInsensitiveContains(query)
        }
    }

    private var pendingNewSkill: String? {
        let candidate = WorkExperienceSkillOptions.normalize(searchText)
        guard !candidate.isEmpty else { return nil }
        guard !WorkExperienceSkillOptions.contains(availableOptions, candidate: candidate) else {
            return nil
        }
        return candidate
    }

    private var summaryText: String {
        guard !selectedSkills.isEmpty else { return "Search, select, or add skills" }
        if selectedSkills.count <= 3 {
            return selectedSkills.joined(separator: ", ")
        }
        return "\(selectedSkills.prefix(3).joined(separator: ", ")) +\(selectedSkills.count - 3) more"
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text(summaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(selectedSkills.isEmpty ? .secondary : .primary)
                Spacer(minLength: 12)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skills")
                        .font(.headline)
                    Text(selectedSkills.isEmpty ? "No skills selected" : "\(selectedSkills.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search or add a skill", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            guard let newSkill = pendingNewSkill else { return }
                            add(newSkill)
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))

                if let newSkill = pendingNewSkill {
                    Button {
                        add(newSkill)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.workLogSkyBlue)
                            Text("Add \"\(newSkill)\"")
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredOptions, id: \.self) { skill in
                            Button {
                                toggle(skill)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedSkills.contains(skill) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedSkills.contains(skill) ? .workLogSkyBlue : .secondary)
                                    Text(skill)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    selectedSkills.contains(skill)
                                        ? Color.workLogSkyBlue.opacity(0.08)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if filteredOptions.isEmpty && pendingNewSkill == nil {
                            Text("No matching skills")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .frame(minWidth: 340, idealWidth: 340, maxWidth: 340, minHeight: 160, maxHeight: 240)

                Divider()

                HStack {
                    if !selectedSkills.isEmpty {
                        Button("Clear Skills") {
                            skills = ""
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .padding(14)
            .onDisappear {
                searchText = ""
            }
        }
    }

    private func toggle(_ skill: String) {
        var values = selectedSkills
        if let index = values.firstIndex(of: skill) {
            values.remove(at: index)
        } else {
            values.append(skill)
        }
        skills = WorkExperienceSkillOptions.joined(values)
    }

    private func add(_ skill: String) {
        guard !WorkExperienceSkillOptions.contains(selectedSkills, candidate: skill) else { return }
        var values = selectedSkills
        values.append(skill)
        skills = WorkExperienceSkillOptions.joined(values)
        searchText = ""
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

private extension WorkExperienceSubtaskStatus {
    var systemImage: String {
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

    var tint: Color {
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

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
