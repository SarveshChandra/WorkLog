import AppKit
import CoreServices
import Darwin
import Foundation

enum DocumentStorageError: LocalizedError {
    case duplicateNameInDirectory(fileName: String, company: String)

    var errorDescription: String? {
        switch self {
        case let .duplicateNameInDirectory(fileName, company):
            if company.isBlank {
                return "A document named \"\(fileName)\" already exists in the root Documents folder. Change the file name or set Company so it saves in a different directory."
            }
            return "A document named \"\(fileName)\" already exists in the \(company) folder. Change the file name or choose a different company."
        }
    }
}

final class DocumentStorageService {
    let documentsDirectory: URL

    init(baseDirectory: URL) {
        documentsDirectory = baseDirectory.appendingPathComponent("Documents", isDirectory: true)
    }

    func importDocument(from sourceURL: URL) throws -> DocumentRecord {
        try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let desiredFileName = sanitizeFileName(sourceURL.lastPathComponent)
        let destinationURL = uniqueDestinationURL(desiredFileName: desiredFileName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        var record = DocumentRecord(
            name: destinationURL.lastPathComponent,
            kind: inferKind(from: sourceURL),
            originalFileName: sourceURL.lastPathComponent,
            storedFileName: storedPath(for: destinationURL)
        )
        record = refreshMetadata(for: record)
        return record
    }

    func fileURL(for document: DocumentRecord) -> URL {
        resolvedFileURL(forStoredPath: document.storedFileName)
    }

    func refreshMetadata(for document: DocumentRecord, loadVersionMetadata: Bool = true) -> DocumentRecord {
        var updated = document

        let url = fileURL(for: document)
        do {
            let values = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
                .creationDateKey,
                .contentModificationDateKey
            ])

            if let size = values.totalFileAllocatedSize ?? values.fileSize {
                updated.fileSizeBytes = Int64(size)
            }
            updated.fileCreatedAt = values.creationDate
            updated.fileModifiedAt = values.contentModificationDate
        } catch {
            // Ignore metadata read errors; keep existing values.
        }

        if loadVersionMetadata,
           updated.version.isBlank,
           let xattrVersion = fileVersionFromXattr(url: url) {
            updated.version = xattrVersion
        } else if loadVersionMetadata,
                  updated.version.isBlank,
                  let version = metadataVersion(for: url) {
            updated.version = version
        }

        return updated
    }

    func renameDocument(_ document: DocumentRecord, to newFileName: String) throws -> DocumentRecord {
        try updateDocument(document, desiredFileName: newFileName, company: document.company)
    }

    func updateDocument(_ document: DocumentRecord, desiredFileName: String, company: String) throws -> DocumentRecord {
        let normalizedCompany = company.collapsedWhitespace
        let currentURL = fileURL(for: document)
        guard FileManager.default.fileExists(atPath: currentURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let requestedName = desiredFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let desiredName = fileNameKeepingCurrentExtension(
            sanitizeFileName(requestedName.isEmpty ? currentURL.lastPathComponent : requestedName),
            currentFileName: currentURL.lastPathComponent
        )
        guard !desiredName.isEmpty else { return document }

        let destinationDirectory = directoryURL(forCompany: normalizedCompany)
        let destinationURL = try destinationURLForUpdate(
            currentURL: currentURL,
            desiredFileName: desiredName,
            destinationDirectory: destinationDirectory,
            company: normalizedCompany
        )

        if destinationURL.standardizedFileURL.path != currentURL.standardizedFileURL.path {
            try moveItemForRename(from: currentURL, to: destinationURL)
            cleanupEmptyDirectories(startingAt: currentURL.deletingLastPathComponent())
        }

        var updated = document
        updated.company = normalizedCompany
        updated.name = destinationURL.lastPathComponent
        updated.storedFileName = storedPath(for: destinationURL)
        updated = refreshMetadata(for: updated)
        return updated
    }

    func updateDocumentsForCompanyRename(
        _ documents: [DocumentRecord],
        from oldCompany: String,
        to newCompany: String,
        selectedDocumentID: UUID? = nil,
        selectedDesiredFileName: String? = nil
    ) throws -> [DocumentRecord] {
        let normalizedOldCompany = oldCompany.collapsedWhitespace
        let normalizedNewCompany = newCompany.collapsedWhitespace
        guard !normalizedOldCompany.isEmpty else { return documents }

        let sourceDirectory = directoryURL(forCompany: normalizedOldCompany)
        let targetDirectory = directoryURL(forCompany: normalizedNewCompany)

        struct PreparedMove {
            var document: DocumentRecord
            let currentURL: URL
            let destinationURL: URL
        }

        var currentURLsByPath: [String: URL] = [:]
        for document in documents {
            let url = fileURL(for: document)
            let pathKey = normalizedStoredPathKey(storedPath(for: url))
            if let existingURL = currentURLsByPath[pathKey],
               !referencesSameFile(existingURL, url) {
                throw DocumentStorageError.duplicateNameInDirectory(
                    fileName: url.lastPathComponent,
                    company: document.company
                )
            }
            currentURLsByPath[pathKey] = url
        }

        var plannedDestinationPaths = Set<String>()
        var preparedMoves: [PreparedMove] = []

        for document in documents {
            let currentURL = fileURL(for: document)
            guard FileManager.default.fileExists(atPath: currentURL.path) else {
                throw CocoaError(.fileNoSuchFile)
            }

            let requestedFileName = document.id == selectedDocumentID ? selectedDesiredFileName ?? "" : ""
            let desiredName = fileNameKeepingCurrentExtension(
                sanitizeFileName(
                    requestedFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? currentURL.lastPathComponent
                        : requestedFileName
                ),
                currentFileName: currentURL.lastPathComponent
            )
            guard !desiredName.isEmpty else { continue }

            let destinationURL = targetDirectory.appendingPathComponent(desiredName)
            let destinationPathKey = normalizedStoredPathKey(storedPath(for: destinationURL))

            if !plannedDestinationPaths.insert(destinationPathKey).inserted {
                throw DocumentStorageError.duplicateNameInDirectory(fileName: desiredName, company: normalizedNewCompany)
            }

            if let batchCurrentURL = currentURLsByPath[destinationPathKey],
               !referencesSameFile(currentURL, batchCurrentURL) {
                throw DocumentStorageError.duplicateNameInDirectory(fileName: desiredName, company: normalizedNewCompany)
            }

            if FileManager.default.fileExists(atPath: destinationURL.path),
               !referencesSameFile(currentURL, destinationURL) {
                throw DocumentStorageError.duplicateNameInDirectory(fileName: desiredName, company: normalizedNewCompany)
            }

            preparedMoves.append(
                PreparedMove(
                    document: document,
                    currentURL: currentURL,
                    destinationURL: destinationURL
                )
            )
        }

        if normalizedOldCompany != normalizedNewCompany,
           sourceDirectory.path.caseInsensitiveCompare(targetDirectory.path) == .orderedSame,
           FileManager.default.fileExists(atPath: sourceDirectory.path) {
            try moveDirectoryForRename(from: sourceDirectory, to: targetDirectory)
            preparedMoves = preparedMoves.map { move in
                var updatedMove = move
                updatedMove.document.company = normalizedNewCompany
                let currentName = move.currentURL.lastPathComponent
                updatedMove = PreparedMove(
                    document: updatedMove.document,
                    currentURL: targetDirectory.appendingPathComponent(currentName),
                    destinationURL: move.destinationURL
                )
                return updatedMove
            }
        } else {
            try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        }

        var updatedDocuments: [DocumentRecord] = []
        for move in preparedMoves {
            if move.currentURL.standardizedFileURL.path != move.destinationURL.standardizedFileURL.path {
                try moveItemForRename(from: move.currentURL, to: move.destinationURL)
            }

            var updated = move.document
            updated.company = normalizedNewCompany
            updated.name = move.destinationURL.lastPathComponent
            updated.storedFileName = storedPath(for: move.destinationURL)
            updated = refreshMetadata(for: updated)
            updatedDocuments.append(updated)
        }

        cleanupEmptyDirectories(startingAt: sourceDirectory)
        return updatedDocuments
    }

    func persistVersionMetadata(_ version: String, for document: DocumentRecord) {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = fileURL(for: document)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        if trimmed.isEmpty {
            removeXattr(name: "com.worklog.version", url: url)
            return
        }
        setXattr(name: "com.worklog.version", value: trimmed, url: url)
    }

    func recordsForExistingFiles(excluding storedFileNames: Set<String>) throws -> [DocumentRecord] {
        guard FileManager.default.fileExists(atPath: documentsDirectory.path) else { return [] }
        let normalizedStoredFileNames = Set(storedFileNames.map(normalizedStoredPathKey))

        guard let enumerator = FileManager.default.enumerator(
            at: documentsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var recovered: [DocumentRecord] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            let relativeStoredPath = storedPath(for: url)
            guard !normalizedStoredFileNames.contains(normalizedStoredPathKey(relativeStoredPath)) else {
                continue
            }

            let relativeComponents = relativeStoredPath.split(separator: "/").map(String.init)
            let company = relativeComponents.count > 1 ? relativeComponents[0] : ""
            let record = DocumentRecord(
                name: url.lastPathComponent,
                kind: inferKind(from: url),
                company: company,
                originalFileName: url.lastPathComponent,
                storedFileName: relativeStoredPath
            )
            recovered.append(refreshMetadata(for: record))
        }

        return recovered
    }

    func open(_ document: DocumentRecord) {
        NSWorkspace.shared.open(fileURL(for: document))
    }

    func reveal(_ document: DocumentRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL(for: document)])
    }

    func createDemoDocumentsIfNeeded(for documents: [DocumentRecord]) throws {
        try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)

        for document in documents {
            guard let demoContent = DemoDataFactory.demoDocumentText(for: document.storedFileName) else {
                continue
            }

            let destination = fileURL(for: document)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            let fileExists = FileManager.default.fileExists(atPath: destination.path)
            guard !fileExists || demoPDFNeedsRewrite(document: document, url: destination) else {
                continue
            }

            if fileExists {
                try FileManager.default.removeItem(at: destination)
            }
            try writeDemoPDF(to: destination, title: demoContent.title, body: demoContent.body)
            setXattr(name: "com.worklog.demoPDFVersion", value: "2", url: destination)
        }
    }

    private func uniqueStoredName(baseName: String, fileExtension: String) -> String {
        // Backwards-compat helper (kept for compatibility).
        let sanitizedBase = baseName
            .components(separatedBy: CharacterSet(charactersIn: "/:"))
            .joined(separator: "-")
        let suffix = UUID().uuidString.prefix(8)
        if fileExtension.isEmpty {
            return "\(sanitizedBase)-\(suffix)"
        }
        return "\(sanitizedBase)-\(suffix).\(fileExtension)"
    }

    private func inferKind(from url: URL) -> DocumentKind {
        let lowercasedName = url.lastPathComponent.lowercased()
        if lowercasedName.contains("resume") || lowercasedName.contains("cv") {
            return .resume
        }
        if lowercasedName.contains("cover") && lowercasedName.contains("letter")
            || lowercasedName.contains("coverletter") {
            return .coverLetter
        }
        if lowercasedName.contains("offer") {
            return .offerLetter
        }
        if lowercasedName.contains("appointment")
            || lowercasedName.contains("joining letter")
            || lowercasedName.contains("joining_")
            || lowercasedName.contains("joining-")
            || lowercasedName.contains("joining ") {
            return .appointmentLetter
        }
        if lowercasedName.contains("relieving") {
            return .relievingLetter
        }
        if lowercasedName.contains("experience") {
            return .experienceLetter
        }
        if lowercasedName.contains("certificate") {
            return .certificate
        }
        if lowercasedName.contains("salary") || lowercasedName.contains("payslip") {
            return .salary
        }
        return .other
    }

    private func sanitizeFileName(_ value: String) -> String {
        let replaced = value
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return replaced.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedFileNameKey(_ value: String) -> String {
        value.folding(options: [.caseInsensitive], locale: nil)
    }

    private func normalizedStoredPathKey(_ value: String) -> String {
        value
            .split(separator: "/")
            .map { normalizedFileNameKey(String($0)) }
            .joined(separator: "/")
    }

    private func fileNameKeepingCurrentExtension(_ desiredFileName: String, currentFileName: String) -> String {
        let desiredURL = URL(fileURLWithPath: desiredFileName)
        guard desiredURL.pathExtension.isEmpty else { return desiredFileName }

        let currentExtension = URL(fileURLWithPath: currentFileName).pathExtension
        guard !currentExtension.isEmpty else { return desiredFileName }
        return "\(desiredFileName).\(currentExtension)"
    }

    private func uniqueDestinationURL(desiredFileName: String) -> URL {
        uniqueDestinationURL(desiredFileName: desiredFileName, in: documentsDirectory)
    }

    private func uniqueDestinationURL(desiredFileName: String, in directory: URL) -> URL {
        let desired = directory.appendingPathComponent(desiredFileName)
        if !FileManager.default.fileExists(atPath: desired.path) {
            return desired
        }
        let base = desired.deletingPathExtension().lastPathComponent
        let ext = desired.pathExtension
        let suffix = UUID().uuidString.prefix(6)
        let finalName = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
        return directory.appendingPathComponent(finalName)
    }

    private func destinationURLForRename(currentURL: URL, desiredFileName: String) -> URL {
        let desiredURL = documentsDirectory.appendingPathComponent(desiredFileName)

        if desiredURL.lastPathComponent == currentURL.lastPathComponent {
            return currentURL
        }

        if desiredURL.path.caseInsensitiveCompare(currentURL.path) == .orderedSame,
           referencesSameFile(currentURL, desiredURL) {
            return desiredURL
        }

        return uniqueDestinationURL(desiredFileName: desiredFileName)
    }

    private func destinationURLForUpdate(
        currentURL: URL,
        desiredFileName: String,
        destinationDirectory: URL,
        company: String
    ) throws -> URL {
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let desiredURL = destinationDirectory.appendingPathComponent(desiredFileName)

        if desiredURL.path.caseInsensitiveCompare(currentURL.path) == .orderedSame,
           referencesSameFile(currentURL, desiredURL) {
            return desiredURL
        }

        if FileManager.default.fileExists(atPath: desiredURL.path),
           !referencesSameFile(currentURL, desiredURL) {
            throw DocumentStorageError.duplicateNameInDirectory(fileName: desiredFileName, company: company)
        }

        return desiredURL
    }

    private func moveItemForRename(from sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if sourceURL.deletingLastPathComponent() == destinationURL.deletingLastPathComponent(),
           sourceURL.lastPathComponent.caseInsensitiveCompare(destinationURL.lastPathComponent) == .orderedSame {
            let temporaryURL = uniqueDestinationURL(
                desiredFileName: ".rename-\(UUID().uuidString)-\(sourceURL.lastPathComponent)",
                in: sourceURL.deletingLastPathComponent()
            )
            try FileManager.default.moveItem(at: sourceURL, to: temporaryURL)
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            return
        }

        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    private func moveDirectoryForRename(from sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if sourceURL.path.caseInsensitiveCompare(destinationURL.path) == .orderedSame {
            let temporaryURL = sourceURL.deletingLastPathComponent()
                .appendingPathComponent(".rename-\(UUID().uuidString)")
            try FileManager.default.moveItem(at: sourceURL, to: temporaryURL)
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            return
        }

        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    private func referencesSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: rhs.path) else {
            return lhs.path.caseInsensitiveCompare(rhs.path) == .orderedSame
        }

        let keys: Set<URLResourceKey> = [.fileResourceIdentifierKey]
        let leftValues = try? lhs.resourceValues(forKeys: keys)
        let rightValues = try? rhs.resourceValues(forKeys: keys)
        guard let leftIdentifier = leftValues?.fileResourceIdentifier as AnyObject?,
              let rightIdentifier = rightValues?.fileResourceIdentifier as AnyObject? else {
            return false
        }
        return leftIdentifier.isEqual(rightIdentifier)
    }

    private func resolvedFileURL(forStoredPath storedPath: String) -> URL {
        let components = storedPath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return documentsDirectory }
        return components.reduce(documentsDirectory) { partial, component in
            partial.appendingPathComponent(component)
        }
    }

    private func directoryURL(forCompany company: String) -> URL {
        let normalizedCompany = sanitizeFileName(company.collapsedWhitespace)
        guard !normalizedCompany.isEmpty else { return documentsDirectory }
        return documentsDirectory.appendingPathComponent(normalizedCompany, isDirectory: true)
    }

    private func storedPath(for url: URL) -> String {
        let basePath = documentsDirectory.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(basePath + "/") else {
            return url.lastPathComponent
        }
        return String(filePath.dropFirst(basePath.count + 1))
    }

    private func cleanupEmptyDirectories(startingAt directoryURL: URL) {
        var current = directoryURL.standardizedFileURL
        let base = documentsDirectory.standardizedFileURL

        while current.path != base.path {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            guard contents.isEmpty else { return }
            try? FileManager.default.removeItem(at: current)
            current = current.deletingLastPathComponent()
        }
    }

    private func fileVersionFromXattr(url: URL) -> String? {
        getXattr(name: "com.worklog.version", url: url)
    }

    private func getXattr(name: String, url: URL) -> String? {
        let path = url.path
        return path.withCString { pathPtr in
            name.withCString { namePtr in
                let size = getxattr(pathPtr, namePtr, nil, 0, 0, 0)
                if size <= 0 { return nil }
                var buffer = [UInt8](repeating: 0, count: size)
                let read = getxattr(pathPtr, namePtr, &buffer, size, 0, 0)
                if read <= 0 { return nil }
                return String(bytes: buffer, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    private func setXattr(name: String, value: String, url: URL) {
        let path = url.path
        let data = Array(value.utf8)
        _ = path.withCString { pathPtr in
            name.withCString { namePtr in
                data.withUnsafeBytes { bytes in
                    setxattr(pathPtr, namePtr, bytes.baseAddress, data.count, 0, 0)
                }
            }
        }
    }

    private func removeXattr(name: String, url: URL) {
        let path = url.path
        _ = path.withCString { pathPtr in
            name.withCString { namePtr in
                removexattr(pathPtr, namePtr, 0)
            }
        }
    }

    private func demoPDFNeedsRewrite(document: DocumentRecord, url: URL) -> Bool {
        guard URL(fileURLWithPath: document.storedFileName).lastPathComponent.hasPrefix("demo-") else { return false }
        return getXattr(name: "com.worklog.demoPDFVersion", url: url) != "2"
    }

    private func metadataVersion(for url: URL) -> String? {
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return nil }
        let keys: [CFString] = [
            "kMDItemVersion" as CFString,
            "kMDItemVersionIdentifier" as CFString
        ]

        for key in keys {
            if let value = MDItemCopyAttribute(item, key) {
                if let string = value as? String {
                    let trimmed = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                } else if let number = value as? NSNumber {
                    return number.stringValue
                }
            }
        }
        return nil
    }

    private func writeDemoPDF(to url: URL, title: String, body: String) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        context.beginPDFPage(nil)

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.darkGray
        ]

        (title as NSString).draw(in: CGRect(x: 72, y: 680, width: 468, height: 40), withAttributes: titleAttributes)
        (body as NSString).draw(in: CGRect(x: 72, y: 620, width: 468, height: 80), withAttributes: bodyAttributes)
        ("Generated by Work Log demo data." as NSString).draw(
            in: CGRect(x: 72, y: 560, width: 468, height: 30),
            withAttributes: bodyAttributes
        )

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
    }
}
