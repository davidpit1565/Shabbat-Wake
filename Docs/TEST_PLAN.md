# QA and Red-Team Test Plan

## Alarm lifecycle
- Create alarm; edit label/time; toggle; delete; confirm persistence after force quit.
- Request alarm authorization; accept, deny, and later re-enable in Settings.
- Verify UI reflects OS-confirmed scheduling state, not only local saved data.
- Test one-time and repeating alarms, multiple alarms, collisions, past times, and weekday selection.
- Test time-zone change, daylight-saving transitions, device restart, low-power mode, Focus, and audio interruptions on physical hardware.
- Confirm cancellation removes the system schedule and no duplicate alarms appear after edits.

## Jewish time and calendar
- Validate dates around Friday/Saturday, Hebrew month/year changes, leap years, holidays and diaspora/Israel differences.
- Compare zmanim for multiple locations and calculation conventions against recognized references.
- Verify manual location works without granting device location.
- Clearly label approximate or unavailable values; never fabricate a result.

## Accessibility and localization
- VoiceOver through onboarding, tab navigation, alarm creation, toggles, validation and errors.
- Dynamic Type through largest accessibility sizes without clipping or hidden controls.
- Reduce Motion enabled; verify ring marker/glow becomes static/subtle and time text never rotates.
- Contrast in Light/Dark/System; no status indicated by color alone.
- English LTR and Hebrew RTL on every screen, alert, widget, notification, Live Activity and purchase sheet.
- Mixed Hebrew/Latin text, time numerals, dates and VoiceOver pronunciation.

## Extensions and lifecycle
- Home Screen widget sizes, Lock Screen accessory styles, timeline refresh, stale data and no-data state.
- Live Activity start/update/end; lock-screen display; Dynamic Island expanded/compact/minimal on supported hardware.
- Test app-group data synchronization and privacy boundaries.
- Unsupported OS/device gracefully hides unavailable controls.

## Privacy, payments, release
- Audit network calls, SDKs, logs, permissions, local storage and privacy manifests.
- Verify restore purchases, cancellation messaging and entitlement updates if Pro is enabled.
- Verify policy/support URLs and App Store privacy answers match binary behavior.
- Run clean install, upgrade install, offline, denied permission, and crash/relaunch tests.

## Evidence required before release
Attach CI logs, unit/UI test results, device/OS matrix, audio rights manifest, final icon and screenshots, and the completed red-team findings. Any unresolved P0/P1 issue blocks submission.
