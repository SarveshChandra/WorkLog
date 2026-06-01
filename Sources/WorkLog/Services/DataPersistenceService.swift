import Foundation

final class DataPersistenceService {
    let appSupportDirectory: URL
    let dataFileURL: URL
    private let cloudDocumentsDirectory: URL?
    private let legacyBaseDirectory: URL
    private let preferredBaseDirectory: URL

    convenience init(fileManager: FileManager = .default) {
        let legacyBase = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Work Log", isDirectory: true)
        let cloudDocs = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        let preferredBase = fileManager.fileExists(atPath: cloudDocs.path)
            ? cloudDocs.appendingPathComponent("Work Log", isDirectory: true)
            : legacyBase
        self.init(
            legacyBaseDirectory: legacyBase,
            preferredBaseDirectory: preferredBase,
            cloudDocumentsDirectory: cloudDocs,
            fileManager: fileManager
        )
    }

    init(
        legacyBaseDirectory: URL,
        preferredBaseDirectory: URL,
        cloudDocumentsDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.legacyBaseDirectory = legacyBaseDirectory
        self.preferredBaseDirectory = preferredBaseDirectory
        self.cloudDocumentsDirectory = cloudDocumentsDirectory
        appSupportDirectory = preferredBaseDirectory
        dataFileURL = preferredBaseDirectory.appendingPathComponent("work-log-data.json")

        // One-time migration: move legacy local data into iCloud Drive/Work Log if available.
        if preferredBaseDirectory != legacyBaseDirectory {
            migrateLegacyDataIfNeeded(fileManager: fileManager)
        }
    }

    func load() throws -> AppData {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)

        guard fileManager.fileExists(atPath: dataFileURL.path) else {
            return AppData()
        }

        let data = try Data(contentsOf: dataFileURL)
        return try JSONCoders.decoder.decode(AppData.self, from: data)
    }

    func save(_ appData: AppData) throws {
        try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        let encoded = try JSONCoders.encoder.encode(appData)
        try encoded.write(to: dataFileURL, options: [.atomic])
    }

    private func migrateLegacyDataIfNeeded(fileManager: FileManager) {
        let legacyDataURL = legacyBaseDirectory.appendingPathComponent("work-log-data.json")
        let preferredDataURL = preferredBaseDirectory.appendingPathComponent("work-log-data.json")
        let legacyDocs = legacyBaseDirectory.appendingPathComponent("Documents", isDirectory: true)
        let preferredDocs = preferredBaseDirectory.appendingPathComponent("Documents", isDirectory: true)
        let legacyBackups = legacyBaseDirectory.appendingPathComponent("Backups", isDirectory: true)

        guard fileManager.fileExists(atPath: legacyBaseDirectory.path) else { return }

        do {
            try fileManager.createDirectory(at: preferredBaseDirectory, withIntermediateDirectories: true)

            if fileManager.fileExists(atPath: legacyDataURL.path),
               !fileManager.fileExists(atPath: preferredDataURL.path) {
                // Move main data file only when iCloud does not already have one.
                try safeMoveItem(fileManager: fileManager, from: legacyDataURL, to: preferredDataURL)
            }

            if fileManager.fileExists(atPath: legacyDocs.path),
               !fileManager.fileExists(atPath: preferredDocs.path) {
                try safeMoveItem(fileManager: fileManager, from: legacyDocs, to: preferredDocs)
            }

            if fileManager.fileExists(atPath: legacyDocs.path) {
                try mergeDirectoryContents(
                    fileManager: fileManager,
                    from: legacyDocs,
                    to: preferredDocs,
                    removeSourceFiles: true,
                    uniquifyConflicts: true
                )
                try removeDirectoryIfEmpty(fileManager: fileManager, at: legacyDocs)
            }

            if let preferredBackups = iCloudDriveBackupRoot(fileManager: fileManager),
               fileManager.fileExists(atPath: legacyBackups.path) {
                try mergeDirectoryContents(
                    fileManager: fileManager,
                    from: legacyBackups,
                    to: preferredBackups,
                    removeSourceFiles: false,
                    uniquifyConflicts: false
                )
            }

        } catch {
            // Migration is best-effort; keep legacy data if anything fails.
        }
    }

    private func safeMoveItem(fileManager: FileManager, from: URL, to: URL) throws {
        do {
            if fileManager.fileExists(atPath: to.path) {
                try fileManager.removeItem(at: to)
            }
            try fileManager.moveItem(at: from, to: to)
        } catch {
            // Fallback to copy+delete (handles cross-volume moves).
            if fileManager.fileExists(atPath: to.path) {
                try fileManager.removeItem(at: to)
            }
            try fileManager.copyItem(at: from, to: to)
            try fileManager.removeItem(at: from)
        }
    }

    private func iCloudDriveBackupRoot(fileManager: FileManager) -> URL? {
        let cloudDocs = cloudDocumentsDirectory ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        guard fileManager.fileExists(atPath: cloudDocs.path) else {
            return nil
        }
        return cloudDocs
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Work Log", isDirectory: true)
    }

    private func mergeDirectoryContents(
        fileManager: FileManager,
        from sourceDirectory: URL,
        to destinationDirectory: URL,
        removeSourceFiles: Bool,
        uniquifyConflicts: Bool
    ) throws {
        guard fileManager.fileExists(atPath: sourceDirectory.path) else { return }

        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let contents = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for sourceItem in contents {
            let destinationItem = destinationDirectory.appendingPathComponent(sourceItem.lastPathComponent)
            let resourceValues = try sourceItem.resourceValues(forKeys: [.isDirectoryKey])

            if resourceValues.isDirectory == true {
                try mergeDirectoryContents(
                    fileManager: fileManager,
                    from: sourceItem,
                    to: destinationItem,
                    removeSourceFiles: removeSourceFiles,
                    uniquifyConflicts: uniquifyConflicts
                )
                if removeSourceFiles {
                    try removeDirectoryIfEmpty(fileManager: fileManager, at: sourceItem)
                }
                continue
            }

            if !fileManager.fileExists(atPath: destinationItem.path) {
                if removeSourceFiles {
                    try safeMoveItem(fileManager: fileManager, from: sourceItem, to: destinationItem)
                } else {
                    try fileManager.copyItem(at: sourceItem, to: destinationItem)
                }
                continue
            }

            guard uniquifyConflicts else { continue }

            let uniqueDestination = uniqueDestinationURL(
                fileManager: fileManager,
                in: destinationDirectory,
                desiredFileName: sourceItem.lastPathComponent
            )
            if removeSourceFiles {
                try safeMoveItem(fileManager: fileManager, from: sourceItem, to: uniqueDestination)
            } else {
                try fileManager.copyItem(at: sourceItem, to: uniqueDestination)
            }
        }
    }

    private func uniqueDestinationURL(
        fileManager: FileManager,
        in directory: URL,
        desiredFileName: String
    ) -> URL {
        let baseURL = directory.appendingPathComponent(desiredFileName)
        let stem = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension
        var candidate = baseURL
        var suffix = 1

        while fileManager.fileExists(atPath: candidate.path) {
            suffix += 1
            let name = ext.isEmpty
                ? "\(stem)-\(String(format: "%03d", suffix))"
                : "\(stem)-\(String(format: "%03d", suffix)).\(ext)"
            candidate = directory.appendingPathComponent(name)
        }

        return candidate
    }

    private func removeDirectoryIfEmpty(fileManager: FileManager, at directory: URL) throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        guard contents.isEmpty else { return }
        try fileManager.removeItem(at: directory)
    }
}
