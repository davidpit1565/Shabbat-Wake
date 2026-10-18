# Implementation Status — Shabbat Wake

Updated: 18 October 2026. Status reflects files present in the repository, not assumptions about untested behavior.

## Confirmed in repository
- [x] Product/UX direction and release checklist documented.
- [x] SwiftUI app entry and main screen source exists.
- [x] XcodeGen project specification and GitHub Actions workflow exist.
- [x] Latest recorded CI run (run 39080570171, commit 99becb0d) completed successfully; later code changes require a fresh green run.
- [x] AlarmKit scheduling adapter, authorization handling, cancellation, sound selection, and error reporting are present in source.
- [x] AlarmStore persists alarm definitions locally and now prevents overlapping toggle/delete operations for the same alarm.
- [x] Location permission is required before Shabbat times are requested; denied/error states clear displayed times.
- [x] Shabbat time requests use reverse-geocoded location time zone when available, falling back to the device time zone.
- [x] Widget extension source, Live Activity source, and original generated WAV sound assets are present in the repository/workflow.
- [x] Privacy policy draft, App Store metadata draft, and release checklist exist.

## Not yet verified / not release-ready
- [ ] A fresh CI run after the latest AlarmStore and location-time-zone changes must pass.
- [ ] AlarmKit behavior on a physical iPhone running a supported iOS version: authorization, schedule, repeat, cancel, custom sound playback, app termination and reboot.
- [ ] Confirm bundled WAV files are actually accepted and played by the native AlarmKit alarm on device.
- [ ] Validate candle-lighting and havdalah times against trusted references across multiple locations, dates, and time zones.
- [ ] Test location changes, time-zone changes, stale network responses, offline behavior, and denied/restricted permission paths.
- [ ] Widget gallery, Lock Screen widgets, Live Activities and Dynamic Island behavior on supported physical devices.
- [ ] Complete Hebrew/English localization, RTL, VoiceOver, Dynamic Type, contrast and Reduce Motion audit.
- [ ] Add broader unit/UI and mocked-network tests; current unit tests are a small baseline, not comprehensive Red Team coverage.
- [ ] Final public privacy-policy/support URLs, operator/contact details, and verified App Store privacy disclosures.
- [ ] Final icon assets, archive signing, TestFlight install, physical-device verification and App Store Connect validation.

## Critical release rule
Never present the app as ready to submit until all release blockers are resolved and the exact release candidate has built, passed tests, been installed on a physical iPhone, and its alarm/widget behavior has been verified. A visual prototype, persisted alarm definition, or successful simulator build alone is not proof of a working system alarm.
