#!/usr/bin/env bash
set -euo pipefail

required=(
  APP_STORE_CONNECT_API_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_P8
  IOS_DISTRIBUTION_CERTIFICATE_BASE64
  IOS_DISTRIBUTION_CERTIFICATE_PASSWORD
  IOS_PROVISIONING_PROFILE_BASE64
  IOS_CI_KEYCHAIN_PASSWORD
)

missing=()
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    missing+=("$name")
  fi
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required GitHub Actions secrets for signed App Store archive:\n' >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi
