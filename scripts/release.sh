#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:-}"
tag="v$version"
fallback_env="$HOME/src/nvm/.env.release"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: $0 x.y.z" >&2
  exit 1
fi

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

SIGN_IDENTITY="Developer ID Application: Pablo Varela (2TZ4Q825M7)" \
  CODESIGN_TIMESTAMP=secure \
  VERSION="$version" \
  "$root/scripts/build-app.sh"

mkdir -p "$root/dist"
rm -f "$root/dist/Nommac-$tag-macos-universal.zip" \
  "$root/dist/Nommac-$tag-macos-universal.dmg" \
  "$root/dist/SHA256SUMS"

submission="$root/dist/Nommac-$tag-notarization.zip"
ditto -c -k --sequesterRsrc --keepParent "$root/build/Nommac.app" "$submission"
xcrun notarytool submit "$submission" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait
rm -f "$submission"

xcrun stapler staple "$root/build/Nommac.app"
xcrun stapler validate "$root/build/Nommac.app"

archive="$root/dist/Nommac-$tag-macos-universal.zip"
disk_image="$root/dist/Nommac-$tag-macos-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$root/build/Nommac.app" "$archive"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$root/build/Nommac.app" "$staging/Nommac.app"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname Nommac -srcfolder "$staging" -ov -format UDZO "$disk_image"

xcrun notarytool submit "$disk_image" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait
xcrun stapler staple "$disk_image"
xcrun stapler validate "$disk_image"

cd "$root/dist"
shasum -a 256 "$(basename "$archive")" "$(basename "$disk_image")" > SHA256SUMS

echo "Created signed and notarized release artifacts in $root/dist"
