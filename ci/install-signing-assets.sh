#!/usr/bin/env bash
set -euo pipefail

: "${IOS_DISTRIBUTION_CERTIFICATE_BASE64:?Missing distribution certificate}"
: "${IOS_DISTRIBUTION_CERTIFICATE_PASSWORD:?Missing certificate password}"
: "${IOS_PROVISIONING_PROFILE_BASE64:?Missing provisioning profile}"
: "${KEYCHAIN_PASSWORD:?Missing CI keychain password}"

CERT_PATH="$RUNNER_TEMP/rpt_distribution.p12"
PROFILE_PATH="$RUNNER_TEMP/RPT_AppStore.mobileprovision"
KEYCHAIN_PATH="$RUNNER_TEMP/rpt-signing.keychain-db"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

mkdir -p "$PROFILE_DIR"
printf '%s' "$IOS_DISTRIBUTION_CERTIFICATE_BASE64" | base64 --decode > "$CERT_PATH"
printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" -P "$IOS_DISTRIBUTION_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | sed 's/[\" ]//g')
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

PROFILE_UUID=$(/usr/libexec/PlistBuddy -c 'Print UUID' /dev/stdin <<< "$(security cms -D -i "$PROFILE_PATH")")
cp "$PROFILE_PATH" "$PROFILE_DIR/$PROFILE_UUID.mobileprovision"
echo "Installed provisioning profile $PROFILE_UUID"
