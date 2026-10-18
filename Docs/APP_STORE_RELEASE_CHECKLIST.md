# App Store Release Checklist — Shabbat Wake

This is a living release gate, not a statement that the app is ready for review. Verify each item against the exact submitted build and current Apple requirements.

## Product identity and listing

- [ ] Confirm final app name and subtitle; “Shabbat Wake” is a working name.
- [ ] Confirm bundle ID, SKU, primary category, age rating, copyright owner, seller name, and supported territories.
- [ ] Create the final app icon as a 1024×1024 PNG with no transparency where Apple requires an opaque App Store icon; add the full Xcode asset catalog variants required by the selected deployment toolchain.
- [ ] Create screenshots for every required display size/device class and localization; screenshots must represent the actual shipping app.
- [ ] Write accurate description, keywords, promotional text, support URL, and marketing URL if used.
- [ ] Provide a public HTTPS Privacy Policy URL in App Store Connect and a reachable in-app privacy link.
- [ ] Provide App Review contact details and review notes, including how to test alarm creation and location-independent flows.
- [ ] If the app has a paid tier, complete subscription names, durations, prices, localized display names, review screenshots, and subscription terms.

## Native implementation and reliability

- [ ] Build with the current supported Xcode toolchain and SDK; set a deliberate minimum iOS deployment target.
- [ ] Confirm AlarmKit API availability and permission flow on each supported OS version; provide a tested fallback or clearly restrict support where necessary.
- [ ] Schedule, edit, cancel, repeat, and reschedule alarms; handle authorization denial, device reboot, time-zone change, daylight-saving transitions, and calendar boundary cases.
- [ ] Confirm actual system scheduling state before displaying “scheduled” or “ready.”
- [ ] Verify notification/alarm permission messaging and Settings recovery paths.
- [ ] Test alarm sound selection, bundled audio licensing, volume behavior, interruptions, and fallback sound.
- [ ] Verify Shabbat/holiday dates and zmanim against documented calculation conventions and reputable references for multiple locations.
- [ ] Avoid presenting illustrative sample times as real calculated zmanim.
- [ ] Test widgets, Lock Screen widgets, Live Activities, and Dynamic Island on supported hardware and OS versions; verify graceful behavior where Dynamic Island is unavailable.
- [ ] Confirm widget timelines and Live Activity staleness/failure handling.
- [ ] Verify app-group entitlements and data-sharing boundaries if extensions share data.

## Localization, accessibility, and design

- [ ] Audit every user-facing string in English and Hebrew, including permission rationale, errors, empty states, purchases, notifications, widgets, and review/legal text.
- [ ] Test true RTL layout in Hebrew, including navigation, icons where directionality matters, dates, numerals, forms, and mixed Hebrew/Latin strings.
- [ ] Check Dynamic Type, VoiceOver labels/order, contrast, Reduce Motion, button hit targets, and color-independent status communication.
- [ ] Keep clock digits and clock face stationary; animate only approved perimeter/glow elements and respect Reduce Motion.
- [ ] Test Light, Dark, and System appearance on real devices.

## Privacy, security, and legal

- [ ] Replace all placeholders in the privacy policy and publish it at a stable HTTPS URL.
- [ ] Audit all SDKs, packages, API calls, logs, permissions, data stores, and app extensions.
- [ ] Complete App Privacy nutrition-label answers accurately for the final binary and all integrated SDKs.
- [ ] Include required privacy manifests and required-reason API declarations if applicable to the selected SDKs and APIs.
- [ ] Confirm any tracking is absent or fully compliant with Apple's consent and disclosure requirements.
- [ ] Add terms/subscription disclosures and restore-purchases flow if monetization is enabled.
- [ ] Review EU consumer, privacy, subscription, and trader/contact obligations for the chosen distribution model.
- [ ] Confirm ownership/license for every sound, font, image, icon, and other included asset.
- [ ] Provide a support contact and a process for handling privacy requests.

## QA and release evidence

- [ ] Unit tests for alarm rules, recurrence, calendar/time-zone logic, localization selection, and readiness-state derivation.
- [ ] UI tests for onboarding, permission denied/granted, alarm create/edit/delete, location setup, Hebrew RTL, and purchase restore if present.
- [ ] Physical-device tests on at least one iPhone that supports the target features; test the oldest supported OS/device too.
- [ ] Test airplane mode/offline behavior, force-quit, reboot, time-zone change, DST boundary, and denied permissions.
- [ ] Run a red-team pass for false readiness claims, missed/duplicate alarms, incorrect zmanim, data leakage, accessibility blockers, and purchase edge cases.
- [ ] Verify CI build and test results; archive logs/artifacts.
- [ ] Validate archive/signing, provisioning, entitlements, version/build numbers, and App Store Connect upload.
- [ ] Test the TestFlight build from a clean install before submission.
- [ ] Resolve all App Store Connect validation warnings and review metadata.
- [ ] Confirm reviewer instructions, screenshots, policy URLs, and purchase configuration are complete.

## Current known blockers

See `IMPLEMENTATION_STATUS.md` for the current list and `TESTFLIGHT_RUNBOOK.md` for the device checks. In short:

- Nothing in this checklist has been verified on a physical iPhone yet.
- Privacy policy contains operator/contact placeholders and is not published; support URL does not exist.
- Screenshots, final name check, and App Store Connect record are not done.
