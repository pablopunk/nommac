#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temporary_directory="$(mktemp -d)"
iconset="$temporary_directory/Nommac.iconset"
trap 'rm -rf "$temporary_directory"' EXIT

mkdir -p "$iconset"

render_icon() {
  local points="$1"
  local scale="$2"
  local pixels=$((points * scale))
  local suffix=""
  if [[ "$scale" == "2" ]]; then suffix="@2x"; fi
  rsvg-convert --width "$pixels" --height "$pixels" \
    "$root/Resources/Nommac.svg" > "$iconset/icon_${points}x${points}${suffix}.png"
}

for points in 16 32 128 256 512; do
  render_icon "$points" 1
  render_icon "$points" 2
done

iconutil --convert icns --output "$root/Resources/Nommac.icns" "$iconset"
