#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from Resources/AppIcon.svg (needs rsvg-convert + iconutil).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"

for s in 16 32 128 256 512; do
  rsvg-convert -w "$s" -h "$s" "$ROOT/Resources/AppIcon.svg" -o "$SET/icon_${s}x${s}.png"
  rsvg-convert -w "$((s * 2))" -h "$((s * 2))" "$ROOT/Resources/AppIcon.svg" -o "$SET/icon_${s}x${s}@2x.png"
done

iconutil -c icns "$SET" -o "$ROOT/Resources/AppIcon.icns"
echo "wrote Resources/AppIcon.icns"
