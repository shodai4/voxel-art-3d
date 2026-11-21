#!/usr/bin/env bash
# VoxelArt3D: GitHub Actions から App Store Connect(TestFlight) へ配信する。
# 必要な Secrets: APP_STORE_CONNECT_KEY_ID / APP_STORE_CONNECT_ISSUER_ID /
#                 APP_STORE_CONNECT_PRIVATE_KEY(p8の中身) / APPLE_TEAM_ID
set -euo pipefail

APP_NAME="VoxelArt3D"
SCHEME="VoxelArt3D"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

: "${KEY_ID:?APP_STORE_CONNECT_KEY_ID is missing}"
: "${ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is missing}"
: "${TEAM_ID:?APPLE_TEAM_ID is missing}"
: "${PRIVATE_KEY:?APP_STORE_CONNECT_PRIVATE_KEY is missing}"

# Secrets 欄で改行が空白や \n に潰れても署名できるよう、PEM を組み立て直す。
normalize_pem() {
  local raw="$1"
  raw="${raw//\\n/$'\n'}"
  if [[ "$raw" != *"-----BEGIN"* ]]; then
    printf '%s\n' "$raw"
    return
  fi
  local body="${raw#*-----BEGIN*-----}"
  body="${body%%-----END*}"
  body="$(printf '%s' "$body" | tr -d '[:space:]')"
  printf -- '-----BEGIN PRIVATE KEY-----\n'
  printf '%s' "$body" | fold -w 64
  printf -- '\n-----END PRIVATE KEY-----\n'
}
PRIVATE_KEY="$(normalize_pem "$PRIVATE_KEY")"

# 鍵の中身は出さず、形だけ確認する。
echo "== Private key shape: lines=$(printf '%s' "$PRIVATE_KEY" | wc -l | tr -d ' ') bytes=$(printf '%s' "$PRIVATE_KEY" | wc -c | tr -d ' ')"

echo "== Toolchain"
xcodebuild -version
ls -d /Applications/Xcode*.app || true

echo "== XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
xcodegen generate
xcodebuild -list -project "$APP_NAME.xcodeproj"

echo "== Export compliance (ITSAppUsesNonExemptEncryption = false)"
grep -A1 '<key>ITSAppUsesNonExemptEncryption</key>' Resources/Info.plist | grep -q '<false/>'

echo "== AppIcon"
test -f Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
sips -g pixelWidth -g pixelHeight -g hasAlpha Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png

echo "== Install App Store Connect API key"
KEY_DIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEY_DIR"
printf '%s\n' "$PRIVATE_KEY" > "$KEY_DIR/AuthKey_${KEY_ID}.p8"
chmod 600 "$KEY_DIR/AuthKey_${KEY_ID}.p8"
KEY_PATH="$RUNNER_TEMP/AuthKey_${KEY_ID}.p8"
printf '%s\n' "$PRIVATE_KEY" > "$KEY_PATH"
chmod 600 "$KEY_PATH"

echo "== Archive (build $BUILD_NUMBER)"
ARCHIVE="$RUNNER_TEMP/${APP_NAME}.xcarchive"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

echo "== ExportOptions"
EXPORT_OPTIONS="$RUNNER_TEMP/ExportOptions.plist"
rm -f "$EXPORT_OPTIONS"
plutil -create xml1 "$EXPORT_OPTIONS"
plutil -insert method -string app-store-connect "$EXPORT_OPTIONS"
plutil -insert teamID -string "$TEAM_ID" "$EXPORT_OPTIONS"
plutil -insert signingStyle -string automatic "$EXPORT_OPTIONS"
plutil -insert destination -string export "$EXPORT_OPTIONS"
plutil -insert manageAppVersionAndBuildNumber -bool false "$EXPORT_OPTIONS"
plutil -insert uploadSymbols -bool true "$EXPORT_OPTIONS"
plutil -insert stripSwiftSymbols -bool true "$EXPORT_OPTIONS"
plutil -lint "$EXPORT_OPTIONS"

echo "== Export IPA (cloud signing)"
EXPORT_DIR="$RUNNER_TEMP/export"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID"

IPA=$(ls -1 "$EXPORT_DIR"/*.ipa | head -n 1)
test -n "$IPA"
echo "IPA: $IPA"
unzip -p "$IPA" "Payload/*.app/Info.plist" > "$RUNNER_TEMP/ipa-info.plist" || true
plutil -extract CFBundleIdentifier raw -o - "$RUNNER_TEMP/ipa-info.plist" || true
plutil -extract CFBundleShortVersionString raw -o - "$RUNNER_TEMP/ipa-info.plist" || true
plutil -extract CFBundleVersion raw -o - "$RUNNER_TEMP/ipa-info.plist" || true

echo "== Upload to TestFlight"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID" --output-format json

echo "== Done: build $BUILD_NUMBER uploaded"
