#!/usr/bin/env bash
# First run on a Mac: checks Xcode, runs the package tests, builds the app for
# the iOS Simulator, and opens the project. Run from anywhere in the repo:
#   bash Tools/setup_mac.sh
# If the build fails, the errors are in build/errors.txt: paste them to Claude Code.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p build

if ! xcode-select -p 2>/dev/null | grep -q "Xcode"; then
  echo "Xcode is not selected. Install Xcode from the App Store, open it once, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi
echo "Using $(xcodebuild -version | head -1)"

echo
echo "==> 1/3 Game logic tests (GroundworkCore and GroundworkView on macOS)"
if (cd GroundworkCore && swift test 2>&1 | tee ../build/tests.log | grep -E "Executed .* tests|error:" | tail -3); then
  :
fi

echo
echo "==> 2/3 Building the app for the iOS Simulator (the first build takes a minute or two)"
xcodebuild -project Groundwork.xcodeproj -scheme Groundwork \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath build/DerivedData build > build/xcodebuild.log 2>&1
status=$?
grep -E "error:" build/xcodebuild.log | sort -u > build/errors.txt
if [ $status -eq 0 ]; then
  echo "BUILD SUCCEEDED"
else
  echo "BUILD FAILED with $(wc -l < build/errors.txt | tr -d ' ') errors (first 20 below)."
  head -20 build/errors.txt
  echo
  echo "Full list: build/errors.txt. Paste it to Claude Code to fix."
fi

echo
echo "==> 3/3 Opening the project in Xcode"
open Groundwork.xcodeproj
echo "In Xcode, choose an iPhone simulator at the top and press Run (Cmd+R)."
