#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="WorkLog"
BUNDLE_NAME="Work Log"
BUNDLE_ID="${WORKLOG_BUNDLE_ID:-com.sarveshchandra.WorkLog}"
MIN_SYSTEM_VERSION="13.0"
APP_VERSION="${WORKLOG_VERSION:-1.0.0}"
APP_BUILD="${WORKLOG_BUILD:-1}"
APP_CATEGORY="${WORKLOG_APP_CATEGORY:-public.app-category.productivity}"
RELEASE_CHANNEL="${WORKLOG_RELEASE_CHANNEL:-development}"
SIGNING_IDENTITY="${WORKLOG_SIGNING_IDENTITY:-}"
COPYRIGHT_TEXT="${WORKLOG_COPYRIGHT:-Copyright © $(date +%Y) Sarvesh Chandra}"
ENABLE_DEMO_DATA_VALUE="${WORKLOG_ENABLE_DEMO_DATA:-0}"

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
  "$ROOT_DIR/Sources/WorkLog/Support/AppRuntimeConfiguration.swift"
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

# Remove Finder and quarantine metadata before signing or archiving the bundle.
xattr -cr "$APP_BUNDLE"

if [[ "$ENABLE_DEMO_DATA_VALUE" =~ ^([1Tt][Rr]?[Uu]?[Ee]?|[Yy][Ee]?[Ss]?|[Oo][Nn])$ ]]; then
  ENABLE_DEMO_DATA_PLIST="<true/>"
else
  ENABLE_DEMO_DATA_PLIST="<false/>"
fi

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
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundleIconFile</key>
  <string>WorkLogIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>$APP_CATEGORY</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHumanReadableCopyright</key>
  <string>$COPYRIGHT_TEXT</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>WorkLogEnableDemoData</key>
  $ENABLE_DEMO_DATA_PLIST
  <key>WorkLogReleaseChannel</key>
  <string>$RELEASE_CHANNEL</string>
</dict>
</plist>
PLIST

sign_bundle_if_requested() {
  if [[ -z "$SIGNING_IDENTITY" ]]; then
    return
  fi

  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP_BINARY"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$APP_BUNDLE"
}

sign_bundle_if_requested

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build|--build-only)
    ;;
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
    echo "usage: $0 [run|build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
