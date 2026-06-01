import AppKit
import CoreServices
import Darwin
import Foundation

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
            storedFileName: destinationURL.lastPathComponent
        )
        record = refreshMetadata(for: record)
        return record
    }

    func fileURL(for document: DocumentRecord) -> URL {
        documentsDirectory.appendingPathComponent(document.storedFileName)
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
        let trimmed = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return document }

        let currentURL = fileURL(for: document)
        guard FileManager.default.fileExists(atPath: currentURL.path) else { return document }

        let desiredName = fileNameKeepingCurrentExtension(
            sanitizeFileName(trimmed),
            currentFileName: currentURL.lastPathComponent
        )
        guard !desiredName.isEmpty else { return document }
        let destinationURL = destinationURLForRename(
            currentURL: currentURL,
            desiredFileName: desiredName
        )

        if destinationURL.lastPathComponent != currentURL.lastPathComponent {
            try moveItemForRename(from: currentURL, to: destinationURL)
        }

        var updated = document
        updated.name = destinationURL.lastPathComponent
        updated.storedFileName = destinationURL.lastPathComponent
        updated = refreshMetadata(for: updated)
        return updated
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
        let normalizedStoredFileNames = Set(storedFileNames.map(normalizedFileNameKey))

        let files = try FileManager.default.contentsOfDirectory(
            at: documentsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return files.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return nil
            }
            guard !normalizedStoredFileNames.contains(normalizedFileNameKey(url.lastPathComponent)) else { return nil }

            let record = DocumentRecord(
                name: url.lastPathComponent,
                kind: inferKind(from: url),
                originalFileName: url.lastPathComponent,
                storedFileName: url.lastPathComponent
            )
            return refreshMetadata(for: record)
        }
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
        if lowercasedName.contains("offer") {
            return .offerLetter
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

    private func fileNameKeepingCurrentExtension(_ desiredFileName: String, currentFileName: String) -> String {
        let desiredURL = URL(fileURLWithPath: desiredFileName)
        guard desiredURL.pathExtension.isEmpty else { return desiredFileName }

        let currentExtension = URL(fileURLWithPath: currentFileName).pathExtension
        guard !currentExtension.isEmpty else { return desiredFileName }
        return "\(desiredFileName).\(currentExtension)"
    }

    private func uniqueDestinationURL(desiredFileName: String) -> URL {
        let desired = documentsDirectory.appendingPathComponent(desiredFileName)
        if !FileManager.default.fileExists(atPath: desired.path) {
            return desired
        }
        let base = desired.deletingPathExtension().lastPathComponent
        let ext = desired.pathExtension
        let suffix = UUID().uuidString.prefix(6)
        let finalName = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
        return documentsDirectory.appendingPathComponent(finalName)
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

    private func moveItemForRename(from sourceURL: URL, to destinationURL: URL) throws {
        if sourceURL.deletingLastPathComponent() == destinationURL.deletingLastPathComponent(),
           sourceURL.lastPathComponent.caseInsensitiveCompare(destinationURL.lastPathComponent) == .orderedSame {
            let temporaryURL = uniqueDestinationURL(
                desiredFileName: ".rename-\(UUID().uuidString)-\(sourceURL.lastPathComponent)"
            )
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
        guard document.storedFileName.hasPrefix("demo-") else { return false }
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
