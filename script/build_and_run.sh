#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="WorkLog"
BUNDLE_NAME="Work Log"
BUNDLE_ID="com.local.WorkLog"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
BUILD_DIR="$ROOT_DIR/.build/manual"
MODULE_CACHE="$ROOT_DIR/.build/ModuleCache"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
SOURCE_FILES=(
  "$ROOT_DIR/Sources/WorkLog/App/WorkLogApp.swift"
  "$ROOT_DIR/Sources/WorkLog/Models/AppSection.swift"
  "$ROOT_DIR/Sources/WorkLog/Models/AppTheme.swift"
  "$ROOT_DIR/Sources/WorkLog/Models/AppData.swift"
  "$ROOT_DIR/Sources/WorkLog/Models/WorkExperience.swift"
  "$ROOT_DIR/Sources/WorkLog/Models/InterviewOpportunity.swift"
  "$ROOT_DIR/Sources/WorkLog/Models/DocumentRecord.swift"
  "$ROOT_DIR/Sources/WorkLog/Support/JSONCoders.swift"
  "$ROOT_DIR/Sources/WorkLog/Support/DateFormatters.swift"
  "$ROOT_DIR/Sources/WorkLog/Support/StringHelpers.swift"
  "$ROOT_DIR/Sources/WorkLog/Support/AppIconArtwork.swift"
  "$ROOT_DIR/Sources/WorkLog/Support/DemoDataFactory.swift"
  "$ROOT_DIR/Sources/WorkLog/Services/DataPersistenceService.swift"
  "$ROOT_DIR/Sources/WorkLog/Services/DocumentStorageService.swift"
  "$ROOT_DIR/Sources/WorkLog/Services/BackupService.swift"
  "$ROOT_DIR/Sources/WorkLog/Stores/AppStore.swift"
  "$ROOT_DIR/Sources/WorkLog/Views/ContentView.swift"
  "$ROOT_DIR/Sources/WorkLog/Views/DashboardView.swift"
  "$ROOT_DIR/Sources/WorkLog/Views/TopBarView.swift"
  "$ROOT_DIR/Sources/WorkLog/Views/SharedControls.swift"
  "$ROOT_DIR/Sources/WorkLog/Views/WorkExperienceView.swift"
  "$ROOT_DIR/Sources/WorkLog/Views/InterviewTrackerView.swift"
  "$ROOT_DIR/Sources/WorkLog/Views/DocumentsView.swift"
  "$ROOT_DIR/Sources/WorkLog/Views/SettingsView.swift"
)

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

mkdir -p "$BUILD_DIR" "$MODULE_CACHE"
swiftc -module-cache-path "$MODULE_CACHE" -o "$BUILD_BINARY" "${SOURCE_FILES[@]}"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ROOT_DIR/Resources/Images/work-log-icon.png" "$APP_RESOURCES/work-log-icon.png"
cp "$ROOT_DIR/Resources/Images/work-log-icon.pdf" "$APP_RESOURCES/work-log-icon.pdf"
cp "$ROOT_DIR/Resources/WorkLogIcon.icns" "$APP_RESOURCES/WorkLogIcon.icns"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>WorkLogIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
