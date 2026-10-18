# Implementation Status — Shabbat Wake

Updated: 18 October 2026 (TestFlight-readiness pass).

## Current status
**Code: ready to archive and install on a device. Not yet verified on hardware. Not yet ready for App Store submission** (store assets and legal pages outstanding, see below).

CI (GitHub Actions, Xcode 26) builds the app and widget extension and runs the unit tests. That proves it compiles and the date/scheduling logic is right. It does not prove an alarm rings, the custom sounds play, or widgets render on a phone. Those checks are listed in `TESTFLIGHT_RUNBOOK.md`.

## Implemented
- SwiftUI app: Home, Alarms, Shabbat times, Readiness, Settings (English + Hebrew, RTL, light/dark).
- AlarmKit scheduling with authorization handling, cancellation, custom sounds; weekday picker (default Saturday); one-time and weekly alarms; reconciliation with what iOS actually has scheduled.
- Shabbat times via Hebcal for the device location, using the location's time zone; fail-closed when location is denied or the network fails.
- Widgets: Home Screen (small, medium) and Lock Screen (rectangular, inline, circular) showing next alarm and candle lighting/havdalah; the widget refreshes itself from Hebcal. Live Activity / Dynamic Island for alarms within 8 hours.
- Readiness screen driven by live iOS state (alarm permission, scheduled alarms, location, Live Activities, bundled sounds).
- App icon, privacy manifests (app and widget), export-compliance key, version numbers, App Group entitlements.

## Still required before TestFlight is meaningful
- [ ] Device checks 1-16 in `TESTFLIGHT_RUNBOOK.md`.
- [ ] Choose final bundle ID / App Group / name (changing later is costly).

## Still required before App Store submission
- [ ] Public privacy-policy and support URLs; operator/contact details; set `AppLinks` in `ShabbatWakeApp.swift`.
- [ ] Screenshots from a physical device.
- [ ] App Privacy answers in App Store Connect (see runbook section 6).
- [ ] Hebrew/RTL, VoiceOver and Dynamic Type audit on device.
- [ ] Decide the minimum iOS version (see below).

## Known limitations (deliberate for v1)
- iOS 26.1+ is needed to create alarms (AlarmKit). The project still declares iOS 17 as the deployment target, so older iPhones can install the app but see "System alarms require iOS 26.1 or later". Raising `deploymentTarget` to 26.1 in `project.yml` is the honest alternative.
- No manual city selection: Shabbat times need Location permission.
- Candle-lighting uses Hebcal's default (18 minutes before sunset) and havdalah uses 8.5 degrees. There is no per-community setting (for example Jerusalem 40 minutes).
- No edit-alarm screen (delete and re-create).
- Widget text follows the iPhone language, not the in-app language switch.
- Hebrew calendar date screen was removed (it was not reachable from the UI).
