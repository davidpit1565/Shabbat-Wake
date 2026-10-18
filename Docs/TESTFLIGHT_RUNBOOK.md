# TestFlight runbook

Everything here needs a Mac with Xcode 26.x, an Apple Developer account, and an iPhone on iOS 26.1 or later.
CI proves the project compiles and the unit tests pass. It cannot prove an alarm rings, so the device checks below are the real gate.

## 1. One-time setup on the Mac

```bash
brew install xcodegen
git clone https://github.com/davidpit1565/Shabbat-Wake && cd Shabbat-Wake
git checkout <branch or main>
./Scripts/bootstrap.sh        # generates the alarm sounds, then ShabbatWake.xcodeproj
open ShabbatWake.xcodeproj
```

In Xcode, select the project, then for **both** targets (`ShabbatWake` and `ShabbatWakeWidget`) open *Signing & Capabilities* and pick your Team.
Don't re-run `xcodegen` afterwards, or you will have to pick the Team again.

Decisions to make before the first upload (changing them later is painful):

| Item | Current value | Notes |
|---|---|---|
| Bundle ID | `com.shabbatwake.ios` (widget `.widget`) | Must be unique on App Store Connect. If you change it, change it in `project.yml` only. |
| App Group | `group.com.shabbatwake.ios` | Must match in `Config/*.entitlements` and `App/Shared/SharedStore.swift`. Xcode registers it for you when the Team is set. |
| Display name | Shabbat Wake | Working name; check availability in App Store Connect before committing. |

## 2. First run on your iPhone (before TestFlight)

Plug the phone in, select it as the run destination, press Run. Do the device checks in section 4 here. It is much faster than TestFlight round-trips.

## 3. Archive and upload

1. In App Store Connect: *Apps → + → New App*, using the bundle ID above.
2. In Xcode choose *Any iOS Device (arm64)*, then *Product → Archive*.
3. In the Organizer: *Distribute App → App Store Connect → Upload*.
4. Wait for the processing email, then add yourself under *TestFlight → Internal Testing*.
5. The first upload for a new app asks for test information. "What to test" can be: *Create a Saturday alarm and check it rings.*

If the upload is rejected, send me the full error text and I can fix it.

## 4. Device checks (the part CI cannot do)

Run these in order and note pass/fail. Each is a thing that has only been written, not seen working.

**Alarms (AlarmKit)**
1. Create an alarm 2 minutes ahead, one-time. Lock the phone. It must ring with the chosen sound. Stop it.
2. Create one for ~5 minutes ahead and force-quit the app. It must still ring.
3. Repeat with each of the three sounds. Does the custom sound play, or does iOS fall back to the default tone?
4. Create a Saturday-only weekly alarm. Open Readiness: every row should be green. Open iOS *Clock*: confirm the alarm is NOT set for every day.
5. Switch an alarm off, then on. Delete one. Confirm it no longer rings.
6. Reboot the phone with an alarm pending. It must still ring.
7. Deny alarm permission (Settings → Shabbat Wake), then try to save. A clear error should show, and Readiness should turn orange.

**Shabbat times**
8. Allow location. Compare candle lighting and havdalah with hebcal.com or your synagogue's printed times for your city.
9. Deny location. No times may be shown, Readiness shows orange.
10. Airplane mode: an error appears, no stale times.

**Widgets**
11. Add small, medium, and the three Lock Screen widgets. They should show the next alarm and Shabbat times.
12. Change an alarm in the app; the widget updates within a few seconds.
13. Delete the app's location permission; the widget shows "Open Shabbat Wake to set your location".

**Look and feel**
14. Switch the app language to Hebrew: layout flips, nothing truncated, no English left on screen (including widgets and the location prompt).
15. Dark / Light, largest Dynamic Type, VoiceOver on the alarm list and the Add Alarm sheet.
16. Reduce Motion on: the ring stops animating, the clock digits never move.

## 5. What to send back

For each failure: the number above, what you expected, what happened, iPhone model and iOS version. A screenshot or a Console log line from the device helps. I can then diagnose and push the fix to this branch.

## 6. Before App Store submission (not needed for TestFlight)

- Publish a privacy policy at a public HTTPS URL, then put that URL in `AppLinks.privacyPolicy` (`App/ShabbatWakeApp.swift`) and in App Store Connect. Replace the placeholders in `Docs/PRIVACY_POLICY.md` first.
- Support URL (a page or a mailto-style contact page).
- Screenshots from a real device (6.9" and 6.5" iPhone sets).
- App Privacy answers: *Location → Precise Location*, used for *App Functionality*, **not** linked to the user, **not** used for tracking. Location is sent to Hebcal.com to compute times.
- Age rating questionnaire (all "None" expected), category *Lifestyle*, export compliance already answered "No" in the build.
- Review notes: Reviewers will need iOS 26.1+ and must tap *Allow* for alarms. Mention the app works without location except for Shabbat times.
