import XCTest
@testable import WorkLog

final class BackupAndPersistenceTests: XCTestCase {
    private let fileManager = FileManager.default

    func testBackupRootUsesVaultBackupsWorkLogWhenCloudDocsExists() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let fallbackBase = tempRoot.appendingPathComponent("ApplicationSupport/Work Log", isDirectory: true)
        let cloudDocs = tempRoot.appendingPathComponent("CloudDocs", isDirectory: true)
        try fileManager.createDirectory(at: cloudDocs, withIntermediateDirectories: true)

        let service = BackupService(
            fallbackBaseDirectory: fallbackBase,
            cloudDocumentsDirectory: cloudDocs
        )

        let root = try service.backupRoot()
        let expected = cloudDocs
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Work Log", isDirectory: true)

        XCTAssertEqual(root.path, expected.path)
        XCTAssertTrue(fileManager.fileExists(atPath: root.path))
    }

    func testCreateBackupWritesToBothCloudBackupPaths() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let fallbackBase = tempRoot.appendingPathComponent("ApplicationSupport/Work Log", isDirectory: true)
        let cloudDocs = tempRoot.appendingPathComponent("CloudDocs", isDirectory: true)
        try fileManager.createDirectory(at: cloudDocs, withIntermediateDirectories: true)

        let service = BackupService(
            fallbackBaseDirectory: fallbackBase,
            cloudDocumentsDirectory: cloudDocs
        )

        let documentsDirectory = tempRoot.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        try "resume".data(using: .utf8)!.write(to: documentsDirectory.appendingPathComponent("resume.txt"), options: [.atomic])

        let result = try service.createBackup(data: AppData(), documentsDirectory: documentsDirectory)
        XCTAssertEqual(result.backupURLs.count, 2)

        let legacyRoot = cloudDocs
            .appendingPathComponent("Work Log", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
        let newRoot = cloudDocs
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Work Log", isDirectory: true)

        let legacyBackup = try XCTAssertSingleBackupFolder(in: legacyRoot)
        let newBackup = try XCTAssertSingleBackupFolder(in: newRoot)
        XCTAssertEqual(legacyBackup.lastPathComponent, newBackup.lastPathComponent)
        XCTAssertTrue(fileManager.fileExists(atPath: legacyBackup.appendingPathComponent("work-log-data.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: newBackup.appendingPathComponent("work-log-data.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: legacyBackup.appendingPathComponent("Documents/resume.txt").path))
        XCTAssertTrue(fileManager.fileExists(atPath: newBackup.appendingPathComponent("Documents/resume.txt").path))
        XCTAssertTrue(result.backupURLs.contains(where: { $0.path == legacyBackup.path }))
        XCTAssertTrue(result.backupURLs.contains(where: { $0.path == newBackup.path }))
    }

    func testCreateBackupCleansUpOlderBackupsInBothCloudPaths() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let fallbackBase = tempRoot.appendingPathComponent("ApplicationSupport/Work Log", isDirectory: true)
        let cloudDocs = tempRoot.appendingPathComponent("CloudDocs", isDirectory: true)
        try fileManager.createDirectory(at: cloudDocs, withIntermediateDirectories: true)

        let service = BackupService(
            fallbackBaseDirectory: fallbackBase,
            cloudDocumentsDirectory: cloudDocs,
            maxBackupsPerLocation: 2
        )

        let documentsDirectory = tempRoot.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        try "resume".data(using: .utf8)!.write(to: documentsDirectory.appendingPathComponent("resume.txt"), options: [.atomic])

        let newRoot = cloudDocs
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Work Log", isDirectory: true)
        let legacyRoot = cloudDocs
            .appendingPathComponent("Work Log", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)

        try createStubBackup(named: "WorkLogBackup_20260501_010101", in: newRoot)
        try createStubBackup(named: "WorkLogBackup_20260501_010101", in: legacyRoot)
        try createStubBackup(named: "WorkLogBackup_20260502_010101", in: newRoot)
        try createStubBackup(named: "WorkLogBackup_20260502_010101", in: legacyRoot)

        _ = try service.createBackup(data: AppData(), documentsDirectory: documentsDirectory)

        let newNames = try backupFolderNames(in: newRoot)
        let legacyNames = try backupFolderNames(in: legacyRoot)

        XCTAssertEqual(newNames.count, 2)
        XCTAssertEqual(legacyNames.count, 2)
        XCTAssertFalse(newNames.contains("WorkLogBackup_20260501_010101"))
        XCTAssertFalse(legacyNames.contains("WorkLogBackup_20260501_010101"))
    }

    func testBackupRootFallsBackWhenCloudDocsMissing() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let fallbackBase = tempRoot.appendingPathComponent("ApplicationSupport/Work Log", isDirectory: true)
        let missingCloudDocs = tempRoot.appendingPathComponent("CloudDocsMissing", isDirectory: true)

        let service = BackupService(
            fallbackBaseDirectory: fallbackBase,
            cloudDocumentsDirectory: missingCloudDocs
        )

        let root = try service.backupRoot()
        XCTAssertEqual(root.path, fallbackBase.appendingPathComponent("Backups", isDirectory: true).path)
        XCTAssertTrue(fileManager.fileExists(atPath: root.path))
    }

    func testLegacyLocalDataMigratesIntoPreferredDataLocationAndNewBackupTree() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let legacyBase = tempRoot.appendingPathComponent("ApplicationSupport/Work Log", isDirectory: true)
        let cloudDocs = tempRoot.appendingPathComponent("CloudDocs", isDirectory: true)
        let preferredBase = cloudDocs.appendingPathComponent("Work Log", isDirectory: true)

        try fileManager.createDirectory(at: legacyBase, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cloudDocs, withIntermediateDirectories: true)

        let originalData = AppData(
            workExperiences: [
                WorkExperience(company: "Acme", designation: "Engineer", role: "iOS")
            ],
            interviewOpportunities: [],
            documents: [],
            dashboardInsightCache: nil,
            lastBackupDate: Date(timeIntervalSince1970: 1_700_000_000),
            lastBackupPath: "/legacy/backup",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let legacyDataURL = legacyBase.appendingPathComponent("work-log-data.json")
        try JSONCoders.encoder.encode(originalData).write(to: legacyDataURL, options: [.atomic])

        let legacyDocs = legacyBase.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: legacyDocs, withIntermediateDirectories: true)
        try "resume".data(using: .utf8)!.write(to: legacyDocs.appendingPathComponent("resume.txt"), options: [.atomic])

        let legacyBackups = legacyBase.appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: legacyBackups, withIntermediateDirectories: true)
        try "backup".data(using: .utf8)!.write(to: legacyBackups.appendingPathComponent("old-backup.txt"), options: [.atomic])

        _ = DataPersistenceService(
            legacyBaseDirectory: legacyBase,
            preferredBaseDirectory: preferredBase,
            cloudDocumentsDirectory: cloudDocs,
            fileManager: fileManager
        )

        let preferredDataURL = preferredBase.appendingPathComponent("work-log-data.json")
        XCTAssertTrue(fileManager.fileExists(atPath: preferredDataURL.path))

        let migratedData = try JSONCoders.decoder.decode(AppData.self, from: Data(contentsOf: preferredDataURL))
        XCTAssertEqual(migratedData.workExperiences.first?.company, "Acme")
        XCTAssertEqual(migratedData.lastBackupPath, "/legacy/backup")
        XCTAssertFalse(fileManager.fileExists(atPath: legacyDataURL.path))

        let preferredDocs = preferredBase.appendingPathComponent("Documents", isDirectory: true)
        XCTAssertTrue(fileManager.fileExists(atPath: preferredDocs.appendingPathComponent("resume.txt").path))

        let preferredBackups = cloudDocs
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Work Log", isDirectory: true)
        XCTAssertTrue(fileManager.fileExists(atPath: preferredBackups.appendingPathComponent("old-backup.txt").path))
    }

    func testMigrationStillMovesLegacyDocumentsAndBackupsWhenPreferredDataAlreadyExists() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let legacyBase = tempRoot.appendingPathComponent("ApplicationSupport/Work Log", isDirectory: true)
        let cloudDocs = tempRoot.appendingPathComponent("CloudDocs", isDirectory: true)
        let preferredBase = cloudDocs.appendingPathComponent("Work Log", isDirectory: true)

        try fileManager.createDirectory(at: legacyBase, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: preferredBase, withIntermediateDirectories: true)

        let preferredData = AppData(
            workExperiences: [WorkExperience(company: "Existing", designation: "Engineer", role: "macOS")],
            interviewOpportunities: [],
            documents: [],
            dashboardInsightCache: nil,
            lastBackupDate: nil,
            lastBackupPath: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_100_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_100_100)
        )
        try JSONCoders.encoder.encode(preferredData).write(
            to: preferredBase.appendingPathComponent("work-log-data.json"),
            options: [.atomic]
        )

        let legacyDocs = legacyBase.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: legacyDocs, withIntermediateDirectories: true)
        try "resume".data(using: .utf8)!.write(
            to: legacyDocs.appendingPathComponent("resume.txt"),
            options: [.atomic]
        )

        let legacyBackups = legacyBase.appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: legacyBackups, withIntermediateDirectories: true)
        try "backup".data(using: .utf8)!.write(
            to: legacyBackups.appendingPathComponent("old-backup.txt"),
            options: [.atomic]
        )

        _ = DataPersistenceService(
            legacyBaseDirectory: legacyBase,
            preferredBaseDirectory: preferredBase,
            cloudDocumentsDirectory: cloudDocs,
            fileManager: fileManager
        )

        let preferredDocs = preferredBase.appendingPathComponent("Documents", isDirectory: true)
        XCTAssertTrue(fileManager.fileExists(atPath: preferredDocs.appendingPathComponent("resume.txt").path))

        let preferredDataURL = preferredBase.appendingPathComponent("work-log-data.json")
        let migratedData = try JSONCoders.decoder.decode(AppData.self, from: Data(contentsOf: preferredDataURL))
        XCTAssertEqual(migratedData.workExperiences.first?.company, "Existing")

        let preferredBackups = cloudDocs
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Work Log", isDirectory: true)
        XCTAssertTrue(fileManager.fileExists(atPath: preferredBackups.appendingPathComponent("old-backup.txt").path))
    }

    func testCreateBackupUsesUniqueFolderNamesWhenMultipleBackupsShareTimestamp() throws {
        let tempRoot = try makeTemporaryDirectory()
        defer { try? fileManager.removeItem(at: tempRoot) }

        let fallbackBase = tempRoot.appendingPathComponent("ApplicationSupport/Work Log", isDirectory: true)
        let cloudDocs = tempRoot.appendingPathComponent("CloudDocs", isDirectory: true)
        try fileManager.createDirectory(at: cloudDocs, withIntermediateDirectories: true)

        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let service = BackupService(
            fallbackBaseDirectory: fallbackBase,
            cloudDocumentsDirectory: cloudDocs,
            now: { fixedDate }
        )

        let documentsDirectory = tempRoot.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        try "resume".data(using: .utf8)!.write(
            to: documentsDirectory.appendingPathComponent("resume.txt"),
            options: [.atomic]
        )

        let first = try service.createBackup(data: AppData(), documentsDirectory: documentsDirectory)
        let second = try service.createBackup(data: AppData(), documentsDirectory: documentsDirectory)

        XCTAssertNotEqual(first.backupURL.lastPathComponent, second.backupURL.lastPathComponent)

        let newRoot = cloudDocs
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Work Log", isDirectory: true)
        let names = try backupFolderNames(in: newRoot)

        XCTAssertEqual(names.count, 2)
        XCTAssertTrue(names.contains(first.backupURL.lastPathComponent))
        XCTAssertTrue(names.contains(second.backupURL.lastPathComponent))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("WorkLogTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func createStubBackup(named folderName: String, in root: URL) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let backupFolder = root.appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        try "{}".data(using: .utf8)!.write(
            to: backupFolder.appendingPathComponent("work-log-data.json"),
            options: [.atomic]
        )
    }

    private func backupFolderNames(in root: URL) throws -> [String] {
        try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        .map(\.lastPathComponent)
        .sorted()
    }

    private func XCTAssertSingleBackupFolder(in root: URL) throws -> URL {
        let contents = try fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let folders = contents.filter { url in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        XCTAssertEqual(folders.count, 1)
        return folders[0]
    }
}
