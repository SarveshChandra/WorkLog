import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    private let buildInfo = AppRuntimeConfiguration.buildInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .padding(.bottom, 4)

                GroupBox("Appearance") {
                    SettingsSectionContent {
                        Picker("Theme", selection: $store.theme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .tint(.workLogSkyBlue)
                        .frame(maxWidth: 420)
                    }
                }

                GroupBox("Backup") {
                    SettingsSectionContent {
                        SettingsValueRow(
                            title: "Last backup",
                            value: store.data.lastBackupDate.map(AppDateFormatters.statusDateTime.string) ?? "Not backed up yet"
                        )

                        if let lastBackupPath = store.data.lastBackupPath {
                            SettingsPathValue(text: lastBackupPath)
                        }

                        SettingsActionsRow {
                            Button {
                                store.backupNow()
                            } label: {
                                Label("Backup Now", systemImage: "arrow.triangle.2.circlepath")
                                    .labelStyle(.iconOnly)
                            }
                            .help("Backup Now")
                            .accessibilityLabel("Backup Now")

                            Button {
                                store.restoreLatestBackup()
                            } label: {
                                Label("Restore Latest", systemImage: "clock.arrow.circlepath")
                                    .labelStyle(.iconOnly)
                            }
                            .help("Restore Latest")
                            .accessibilityLabel("Restore Latest")

                            Button {
                                store.openBackupFolder()
                            } label: {
                                Label("Open Backup Folder", systemImage: "folder")
                                    .labelStyle(.iconOnly)
                            }
                            .help("Open Backup Folder")
                            .accessibilityLabel("Open Backup Folder")
                        }
                    }
                }

                GroupBox("Data") {
                    SettingsSectionContent {
                        SettingsActionsRow {
                            Button {
                                store.exportJSON()
                            } label: {
                                Label("Export JSON", systemImage: "square.and.arrow.up")
                                    .labelStyle(.iconOnly)
                            }
                            .help("Export JSON")
                            .accessibilityLabel("Export JSON")

                            Button {
                                store.openDataFolder()
                            } label: {
                                Label("Open Data Folder", systemImage: "folder")
                                    .labelStyle(.iconOnly)
                            }
                            .help("Open Data Folder")
                            .accessibilityLabel("Open Data Folder")
                        }

                        SettingsPathRow(title: "Data file", value: store.dataFilePath)
                        SettingsPathRow(title: "Documents folder", value: store.documentsDirectoryPath)
                        SettingsPathRow(title: "Backup folder", value: store.backupDirectoryPath)
                    }
                }

                GroupBox("App") {
                    SettingsSectionContent {
                        SettingsValueRow(title: "Version", value: buildInfo.version)
                        SettingsValueRow(title: "Build", value: buildInfo.build)
                        SettingsValueRow(title: "Release channel", value: buildInfo.releaseChannel.capitalized)
                        SettingsValueRow(title: "Bundle identifier", value: buildInfo.bundleIdentifier)
                        SettingsValueRow(
                            title: "Demo data",
                            value: AppRuntimeConfiguration.allowsDemoData ? "Enabled" : "Disabled"
                        )
                    }
                }

                GroupBox("Status") {
                    SettingsSectionContent {
                        Text(store.statusMessage.isBlank ? "Ready" : store.statusMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SettingsSectionContent<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

private struct SettingsValueRow: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.workLogHeaderText)
            Text(value)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.92))
        }
    }
}

private struct SettingsPathRow: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.workLogHeaderText)
            SettingsPathValue(text: value)
        }
    }
}

private struct SettingsPathValue: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
    }
}

private struct SettingsActionsRow<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            content
            Spacer(minLength: 0)
        }
        .buttonStyle(SettingsActionButtonStyle())
    }
}

private struct SettingsActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.045))
            )
            .workLogHoverOutline(cornerRadius: 9)
    }
}
