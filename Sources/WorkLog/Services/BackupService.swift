import Foundation

struct BackupResult {
    var backupURL: URL
    var backupURLs: [URL]
    var date: Date
    var usedICloudDrive: Bool
}

final class BackupService {
    private static let defaultMaxBackupsPerLocation = 30

    private let fallbackBaseDirectory: URL
    private let cloudDocumentsDirectory: URL?
    private let maxBackupsPerLocation: Int

    init(
        fallbackBaseDirectory: URL,
        cloudDocumentsDirectory: URL? = nil,
        maxBackupsPerLocation: Int = BackupService.defaultMaxBackupsPerLocation
    ) {
        self.fallbackBaseDirectory = fallbackBaseDirectory
        self.cloudDocumentsDirectory = cloudDocumentsDirectory
        self.maxBackupsPerLocation = max(1, maxBackupsPerLocation)
    }

    func backupRoot() throws -> URL {
        let root = backupRoots().first ?? fallbackBaseDirectory.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func backupRoots() -> [URL] {
        guard let cloudDocs = iCloudDriveCloudDocumentsRoot() else {
            return [fallbackBaseDirectory.appendingPathComponent("Backups", isDirectory: true)]
        }

        let newRoot = cloudDocs
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Work Log", isDirectory: true)
        let legacyRoot = cloudDocs
            .appendingPathComponent("Work Log", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
        return [newRoot, legacyRoot]
    }

    func backupIfNeeded(data: AppData, documentsDirectory: URL) throws -> BackupResult? {
        if let lastBackupDate = data.lastBackupDate,
           Calendar.current.isDate(lastBackupDate, inSameDayAs: Date()) {
            return nil
        }
        return try createBackup(data: data, documentsDirectory: documentsDirectory)
    }

    func createBackup(data: AppData, documentsDirectory: URL) throws -> BackupResult {
        let backupDate = Date()
        var backupData = data
        backupData.lastBackupDate = backupDate
        let encoded = try JSONCoders.encoder.encode(backupData)
        let backupFolderName = "WorkLogBackup_\(AppDateFormatters.backupStamp.string(from: backupDate))"
        let roots = backupRoots()
        var backupURLs: [URL] = []
        var failures: [(URL, Error)] = []

        for root in roots {
            do {
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
                let backupFolder = root.appendingPathComponent(backupFolderName, isDirectory: true)
                try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)

                let dataURL = backupFolder.appendingPathComponent("work-log-data.json")
                try encoded.write(to: dataURL, options: [.atomic])

                if FileManager.default.fileExists(atPath: documentsDirectory.path) {
                    let documentsBackupURL = backupFolder.appendingPathComponent("Documents", isDirectory: true)
                    if FileManager.default.fileExists(atPath: documentsBackupURL.path) {
                        try FileManager.default.removeItem(at: documentsBackupURL)
                    }
                    try FileManager.default.copyItem(at: documentsDirectory, to: documentsBackupURL)
                }

                try cleanupBackups(in: root)
                backupURLs.append(backupFolder)
            } catch {
                failures.append((root, error))
            }
        }

        guard failures.isEmpty, let primaryBackupURL = backupURLs.first else {
            let message = failures
                .map { "\($0.0.path): \($0.1.localizedDescription)" }
                .joined(separator: "; ")
            throw NSError(
                domain: "WorkLog.BackupService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? "Backup failed." : "Backup failed: \(message)"]
            )
        }

        return BackupResult(
            backupURL: primaryBackupURL,
            backupURLs: backupURLs,
            date: backupDate,
            usedICloudDrive: iCloudDriveCloudDocumentsRoot() != nil
        )
    }

    func latestBackup() throws -> URL? {
        let backupFolders = try backupRoots().flatMap { root -> [URL] in
            guard FileManager.default.fileExists(atPath: root.path) else { return [] }
            return try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            .filter { url in
                var isDirectory: ObjCBool = false
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
                    && FileManager.default.fileExists(atPath: url.appendingPathComponent("work-log-data.json").path)
            }
        }

        return backupFolders.sorted { $0.lastPathComponent > $1.lastPathComponent }.first
    }

    func restore(from backupURL: URL, documentsDirectory: URL) throws -> AppData {
        let dataURL = backupURL.appendingPathComponent("work-log-data.json")
        let data = try Data(contentsOf: dataURL)
        let appData = try JSONCoders.decoder.decode(AppData.self, from: data)

        let backupDocumentsURL = backupURL.appendingPathComponent("Documents", isDirectory: true)
        if FileManager.default.fileExists(atPath: documentsDirectory.path) {
            try FileManager.default.removeItem(at: documentsDirectory)
        }

        if FileManager.default.fileExists(atPath: backupDocumentsURL.path) {
            try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
            let files = try FileManager.default.contentsOfDirectory(at: backupDocumentsURL, includingPropertiesForKeys: nil)
            for file in files {
                let destination = documentsDirectory.appendingPathComponent(file.lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: file, to: destination)
            }
        }

        return appData
    }

    private func iCloudDriveCloudDocumentsRoot() -> URL? {
        let cloudDocs = cloudDocumentsDirectory ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        return FileManager.default.fileExists(atPath: cloudDocs.path) ? cloudDocs : nil
    }

    private func cleanupBackups(in root: URL) throws {
        let backupFolders = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
                && FileManager.default.fileExists(atPath: url.appendingPathComponent("work-log-data.json").path)
        }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }

        guard backupFolders.count > maxBackupsPerLocation else { return }

        for backupFolder in backupFolders.dropFirst(maxBackupsPerLocation) {
            try FileManager.default.removeItem(at: backupFolder)
        }
    }
}
