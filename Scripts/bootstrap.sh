#!/usr/bin/env bash
# One-step setup on a Mac: generates the alarm sounds, then the Xcode project.
# Usage: ./Scripts/bootstrap.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }

python3 App/AlarmSoundGenerator.py
for f in GentleChime SunriseSequence ClassicWake $(ls App/SoundSources/*.mp3 | xargs -n1 basename | sed 's/\.mp3$//'); do
  for suffix in "" _10s _15s _20s _30s _40s _50s _n10s _n15s _n20s _n29s; do
    test -s "App/Resources/$f$suffix.wav" || { echo "Missing App/Resources/$f$suffix.wav"; exit 1; }
  done
done
xcodegen generate
echo "Done. Open ShabbatWake.xcodeproj, pick your Team under Signing & Capabilities for BOTH targets, then run on your iPhone."
