# Work Log

Native macOS app for structured career tracking.

## V1 Scope

- Tasks: table-first work log with company, designation, role, project/product, team, feature, task, searchable multiselect tags, date, situation, challenges, skills used, action, outcome, and learning.
- Interview Tracker: minimal company-role tracker with status, next action, due date, cooldown period input, calculated stage/last activity/eligible-again date/result/referral summary, optional referral details, interview rounds, and notes.
- Documents: standalone document vault for resumes, offer letters, relieving letters, certificates, salary files, and other career documents. Documents are not linked to interview opportunities.
- Settings: backup status, manual backup, restore latest backup, export JSON, and data folder shortcuts.
- Top navigation: no sidebar; the app icon and title stay visible at the top.
- Appearance: light, dark, and system theme modes.
- Demo data: seeded automatically on an empty data file, with sample work logs, interview opportunities, referral/cooldown cases, and document records.

## Build

Use the project script to compile and launch the app:

```bash
./script/build_and_run.sh
```

To verify the build without keeping the app in the foreground:

```bash
./script/build_and_run.sh --verify
```

The script directly compiles the SwiftUI sources with `swiftc`, stages `dist/Work Log.app`, and launches it as a real macOS app bundle. It avoids `swift build` because the active Command Line Tools install has a SwiftPM `PackageDescription` manifest-link mismatch on this machine.

## Screenshot

![Work Log app screenshot](image.png)

The screenshot shows the tasks view of the app on macOS.

## App Icon

The top bar and runtime Dock icon use a simple SwiftUI vector mark. The vector source file is:

```text
Sources/WorkLog/Support/AppIconArtwork.swift
```

Generated bundle resources are stored at:

```text
Resources/Images/work-log-icon.pdf
Resources/Images/work-log-icon.png
Resources/WorkLogIcon.icns
```

## Data

Local app data:

```text
~/Library/Application Support/Work Log/work-log-data.json
```

Imported documents:

```text
~/Library/Application Support/Work Log/Documents/
```

Daily iCloud Drive backups:

```text
~/Library/Mobile Documents/com~apple~CloudDocs/Vault/Backups/Work Log/
```

If iCloud Drive is unavailable, the app falls back to:

```text
~/Library/Application Support/Work Log/Backups/
```
