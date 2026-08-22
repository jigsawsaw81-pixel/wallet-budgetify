#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
REPORT="${BUILD_DIR}/build-report.txt"
LOG="${BUILD_DIR}/xcodebuild-archive.log"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

WORKSPACE="$(find "$ROOT_DIR" -maxdepth 2 -name '*.xcworkspace' -print | sort | head -n 1 || true)"
PROJECT="$(find "$ROOT_DIR" -maxdepth 2 -name '*.xcodeproj' -print | sort | head -n 1 || true)"
if [[ -n "$WORKSPACE" ]]; then
  BUILD_CONTAINER=(-workspace "$WORKSPACE")
  CONTAINER_PATH="$WORKSPACE"
elif [[ -n "$PROJECT" ]]; then
  BUILD_CONTAINER=(-project "$PROJECT")
  CONTAINER_PATH="$PROJECT"
else
  echo "No Xcode project or workspace found." >&2
  exit 1
fi

if [[ "${CONTAINER_PATH##*.}" == "xcworkspace" ]]; then
  LIST_OUTPUT="$(xcodebuild -list -workspace "$CONTAINER_PATH")"
else
  LIST_OUTPUT="$(xcodebuild -list -project "$CONTAINER_PATH")"
fi
SCHEME="${SCHEME:-$(printf '%s\n' "$LIST_OUTPUT" | awk '/Schemes:/{found=1; next} found && NF {print $1; exit}') }"
SCHEME="${SCHEME// /}"
if [[ -z "$SCHEME" ]]; then
  echo "Unable to detect an Xcode scheme." >&2
  exit 1
fi

SETTINGS="$(xcodebuild "${BUILD_CONTAINER[@]}" -scheme "$SCHEME" -configuration Release -showBuildSettings)"
PRODUCT_NAME="$(printf '%s\n' "$SETTINGS" | awk -F ' = ' '/^[[:space:]]*PRODUCT_NAME = /{print $2; exit}' | xargs)"
BUNDLE_ID="$(printf '%s\n' "$SETTINGS" | awk -F ' = ' '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = /{print $2; exit}' | xargs)"
DEPLOYMENT_TARGET="$(printf '%s\n' "$SETTINGS" | awk -F ' = ' '/^[[:space:]]*IPHONEOS_DEPLOYMENT_TARGET = /{print $2; exit}' | xargs)"
PRODUCT_NAME="${PRODUCT_NAME:-Wallet}"
BUNDLE_ID="${BUNDLE_ID:-unknown.bundle.identifier}"
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-unknown}"

XCODE_VERSION="$(xcodebuild -version | tr '\n' ' ')"
SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
ARCHIVE="${BUILD_DIR}/${PRODUCT_NAME}.xcarchive"

set +e
xcodebuild \
  "${BUILD_CONTAINER[@]}" \
  -scheme "$SCHEME" \
  -sdk iphoneos \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  DEVELOPMENT_TEAM= \
  archive 2>&1 | tee "$LOG"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [[ "$BUILD_STATUS" -eq 0 && -d "$ARCHIVE/Products/Applications" ]]; then
  APP_SOURCE="$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' -print | sort | head -n 1)"
  if [[ -n "$APP_SOURCE" ]]; then
    PAYLOAD="$BUILD_DIR/Payload"
    IPA_PATH="$BUILD_DIR/Wallet-unsigned.ipa"
    mkdir -p "$PAYLOAD"
    rm -rf "$PAYLOAD/Wallet.app"
    cp -R "$APP_SOURCE" "$PAYLOAD/Wallet.app"
    (cd "$BUILD_DIR" && /usr/bin/zip -qry "$IPA_PATH" Payload)
    rm -rf "$PAYLOAD"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$ARCHIVE" "$BUILD_DIR/Wallet.xcarchive.zip"
    /usr/bin/shasum -a 256 "$IPA_PATH" "$BUILD_DIR/Wallet.xcarchive.zip" > "$BUILD_DIR/SHA256SUMS.txt"
  else
    BUILD_STATUS=1
  fi
fi

IPA_PATH="${BUILD_DIR}/Wallet-unsigned.ipa"
ARCHIVE_ZIP="${BUILD_DIR}/Wallet.xcarchive.zip"
{
  echo "Wallet unsigned IPA build report"
  echo "============================================"
  echo "Status: $([[ "$BUILD_STATUS" -eq 0 ]] && echo SUCCESS || echo FAILED)"
  echo "Project or workspace: $CONTAINER_PATH"
  echo "Scheme: $SCHEME"
  echo "Bundle identifier: $BUNDLE_ID"
  echo "Product name: $PRODUCT_NAME"
  echo "Deployment target: $DEPLOYMENT_TARGET"
  echo "Xcode: $XCODE_VERSION"
  echo "iOS SDK: $SDK_VERSION"
  echo "Unsigned IPA: $IPA_PATH"
  echo "Archive ZIP: $ARCHIVE_ZIP"
  if [[ -f "$IPA_PATH" ]]; then echo "IPA size: $(du -h "$IPA_PATH" | cut -f1)"; else echo "IPA size: unavailable"; fi
  if [[ -f "$ARCHIVE_ZIP" ]]; then echo "Archive size: $(du -h "$ARCHIVE_ZIP" | cut -f1)"; else echo "Archive size: unavailable"; fi
  if [[ -f "$BUILD_DIR/SHA256SUMS.txt" ]]; then
    echo "Checksums: $BUILD_DIR/SHA256SUMS.txt"
    cat "$BUILD_DIR/SHA256SUMS.txt"
  else
    echo "Checksums: unavailable because the build failed"
  fi
  echo "Warnings: unsigned output requires legitimate Apple-ID-based signing before installation; no credentials were used by this workflow."
} | tee "$REPORT"

exit "$BUILD_STATUS"
