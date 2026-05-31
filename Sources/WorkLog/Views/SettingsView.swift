import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(.bottom, 2)

                GroupBox("Appearance") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRow(title: "Theme") {
                            Picker("Theme", selection: $store.theme) {
                                ForEach(AppTheme.allCases) { theme in
                                    Text(theme.rawValue).tag(theme)
                                }
                            }
                            .pickerStyle(.segmented)
                            .tint(.workLogSkyBlue)
                            .frame(maxWidth: 360)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }

                GroupBox("Backup") {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsValueRow(
                            title: "Last backup",
                            value: store.data.lastBackupDate.map(AppDateFormatters.statusDateTime.string) ?? "Not backed up yet"
                        )

                        if let lastBackupPath = store.data.lastBackupPath {
                            Text(lastBackupPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 12) {
                            Button {
                                store.backupNow()
                            } label: {
                                Label("Backup Now", systemImage: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                store.restoreLatestBackup()
                            } label: {
                                Label("Restore Latest", systemImage: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                store.openBackupFolder()
                            } label: {
                                Label("Open Backup Folder", systemImage: "folder")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }

                GroupBox("Data") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                store.exportJSON()
                            } label: {
                                Label("Export JSON", systemImage: "square.and.arrow.up")
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                store.openDataFolder()
                            } label: {
                                Label("Open Data Folder", systemImage: "folder")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        SettingsPathRow(title: "Data file", value: store.dataFilePath)
                        SettingsPathRow(title: "Documents folder", value: store.documentsDirectoryPath)
                        SettingsPathRow(title: "Backup folder", value: store.backupDirectoryPath)
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }

                GroupBox("Status") {
                    Text(store.statusMessage.isBlank ? "Ready" : store.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                        .padding(.bottom, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .foregroundStyle(.workLogHeaderText)
                .frame(width: 120, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
    }
}

private struct SettingsValueRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.workLogHeaderText)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.primary.opacity(0.9))
        }
    }
}

private struct SettingsPathRow: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .foregroundStyle(.workLogHeaderText)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
