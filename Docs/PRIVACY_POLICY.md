# Privacy policy

The published policy (English and Hebrew) lives in `privacy/index.html` and is what App Store Connect and the in-app link should point to.

Before publishing, replace the two placeholders in that file:

- `{{OPERATOR_NAME}}` – legal name of the person or company publishing the app
- `{{CONTACT_EMAIL}}` – a monitored contact address

To host it for free: make the repository public, then *Settings → Pages → Deploy from branch → main / (root)*. The URL will be `https://<owner>.github.io/<repo>/privacy/`. Put that URL in `AppLinks.privacyPolicy` in `App/ShabbatWakeApp.swift` and in App Store Connect.

Facts the policy states (verify they stay true when features change):
- No account, analytics, advertising, tracking or operator-run server.
- Location is sent with the time zone to Hebcal.com (app and widget); Apple's geocoder is used for the place name.
- Alarms/preferences are stored on-device, plus an App Group container for widgets.
- Hebcal data is CC BY 4.0, credited in the app (Shabbat times screen and Settings → About).
