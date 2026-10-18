# Shabbat Wake — Red-Team Review

Last updated: 2026-10-18

This is an adversarial checklist, not a claim that every device-level scenario has passed. A scenario is marked PASS only after there is direct evidence.

## Critical safety and reliability checks

| Scenario | Current state | Risk / required evidence |
|---|---|---|
| Location denied on first prompt | Implemented fail-closed UI | Verify on a real iPhone that no Shabbat times are displayed after denial |
| Location restricted by Screen Time / MDM | Error state implemented | Device test required |
| Location temporarily unavailable | Error state implemented | Device test required |
| Network unavailable / Hebcal fails | Clears times and displays an error | Add mocked network tests |
| Wrong time zone or travel across time zones | Uses reverse-geocoded location time zone when available, with device-zone fallback | Must test travel, missing geocoder timezone, and timezone changes on-device |
| User denies AlarmKit authorization | Scheduling returns an error and the sheet stays open | Must verify on iOS 26+ device |
| OS version before iOS 26 | Native scheduler returns unsupported | Must verify that UI communicates this clearly |
| Sound resource missing | Preview fails silently today | Improve visible error state and validate bundled WAV files in CI |
| Alarm disabled/deleted | Store requests system cancel; overlapping toggle/delete operations for the same alarm are guarded | Verify system state and repeat alarm behavior on-device; add race-focused tests |
| App killed / device reboot | Relies on OS AlarmKit scheduling | Must verify on device; no simulator claim |
| Hebrew RTL layout | Basic locale override and Hebrew strings added | Full screen-by-screen RTL and truncation audit required |
| VoiceOver / Dynamic Type | Not fully audited | Accessibility audit required |
| Widgets / Live Activities | Extension scaffold added | Verify install, widget gallery, Lock Screen and Dynamic Island on device |
| Privacy | Location is requested for local time calculations | Review privacy policy, network disclosure and App Store privacy labels before release |

## Build/test evidence

- GitHub Actions now targets macOS 26 / Xcode 26 and runs an iPhone 17 simulator test action.
- Earlier CI runs exposed a compile error in the location model; that access-control error was corrected.
- Do not treat queued or in-progress Actions runs as passing.
- CI run 39080570171 completed successfully for commit 99becb0d, but subsequent AlarmStore and location-time-zone changes require a fresh green run.
- Do not claim AlarmKit is operational until the latest Xcode 26 build passes and a physical iPhone confirms authorization, scheduling, cancellation, custom sound playback, and reboot behavior.

## Release blockers

1. Green latest CI run including app + widget extension + unit tests.
2. Physical-device AlarmKit verification on iOS 26+.
3. Custom sound WAVs present in the built app bundle and heard through the system alarm, not only in preview.
4. Correct candle-lighting / havdalah results against trusted references for multiple locations and dates.
5. Complete English/Hebrew localization and RTL review.
6. App privacy policy and App Store disclosures updated for location/network use.
7. Real app icon, final name, screenshots, TestFlight and review preparation.
