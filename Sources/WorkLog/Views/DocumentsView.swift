import Foundation
import PDFKit
import SwiftUI
import Quartz

struct DocumentsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var searchText = ""
    @State private var selectedCompany = ""
    @State private var selectedType = ""
    @State private var isEditing = false

    private var documents: [DocumentRecord] {
        store.filteredDocuments(search: searchText).filter { document in
            matchesSelectedCompany(document) && matchesSelectedType(document)
        }
    }

    private var availableCompanies: [String] {
        store.availableCompanyOptions
    }

    private var availableDocumentCompanies: [String] {
        AppStore.availableCompanies(in: AppData(documents: store.data.documents))
    }

    private var availableDocumentTypes: [DocumentKind] {
        DocumentKind.allCases.filter { kind in
            store.data.documents.contains { $0.kind == kind }
        }
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedDocumentID },
            set: { newValue in
                store.selectedDocumentID = newValue
                isEditing = false
            }
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            PageHeader(
                title: "Documents",
                subtitle: "Store important career files without linking them to interviews."
            ) {
                SearchField(placeholder: "Search documents", text: searchBinding)
                Picker("Company", selection: companyFilterBinding) {
                    Text("All Companies").tag("")
                    ForEach(availableDocumentCompanies, id: \.self) { company in
                        Text(company).tag(company)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(selectedCompany.isEmpty ? .secondary : .workLogSkyBlue)
                .frame(width: 190)
                .opacity(selectedCompany.isEmpty ? 0.62 : 1)

                Picker("Type", selection: typeFilterBinding) {
                    Text("All Types").tag("")
                    ForEach(availableDocumentTypes) { kind in
                        Text(kind.rawValue).tag(kind.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(selectedType.isEmpty ? .secondary : .workLogSkyBlue)
                .frame(width: 150)
                .opacity(selectedType.isEmpty ? 0.62 : 1)

                Button {
                    searchText = ""
                    selectedCompany = ""
                    selectedType = ""
                    store.importDocument()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 0) {
                Table(documents, selection: selectionBinding) {
                    TableColumn("Name") { document in
                        Text(document.displayFileName)
                    }
                    .width(min: 340, ideal: 480)

                    TableColumn("Type") { document in
                        Text(document.kind.rawValue)
                    }
                    .width(min: 170, ideal: 210)

                    TableColumn("Version") { document in
                        Text(document.version)
                    }
                    .width(min: 140, ideal: 180)

                    TableColumn("Size") { document in
                        Text(ByteCountFormatter.string(fromByteCount: document.fileSizeBytes, countStyle: .file))
                    }
                    .width(min: 120, ideal: 140)

                    TableColumn("Modified") { document in
                        Text(document.fileModifiedAt.map(AppDateFormatters.short) ?? "")
                    }
                    .width(min: 130, ideal: 150)

                    TableColumn("Created") { document in
                        Text(document.fileCreatedAt.map(AppDateFormatters.short) ?? "")
                    }
                    .width(min: 130, ideal: 150)

                    TableColumn("Company") { document in
                        Text(document.company)
                    }
                    .width(min: 220, ideal: 280)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .background(TableHeaderFontInstaller().frame(width: 0, height: 0))
                .id(store.selectedDocumentID == nil ? "documents-table-full" : "documents-table-detail")

                if let id = store.selectedDocumentID,
                   let binding = store.bindingForDocument(id: id) {
                    Divider()

                    DocumentDetailView(
                        document: binding,
                        isEditing: $isEditing,
                        availableCompanyOptions: availableCompanies
                    ) {
                        store.deleteSelectedDocument()
                        isEditing = false
                    }
                    .id(id)
                    .frame(minWidth: 340, idealWidth: 400, maxWidth: 500)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .onReceive(store.$data) { _ in
            normalizeFilters()
            reconcileSelection()
        }
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

    private var companyFilterBinding: Binding<String> {
        Binding(
            get: { selectedCompany },
            set: { newValue in
                selectedCompany = newValue
                reconcileSelection()
            }
        )
    }

    private var typeFilterBinding: Binding<String> {
        Binding(
            get: { selectedType },
            set: { newValue in
                selectedType = newValue
                reconcileSelection()
            }
        )
    }

    private func reconcileSelection() {
        guard let selectedID = store.selectedDocumentID else { return }
        guard !documents.contains(where: { $0.id == selectedID }) else { return }
        store.selectedDocumentID = documents.first?.id
        isEditing = false
    }

    private func normalizeFilters() {
        if !selectedCompany.isEmpty,
           !availableDocumentCompanies.contains(where: {
               $0.localizedCaseInsensitiveCompare(selectedCompany) == .orderedSame
           }) {
            selectedCompany = ""
        }

        if !selectedType.isEmpty,
           !availableDocumentTypes.contains(where: { $0.rawValue == selectedType }) {
            selectedType = ""
        }
    }

    private func matchesSelectedCompany(_ document: DocumentRecord) -> Bool {
        guard !selectedCompany.isEmpty else { return true }
        return document.company.collapsedWhitespace.localizedCaseInsensitiveCompare(selectedCompany) == .orderedSame
    }

    private func matchesSelectedType(_ document: DocumentRecord) -> Bool {
        guard !selectedType.isEmpty else { return true }
        return document.kind.rawValue == selectedType
    }
}

private struct DocumentDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var document: DocumentRecord
    @Binding var isEditing: Bool
    var availableCompanyOptions: [String]
    var onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    @State private var draftFileName: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()

                    Button {
                        if isEditing {
                            // Leaving edit mode: apply file rename if needed.
                            let trimmedDraft = draftFileName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let currentName = document.storedFileName.isBlank ? document.name : document.storedFileName
                            if !trimmedDraft.isEmpty, trimmedDraft != currentName {
                                store.renameDocument(id: document.id, to: trimmedDraft)
                            }
                        } else {
                            draftFileName = document.storedFileName.isBlank ? document.name : document.storedFileName
                        }
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

                HStack {
                    Button {
                        store.openDocument(document)
                    } label: {
                        Label("Open", systemImage: "doc")
                    }

                    Button {
                        store.revealDocument(document)
                    } label: {
                        Label("Reveal", systemImage: "folder")
                    }
                }

                DocumentInlinePreview(url: store.fileURL(for: document))
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 0.5)
                    }

                if isEditing {
                    DocumentEditForm(
                        document: $document,
                        fileName: $draftFileName,
                        availableCompanyOptions: availableCompanyOptions
                    )
                } else {
                    DocumentReadOnlyView(document: document)
                }
            }
            .padding(18)
        }
        .confirmationDialog(
            "Delete this document?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected document.")
        }
    }
}

private struct DocumentInlinePreview: NSViewRepresentable {
    var url: URL

    func makeNSView(context: Context) -> NSView {
        let container = DocumentPreviewHostView()
        container.apply(url: url)
        context.coordinator.container = container
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? DocumentPreviewHostView)?.apply(url: url)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var container: DocumentPreviewHostView?
    }
}

private final class DocumentPreviewHostView: NSView {
    private var pdfView: PDFView?
    private var quickLookView: QLPreviewView?
    private var emptyLabel: NSTextField?

    func apply(url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            showPDF(url: url)
        } else {
            showQuickLook(url: url)
        }
    }

    override func layout() {
        super.layout()
        pdfView?.frame = bounds
        quickLookView?.frame = bounds
        emptyLabel?.frame = bounds.insetBy(dx: 12, dy: 12)
        fitPDFToWidthIfNeeded()
    }

    private func showPDF(url: URL) {
        cleanupQuickLook()
        cleanupLabel()

        let view = pdfView ?? PDFView(frame: bounds)
        view.document = PDFDocument(url: url)
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.backgroundColor = .clear
        view.autoScales = false
        view.minScaleFactor = 0.25
        view.maxScaleFactor = 6.0

        if view.superview == nil {
            addSubview(view)
        }
        pdfView = view
        needsLayout = true
    }

    private func showQuickLook(url: URL) {
        cleanupPDF()
        cleanupLabel()

        if let ql = quickLookView ?? QLPreviewView(frame: bounds, style: .compact) {
            ql.autostarts = true
            ql.previewItem = url as NSURL
            if ql.superview == nil {
                addSubview(ql)
            }
            quickLookView = ql
            needsLayout = true
        } else {
            showUnavailable()
        }
    }

    private func showUnavailable() {
        cleanupPDF()
        cleanupQuickLook()

        let label = emptyLabel ?? NSTextField(labelWithString: "Preview unavailable")
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        if label.superview == nil {
            addSubview(label)
        }
        emptyLabel = label
        needsLayout = true
    }

    private func fitPDFToWidthIfNeeded() {
        guard let pdfView,
              let page = pdfView.document?.page(at: 0) else { return }

        let pageRect = page.bounds(for: pdfView.displayBox)
        guard pageRect.width > 0, bounds.width > 0 else { return }

        let target = (bounds.width - 8) / pageRect.width
        let clamped = min(max(target, pdfView.minScaleFactor), pdfView.maxScaleFactor)

        if abs(pdfView.scaleFactor - clamped) > 0.001 {
            pdfView.scaleFactor = clamped
        }
    }

    private func cleanupPDF() {
        pdfView?.removeFromSuperview()
        pdfView = nil
    }

    private func cleanupQuickLook() {
        quickLookView?.removeFromSuperview()
        quickLookView = nil
    }

    private func cleanupLabel() {
        emptyLabel?.removeFromSuperview()
        emptyLabel = nil
    }
}

private struct DocumentReadOnlyView: View {
    var document: DocumentRecord

    private var displayName: String {
        document.displayFileName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ReadOnlyDetailField(title: "Name", value: displayName, hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Type", value: document.kind.rawValue, hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Version", value: document.version)
            ReadOnlyDetailField(title: "Size", value: ByteCountFormatter.string(fromByteCount: document.fileSizeBytes, countStyle: .file), hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Modified", value: document.fileModifiedAt.map(AppDateFormatters.short) ?? "", hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Created", value: document.fileCreatedAt.map(AppDateFormatters.short) ?? "", hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Company", value: document.company)
            ReadOnlyDetailField(title: "Original File", value: document.originalFileName, hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Notes", value: document.notes, isLong: true)
        }
    }
}

private struct DocumentEditForm: View {
    @Binding var document: DocumentRecord
    @Binding var fileName: String
    var availableCompanyOptions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FieldRow(title: "Name") {
                TextField("File name", text: $fileName)
            }

            FieldRow(title: "Type") {
                Picker("", selection: $document.kind) {
                    ForEach(DocumentKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 190)
            }

            FieldRow(title: "Version") {
                TextField("Version", text: $document.version)
            }

            ReadOnlyDetailField(title: "Size", value: ByteCountFormatter.string(fromByteCount: document.fileSizeBytes, countStyle: .file), hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Modified", value: document.fileModifiedAt.map(AppDateFormatters.short) ?? "", hideWhenEmpty: false)
            ReadOnlyDetailField(title: "Created", value: document.fileCreatedAt.map(AppDateFormatters.short) ?? "", hideWhenEmpty: false)

            FieldRow(title: "Company") {
                SingleSelectCompanyPicker(
                    placeholder: "Select or add a company",
                    company: $document.company,
                    options: availableCompanyOptions
                )
                .frame(maxWidth: 260, alignment: .leading)
            }

            FieldRow(title: "Original File") {
                Text(document.originalFileName)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            LabeledTextEditor(title: "Notes", text: $document.notes, minHeight: 140)
        }
    }
}
