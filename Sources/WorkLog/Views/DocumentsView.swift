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
    @State private var showCloseEditingConfirmation = false
    @State private var pendingSearchText: String?
    @State private var pendingSelectedCompany: String?
    @State private var pendingSelectedType: String?

    private var documents: [DocumentRecord] {
        filteredDocuments(search: searchText, company: selectedCompany, type: selectedType)
    }

    private var searchedDocuments: [DocumentRecord] {
        store.filteredDocuments(search: searchText)
    }

    private var availableCompanies: [String] {
        store.availableCompanyOptions
    }

    private var allDocumentCompanies: [String] {
        AppStore.availableCompanies(in: AppData(documents: store.data.documents))
    }

    private var availableDocumentCompanies: [String] {
        let matchingDocuments = searchedDocuments.filter { document in
            matchesSelectedType(document, selectedType: selectedType)
        }
        var companies = AppStore.availableCompanies(in: AppData(documents: matchingDocuments))
        if !selectedCompany.isEmpty,
           !companies.contains(where: { $0.localizedCaseInsensitiveCompare(selectedCompany) == .orderedSame }) {
            companies.append(selectedCompany.collapsedWhitespace)
        }
        return companies
    }

    private var allDocumentTypes: [DocumentKind] {
        DocumentKind.allCases.filter { kind in
            store.data.documents.contains { $0.kind == kind }
        }
    }

    private var availableDocumentTypes: [DocumentKind] {
        let matchingDocuments = searchedDocuments.filter { document in
            matchesSelectedCompany(document, selectedCompany: selectedCompany)
        }
        var kinds = DocumentKind.allCases.filter { kind in
            matchingDocuments.contains { $0.kind == kind }
        }
        if let selectedKind = DocumentKind(rawValue: selectedType),
           !kinds.contains(selectedKind) {
            kinds.append(selectedKind)
        }
        return kinds
    }

    private var outlinedRowIndex: Int? {
        guard let selectedID = store.selectedDocumentID else { return nil }
        return documents.firstIndex { $0.id == selectedID }
    }

    private var tableLayoutSignature: Int {
        var hasher = Hasher()
        hasher.combine(documents.count)
        for document in documents {
            hasher.combine(document.id)
            hasher.combine(document.displayFileName)
            hasher.combine(document.kind.rawValue)
            hasher.combine(document.company)
            hasher.combine(document.fileSizeBytes)
            hasher.combine(document.fileModifiedAt)
            hasher.combine(document.fileCreatedAt)
        }
        return hasher.finalize()
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedDocumentID },
            set: { newValue in
                if newValue == nil, isEditing, store.selectedDocumentID != nil {
                    showCloseEditingConfirmation = true
                    return
                }
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
                .opacity(selectedCompany.isEmpty ? 0.72 : 1)
                .workLogFilterHighlight(isActive: !selectedCompany.isEmpty)

                Picker("Type", selection: typeFilterBinding) {
                    Text("All Types").tag("")
                    ForEach(availableDocumentTypes) { kind in
                        Text(kind.displayName).tag(kind.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(selectedType.isEmpty ? .secondary : .workLogSkyBlue)
                .frame(width: 150)
                .opacity(selectedType.isEmpty ? 0.72 : 1)
                .workLogFilterHighlight(isActive: !selectedType.isEmpty)

                IconOnlyActionButton("Import", systemImage: "square.and.arrow.down") {
                    searchText = ""
                    selectedCompany = ""
                    selectedType = ""
                    store.importDocument()
                }
            }

            StableDetailPaneLayout(showsDetail: store.selectedDocumentID != nil) {
                Table(documents, selection: selectionBinding) {
                    TableColumn("Name") { document in
                        TableValueText(value: document.displayFileName)
                    }
                    .width(480)

                    TableColumn("Type") { document in
                        TableValueText(value: document.kind.displayName)
                    }
                    .width(210)

                    TableColumn("Company") { document in
                        TableValueText(value: document.company)
                    }
                    .width(280)

                    TableColumn("Size") { document in
                        TableValueText(
                            value: ByteCountFormatter.string(fromByteCount: document.fileSizeBytes, countStyle: .file)
                        )
                    }
                    .width(140)

                    TableColumn("Modified") { document in
                        TableValueText(value: document.fileModifiedAt.map(AppDateFormatters.short) ?? "")
                    }
                    .width(150)

                    TableColumn("Created") { document in
                        TableValueText(value: document.fileCreatedAt.map(AppDateFormatters.short) ?? "")
                    }
                    .width(150)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .background(
                    TableHeaderFontInstaller(
                        layoutSignature: tableLayoutSignature,
                        outlinedRowIndex: outlinedRowIndex
                    )
                    .frame(width: 0, height: 0)
                )
            } detail: {
                if let id = store.selectedDocumentID,
                   let binding = store.bindingForDocument(id: id) {
                    DocumentDetailView(
                        document: binding,
                        isEditing: $isEditing,
                        availableCompanyOptions: availableCompanies,
                        onClose: {
                            requestCloseDetailPane()
                        },
                        onDelete: {
                            store.deleteSelectedDocument()
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
            normalizeFilters()
            reconcileSelection()
        }
        .confirmationDialog(
            "Close the document details?",
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
            Text("You are editing this document. Close the right pane?")
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { searchText },
            set: { newValue in
                guard canApplyFilterChange(search: newValue, company: selectedCompany, type: selectedType) else {
                    pendingSearchText = newValue
                    pendingSelectedCompany = nil
                    pendingSelectedType = nil
                    showCloseEditingConfirmation = true
                    return
                }
                searchText = newValue
                reconcileSelection()
            }
        )
    }

    private var companyFilterBinding: Binding<String> {
        Binding(
            get: { selectedCompany },
            set: { newValue in
                guard canApplyFilterChange(search: searchText, company: newValue, type: selectedType) else {
                    pendingSelectedCompany = newValue
                    pendingSearchText = nil
                    pendingSelectedType = nil
                    showCloseEditingConfirmation = true
                    return
                }
                selectedCompany = newValue
                reconcileSelection()
            }
        )
    }

    private var typeFilterBinding: Binding<String> {
        Binding(
            get: { selectedType },
            set: { newValue in
                guard canApplyFilterChange(search: searchText, company: selectedCompany, type: newValue) else {
                    pendingSelectedType = newValue
                    pendingSearchText = nil
                    pendingSelectedCompany = nil
                    showCloseEditingConfirmation = true
                    return
                }
                selectedType = newValue
                reconcileSelection()
            }
        )
    }

    private func filteredDocuments(search: String, company: String, type: String) -> [DocumentRecord] {
        store.filteredDocuments(search: search).filter { document in
            matchesSelectedCompany(document, selectedCompany: company)
                && matchesSelectedType(document, selectedType: type)
        }
    }

    private func canApplyFilterChange(search: String, company: String, type: String) -> Bool {
        guard isEditing, let selectedID = store.selectedDocumentID else { return true }
        return filteredDocuments(search: search, company: company, type: type).contains { $0.id == selectedID }
    }

    private func reconcileSelection() {
        guard let selectedID = store.selectedDocumentID else { return }
        guard !documents.contains(where: { $0.id == selectedID }) else { return }
        if isEditing {
            showCloseEditingConfirmation = true
            return
        }
        store.selectedDocumentID = documents.first?.id
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
        store.selectedDocumentID = nil
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
        if let pendingSelectedCompany {
            selectedCompany = pendingSelectedCompany
        }
        if let pendingSelectedType {
            selectedType = pendingSelectedType
        }
        clearPendingFilterChanges()
    }

    private func clearPendingFilterChanges() {
        pendingSearchText = nil
        pendingSelectedCompany = nil
        pendingSelectedType = nil
    }

    private func normalizeFilters() {
        if !selectedCompany.isEmpty,
           !allDocumentCompanies.contains(where: {
               $0.localizedCaseInsensitiveCompare(selectedCompany) == .orderedSame
           }) {
            selectedCompany = ""
        }

        if !selectedType.isEmpty,
           !allDocumentTypes.contains(where: { $0.rawValue == selectedType }) {
            selectedType = ""
        }
    }

    private func matchesSelectedCompany(_ document: DocumentRecord) -> Bool {
        matchesSelectedCompany(document, selectedCompany: selectedCompany)
    }

    private func matchesSelectedType(_ document: DocumentRecord) -> Bool {
        matchesSelectedType(document, selectedType: selectedType)
    }

    private func matchesSelectedCompany(_ document: DocumentRecord, selectedCompany: String) -> Bool {
        guard !selectedCompany.isEmpty else { return true }
        return document.company.collapsedWhitespace.localizedCaseInsensitiveCompare(selectedCompany) == .orderedSame
    }

    private func matchesSelectedType(_ document: DocumentRecord, selectedType: String) -> Bool {
        guard !selectedType.isEmpty else { return true }
        return document.kind.rawValue == selectedType
    }
}

private struct DocumentDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var document: DocumentRecord
    @Binding var isEditing: Bool
    var availableCompanyOptions: [String]
    var onClose: () -> Void
    var onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    @State private var draftDocument = DocumentRecord()
    @State private var draftFileName: String = ""
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

                HStack(spacing: 8) {
                    IconOnlyActionButton("Open", systemImage: "doc") {
                        store.openDocument(document)
                    }

                    IconOnlyActionButton("Reveal", systemImage: "folder") {
                        store.revealDocument(document)
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
                    if !saveErrorMessage.isBlank {
                        Text(saveErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    DocumentEditForm(
                        document: $draftDocument,
                        fileName: $draftFileName,
                        availableCompanyOptions: availableCompanyOptions
                    )
                } else {
                    DocumentReadOnlyView(document: document)
                }
        }
        .padding(18)
        }
        .font(.workLogDetailPaneBody)
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
        draftDocument = document
        draftFileName = document.displayFileName
    }

    private func saveDraft() {
        do {
            try store.saveDocumentEdits(id: document.id, draft: draftDocument, desiredFileName: draftFileName)
            saveErrorMessage = ""
            isEditing = false
            resetDraft()
        } catch {
            saveErrorMessage = error.localizedDescription
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
            ReadOnlyDetailField(title: "Type", value: document.kind.displayName, hideWhenEmpty: false)
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
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
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
