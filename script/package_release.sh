#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Work Log.app"
RELEASE_DIR="$DIST_DIR/release"
VERSION="${WORKLOG_VERSION:-1.0.0}"
BUILD="${WORKLOG_BUILD:-1}"
SIGNING_IDENTITY="${WORKLOG_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${WORKLOG_NOTARY_PROFILE:-}"
ZIP_NAME="Work-Log-${VERSION}-${BUILD}.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "WORKLOG_SIGNING_IDENTITY is required for release packaging." >&2
  echo "Example: WORKLOG_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./script/package_release.sh" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
rm -f "$ZIP_PATH"

WORKLOG_ENABLE_DEMO_DATA=0 \
WORKLOG_RELEASE_CHANNEL="${WORKLOG_RELEASE_CHANNEL:-release}" \
WORKLOG_VERSION="$VERSION" \
WORKLOG_BUILD="$BUILD" \
WORKLOG_SIGNING_IDENTITY="$SIGNING_IDENTITY" \
"$ROOT_DIR/script/build_and_run.sh" build

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
fi

echo "Release app bundle: $APP_BUNDLE"
echo "Release archive: $ZIP_PATH"

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "Notarization skipped. Set WORKLOG_NOTARY_PROFILE to submit and staple automatically."
fi
