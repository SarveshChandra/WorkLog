import SwiftUI

struct InterviewTrackerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var showCloseEditingConfirmation = false
    @State private var pendingSearchText: String?
    @State private var pendingInterviewFilter: InterviewFilter?

    private var opportunities: [InterviewOpportunity] {
        filteredOpportunities(search: searchText, filter: store.interviewFilter)
    }

    private var outlinedRowIndex: Int? {
        guard let selectedID = store.selectedOpportunityID else { return nil }
        return opportunities.firstIndex { $0.id == selectedID }
    }

    private var currentTableLayoutSignature: Int {
        var hasher = Hasher()
        hasher.combine(store.interviewFilter.rawValue)
        hasher.combine(opportunities.count)

        for opportunity in opportunities {
            hasher.combine(opportunity.id)
            hasher.combine(opportunity.company)
            hasher.combine(opportunity.role)
            hasher.combine(opportunity.displayStatus)
            hasher.combine(opportunity.calculatedStage)
            hasher.combine(opportunity.nextAction)
            hasher.combine(opportunity.nextActionDueDate)
            hasher.combine(opportunity.cooldownEligibleDate)
            hasher.combine(opportunity.techStack)
            hasher.combine(opportunity.referralProfileName)
            hasher.combine(opportunity.referralChannel)
            hasher.combine(opportunity.referralEmail)
            hasher.combine(opportunity.referralStatus)
            hasher.combine(opportunity.calculatedLastActivityDate)
            hasher.combine(opportunity.latestRound?.interviewer)
            hasher.combine(opportunity.latestRound?.result)
            hasher.combine(opportunity.contactOrInterviewer)
            hasher.combine(opportunity.pocEmail)
            hasher.combine(opportunity.pocNumber)
            hasher.combine(opportunity.notes)
        }

        return hasher.finalize()
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedOpportunityID },
            set: { newValue in
                if newValue == nil, isEditing, store.selectedOpportunityID != nil {
                    showCloseEditingConfirmation = true
                    return
                }
                store.selectedOpportunityID = newValue
                isEditing = false
            }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            PageHeader(
                title: "Interview Tracker",
                subtitle: "Enter company, role, application link, status, next action, and PoC details. Source, round, last activity, referral summary, and re-eligible date are calculated."
            ) {
                SearchField(placeholder: "Search opportunities", text: searchBinding)
                IconOnlyActionButton("Add", systemImage: "plus") {
                    searchText = ""
                    store.interviewFilter = .all
                    store.addInterviewOpportunity()
                    isEditing = true
                }
            }

            Picker("View", selection: interviewFilterBinding) {
                ForEach(InterviewFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .tint(.workLogSkyBlue)
            .opacity(store.interviewFilter == .all ? 0.62 : 1)
            .padding(.vertical, 6)

            StableDetailPaneLayout(showsDetail: store.selectedOpportunityID != nil) {
                tableView
            } detail: {
                if let id = store.selectedOpportunityID,
                   let binding = store.bindingForOpportunity(id: id) {
                    InterviewOpportunityDetailView(
                        opportunity: binding,
                        isEditing: $isEditing,
                        onClose: {
                            requestCloseDetailPane()
                        },
                        onDelete: {
                            store.deleteSelectedInterviewOpportunity()
                            isEditing = false
                        }
                    )
                    .id(id)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .onReceive(store.$data) { _ in
            reconcileSelection()
        }
        .confirmationDialog(
            "Close the interview details?",
            isPresented: $showCloseEditingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Close", role: .destructive) {
                confirmCloseDetailPane()
            }
            Button("Cancel", role: .cancel) {
                clearPendingFilterChanges()
            }
        } message: {
            Text("You are editing this opportunity. Close the right pane?")
        }
    }

    @ViewBuilder
    private var tableView: some View {
        if store.interviewFilter == .active {
            activeTable
        } else if store.interviewFilter == .closed {
            closedTable
        } else if store.interviewFilter == .eligibleAgain {
            eligibleAgainTable
        } else {
            defaultTable
        }
    }

    private var defaultTable: some View {
        Table(opportunities, selection: selectionBinding) {
            TableColumn("Opportunity") { opportunity in
                VStack(alignment: .leading, spacing: 2) {
                    TableValueText(value: opportunity.company.isBlank ? "Untitled company" : opportunity.company)
                    TableValueText(
                        value: opportunity.role.isBlank ? "Role not set" : opportunity.role,
                        style: .caption,
                        isSecondary: true
                    )
                }
            }
            .width(360)

            TableColumn("Status") { opportunity in
                TableValueText(value: opportunity.displayStatus)
            }
            .width(150)

            TableColumn("Round") { opportunity in
                TableValueText(value: opportunity.calculatedStage)
            }
            .width(220)

            TableColumn("Next Action") { opportunity in
                TableValueText(value: opportunity.nextAction)
            }
            .width(440)

            TableColumn("Due") { opportunity in
                TableValueText(value: AppDateFormatters.short(opportunity.nextActionDueDate))
            }
            .width(120)

            TableColumn("Re-Eligible Date") { opportunity in
                TableValueText(value: AppDateFormatters.short(opportunity.cooldownEligibleDate))
            }
            .width(190)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(
            TableHeaderFontInstaller(
                layoutSignature: currentTableLayoutSignature,
                outlinedRowIndex: outlinedRowIndex
            )
            .frame(width: 0, height: 0)
        )
    }

    private var activeTable: some View {
        Table(opportunities, selection: selectionBinding) {
            TableColumn("Opportunity") { opportunity in
                VStack(alignment: .leading, spacing: 2) {
                    TableValueText(value: opportunity.company.isBlank ? "Untitled company" : opportunity.company)
                    TableValueText(
                        value: opportunity.role.isBlank ? "Role not set" : opportunity.role,
                        style: .caption,
                        isSecondary: true
                    )
                }
            }
            .width(360)

            TableColumn("Status") { opportunity in
                TableValueText(value: opportunity.displayStatus)
            }
            .width(150)

            TableColumn("Round") { opportunity in
                TableValueText(value: opportunity.calculatedStage)
            }
            .width(220)

            TableColumn("Next Action") { opportunity in
                TableValueText(value: opportunity.nextAction)
            }
            .width(440)

            TableColumn("Due") { opportunity in
                TableValueText(value: AppDateFormatters.short(opportunity.nextActionDueDate))
            }
            .width(120)

            TableColumn("Tech Stack Required") { opportunity in
                TableValueText(value: opportunity.techStack)
            }
            .width(340)

            TableColumn("Referral") { opportunity in
                VStack(alignment: .leading, spacing: 2) {
                    TableValueText(
                        value: opportunity.referralProfileName.isBlank
                            ? opportunity.referralChannel
                            : opportunity.referralProfileName
                    )
                    if !opportunity.referralEmail.isBlank {
                        TableValueText(value: opportunity.referralEmail, style: .caption, isSecondary: true)
                    }
                    if !opportunity.referralStatus.isBlank {
                        TableValueText(value: opportunity.referralStatus, style: .caption, isSecondary: true)
                    }
                }
            }
            .width(360)

            TableColumn("Notes") { opportunity in
                TableValueText(value: opportunity.notes)
            }
            .width(440)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(
            TableHeaderFontInstaller(
                layoutSignature: currentTableLayoutSignature,
                outlinedRowIndex: outlinedRowIndex
            )
            .frame(width: 0, height: 0)
        )
    }

    private var closedTable: some View {
        Table(opportunities, selection: selectionBinding) {
            TableColumn("Company") { opportunity in
                TableValueText(value: opportunity.company.isBlank ? "Untitled company" : opportunity.company)
            }
            .width(280)

            TableColumn("Role") { opportunity in
                TableValueText(value: opportunity.role)
            }
            .width(300)

            TableColumn("Status") { opportunity in
                TableValueText(value: opportunity.displayStatus)
            }
            .width(150)

            TableColumn("Last Activity") { opportunity in
                TableValueText(value: AppDateFormatters.short(opportunity.calculatedLastActivityDate))
            }
            .width(180)

            TableColumn("Round") { opportunity in
                TableValueText(value: opportunity.calculatedStage)
            }
            .width(220)

            TableColumn("Interviewer") { opportunity in
                TableValueText(value: opportunity.latestRound?.interviewer ?? "")
            }
            .width(240)

            TableColumn("Outcome") { opportunity in
                TableValueText(value: opportunity.latestRound?.result ?? "")
            }
            .width(170)

            TableColumn("Re-Eligible Date") { opportunity in
                TableValueText(value: AppDateFormatters.short(opportunity.cooldownEligibleDate))
            }
            .width(190)

            TableColumn("Notes") { opportunity in
                TableValueText(value: opportunity.notes)
            }
            .width(440)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(
            TableHeaderFontInstaller(
                layoutSignature: currentTableLayoutSignature,
                outlinedRowIndex: outlinedRowIndex
            )
            .frame(width: 0, height: 0)
        )
    }

    private var eligibleAgainTable: some View {
        Table(opportunities, selection: selectionBinding) {
            TableColumn("Company") { opportunity in
                TableValueText(value: opportunity.company.isBlank ? "Untitled company" : opportunity.company)
            }
            .width(300)

            TableColumn("Re-Eligible Date") { opportunity in
                TableValueText(value: AppDateFormatters.short(opportunity.cooldownEligibleDate))
            }
            .width(190)

            TableColumn("Last Activity") { opportunity in
                TableValueText(value: AppDateFormatters.short(opportunity.calculatedLastActivityDate))
            }
            .width(180)

            TableColumn("PoC") { opportunity in
                TableValueText(value: opportunity.contactOrInterviewer)
            }
            .width(240)

            TableColumn("PoC Email") { opportunity in
                TableValueText(value: opportunity.pocEmail)
            }
            .width(280)

            TableColumn("PoC Number") { opportunity in
                TableValueText(value: opportunity.pocNumber)
            }
            .width(190)

            TableColumn("Referral") { opportunity in
                TableValueText(value: opportunity.referralProfileName)
            }
            .width(240)

            TableColumn("Referral Email") { opportunity in
                TableValueText(value: opportunity.referralEmail)
            }
            .width(280)

            TableColumn("Referral Status") { opportunity in
                TableValueText(value: opportunity.referralStatus)
            }
            .width(190)

            TableColumn("Notes") { opportunity in
                TableValueText(value: opportunity.notes)
            }
            .width(440)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .background(
            TableHeaderFontInstaller(
                layoutSignature: currentTableLayoutSignature,
                outlinedRowIndex: outlinedRowIndex
            )
            .frame(width: 0, height: 0)
        )
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { searchText },
            set: { newValue in
                guard canApplyFilterChange(search: newValue, filter: store.interviewFilter) else {
                    pendingSearchText = newValue
                    pendingInterviewFilter = nil
                    showCloseEditingConfirmation = true
                    return
                }
                searchText = newValue
                reconcileSelection()
            }
        )
    }

    private var interviewFilterBinding: Binding<InterviewFilter> {
        Binding(
            get: { store.interviewFilter },
            set: { newValue in
                guard canApplyFilterChange(search: searchText, filter: newValue) else {
                    pendingInterviewFilter = newValue
                    pendingSearchText = nil
                    showCloseEditingConfirmation = true
                    return
                }
                store.interviewFilter = newValue
                reconcileSelection()
            }
        )
    }

    private func filteredOpportunities(search: String, filter: InterviewFilter) -> [InterviewOpportunity] {
        store.filteredOpportunities(search: search, filter: filter)
    }

    private func canApplyFilterChange(search: String, filter: InterviewFilter) -> Bool {
        guard isEditing, let selectedID = store.selectedOpportunityID else { return true }
        return filteredOpportunities(search: search, filter: filter).contains { $0.id == selectedID }
    }

    private func reconcileSelection() {
        guard let selectedID = store.selectedOpportunityID else { return }
        guard !opportunities.contains(where: { $0.id == selectedID }) else { return }
        if isEditing {
            showCloseEditingConfirmation = true
            return
        }
        store.selectedOpportunityID = opportunities.first?.id
        isEditing = false
    }

    private func requestCloseDetailPane() {
        if isEditing {
            showCloseEditingConfirmation = true
        } else {
            closeDetailPane()
        }
    }

    private func closeDetailPane() {
        store.selectedOpportunityID = nil
        isEditing = false
    }

    private func confirmCloseDetailPane() {
        applyPendingFilterChanges()
        closeDetailPane()
    }

    private func applyPendingFilterChanges() {
        if let pendingSearchText {
            searchText = pendingSearchText
        }
        if let pendingInterviewFilter {
            store.interviewFilter = pendingInterviewFilter
        }
        clearPendingFilterChanges()
    }

    private func clearPendingFilterChanges() {
        pendingSearchText = nil
        pendingInterviewFilter = nil
    }
}

private struct InterviewOpportunityDetailView: View {
    @Binding var opportunity: InterviewOpportunity
    @Binding var isEditing: Bool
    var onClose: () -> Void
    var onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    @State private var selectedTab: InterviewDetailTab = .overview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DetailPaneToolbar(
                    isEditing: isEditing,
                    onClose: onClose,
                    onToggleEditing: {
                        isEditing.toggle()
                    },
                    onDelete: {
                        showDeleteConfirmation = true
                    }
                )

                Picker("Detail", selection: $selectedTab) {
                    ForEach(InterviewDetailTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .tint(.workLogSkyBlue)

                if isEditing {
                    InterviewOpportunityEditForm(opportunity: $opportunity, selectedTab: selectedTab)
                } else {
                    InterviewOpportunityReadOnlyView(opportunity: opportunity, selectedTab: selectedTab)
                }
        }
        .padding(18)
        }
        .font(.workLogDetailPaneBody)
        .confirmationDialog(
            "Delete this opportunity?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected interview tracker entry.")
        }
    }
}

private enum InterviewDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case followUp = "Follow-up"
    case referral = "Referral"
    case rounds = "Rounds"
    case notes = "Notes"

    var id: String { rawValue }
}

private struct InterviewOpportunityReadOnlyView: View {
    var opportunity: InterviewOpportunity
    var selectedTab: InterviewDetailTab

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch selectedTab {
            case .overview:
                overviewContent
            case .followUp:
                followUpContent
            case .referral:
                referralContent
            case .rounds:
                roundsContent
            case .notes:
                notesContent
            }
        }
    }

    private var overviewContent: some View {
        InterviewDetailSection {
            ReadOnlyDetailField(title: "Company", value: opportunity.company)
            ReadOnlyDetailField(title: "Role", value: opportunity.role)
            ReadOnlyDetailField(title: "Status", value: opportunity.displayStatus, hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Applied Date", value: AppDateFormatters.short(opportunity.appliedDate), hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Round", value: opportunity.calculatedStage)
            ReadOnlyDetailField(title: "Last Activity", value: AppDateFormatters.short(opportunity.calculatedLastActivityDate), hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Tech Stack Required", value: opportunity.techStack, isLong: true)
            ReadOnlyDetailField(title: "Application Link", value: opportunity.applicationLink, isLong: true)
            ReadOnlyDetailField(title: "Source", value: opportunity.applicationSource)
            ReadOnlyDetailField(title: "PoC", value: opportunity.contactOrInterviewer)
            ReadOnlyDetailField(title: "PoC Email", value: opportunity.pocEmail)
            ReadOnlyDetailField(title: "PoC Number", value: opportunity.pocNumber)
        }
    }

    private var followUpContent: some View {
        InterviewDetailSection {
            ReadOnlyDetailField(title: "Action", value: opportunity.nextAction)
            ReadOnlyDetailField(title: "Due Date", value: AppDateFormatters.short(opportunity.nextActionDueDate))
            ReadOnlyDetailField(title: "Cooldown Period", value: opportunity.cooldownPeriodLabel)
            ReadOnlyDetailField(title: "Re-Eligible Date", value: AppDateFormatters.short(opportunity.cooldownEligibleDate))
        }
    }

    @ViewBuilder
    private var referralContent: some View {
        if opportunity.hasReferral {
            InterviewDetailSection {
                ReadOnlyDetailField(title: "Referral Channel", value: opportunity.referralChannel)
                ReadOnlyDetailField(title: "Referral Name", value: opportunity.referralProfileName)
                ReadOnlyDetailField(title: "Referral Email", value: opportunity.referralEmail)
                ReadOnlyDetailField(title: "Referral Status", value: opportunity.referralStatus)
                ReadOnlyDetailField(title: "Referral Notes", value: opportunity.referralNotes, isLong: true)
            }
        } else {
            Text("No referral involved.")
                .foregroundStyle(.secondary)
        }
    }

    private var roundsContent: some View {
        InterviewDetailSection {
            Text("Rounds")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.workLogHeaderText)

            if opportunity.interviewRounds.isEmpty {
                Text("No rounds added.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedRounds) { round in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(round.roundName.isBlank ? "Round" : round.roundName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.workLogHeaderText)
                        Text(AppDateFormatters.short(round.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ReadOnlyDetailField(title: "Interviewer", value: round.interviewer)
                        ReadOnlyDetailField(title: "Outcome", value: round.result)
                        ReadOnlyDetailField(title: "Feedback", value: round.feedback, isLong: true)
                    }
                    .padding(10)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    }
                }
            }
        }
    }

    private var notesContent: some View {
        InterviewDetailSection {
            ReadOnlyDetailField(title: "Notes", value: opportunity.notes, isLong: true)
            ReadOnlyDetailField(title: "Job Description", value: opportunity.jobDescription, isLong: true)
        }
    }

    private var sortedRounds: [InterviewRound] {
        opportunity.interviewRounds.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.date == rhs.element.date {
                    return lhs.offset > rhs.offset
                }

                return lhs.element.date > rhs.element.date
            }
            .map(\.element)
    }
}

private struct InterviewOpportunityEditForm: View {
    @Binding var opportunity: InterviewOpportunity
    var selectedTab: InterviewDetailTab

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch selectedTab {
            case .overview:
                overviewFields
            case .followUp:
                followUpFields
            case .referral:
                referralFields
            case .rounds:
                roundsFields
            case .notes:
                notesFields
            }
        }
    }

    private var overviewFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            InterviewEditField(title: "Company") {
                TextField("Company", text: $opportunity.company)
            }

            InterviewEditField(title: "Role") {
                TextField("Role", text: $opportunity.role)
            }

            InterviewEditField(title: "Status") {
                if opportunity.interviewRounds.isEmpty {
                    Picker("", selection: $opportunity.status) {
                        ForEach(InterviewStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 180)
                } else {
                    Text(opportunity.displayStatus.isBlank ? "Not set" : opportunity.displayStatus)
                        .foregroundStyle((opportunity.displayStatus.isBlank ? "Not set" : opportunity.displayStatus).workLogDisplayColor())
                }
            }

            InterviewEditField(title: "Applied Date") {
                DatePicker("", selection: $opportunity.appliedDate, displayedComponents: .date)
                    .labelsHidden()
            }

            InterviewEditField(title: "Round") {
                Text(opportunity.calculatedStage.isBlank ? "Not set" : opportunity.calculatedStage)
                    .foregroundStyle((opportunity.calculatedStage.isBlank ? "Not set" : opportunity.calculatedStage).workLogDisplayColor())
            }

            InterviewEditField(title: "Last Activity") {
                Text(AppDateFormatters.short(opportunity.calculatedLastActivityDate))
            }

            InterviewEditField(title: "Tech Stack Required") {
                TextField("Required tech stack", text: $opportunity.techStack)
            }

            InterviewEditField(title: "Application Link") {
                TextField("Job post or careers page URL", text: $opportunity.applicationLink)
            }

            InterviewEditField(title: "PoC") {
                TextField("Point of contact", text: $opportunity.contactOrInterviewer)
            }

            InterviewEditField(title: "PoC Email") {
                TextField("PoC email", text: $opportunity.pocEmail)
            }

            InterviewEditField(title: "PoC Number") {
                TextField("Phone number or PoC number", text: $opportunity.pocNumber)
            }
        }
    }

    private var followUpFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Follow-up?", isOn: followUpBinding)
                .toggleStyle(.checkbox)

            if hasFollowUp {
                InterviewEditField(title: "Action") {
                    TextField("Follow up, prepare, wait, reapply, etc.", text: $opportunity.nextAction)
                }

                InterviewFollowUpDateField(date: $opportunity.nextActionDueDate)
            }

            InterviewCooldownField(
                value: $opportunity.cooldownPeriodDays,
                isEditable: opportunity.canSetCooldownPeriod
            )
        }
    }

    private var referralFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Referral involved", isOn: referralInvolvedBinding)
                .toggleStyle(.checkbox)

            if opportunity.hasReferral {
                InterviewEditField(title: "Channel") {
                    TextField("LinkedIn, friend, recruiter, alumni, etc.", text: $opportunity.referralChannel)
                }

                InterviewEditField(title: "Referral Name") {
                    TextField("Person or profile name", text: $opportunity.referralProfileName)
                }

                InterviewEditField(title: "Referral Email") {
                    TextField("Referral email", text: $opportunity.referralEmail)
                }

                InterviewEditField(title: "Referral Status") {
                    Picker("", selection: $opportunity.referralStatus) {
                        ForEach(ReferralStatusOption.allCases) { status in
                            Text(status.rawValue).tag(status.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 190)
                }

                LabeledTextEditor(title: "Referral Notes", text: $opportunity.referralNotes, minHeight: 80)
            }
        }
    }

    private var roundsFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rounds")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.workLogHeaderText)

            ForEach(sortedRoundIndices, id: \.self) { index in
                InterviewRoundEditor(round: $opportunity.interviewRounds[index]) {
                    opportunity.interviewRounds.remove(at: index)
                }
            }

            IconOnlyActionButton("Add Round", systemImage: "plus.circle") {
                var round = InterviewRound()
                round.roundName = "Round \(opportunity.interviewRounds.count + 1)"
                round.result = RoundOutcomeOption.pending.rawValue
                opportunity.interviewRounds.append(round)
                if opportunity.status == .invited || opportunity.status == .applied || opportunity.status == .waiting {
                    opportunity.status = .interviewing
                }
            }
        }
    }

    private var notesFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledTextEditor(title: "Notes", text: $opportunity.notes, minHeight: 100)
            LabeledTextEditor(title: "Job Description", text: $opportunity.jobDescription, minHeight: 130)
        }
    }

    private var sortedRoundIndices: [Int] {
        opportunity.interviewRounds.indices.sorted { lhs, rhs in
            let left = opportunity.interviewRounds[lhs]
            let right = opportunity.interviewRounds[rhs]

            if left.date == right.date {
                return lhs > rhs
            }

            return left.date > right.date
        }
    }

    private var referralInvolvedBinding: Binding<Bool> {
        Binding(
            get: { opportunity.hasReferral },
            set: { isEnabled in
                opportunity.hasReferral = isEnabled
                if isEnabled && (opportunity.referralStatus.isBlank || opportunity.referralStatus == ReferralStatusOption.notApplicable.rawValue) {
                    opportunity.referralStatus = ReferralStatusOption.toAsk.rawValue
                }
            }
        )
    }

    private var hasFollowUp: Bool {
        !opportunity.nextAction.isBlank || opportunity.nextActionDueDate != nil
    }

    private var followUpBinding: Binding<Bool> {
        Binding(
            get: { hasFollowUp },
            set: { isEnabled in
                if isEnabled {
                    if opportunity.nextActionDueDate == nil {
                        opportunity.nextActionDueDate = Date()
                    }
                } else {
                    opportunity.nextAction = ""
                    opportunity.nextActionDueDate = nil
                }
            }
        )
    }
}

private struct InterviewDetailSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InterviewEditField<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.workLogHeaderText)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InterviewOptionalDateField: View {
    var title: String
    @Binding var date: Date?

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { date != nil },
            set: { enabled in
                date = enabled ? (date ?? Date()) : nil
            }
        )
    }

    private var selectedDate: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { date = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: isEnabled)
                .toggleStyle(.checkbox)

            if date != nil {
                DatePicker("", selection: selectedDate, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }
}

private struct InterviewFollowUpDateField: View {
    @Binding var date: Date?

    private var selectedDate: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { date = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Due Date")
                .font(.callout)
                .foregroundStyle(.workLogHeaderText)

            DatePicker("", selection: selectedDate, displayedComponents: .date)
                .labelsHidden()
        }
    }
}

private struct InterviewCooldownField: View {
    @Binding var value: Int?
    var isEditable: Bool

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { value != nil },
            set: { enabled in
                guard isEditable else { return }
                value = enabled ? max(value ?? 30, 0) : nil
            }
        )
    }

    private var integerValue: Binding<Int> {
        Binding(
            get: { value ?? 30 },
            set: { newValue in
                guard isEditable else { return }
                value = max(newValue, 0)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Cooldown Period", isOn: isEnabled)
                .toggleStyle(.checkbox)
                .disabled(!isEditable)

            if value != nil {
                Stepper(value: integerValue, in: 0...730) {
                    Text("\(integerValue.wrappedValue) days")
                        .frame(width: 88, alignment: .leading)
                }
                .disabled(!isEditable)
                .opacity(isEditable ? 1 : 0.55)
            } else {
                let message = isEditable ? "Not set" : "Set a cooldown-eligible status first"
                Text(message)
                    .foregroundStyle(isEditable ? message.workLogDisplayColor() : .workLogPlaceholderText)
            }
        }
    }
}

private struct InterviewRoundEditor: View {
    @Binding var round: InterviewRound
    var onDelete: () -> Void
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DatePicker("", selection: $round.date, displayedComponents: .date)
                    .labelsHidden()
                TextField("Round", text: $round.roundName)
                IconOnlyActionButton("Delete", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }

            TextField("Interviewer", text: $round.interviewer)
            Picker("Outcome", selection: $round.result) {
                ForEach(RoundOutcomeOption.allCases) { outcome in
                    Text(outcome.rawValue).tag(outcome.rawValue)
                }

                if shouldShowCustomOutcome {
                    Text(round.result).tag(round.result)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 190, alignment: .leading)
            LabeledTextEditor(title: "Feedback", text: $round.feedback, minHeight: 70)
        }
        .padding(10)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
        .confirmationDialog(
            "Delete this interview round?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected interview round.")
        }
    }

    private var shouldShowCustomOutcome: Bool {
        !round.result.isBlank && !RoundOutcomeOption.allCases.contains { $0.rawValue == round.result }
    }
}
