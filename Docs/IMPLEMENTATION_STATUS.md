# Implementation Status — Shabbat Wake

Updated: 18 October 2026. Status reflects files present in the repository, not assumptions about untested behavior.

## Confirmed in repository
- [x] Product/UX direction documented.
- [x] Initial SwiftUI app entry and visual home screen source exists.
- [x] Starter ring motion keeps the time text stationary; the perimeter marker/glow is the moving element.
- [x] XcodeGen project specification exists.
- [x] GitHub Actions workflow exists to generate an Xcode project and attempt a simulator build.
- [x] Privacy policy draft exists, with explicit release placeholders.
- [x] App Store metadata draft exists.
- [x] Release checklist exists.
- [x] Local alarm data model/store source added; persistence is local UserDefaults only.

## Not yet verified / not release-ready
- [ ] Successful CI build. Check the Actions run for a completed green result before claiming build success.
- [ ] Valid app icon image and all required app icon assets.
- [ ] All main screens implemented and connected to shared real data.
- [ ] AlarmKit adapter, authorization, scheduling, cancellation, repeat rules, and error handling.
- [ ] AlarmStore connected to actual system alarm scheduling. Local persistence alone does not ring an alarm.
- [ ] Fully localized English/Hebrew strings and true RTL across every screen and extension.
- [ ] Jewish calendar and zmanim calculations validated against documented conventions and trusted references.
- [ ] Sound files included, tested, and documented as owned/licensed for distribution.
- [ ] Widget extension, Lock Screen widget, Live Activity/Dynamic Island extension and app-group data exchange.
- [ ] VoiceOver audit, Dynamic Type, contrast, Reduce Motion and accessibility UI tests.
- [ ] Unit/UI tests and red-team report with actual execution evidence.
- [ ] Final privacy-policy operator/contact details, hosted public URL, support URL, and verified privacy disclosures.
- [ ] Final App Store name, bundle ID, seller details, screenshots, review notes and metadata.
- [ ] Archive signing, TestFlight install, physical iPhone testing and App Store Connect validation.

## Critical release rule
Never present the app as ready to submit until all release blockers are resolved and the exact release candidate has built, passed tests, been installed on a physical iPhone, and its alarm/widget behavior has been verified. A visual prototype, persisted alarm definition, or successful simulator build alone is not proof of a working system alarm.
