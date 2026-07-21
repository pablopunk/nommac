#!/usr/bin/env bash
set -euo pipefail

app="${1:?Usage: $0 /path/to/Nommac.app [version]}"
expected_version="${2:-}"
executable="$app/Contents/MacOS/Nommac"
resources="$app/Contents/Resources"

plutil -lint "$app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleIdentifier raw "$app/Contents/Info.plist")" == "com.pablopunk.nommac" ]]
if [[ -n "$expected_version" ]]; then
  [[ "$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")" == "$expected_version" ]]
fi

for icon_resource in "$resources/Assets.car" "$resources/Nommac.icns"; do
  [[ -f "$icon_resource" && -s "$icon_resource" && ! -L "$icon_resource" ]]
done
/usr/bin/assetutil --info "$resources/Assets.car" | grep '"Name" : "Nommac"' >/dev/null

architectures="$(lipo -archs "$executable")"
[[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]]
codesign --verify --deep --strict --verbose=2 "$app"

if [[ -n "${EXPECTED_SDK_MAJOR:-}" ]]; then
  xcrun vtool -show-build "$executable" | grep -Eq "sdk ${EXPECTED_SDK_MAJOR}\\."
fi
