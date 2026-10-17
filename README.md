# Shabbat Wake

A premium, futuristic iPhone-first Shabbat alarm app. Working product name; branding and store availability remain to be validated before release.

## Product direction

- Futuristic premium visual language inspired by a restrained JARVIS-style interface: deep navy, white, silver, focused cyan/blue accents, fine luminous rings, restrained glass surfaces, and purposeful motion.
- The clock digits remain completely stationary and readable. Only the outer ring, progress arc, orbit marker, and subtle glow may animate. No spinning clock face or rotating time text.
- Native-feeling iOS controls and navigation, balanced with a distinctive sci-fi visual identity. Motion respects Reduce Motion and accessibility settings.
- Full English and Hebrew localization, including right-to-left layout in Hebrew.
- Both light and dark appearance.
- Home Screen widgets, Lock Screen widgets, Live Activities, and Dynamic Island on supported devices and OS versions.
- Alarm scheduling must use supported native alarm APIs and show truthful readiness/permission state; no simulated success states in production.

## Audio

Bundled soundtracks are possible. Each audio file must be legally owned, created, or licensed for redistribution. Add approved audio assets to the app bundle, provide a sound picker and preview, and test playback and alarm behavior on supported devices. No sound files have been supplied yet.

## Architecture direction

- SwiftUI iPhone app
- AlarmKit for supported native alarm scheduling (availability and deployment target to be verified against current Apple documentation)
- WidgetKit widgets
- ActivityKit Live Activities / Dynamic Island
- Shared app data via App Groups where required
- Localized strings in English and Hebrew
- Unit tests for scheduling rules, localization-sensitive presentation, readiness states, and date calculations

## Delivery rule

A feature is not marked complete until implementation and relevant tests/build/device checks support the claim. Visual prototypes are not alarm functionality. Validate date calculations against a trusted source and clearly surface unavailable permissions or scheduling errors.

## Planned build sequence

1. Product and UX specification
2. Design system and screen inventory
3. Native app shell and localization
4. Alarm scheduling and readiness
5. Jewish calendar / zmanim and location settings
6. Sound library and preview
7. Widgets and Live Activities
8. Accessibility, test coverage, App Store materials, and red-team review

## Status

Repository initialized; production implementation and device validation are not yet complete.
