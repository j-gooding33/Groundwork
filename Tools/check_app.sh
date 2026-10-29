#!/usr/bin/env bash
# Best-effort checks of the iOS app code on Linux, where Apple's frameworks
# do not exist:
#  1. every file in App/Groundwork parses;
#  2. the SpriteKit, UIKit and AVFoundation files type-check against small
#     stand-ins (Tools/AppleStubs) plus the real GroundworkCore and
#     GroundworkView. The stand-ins can differ from Apple's real API, so this
#     catches mistakes in our code, not every possible compile error.
# SwiftUI files are only parsed. The real check is building in Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

echo "==> Parsing App/Groundwork"
swiftc -parse App/Groundwork/*.swift

echo "==> Building GroundworkCore and GroundworkView"
(cd GroundworkCore && swift build --target GroundworkView >/dev/null)
MODULES="$(cd GroundworkCore && swift build --show-bin-path)/Modules"

echo "==> Building the Apple stand-ins"
for module in UIKit SpriteKit AVFoundation; do
  swiftc -parse-as-library -emit-module -module-name "$module" -I "$OUT" \
    -emit-module-path "$OUT/$module.swiftmodule" "Tools/AppleStubs/$module.swift"
done

echo "==> Type-checking the scene, atlas, sound and store"
swiftc -typecheck -module-name Groundwork -I "$OUT" -I "$MODULES" \
  App/Groundwork/GameStore.swift App/Groundwork/Feel.swift App/Groundwork/Atlas.swift App/Groundwork/WorldScene.swift

echo "App checks passed (SwiftUI files parsed only)."
