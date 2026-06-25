import AppKit
import ObjectiveC.runtime
import SwiftUI

extension ShapeStyle where Self == Color {
    static var workLogSkyBlue: Color {
        // English green (used as the app accent color).
        Color(red: 0.195, green: 0.475, blue: 0.335)
    }

    static var workLogIconGreen: Color {
        // Matches the check-circle green in WorkLogIconMark.
        Color(red: 0.05, green: 0.56, blue: 0.48)
    }

    static var workLogIconGreenDark: Color {
        // Slightly darker variant for the topbar title.
        Color(red: 0.04, green: 0.46, blue: 0.39)
    }

    static var workLogHeaderText: Color {
        Color.secondary.opacity(0.72)
    }

    static var workLogDoingYellow: Color {
        Color(red: 0.76, green: 0.60, blue: 0.10)
    }

    static var workLogPendingCream: Color {
        Color(red: 0.99, green: 0.96, blue: 0.88)
    }

    static var workLogPlaceholderText: Color {
        Color.secondary.opacity(0.34)
    }
}

extension Font {
    static var workLogDetailPaneBody: Font {
        .system(size: NSFont.systemFontSize + 1)
    }

    static var workLogDetailPaneLabel: Font {
        .system(size: NSFont.systemFontSize)
    }
}

struct PageHeader<Actions: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.workLogHeaderText)
            }

            Spacer()

            HStack(spacing: 10) {
                actions
            }
        }
        .padding(.bottom, 6)
    }
}

struct SearchField: View {
    var placeholder: String
    @Binding var text: String

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if hasText {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary.opacity(0.82))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            hasText ? Color.workLogSkyBlue.opacity(0.10) : Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    hasText ? Color.workLogSkyBlue.opacity(0.32) : Color.clear,
                    lineWidth: hasText ? 1 : 0
                )
        }
        .frame(width: 280)
    }
}

extension View {
    @ViewBuilder
    func workLogHelp(_ text: String) -> some View {
        if text.isBlank {
            self
        } else {
            self.help(text)
        }
    }

    func workLogHoverOutline(cornerRadius: CGFloat = 8) -> some View {
        modifier(WorkLogHoverOutlineModifier(cornerRadius: cornerRadius))
    }

    func workLogFilterHighlight(isActive: Bool, cornerRadius: CGFloat = 7) -> some View {
        modifier(WorkLogFilterHighlightModifier(isActive: isActive, cornerRadius: cornerRadius))
    }
}

extension String {
    func workLogDisplayColor(isSecondary: Bool = false) -> Color {
        if isWorkLogPlaceholderValue {
            return .workLogPlaceholderText
        }
        return isSecondary ? .secondary : .primary
    }
}

private struct WorkLogHoverOutlineModifier: ViewModifier {
    var cornerRadius: CGFloat
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isHovering ? Color.workLogSkyBlue.opacity(0.72) : Color.clear,
                        lineWidth: isHovering ? 1 : 0
                    )
            }
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

private struct WorkLogFilterHighlightModifier: ViewModifier {
    var isActive: Bool
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                isActive ? Color.workLogSkyBlue.opacity(0.10) : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isActive ? Color.workLogSkyBlue.opacity(0.32) : Color.clear,
                        lineWidth: isActive ? 1 : 0
                    )
            }
    }
}

enum TableValueTextStyle {
    case body
    case caption

    var font: Font {
        switch self {
        case .body:
            return .body
        case .caption:
            return .caption
        }
    }
}

struct TableValueText: View {
    var value: String
    var style: TableValueTextStyle = .body
    var isSecondary: Bool = false

    var body: some View {
        Text(value)
            .font(style.font)
            .foregroundStyle(value.workLogDisplayColor(isSecondary: isSecondary))
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .workLogHelp(value)
    }
}

struct IconOnlyActionButton: View {
    var title: String
    var systemImage: String
    var role: ButtonRole?
    var dimUntilHover: Bool
    var action: () -> Void
    @State private var isHovering = false

    init(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        dimUntilHover: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.dimUntilHover = dimUntilHover
        self.action = action
    }

    private var foregroundColor: Color {
        if dimUntilHover {
            if role == .destructive {
                return isHovering ? .red : .red.opacity(0.5)
            }
            return isHovering ? Color.primary.opacity(0.88) : Color.secondary.opacity(0.5)
        }

        if role == .destructive {
            return .red
        }

        return .secondary
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .frame(width: 16, height: 16)
                .padding(6)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                .workLogHoverOutline(cornerRadius: 7)
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .foregroundStyle(foregroundColor)
        .workLogHelp(title)
        .accessibilityLabel(title)
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct DetailPaneToolbar: View {
    var isEditing: Bool
    var onClose: () -> Void
    var onToggleEditing: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            IconOnlyActionButton("Close", systemImage: "xmark", dimUntilHover: true, action: onClose)
            IconOnlyActionButton(
                isEditing ? "Done" : "Edit",
                systemImage: isEditing ? "checkmark" : "pencil",
                dimUntilHover: true,
                action: onToggleEditing
            )
            IconOnlyActionButton(
                "Delete",
                systemImage: "trash",
                role: .destructive,
                dimUntilHover: true,
                action: onDelete
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StableDetailPaneLayout<Primary: View, Detail: View>: View {
    var showsDetail: Bool
    var detailWidthRatio: CGFloat = 0.5
    @ViewBuilder var primary: Primary
    @ViewBuilder var detail: Detail

    var body: some View {
        GeometryReader { geometry in
            let detailWidth = geometry.size.width * min(max(detailWidthRatio, 0.25), 0.75)

            ZStack(alignment: .trailing) {
                primary
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)

                if showsDetail {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor))
                            .frame(width: 1)

                        detail
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(width: detailWidth, height: geometry.size.height, alignment: .topLeading)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }
}

struct SingleSelectAddablePicker: View {
    var title: String
    var placeholder: String
    var emptySelectionText: String
    var searchPrompt: String
    var noMatchesText: String
    var clearButtonTitle: String
    @Binding var selection: String
    var options: [String]

    @State private var isPresented = false
    @State private var searchText = ""

    private var selectedValue: String {
        selection.collapsedWhitespace
    }

    private var filteredOptions: [String] {
        let query = searchText.collapsedWhitespace
        guard !query.isEmpty else { return options }
        return options.filter { option in
            option.localizedCaseInsensitiveContains(query)
        }
    }

    private var pendingNewOption: String? {
        let candidate = searchText.collapsedWhitespace
        guard !candidate.isEmpty else { return nil }
        guard !options.contains(where: { option in
            option.collapsedWhitespace.localizedCaseInsensitiveCompare(candidate) == .orderedSame
        }) else {
            return nil
        }
        return candidate
    }

    private var summaryText: String {
        selectedValue.isBlank ? placeholder : selectedValue
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text(summaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(selectedValue.isBlank ? .workLogPlaceholderText : .primary)
                Spacer(minLength: 12)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
            .workLogHoverOutline(cornerRadius: 7)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(selectedValue.isBlank ? emptySelectionText : selectedValue)
                        .font(.caption)
                        .foregroundStyle(selectedValue.isBlank ? .workLogPlaceholderText : .secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(searchPrompt, text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            if let newOption = pendingNewOption {
                                select(newOption)
                            } else if filteredOptions.count == 1 {
                                select(filteredOptions[0])
                            }
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))

                if let newOption = pendingNewOption {
                    Button {
                        select(newOption)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.workLogSkyBlue)
                            Text("Add \"\(newOption)\"")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .workLogHoverOutline(cornerRadius: 6)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredOptions, id: \.self) { option in
                            Button {
                                select(option)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isSelected(option) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected(option) ? .workLogSkyBlue : .secondary)
                                    Text(option)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    isSelected(option)
                                        ? Color.workLogSkyBlue.opacity(0.08)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .workLogHoverOutline(cornerRadius: 6)
                            }
                            .buttonStyle(.plain)
                        }

                        if filteredOptions.isEmpty && pendingNewOption == nil {
                            Text(noMatchesText)
                                .font(.callout)
                                .foregroundStyle(.workLogPlaceholderText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .frame(minWidth: 320, idealWidth: 320, maxWidth: 320, minHeight: 160, maxHeight: 220)

                Divider()

                HStack {
                    if !selectedValue.isBlank {
                        Button(clearButtonTitle) {
                            selection = ""
                            isPresented = false
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .workLogHoverOutline(cornerRadius: 6)
                    }

                    Spacer()

                    Button("Done") {
                        isPresented = false
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .workLogHoverOutline(cornerRadius: 6)
                }
            }
            .padding(14)
            .onDisappear {
                searchText = ""
            }
        }
    }

    private func isSelected(_ option: String) -> Bool {
        option.collapsedWhitespace.localizedCaseInsensitiveCompare(selectedValue) == .orderedSame
    }

    private func select(_ option: String) {
        selection = option.collapsedWhitespace
        isPresented = false
    }
}

struct SingleSelectCompanyPicker: View {
    var placeholder: String
    @Binding var company: String
    var options: [String]

    var body: some View {
        SingleSelectAddablePicker(
            title: "Company",
            placeholder: placeholder,
            emptySelectionText: "No company selected",
            searchPrompt: "Search or add a company",
            noMatchesText: "No matching companies",
            clearButtonTitle: "Clear Company",
            selection: $company,
            options: options
        )
    }
}

struct EmptyDetailView: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.workLogHeaderText)
            Text(message)
                .font(.callout)
                .foregroundStyle(.workLogHeaderText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct FieldRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.workLogHeaderText)
                .frame(width: 128, alignment: .trailing)
            content
        }
    }
}

struct OptionalDatePicker: View {
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
        HStack(spacing: 12) {
            Toggle(title, isOn: isEnabled)
                .toggleStyle(.checkbox)
                .frame(width: 128, alignment: .trailing)

            if date != nil {
                DatePicker("", selection: selectedDate, displayedComponents: .date)
                    .labelsHidden()
            } else {
                Text("Not set")
                    .foregroundStyle(.workLogPlaceholderText)
            }

            Spacer()
        }
    }
}

struct OptionalIntStepper: View {
    var title: String
    @Binding var value: Int?
    var suffix: String

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { value != nil },
            set: { enabled in
                value = enabled ? max(value ?? 30, 0) : nil
            }
        )
    }

    private var integerValue: Binding<Int> {
        Binding(
            get: { value ?? 30 },
            set: { value = max($0, 0) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Toggle(title, isOn: isEnabled)
                .toggleStyle(.checkbox)
                .frame(width: 128, alignment: .trailing)

            if value != nil {
                Stepper(value: integerValue, in: 0...730) {
                    Text("\(integerValue.wrappedValue) \(suffix)")
                        .frame(width: 88, alignment: .leading)
                }
            } else {
                Text("Not set")
                    .foregroundStyle(.workLogPlaceholderText)
            }

            Spacer()
        }
    }
}

struct LabeledTextEditor: View {
    var title: String
    @Binding var text: String
    var minHeight: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.workLogDetailPaneLabel)
                .foregroundStyle(.workLogHeaderText)

            TextEditor(text: $text)
                .font(.workLogDetailPaneBody)
                .frame(minHeight: minHeight)
                .padding(4)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary)
                }
        }
    }
}

struct DetailSectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.workLogHeaderText)
            .padding(.top, 6)
    }
}

struct ReadOnlyDetailField: View {
    var title: String
    var value: String
    var isLong: Bool = false
    var hideWhenEmpty: Bool = true

    var body: some View {
        if !hideWhenEmpty || !value.isBlank {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.workLogDetailPaneLabel)
                    .foregroundStyle(.workLogHeaderText)
                Text(value.isBlank ? "Not set" : value)
                    .font(.workLogDetailPaneBody)
                    .foregroundStyle((value.isBlank ? "Not set" : value).workLogDisplayColor(isSecondary: false))
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum TableRowHighlight: Int, Hashable {
    case none
    case pending
    case overdue
}

struct TableHeaderFontInstaller: NSViewRepresentable {
    var rowHighlights: [TableRowHighlight]? = nil
    var layoutSignature: Int? = nil
    var outlinedRowIndex: Int? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        scheduleHeaderUpdates(from: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleHeaderUpdates(from: nsView, coordinator: context.coordinator)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.cancelPendingUpdates()
    }

    private func scheduleHeaderUpdates(from view: NSView, coordinator: Coordinator) {
        coordinator.scheduleUpdate(for: view) { targetView in
            applyTableStyling(from: targetView)
        }
    }

    @discardableResult
    private func applyTableStyling(from view: NSView) -> Bool {
        if let tableView = Self.findNearestTable(from: view) {
            Self.update(
                tableView: tableView,
                rowHighlights: rowHighlights,
                layoutSignature: layoutSignature,
                outlinedRowIndex: outlinedRowIndex
            )
            return true
        }

        guard let contentView = view.window?.contentView else { return false }
        return Self.updateTables(
            in: contentView,
            rowHighlights: rowHighlights,
            layoutSignature: layoutSignature,
            outlinedRowIndex: outlinedRowIndex
        )
    }

    private static func updateTables(
        in view: NSView,
        rowHighlights: [TableRowHighlight]?,
        layoutSignature: Int?,
        outlinedRowIndex: Int?
    ) -> Bool {
        var didUpdateAnyTable = false

        if let tableView = view as? NSTableView {
            update(
                tableView: tableView,
                rowHighlights: rowHighlights,
                layoutSignature: layoutSignature,
                outlinedRowIndex: outlinedRowIndex
            )
            didUpdateAnyTable = true
        }

        for subview in view.subviews {
            if updateTables(
                in: subview,
                rowHighlights: rowHighlights,
                layoutSignature: layoutSignature,
                outlinedRowIndex: outlinedRowIndex
            ) {
                didUpdateAnyTable = true
            }
        }

        return didUpdateAnyTable
    }

    private static func update(
        tableView: NSTableView,
        rowHighlights: [TableRowHighlight]?,
        layoutSignature: Int?,
        outlinedRowIndex: Int?
    ) {
        let state = tableState(for: tableView)
        state.installScrollObserver(for: tableView)
        state.currentRowHighlights = rowHighlights
        state.currentOutlinedRowIndex = outlinedRowIndex

        var requiresFullHeightInvalidation = !state.didApplyInitialLayout
        var headerNeedsDisplay = false
        let layoutSignatureChanged = layoutSignature != state.lastLayoutSignature

        if layoutSignatureChanged {
            requiresFullHeightInvalidation = true
            state.lastStyledVisibleRows = nil
        }

        if !tableView.usesAutomaticRowHeights {
            tableView.usesAutomaticRowHeights = true
            requiresFullHeightInvalidation = true
        }

        if tableView.enclosingScrollView?.hasHorizontalScroller != true {
            tableView.enclosingScrollView?.hasHorizontalScroller = true
        }
        if tableView.enclosingScrollView?.autohidesScrollers != true {
            tableView.enclosingScrollView?.autohidesScrollers = true
        }

        for column in tableView.tableColumns {
            let title = column.headerCell.stringValue.isEmpty ? column.title : column.headerCell.stringValue
            if !(column.headerCell is WorkLogTableHeaderCell) || column.headerCell.stringValue != title {
                column.headerCell = WorkLogTableHeaderCell(textCell: title)
                headerNeedsDisplay = true
            }
        }

        if state.lastRowCount != tableView.numberOfRows {
            requiresFullHeightInvalidation = true
        }

        if requiresFullHeightInvalidation, tableView.numberOfRows > 0 {
            invalidateRowHeights(in: tableView)
        }

        let rowHighlightSignature = signature(for: rowHighlights)
        let rowHighlightsChanged = rowHighlightSignature != state.lastRowHighlightSignature
        let outlinedRowChanged = outlinedRowIndex != state.lastOutlinedRowIndex

        if rowHighlightsChanged || outlinedRowChanged || requiresFullHeightInvalidation {
            state.lastStyledVisibleRows = applyVisibleRowHighlights(
                rowHighlights,
                outlinedRowIndex: outlinedRowIndex,
                to: tableView
            )
        }

        if headerNeedsDisplay {
            tableView.headerView?.needsDisplay = true
        }

        state.didApplyInitialLayout = true
        state.lastLayoutSignature = layoutSignature
        state.lastRowCount = tableView.numberOfRows
        state.lastRowHighlightSignature = rowHighlightSignature
        state.lastOutlinedRowIndex = outlinedRowIndex
    }

    @discardableResult
    private static func applyVisibleRowHighlights(
        _ rowHighlights: [TableRowHighlight]?,
        outlinedRowIndex: Int?,
        to tableView: NSTableView
    ) -> Range<Int>? {
        guard tableView.numberOfRows > 0 else { return nil }

        let alternatingRowBackgroundColors = NSColor.alternatingContentBackgroundColors
        let pendingBackgroundColor = NSColor(
            calibratedRed: 0.99,
            green: 0.96,
            blue: 0.88,
            alpha: 1
        )
        let overdueBackgroundColor = NSColor(
            calibratedRed: 0.99,
            green: 0.88,
            blue: 0.88,
            alpha: 1
        )
        let outlineColor = NSColor(
            calibratedRed: 0.195,
            green: 0.475,
            blue: 0.335,
            alpha: 0.9
        )

        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.location != NSNotFound else { return nil }
        let lowerBound = max(0, visibleRows.location)
        let upperBound = min(tableView.numberOfRows, visibleRows.location + visibleRows.length)
        guard lowerBound < upperBound else { return nil }

        configureRows(
            lowerBound..<upperBound,
            rowHighlights: rowHighlights,
            outlinedRowIndex: outlinedRowIndex,
            alternatingRowBackgroundColors: alternatingRowBackgroundColors,
            pendingBackgroundColor: pendingBackgroundColor,
            overdueBackgroundColor: overdueBackgroundColor,
            outlineColor: outlineColor,
            tableView: tableView
        )

        return lowerBound..<upperBound
    }

    private static func configureRows(
        _ rows: Range<Int>,
        rowHighlights: [TableRowHighlight]?,
        outlinedRowIndex: Int?,
        alternatingRowBackgroundColors: [NSColor],
        pendingBackgroundColor: NSColor,
        overdueBackgroundColor: NSColor,
        outlineColor: NSColor,
        tableView: NSTableView
    ) {
        for row in rows {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: true) else { continue }
            let rowHighlight = rowHighlights.map { highlights in
                row < highlights.count ? highlights[row] : .none
            } ?? .none
            configureRowView(
                rowView,
                row: row,
                rowHighlight: rowHighlight,
                outlinedRowIndex: outlinedRowIndex,
                alternatingRowBackgroundColors: alternatingRowBackgroundColors,
                pendingBackgroundColor: pendingBackgroundColor,
                overdueBackgroundColor: overdueBackgroundColor,
                outlineColor: outlineColor,
                tableView: tableView
            )
        }
    }

    private static func configureRowView(
        _ rowView: NSTableRowView,
        row: Int,
        rowHighlight: TableRowHighlight,
        outlinedRowIndex: Int?,
        alternatingRowBackgroundColors: [NSColor],
        pendingBackgroundColor: NSColor,
        overdueBackgroundColor: NSColor,
        outlineColor: NSColor,
        tableView: NSTableView
    ) {
        let defaultBackgroundColor: NSColor
        if tableView.usesAlternatingRowBackgroundColors, !alternatingRowBackgroundColors.isEmpty {
            defaultBackgroundColor = alternatingRowBackgroundColors[row % alternatingRowBackgroundColors.count]
        } else {
            defaultBackgroundColor = tableView.backgroundColor
        }

        let styleSignature = rowStyleSignature(
            row: row,
            rowHighlight: rowHighlight,
            outlinedRowIndex: outlinedRowIndex,
            tableView: tableView,
            alternatingRowBackgroundColors: alternatingRowBackgroundColors
        )
        let styleState = rowStyleState(for: rowView)
        guard styleState.signature != styleSignature else { return }
        styleState.signature = styleSignature

        let rowBackgroundColor: NSColor
        switch rowHighlight {
        case .none:
            rowBackgroundColor = defaultBackgroundColor
        case .pending:
            rowBackgroundColor = defaultBackgroundColor.blended(
                withFraction: 0.78,
                of: pendingBackgroundColor
            ) ?? pendingBackgroundColor
        case .overdue:
            rowBackgroundColor = defaultBackgroundColor.blended(
                withFraction: 0.72,
                of: overdueBackgroundColor
            ) ?? overdueBackgroundColor
        }

        rowView.backgroundColor = rowBackgroundColor
        if row == outlinedRowIndex {
            if !rowView.wantsLayer {
                rowView.wantsLayer = true
            }
            rowView.layer?.cornerRadius = 4
            rowView.layer?.borderColor = outlineColor.cgColor
            rowView.layer?.borderWidth = 2
        } else if rowView.wantsLayer {
            rowView.layer?.borderWidth = 0
            rowView.layer?.borderColor = nil
            rowView.layer?.cornerRadius = 0
            rowView.wantsLayer = false
        }
        rowView.needsDisplay = true
    }

    private static func invalidateRowHeights(in tableView: NSTableView) {
        guard tableView.numberOfRows > 0 else { return }
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<tableView.numberOfRows))
    }

    private static func signature(for rowHighlights: [TableRowHighlight]?) -> Int? {
        guard let rowHighlights else { return nil }

        var hasher = Hasher()
        hasher.combine(rowHighlights.count)
        for rowHighlight in rowHighlights {
            hasher.combine(rowHighlight.rawValue)
        }
        return hasher.finalize()
    }

    private static func tableState(for tableView: NSTableView) -> TableHeaderState {
        if let state = objc_getAssociatedObject(tableView, &AssociatedKeys.tableHeaderState) as? TableHeaderState {
            return state
        }

        let state = TableHeaderState()
        objc_setAssociatedObject(
            tableView,
            &AssociatedKeys.tableHeaderState,
            state,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return state
    }

    private static func rowStyleState(for rowView: NSTableRowView) -> TableRowStyleState {
        if let state = objc_getAssociatedObject(rowView, &AssociatedKeys.tableRowStyleState) as? TableRowStyleState {
            return state
        }

        let state = TableRowStyleState()
        objc_setAssociatedObject(
            rowView,
            &AssociatedKeys.tableRowStyleState,
            state,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return state
    }

    private static func rowStyleSignature(
        row: Int,
        rowHighlight: TableRowHighlight,
        outlinedRowIndex: Int?,
        tableView: NSTableView,
        alternatingRowBackgroundColors: [NSColor]
    ) -> Int {
        let alternatingIndex: Int
        if tableView.usesAlternatingRowBackgroundColors, !alternatingRowBackgroundColors.isEmpty {
            alternatingIndex = row % alternatingRowBackgroundColors.count
        } else {
            alternatingIndex = 0
        }

        return (alternatingIndex << 8)
            ^ (rowHighlight.rawValue << 2)
            ^ (row == outlinedRowIndex ? 1 : 0)
    }

    private static func findNearestTable(from view: NSView) -> NSTableView? {
        var currentView: NSView? = view

        while let candidate = currentView {
            if let tableView = candidate as? NSTableView {
                return tableView
            }
            if let tableView = firstTable(in: candidate) {
                return tableView
            }
            currentView = candidate.superview
        }

        return nil
    }

    private static func firstTable(in view: NSView) -> NSTableView? {
        if let tableView = view as? NSTableView {
            return tableView
        }

        for subview in view.subviews {
            if let tableView = firstTable(in: subview) {
                return tableView
            }
        }

        return nil
    }

    final class Coordinator {
        private var pendingImmediateUpdate: DispatchWorkItem?
        private var pendingRetryUpdate: DispatchWorkItem?

        func scheduleUpdate(for view: NSView, apply: @escaping (NSView) -> Bool) {
            cancelPendingUpdates()

            let immediateUpdate = DispatchWorkItem { [weak self, weak view] in
                guard let view else { return }
                if apply(view) {
                    return
                }

                let retryUpdate = DispatchWorkItem { [weak view] in
                    guard let view else { return }
                    _ = apply(view)
                }

                self?.pendingRetryUpdate = retryUpdate
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: retryUpdate)
            }

            pendingImmediateUpdate = immediateUpdate
            DispatchQueue.main.async(execute: immediateUpdate)
        }

        func cancelPendingUpdates() {
            pendingImmediateUpdate?.cancel()
            pendingRetryUpdate?.cancel()
            pendingImmediateUpdate = nil
            pendingRetryUpdate = nil
        }
    }

    private final class TableHeaderState: NSObject {
        var didApplyInitialLayout = false
        var lastLayoutSignature: Int?
        var lastRowCount = -1
        var lastRowHighlightSignature: Int?
        var lastOutlinedRowIndex: Int?
        var currentRowHighlights: [TableRowHighlight]?
        var currentOutlinedRowIndex: Int?
        var lastStyledVisibleRows: Range<Int>?
        weak var observedClipView: NSClipView?
        var scrollObserver: NSObjectProtocol?

        deinit {
            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }
        }

        func installScrollObserver(for tableView: NSTableView) {
            guard let clipView = tableView.enclosingScrollView?.contentView else { return }
            guard observedClipView !== clipView else { return }

            if let scrollObserver {
                NotificationCenter.default.removeObserver(scrollObserver)
            }

            observedClipView = clipView
            clipView.postsBoundsChangedNotifications = true
            scrollObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self, weak tableView] _ in
                guard let self, let tableView else { return }
                let visibleRows = TableHeaderFontInstaller.visibleRowRange(for: tableView)
                guard visibleRows != self.lastStyledVisibleRows else { return }

                guard let visibleRows else {
                    self.lastStyledVisibleRows = nil
                    return
                }

                let alternatingRowBackgroundColors = NSColor.alternatingContentBackgroundColors
                let pendingBackgroundColor = NSColor(
                    calibratedRed: 0.99,
                    green: 0.96,
                    blue: 0.88,
                    alpha: 1
                )
                let overdueBackgroundColor = NSColor(
                    calibratedRed: 0.99,
                    green: 0.88,
                    blue: 0.88,
                    alpha: 1
                )
                let outlineColor = NSColor(
                    calibratedRed: 0.195,
                    green: 0.475,
                    blue: 0.335,
                    alpha: 0.9
                )

                if let previousVisibleRows = self.lastStyledVisibleRows {
                    let rowsToConfigure = TableHeaderFontInstaller.enteringRows(
                        from: previousVisibleRows,
                        to: visibleRows
                    )
                    if !rowsToConfigure.isEmpty {
                        for rowRange in rowsToConfigure {
                            TableHeaderFontInstaller.configureRows(
                                rowRange,
                                rowHighlights: self.currentRowHighlights,
                                outlinedRowIndex: self.currentOutlinedRowIndex,
                                alternatingRowBackgroundColors: alternatingRowBackgroundColors,
                                pendingBackgroundColor: pendingBackgroundColor,
                                overdueBackgroundColor: overdueBackgroundColor,
                                outlineColor: outlineColor,
                                tableView: tableView
                            )
                        }
                    }
                } else {
                    TableHeaderFontInstaller.configureRows(
                        visibleRows,
                        rowHighlights: self.currentRowHighlights,
                        outlinedRowIndex: self.currentOutlinedRowIndex,
                        alternatingRowBackgroundColors: alternatingRowBackgroundColors,
                        pendingBackgroundColor: pendingBackgroundColor,
                        overdueBackgroundColor: overdueBackgroundColor,
                        outlineColor: outlineColor,
                        tableView: tableView
                    )
                }

                self.lastStyledVisibleRows = visibleRows
            }
        }
    }

    private static func visibleRowRange(for tableView: NSTableView) -> Range<Int>? {
        guard tableView.numberOfRows > 0 else { return nil }

        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.location != NSNotFound else { return nil }

        let lowerBound = max(0, visibleRows.location)
        let upperBound = min(tableView.numberOfRows, visibleRows.location + visibleRows.length)
        guard lowerBound < upperBound else { return nil }

        return lowerBound..<upperBound
    }

    private static func enteringRows(from previous: Range<Int>, to current: Range<Int>) -> [Range<Int>] {
        var ranges: [Range<Int>] = []

        if current.lowerBound < previous.lowerBound {
            let upperBound = min(current.upperBound, previous.lowerBound)
            if current.lowerBound < upperBound {
                ranges.append(current.lowerBound..<upperBound)
            }
        }

        if current.upperBound > previous.upperBound {
            let lowerBound = max(current.lowerBound, previous.upperBound)
            if lowerBound < current.upperBound {
                ranges.append(lowerBound..<current.upperBound)
            }
        }

        if ranges.isEmpty, !previous.overlaps(current) {
            ranges.append(current)
        }

        return ranges
    }

    private final class TableRowStyleState: NSObject {
        var signature = Int.min
    }

    private enum AssociatedKeys {
        static var tableHeaderState: UInt8 = 0
        static var tableRowStyleState: UInt8 = 0
    }
}

private final class WorkLogTableHeaderCell: NSTableHeaderCell {
    private static let headerFont = NSFont(name: "Helvetica Neue", size: 12)
        ?? .systemFont(ofSize: 12)
    private static let headerColor = NSColor.lightGray

    override init(textCell string: String) {
        super.init(textCell: string)
        font = Self.headerFont
        textColor = Self.headerColor
        alignment = .left
        lineBreakMode = .byTruncatingTail
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        font = Self.headerFont
        textColor = Self.headerColor
        alignment = .left
        lineBreakMode = .byTruncatingTail
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        paragraphStyle.alignment = .left

        let title = attributedStringValue.string.isEmpty ? stringValue : attributedStringValue.string
        let attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: Self.headerFont,
                .foregroundColor: Self.headerColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        let titleSize = attributedTitle.size()
        let titleRect = NSRect(
            x: cellFrame.minX + 8,
            y: cellFrame.midY - (titleSize.height / 2),
            width: max(0, cellFrame.width - 16),
            height: titleSize.height
        )
        attributedTitle.draw(in: titleRect)
    }
}
