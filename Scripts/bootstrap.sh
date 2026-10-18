#!/usr/bin/env bash
# One-step setup on a Mac: generates the alarm sounds, then the Xcode project.
# Usage: ./Scripts/bootstrap.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }

python3 App/AlarmSoundGenerator.py
for f in GentleChime SunriseSequence ClassicWake; do
  test -s "App/Resources/$f.wav" || { echo "Missing App/Resources/$f.wav"; exit 1; }
done
xcodegen generate
echo "Done. Open ShabbatWake.xcodeproj, pick your Team under Signing & Capabilities for BOTH targets, then run on your iPhone."
