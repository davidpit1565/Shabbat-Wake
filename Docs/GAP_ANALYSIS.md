# What is missing to be the best Shabbat alarm app

Based on the code, the first device test, and the competing listings linked in `PRO_STRATEGY.md`.

## Highest value, do next
1. **A true "Shabbat mode" alarm.** Observant users set the alarm before Shabbat and cannot touch the phone on Shabbat. The alarm must ring for a fixed time and then stop on its own, never repeat, never offer snooze. Competitors advertise short, non-looping tones under 30 seconds. We confirmed there is no snooze, but we do not yet know how long AlarmKit rings a 3-second tone (does it loop until Stop?). This needs one test on a device: set an alarm, do not touch the phone, and time it. Then build the "ring for 10/20/30/50 seconds" setting around the real behavior.
2. **Reminder before candle lighting** ("Shabbat in 40 minutes"), with an offset setting. Every competitor has it.
3. **Alarm for a specific Shabbat or for the next X weeks** (fixed dates), plus edit an existing alarm. Today alarms can only be created, switched on/off or deleted.
4. **Yom Tov and holidays** (candle lighting and end times, plus Chag alarms).
5. **Manual city picker** so times work without location permission, while travelling, or for family elsewhere.

## Important
6. **Offline times:** cache a year of times after the first successful load so the app and widget work without a connection.
7. **Customs:** setting for candle-lighting minutes (18/20/30/40) and the Shabbat end convention (8.5 degrees, 42/50/72 minutes). Today Jerusalem 40 and Haifa 30 are automatic, everything else uses 18 and 8.5 degrees.
8. **Apple Watch app and complications**, **Siri/Shortcuts**.
9. **Parasha page** (short summary or link), since competitors have a reader.
10. **More languages** for Jewish communities (French, Russian, Spanish).

## Quality and release
11. Accessibility audit: VoiceOver on every screen, Dynamic Type at the largest sizes, contrast.
12. Crash and health data without third-party analytics (Xcode Organizer and MetricKit are enough).
13. App Store page: screenshots in both languages, keywords (Shabbat, candle lighting, alarm, havdalah, zmanim), preview video, support page, a short site.
14. Automated UI tests for the add-alarm flow and a language switch test.

## Known limits today
- Alarms need iOS 26.1 or later.
- Language switch rebuilds the screens; system pickers and the email composer follow the iPhone language.
- Widgets follow the iPhone language, not the in-app setting.
