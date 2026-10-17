# Shabbat Wake — Product & UX Specification

## Product promise

Help a user prepare a Shabbat or holiday wake-up alarm with a clear understanding of what is scheduled, what the device has authorized, and what still needs attention. The visual experience is futuristic and polished, but clarity and trust outrank visual effects.

## Visual system

### Palette
- Deep navy foundation: `#071020`
- Elevated navy surface: `#102440`
- Primary electric blue: `#2874FF`
- Cyan highlight: `#59E6FF`
- Silver: `#C9D8EC`
- Light canvas: `#F4F7FC`
- Main light text: `#10213D`
- Positive state: use sparingly and only for verified state
- Error state: clear accessible red with explanatory copy

### Motion rules
- The clock digits, clock face, and displayed time never rotate.
- A decorative outer ring/progress arc may animate slowly; orbit marker and halo may pulse subtly.
- Never use continuous motion that competes with time legibility.
- Support Reduce Motion; when enabled, replace continuous animation with static rings and short crossfades.
- Every readiness animation must be driven by actual state transitions, not hard-coded success.
- Keep navigation and controls recognizably native to iOS; apply glass/material effects selectively rather than to every surface.

### Typography and layout
- Prefer system SF typography, Dynamic Type, sufficient contrast, generous touch targets, and VoiceOver labels.
- English left-to-right and Hebrew right-to-left layouts must both be complete, not just translated labels.
- Test mixed Hebrew/English, time values, dates, numerals, and icon direction in RTL.

## Screen-by-screen inventory

### 1. Onboarding
Explain the app's purpose and limits. Ask for location only when needed for zmanim. Explain alarm authorization before requesting it. Never imply alarms are scheduled before the OS confirms scheduling.

### 2. Home
- Header with greeting/date and settings access.
- Main countdown ring with stationary digits and a calm animated perimeter.
- Next scheduled alarm card with label, local time, date, and event context.
- Shabbat start/end summary when a trusted calculation is available.
- Readiness summary that distinguishes Ready, Needs attention, and Not checked.
- Bottom navigation for Home, Calendar, Readiness, and Settings.

### 3. Alarms
List upcoming and recurring alarms. Each row shows label, next occurrence, repeat rule, enabled state, and scheduling state. Provide add/edit, duplicate, disable, delete with confirmation, and test sound.

### 4. Create/Edit Alarm
Fields: title, time or supported event-based rule, repeat days, holiday/Shabbat rule where applicable, sound, auto-stop duration if supported, enabled toggle. Validate conflicts and authorization. Explain any rule that cannot be scheduled natively.

### 5. Calendar
Hebrew and civil date, Shabbat and holiday context, upcoming events, and selected location. Dates must come from a tested calendar implementation, not sample hard-coded values.

### 6. Zmanim and location
Location selection and permission status, calculation method and relevant community preferences. Clearly label the calculation convention. Provide a way to correct location manually. Do not claim a time is authoritative without a defined calculation/source.

### 7. Readiness
Check actual current permission/authorization, each intended alarm's OS scheduling result, selected sound availability, date/time validity, and relevant location/calculation configuration. Every item includes status and an action to fix it. A single green all-clear is allowed only if all required checks pass.

### 8. Sounds
List bundled/licensed sounds with names and durations; preview/stop preview; choose default or per-alarm sound where supported. Handle missing or unsupported assets gracefully. Avoid copyrighted melodies unless redistribution rights are confirmed.

### 9. Settings
Appearance (System/Light/Dark), language (System/English/עברית), location, zmanim convention, default sound, auto-stop preferences, accessibility/reduced motion, notifications/alarm authorization, privacy, support, and subscription management.

### 10. Pro paywall
Explain exact benefits and terms, show monthly/yearly/lifetime only if actually configured in App Store Connect, restore purchases, terms, privacy, and cancellation information. Never block core basic Shabbat alarm scheduling behind a paywall.

### 11. Widgets
Home Screen small/medium/large and Lock Screen accessory variants where supported. Show concise next-alarm or Shabbat timing plus a truthful state. Widget content must tolerate stale timelines and unavailable location. Deep-link to the relevant app screen.

### 12. Live Activity / Dynamic Island
Use only when an active, meaningful countdown/state exists. Show concise event label and time remaining. Respect system lifecycle, stale content and user privacy. Live Activity is not an alarm mechanism and must not claim that it guarantees ringing.

## Localization

Create English and Hebrew localization resources from the start. Use semantic layout direction and native localization APIs. Test pluralization, VoiceOver, Dynamic Type, long strings, mirrored navigation, date/time formatting, and Hebrew mixed with Latin text.

## Audio asset policy

Bundled audio is supported technically. Only include original recordings or assets with a license explicitly permitting redistribution in a commercial app. Track asset name, source, license, attribution requirements, and modification rights. Until sound files and rights are supplied, implement the picker/preview interface with clearly identified placeholder/sample tones only.

## Trust and reliability

- Distinguish local app intent from OS-confirmed scheduled alarms.
- Surface AlarmKit authorization and scheduling errors.
- Do not promise alarms will ring under every device or OS condition.
- Test lock screen, Focus/silent configurations where applicable, reboot, time-zone changes, daylight-saving changes, permission revocation, and app upgrades on physical devices.
- Test recurrence and Shabbat/holiday transitions around midnight and date boundaries.

## Monetization hypothesis

Free: core alarm scheduling, basic sound selection, readiness, and essential widgets.
Pro candidates: extended licensed sound packs, advanced templates, multiple personalization presets, and richer calendar/zmanim tools. Pricing and lifetime purchase are hypotheses pending competitor and cost review. No paywall should imply paid access makes the alarm more reliable.

## Release gates

1. Build succeeds for documented deployment target.
2. Unit tests and localization checks pass.
3. Widget and Live Activity extensions build and render on supported OS versions.
4. Alarm authorization/scheduling behavior is verified on a physical supported iPhone.
5. Audio licenses are documented.
6. Privacy policy and support pages are live.
7. Store listing, subscription products, and review notes are complete.
8. Red-team review checks misleading reliability claims, date/time errors, RTL defects, accessibility, permission failures, and subscription disclosures.
