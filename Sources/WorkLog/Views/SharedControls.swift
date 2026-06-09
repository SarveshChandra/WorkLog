import AppKit
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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
        .frame(width: 280)
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
                    .foregroundStyle(selectedValue.isBlank ? .secondary : .primary)
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
                    Text(title)
                        .font(.headline)
                    Text(selectedValue.isBlank ? emptySelectionText : selectedValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                            }
                            .buttonStyle(.plain)
                        }

                        if filteredOptions.isEmpty && pendingNewOption == nil {
                            Text(noMatchesText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                .font(.callout)
                .foregroundStyle(.workLogHeaderText)

            TextEditor(text: $text)
                .font(.body)
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
                    .font(.callout)
                    .foregroundStyle(.workLogHeaderText)
                Text(value.isBlank ? "Not set" : value)
                    .font(.body)
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum TableRowHighlight {
    case none
    case pending
    case overdue
}

struct TableHeaderFontInstaller: NSViewRepresentable {
    var rowHighlights: [TableRowHighlight]? = nil

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        scheduleHeaderUpdates(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleHeaderUpdates(from: nsView)
    }

    private func scheduleHeaderUpdates(from view: NSView) {
        for delay in [0.0, 0.05, 0.15, 0.35, 0.75, 1.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                applyTableStyling(from: view)
            }
        }
    }

    private func applyTableStyling(from view: NSView) {
        if let tableView = Self.findNearestTable(from: view) {
            Self.update(tableView: tableView, rowHighlights: rowHighlights)
            return
        }

        guard let contentView = view.window?.contentView else { return }
        Self.updateTables(in: contentView, rowHighlights: rowHighlights)
    }

    private static func updateTables(in view: NSView, rowHighlights: [TableRowHighlight]?) {
        if let tableView = view as? NSTableView {
            update(tableView: tableView, rowHighlights: rowHighlights)
        }

        for subview in view.subviews {
            updateTables(in: subview, rowHighlights: rowHighlights)
        }
    }

    private static func update(tableView: NSTableView, rowHighlights: [TableRowHighlight]?) {
        for column in tableView.tableColumns {
            let title = column.headerCell.stringValue.isEmpty ? column.title : column.headerCell.stringValue
            column.headerCell = WorkLogTableHeaderCell(textCell: title)
        }
        applyRowHighlights(rowHighlights, to: tableView)
        tableView.headerView?.needsDisplay = true
        tableView.needsDisplay = true
    }

    private static func applyRowHighlights(_ rowHighlights: [TableRowHighlight]?, to tableView: NSTableView) {
        guard let rowHighlights else { return }

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

        for row in 0..<tableView.numberOfRows {
            guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: true) else { continue }
            let defaultBackgroundColor: NSColor
            if tableView.usesAlternatingRowBackgroundColors, !alternatingRowBackgroundColors.isEmpty {
                defaultBackgroundColor = alternatingRowBackgroundColors[row % alternatingRowBackgroundColors.count]
            } else {
                defaultBackgroundColor = tableView.backgroundColor
            }
            let rowHighlight = row < rowHighlights.count ? rowHighlights[row] : .none
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
            rowView.needsDisplay = true
        }
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
