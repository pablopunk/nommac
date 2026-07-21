#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
version="${VERSION:-$(tr -d '[:space:]' < "$root/VERSION")}"
build_number="${BUILD_NUMBER:-$(git -C "$root" rev-list --count HEAD)}"
sign_identity="${SIGN_IDENTITY:--}"
timestamp="${CODESIGN_TIMESTAMP:-none}"
app="$root/build/Nommac.app"
executable="$app/Contents/MacOS/Nommac"
icon_metadata="$root/build/Nommac-icon-info.plist"
icon_output="$(mktemp -d)"
trap 'rm -rf "$icon_output"' EXIT

build_architecture() {
  local architecture="$1"
  swift build \
    --package-path "$root" \
    --configuration release \
    --scratch-path "$root/.build/$architecture" \
    --triple "${architecture}-apple-macosx15.0"
}

build_architecture arm64
build_architecture x86_64

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create \
  "$root/.build/arm64/arm64-apple-macosx/release/Nommac" \
  "$root/.build/x86_64/x86_64-apple-macosx/release/Nommac" \
  -output "$executable"
ditto "$root/Resources/Info.plist" "$app/Contents/Info.plist"
xcrun actool "$root/Resources/Nommac.icon" \
  --compile "$icon_output" \
  --platform macosx \
  --minimum-deployment-target 15.0 \
  --app-icon Nommac \
  --output-partial-info-plist "$icon_metadata" \
  --warnings --notices --errors >/dev/null
install -m 0644 "$icon_output/Assets.car" "$app/Contents/Resources/Assets.car"
install -m 0644 "$icon_output/Nommac.icns" "$app/Contents/Resources/Nommac.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app/Contents/Info.plist"

codesign_arguments=(
  --force
  --options runtime
  --entitlements "$root/Resources/Nommac.entitlements"
  --sign "$sign_identity"
)
if [[ "$timestamp" == "none" ]]; then
  codesign_arguments+=(--timestamp=none)
else
  codesign_arguments+=(--timestamp)
fi

codesign "${codesign_arguments[@]}" "$app"
"$root/scripts/verify-app.sh" "$app" "$version"
architectures="$(lipo -archs "$executable")"
echo "Built Nommac $version ($build_number): $architectures"
