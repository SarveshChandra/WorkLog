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

struct TableHeaderFontInstaller: NSViewRepresentable {
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
                applyHeaderFont(from: view)
            }
        }
    }

    private func applyHeaderFont(from view: NSView) {
        guard let contentView = view.window?.contentView else { return }
        Self.updateTables(in: contentView)
    }

    private static func updateTables(in view: NSView) {
        if let tableView = view as? NSTableView {
            for column in tableView.tableColumns {
                let title = column.headerCell.stringValue.isEmpty ? column.title : column.headerCell.stringValue
                column.headerCell = WorkLogTableHeaderCell(textCell: title)
            }
            tableView.headerView?.needsDisplay = true
            tableView.needsDisplay = true
        }

        for subview in view.subviews {
            updateTables(in: subview)
        }
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
