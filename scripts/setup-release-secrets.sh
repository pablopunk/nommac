#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
fallback_env="$HOME/src/nvm/.env.release"

if [[ -f "$root/.env.release" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$root/.env.release"
  set +a
elif [[ -f "$fallback_env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$fallback_env"
  set +a
fi

: "${APPLE_ID:?Missing APPLE_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Missing APPLE_APP_SPECIFIC_PASSWORD}"
: "${APPLE_TEAM_ID:?Missing APPLE_TEAM_ID}"
: "${MACOS_CERT_P12_PATH:?Missing MACOS_CERT_P12_PATH}"
: "${MACOS_CERT_PASSWORD:?Missing MACOS_CERT_PASSWORD}"
[[ -f "$MACOS_CERT_P12_PATH" ]]

printf '%s' "$APPLE_ID" | gh secret set APPLE_ID --repo pablopunk/nommac
printf '%s' "$APPLE_APP_SPECIFIC_PASSWORD" | gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo pablopunk/nommac
printf '%s' "$APPLE_TEAM_ID" | gh secret set APPLE_TEAM_ID --repo pablopunk/nommac
printf '%s' "$MACOS_CERT_PASSWORD" | gh secret set MACOS_CERT_PASSWORD --repo pablopunk/nommac
openssl base64 -A -in "$MACOS_CERT_P12_PATH" | gh secret set MACOS_CERT_P12_BASE64 --repo pablopunk/nommac

gh secret list --repo pablopunk/nommac
