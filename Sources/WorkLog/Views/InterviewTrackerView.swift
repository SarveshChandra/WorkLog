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
            hasher.combine(companyLabel(for: opportunity))
            hasher.combine(roleLabel(for: opportunity))
            hasher.combine(sourceLabel(for: opportunity))
            hasher.combine(opportunity.displayStatus)
            hasher.combine(stageLabel(for: opportunity))
            hasher.combine(nextActionLabel(for: opportunity))
            hasher.combine(dateLabel(opportunity.currentNextActionDueDate))
            hasher.combine(dateLabel(opportunity.cooldownEligibleDate))
            hasher.combine(referralLabel(for: opportunity))
            hasher.combine(opportunity.latestRound?.interviewer)
            hasher.combine(opportunity.latestRound?.result)
            hasher.combine(opportunity.contactOrInterviewer)
        }

        return hasher.finalize()
    }

    private var tableIdentity: String {
        "\(store.interviewFilter.rawValue)|\(searchText)|\(currentTableLayoutSignature)"
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
                subtitle: "Enter company, role, application link, status, next action, and PoC details. Source, round, referral summary, and re-eligible date are calculated."
            ) {
                SearchField(placeholder: "Search opportunities", text: searchBinding)
                IconOnlyActionButton("Add", systemImage: "plus") {
                    searchText = ""
                    store.interviewFilter = .all
                    store.addInterviewOpportunity()
                    isEditing = true
                }
            }

            if !store.calendarInterviewImportMessage.isBlank {
                Text(store.calendarInterviewImportMessage)
                    .font(.caption)
                    .foregroundStyle(store.calendarInterviewImportMessage.workLogDisplayColor(isSecondary: true))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Picker("View", selection: interviewFilterBinding) {
                ForEach(InterviewFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .tint(.workLogSkyBlue)
            .opacity(store.interviewFilter == .all ? 0.72 : 1)
            .workLogFilterHighlight(isActive: store.interviewFilter != .all, cornerRadius: 10)

            StableDetailPaneLayout(showsDetail: store.selectedOpportunityID != nil) {
                tableView
                    .id(tableIdentity)
            } detail: {
                if let id = store.selectedOpportunityID,
                   let opportunity = store.opportunity(id: id) {
                    InterviewOpportunityDetailView(
                        opportunity: opportunity,
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
            allTable
        }
    }

    private var allTable: some View {
        Table(opportunities, selection: selectionBinding) {
            TableColumn("Company") { opportunity in
                TableValueText(value: companyLabel(for: opportunity))
            }
            .width(220)

            TableColumn("Role") { opportunity in
                TableValueText(value: roleLabel(for: opportunity))
            }
            .width(220)

            TableColumn("Status") { opportunity in
                TableValueText(value: opportunity.displayStatus)
            }
            .width(150)

            TableColumn("Round") { opportunity in
                TableValueText(value: stageLabel(for: opportunity))
            }
            .width(180)

            TableColumn("Next Action") { opportunity in
                TableValueText(value: nextActionLabel(for: opportunity))
            }
            .width(300)

            TableColumn("Due") { opportunity in
                TableValueText(value: dateLabel(opportunity.currentNextActionDueDate))
            }
            .width(120)

            TableColumn("Source") { opportunity in
                TableValueText(value: sourceLabel(for: opportunity))
            }
            .width(150)

            TableColumn("Re-Eligible Date") { opportunity in
                TableValueText(value: dateLabel(opportunity.cooldownEligibleDate))
            }
            .width(160)

            TableColumn("Referral") { opportunity in
                TableValueText(value: referralLabel(for: opportunity))
            }
            .width(220)
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
                opportunityTitleCell(for: opportunity)
            }
            .width(360)

            TableColumn("Status") { opportunity in
                TableValueText(value: opportunity.displayStatus)
            }
            .width(150)

            TableColumn("Round") { opportunity in
                TableValueText(value: stageLabel(for: opportunity))
            }
            .width(180)

            TableColumn("Next Action") { opportunity in
                TableValueText(value: nextActionLabel(for: opportunity))
            }
            .width(320)

            TableColumn("Due") { opportunity in
                TableValueText(value: dateLabel(opportunity.currentNextActionDueDate))
            }
            .width(120)

            TableColumn("Source") { opportunity in
                TableValueText(value: sourceLabel(for: opportunity))
            }
            .width(150)

            TableColumn("Referral") { opportunity in
                TableValueText(value: referralLabel(for: opportunity))
            }
            .width(220)
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
                TableValueText(value: companyLabel(for: opportunity))
            }
            .width(240)

            TableColumn("Role") { opportunity in
                TableValueText(value: roleLabel(for: opportunity))
            }
            .width(240)

            TableColumn("Round") { opportunity in
                TableValueText(value: stageLabel(for: opportunity))
            }
            .width(180)

            TableColumn("Interviewer") { opportunity in
                TableValueText(value: opportunity.latestRound?.interviewer ?? "Not set")
            }
            .width(220)

            TableColumn("Status") { opportunity in
                TableValueText(value: opportunity.displayStatus)
            }
            .width(170)

            TableColumn("Re-Eligible Date") { opportunity in
                TableValueText(value: dateLabel(opportunity.cooldownEligibleDate))
            }
            .width(160)

            TableColumn("Referral") { opportunity in
                TableValueText(value: referralLabel(for: opportunity))
            }
            .width(220)
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
                TableValueText(value: companyLabel(for: opportunity))
            }
            .width(240)

            TableColumn("Role") { opportunity in
                TableValueText(value: roleLabel(for: opportunity))
            }
            .width(220)

            TableColumn("Re-Eligible Date") { opportunity in
                TableValueText(value: dateLabel(opportunity.cooldownEligibleDate))
            }
            .width(160)

            TableColumn("PoC") { opportunity in
                TableValueText(value: opportunity.contactOrInterviewer.isBlank ? "Not set" : opportunity.contactOrInterviewer)
            }
            .width(220)

            TableColumn("Status") { opportunity in
                TableValueText(value: opportunity.displayStatus)
            }
            .width(150)

            TableColumn("Round") { opportunity in
                TableValueText(value: stageLabel(for: opportunity))
            }
            .width(180)

            TableColumn("Referral") { opportunity in
                TableValueText(value: referralLabel(for: opportunity))
            }
            .width(220)
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

    private func opportunityTitleCell(for opportunity: InterviewOpportunity) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TableValueText(value: companyLabel(for: opportunity))
            TableValueText(
                value: roleLabel(for: opportunity),
                style: .caption,
                isSecondary: true
            )
        }
    }

    private func companyLabel(for opportunity: InterviewOpportunity) -> String {
        opportunity.company.isBlank ? "Untitled company" : opportunity.company
    }

    private func roleLabel(for opportunity: InterviewOpportunity) -> String {
        opportunity.role.isBlank ? "Role not set" : opportunity.role
    }

    private func sourceLabel(for opportunity: InterviewOpportunity) -> String {
        let source = opportunity.applicationSource
        return source.isBlank ? "Not set" : source
    }

    private func stageLabel(for opportunity: InterviewOpportunity) -> String {
        opportunity.calculatedStage.isBlank ? "Not set" : opportunity.calculatedStage
    }

    private func nextActionLabel(for opportunity: InterviewOpportunity) -> String {
        opportunity.currentNextAction.isBlank ? "Not set" : opportunity.currentNextAction
    }

    private func dateLabel(_ date: Date?) -> String {
        let formatted = AppDateFormatters.short(date)
        return formatted.isBlank ? "Not set" : formatted
    }

    private func referralLabel(for opportunity: InterviewOpportunity) -> String {
        if opportunity.hasReferral {
            return opportunity.referralSummary.isBlank ? "Yes" : opportunity.referralSummary
        }
        return "No referral"
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
    @EnvironmentObject private var store: AppStore
    var opportunity: InterviewOpportunity
    @Binding var isEditing: Bool
    var onClose: () -> Void
    var onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    @State private var selectedTab: InterviewDetailTab = .overview
    @State private var draftOpportunity = InterviewOpportunity()
    @State private var saveErrorMessage: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DetailPaneToolbar(
                    isEditing: isEditing,
                    onClose: onClose,
                    onToggleEditing: {
                        toggleEditing()
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
                    if !saveErrorMessage.isBlank {
                        Text(saveErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    InterviewOpportunityEditForm(opportunity: $draftOpportunity, selectedTab: selectedTab)
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
        .onAppear {
            resetDraft()
        }
    }

    private func toggleEditing() {
        if isEditing {
            saveDraft()
        } else {
            resetDraft()
            saveErrorMessage = ""
            isEditing = true
        }
    }

    private func resetDraft() {
        draftOpportunity = opportunity
        draftOpportunity.normalizeDerivedFields()
    }

    private func saveDraft() {
        do {
            try store.saveInterviewEdits(id: opportunity.id, draft: draftOpportunity)
            saveErrorMessage = ""
            isEditing = false
            resetDraft()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}

private enum InterviewDetailTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case rounds = "Rounds"
    case referral = "Referral"
    case followUp = "Follow-up"

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
            case .rounds:
                roundsContent
            case .referral:
                referralContent
            case .followUp:
                followUpContent
            }
        }
    }

    private var overviewContent: some View {
        InterviewDetailSection {
            ReadOnlyDetailField(title: "Company", value: opportunity.company)
            ReadOnlyDetailField(title: "Role", value: opportunity.role)
            ReadOnlyDetailField(title: "Status", value: opportunity.displayStatus, hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Start Date", value: AppDateFormatters.short(opportunity.appliedDate), hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Round", value: opportunity.calculatedStage)
            ReadOnlyDetailField(title: "Tech Stack Required", value: opportunity.techStack, isLong: true)
            ReadOnlyDetailField(title: "Application Link", value: opportunity.applicationLink, isLong: true)
            ReadOnlyDetailField(title: "Source", value: opportunity.applicationSource)
            ReadOnlyDetailField(title: "PoC", value: opportunity.contactOrInterviewer)
            ReadOnlyDetailField(title: "PoC Email", value: opportunity.pocEmail)
            ReadOnlyDetailField(title: "PoC Number", value: opportunity.pocNumber)
            ReadOnlyDetailField(title: "Notes", value: opportunity.notes, isLong: true)
            ReadOnlyDetailField(title: "Job Description", value: opportunity.jobDescription, isLong: true)
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
                ForEach(opportunity.interviewRounds) { round in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(round.roundName.isBlank ? "Round" : round.roundName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.workLogHeaderText)
                        Text(interviewRoundDateText(round))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ReadOnlyDetailField(title: "Interviewer", value: round.interviewer)
                        ReadOnlyDetailField(title: "Status", value: round.normalizedStatusValue())
                        ReadOnlyDetailField(title: "Feedback", value: round.feedback, isLong: true)
                        if round.isImportedFromCalendar {
                            ReadOnlyDetailField(title: "Calendar", value: round.calendarTitle ?? "")
                            ReadOnlyDetailField(title: "Location", value: round.calendarLocation ?? "")
                            ReadOnlyDetailField(title: "Meeting Link", value: round.calendarMeetingURL ?? "", isLong: true)
                            ReadOnlyDetailField(
                                title: "Attendees",
                                value: round.calendarAttendees?.joined(separator: ", ") ?? "",
                                isLong: true
                            )
                            ReadOnlyDetailField(title: "Calendar Notes", value: round.calendarEventNotes ?? "", isLong: true)
                        }
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
}

private struct InterviewOpportunityEditForm: View {
    @Binding var opportunity: InterviewOpportunity
    var selectedTab: InterviewDetailTab

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch selectedTab {
            case .overview:
                overviewFields
            case .rounds:
                roundsFields
            case .referral:
                referralFields
            case .followUp:
                followUpFields
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

            InterviewEditField(title: "Start Date") {
                DatePicker("", selection: $opportunity.appliedDate, displayedComponents: .date)
                    .labelsHidden()
            }

            InterviewEditField(title: "Round") {
                Text(opportunity.calculatedStage.isBlank ? "Not set" : opportunity.calculatedStage)
                    .foregroundStyle((opportunity.calculatedStage.isBlank ? "Not set" : opportunity.calculatedStage).workLogDisplayColor())
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

            LabeledTextEditor(title: "Notes", text: $opportunity.notes, minHeight: 100)
            LabeledTextEditor(title: "Job Description", text: $opportunity.jobDescription, minHeight: 130)
        }
    }

    private var followUpFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Follow-up?", isOn: followUpBinding)
                .toggleStyle(.checkbox)

            if shouldShowFollowUpFields {
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

            ForEach(roundIndices, id: \.self) { index in
                InterviewRoundEditor(round: $opportunity.interviewRounds[index]) {
                    opportunity.interviewRounds.remove(at: index)
                }
            }

            IconOnlyActionButton("Add Round", systemImage: "plus.circle") {
                var round = InterviewRound()
                round.roundName = "Round \(opportunity.interviewRounds.count + 1)"
                round.result = RoundOutcomeOption.upcoming.rawValue
                opportunity.interviewRounds.append(round)
                if opportunity.status == .invited || opportunity.status == .applied || opportunity.status == .waiting {
                    opportunity.status = .interviewing
                }
            }
        }
    }

    private var roundIndices: [Int] {
        Array(opportunity.interviewRounds.indices)
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
        opportunity.hasCurrentFollowUp()
    }

    private var shouldShowFollowUpFields: Bool {
        opportunity.hasFollowUpRecord
    }

    private var followUpBinding: Binding<Bool> {
        Binding(
            get: { hasFollowUp },
            set: { isEnabled in
                if isEnabled {
                    if opportunity.nextActionDueDate == nil || !opportunity.hasCurrentFollowUp() {
                        opportunity.nextActionDueDate = InterviewOpportunity.defaultManualFollowUpDueDate()
                    }
                    opportunity.nextActionLinkedRoundID = nil
                    opportunity.nextActionWasAutoGenerated = false
                } else {
                    opportunity.nextAction = ""
                    opportunity.nextActionDueDate = nil
                    opportunity.nextActionLinkedRoundID = nil
                    opportunity.nextActionWasAutoGenerated = false
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

    private var dateBinding: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { newDate in
                date = Self.mergingDate(newDate, withTimeFrom: date ?? Date())
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { date ?? Date() },
            set: { newTime in
                date = Self.mergingTime(from: newTime, into: date ?? Date())
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Due Date & Time")
                .font(.callout)
                .foregroundStyle(.workLogHeaderText)

            DatePicker("", selection: dateBinding, displayedComponents: .date)
                .labelsHidden()

            DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    private static func mergingDate(_ newDate: Date, withTimeFrom existingDate: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: newDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: existingDate)
        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged) ?? newDate
    }

    private static func mergingTime(from newTime: Date, into existingDate: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: existingDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: newTime)
        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged) ?? existingDate
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
                TextField("Round", text: $round.roundName)
                IconOnlyActionButton("Delete", systemImage: "trash", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }

            InterviewEditField(title: "Schedule") {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("", selection: dateBinding, displayedComponents: .date)
                        .labelsHidden()

                    Toggle("Add time", isOn: timeEnabledBinding)
                        .toggleStyle(.checkbox)

                    if round.usesTime {
                        DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }

            TextField("Interviewer", text: $round.interviewer)
            Picker("Status", selection: statusSelection) {
                ForEach(RoundOutcomeOption.allCases) { outcome in
                    Text(outcome.rawValue).tag(outcome.rawValue)
                }

                if shouldShowCustomStatus {
                    Text(normalizedStatusValue).tag(normalizedStatusValue)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 220, alignment: .leading)
            LabeledTextEditor(title: "Feedback", text: $round.feedback, minHeight: 70)

            if round.isImportedFromCalendar {
                Divider()
                Text("Apple Calendar Details")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ReadOnlyDetailField(title: "Calendar", value: round.calendarTitle ?? "")
                ReadOnlyDetailField(title: "Schedule", value: interviewRoundDateText(round), hideWhenEmpty: false)
                ReadOnlyDetailField(title: "Location", value: round.calendarLocation ?? "")
                ReadOnlyDetailField(title: "Meeting Link", value: round.calendarMeetingURL ?? "", isLong: true)
                ReadOnlyDetailField(
                    title: "Attendees",
                    value: round.calendarAttendees?.joined(separator: ", ") ?? "",
                    isLong: true
                )
                ReadOnlyDetailField(title: "Calendar Notes", value: round.calendarEventNotes ?? "", isLong: true)
            }
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

    private var normalizedStatusValue: String {
        round.normalizedStatusValue()
    }

    private var shouldShowCustomStatus: Bool {
        !normalizedStatusValue.isBlank && !RoundOutcomeOption.allCases.contains { $0.rawValue == normalizedStatusValue }
    }

    private var statusSelection: Binding<String> {
        Binding(
            get: { normalizedStatusValue },
            set: { round.result = $0 }
        )
    }

    private var timeEnabledBinding: Binding<Bool> {
        Binding(
            get: { round.usesTime },
            set: { isEnabled in
                let wasEnabled = round.usesTime
                round.includesTime = isEnabled

                guard wasEnabled != isEnabled else { return }
                if isEnabled {
                    round.date = Self.mergingTime(from: Date(), into: round.date)
                } else {
                    round.date = Calendar.current.startOfDay(for: round.date)
                }
            }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { round.date },
            set: { newDate in
                round.date = Self.mergingDate(newDate, withTimeFrom: round.date, usesTime: round.usesTime)
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { round.date },
            set: { newTime in
                round.date = Self.mergingTime(from: newTime, into: round.date)
            }
        )
    }

    private static func mergingDate(_ newDate: Date, withTimeFrom existingDate: Date, usesTime: Bool) -> Date {
        let calendar = Calendar.current
        guard usesTime else {
            return calendar.startOfDay(for: newDate)
        }

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: newDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: existingDate)
        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged) ?? newDate
    }

    private static func mergingTime(from newTime: Date, into existingDate: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: existingDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: newTime)
        var merged = DateComponents()
        merged.year = dateComponents.year
        merged.month = dateComponents.month
        merged.day = dateComponents.day
        merged.hour = timeComponents.hour
        merged.minute = timeComponents.minute
        return calendar.date(from: merged) ?? existingDate
    }
}

private func interviewRoundDateText(_ round: InterviewRound) -> String {
    guard round.usesTime else {
        return AppDateFormatters.short(round.date)
    }

    let start = AppDateFormatters.calendarDateTime.string(from: round.date)
    guard round.isImportedFromCalendar,
          let end = round.calendarEndDate else {
        return start
    }
    return "\(start) to \(AppDateFormatters.calendarDateTime.string(from: end))"
}
