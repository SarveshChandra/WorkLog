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

        guard fileManager.fileExists(atPath: legacyBaseDirectory.path) else { return }
        guard !fileManager.fileExists(atPath: preferredDataURL.path) else {
            // iCloud already has a data file; do not overwrite.
            return
        }
        guard fileManager.fileExists(atPath: legacyDataURL.path) else { return }

        do {
            try fileManager.createDirectory(at: preferredBaseDirectory, withIntermediateDirectories: true)

            // Move main data file.
            try safeMoveItem(fileManager: fileManager, from: legacyDataURL, to: preferredDataURL)

            // Move documents directory if present.
            let legacyDocs = legacyBaseDirectory.appendingPathComponent("Documents", isDirectory: true)
            let preferredDocs = preferredBaseDirectory.appendingPathComponent("Documents", isDirectory: true)
            if fileManager.fileExists(atPath: legacyDocs.path), !fileManager.fileExists(atPath: preferredDocs.path) {
                try safeMoveItem(fileManager: fileManager, from: legacyDocs, to: preferredDocs)
            }

            // Copy legacy backups folder if present so both backup locations stay populated.
            let legacyBackups = legacyBaseDirectory.appendingPathComponent("Backups", isDirectory: true)
            if let preferredBackups = iCloudDriveBackupRoot(fileManager: fileManager),
               fileManager.fileExists(atPath: legacyBackups.path) {
                try fileManager.createDirectory(at: preferredBackups, withIntermediateDirectories: true)
                let files = try fileManager.contentsOfDirectory(at: legacyBackups, includingPropertiesForKeys: nil)
                for file in files {
                    let destination = preferredBackups.appendingPathComponent(file.lastPathComponent)
                    if fileManager.fileExists(atPath: destination.path) {
                        try fileManager.removeItem(at: destination)
                    }
                    try fileManager.copyItem(at: file, to: destination)
                }
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
}
