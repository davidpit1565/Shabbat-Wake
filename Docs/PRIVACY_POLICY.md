# Shabbat Wake Privacy Policy

**Draft for review — do not publish until the operator details and actual app behavior have been verified.**  
**Last updated:** 18 October 2026  
**App:** Shabbat Wake (working title)  
**Operator:** [LEGAL NAME / BUSINESS NAME TO BE COMPLETED]  
**Contact:** [PRIVACY CONTACT EMAIL TO BE COMPLETED]  
**Public URL:** [PUBLISH THIS POLICY AT A STABLE HTTPS URL]

## 1. Scope

This policy describes the intended privacy approach for Shabbat Wake, an iOS app for alarms, Shabbat and Jewish-calendar information, zmanim, widgets, and Live Activities. The released policy must be updated to match the exact production build, SDKs, and services. This draft is not a claim that all described controls are already implemented.

## 2. Data processed

The intended design is privacy-first and on-device by default.

- **Alarm settings:** labels, selected times, repeat rules, and sound choices needed to create and manage alarms.
- **Location:** if the user grants permission, the device's coordinates are used to calculate local candle-lighting and havdalah times. The coordinates and the location's time zone are sent to the third-party service Hebcal.com (https://www.hebcal.com) to obtain those times, and the widget repeats that request in the background. The app also uses Apple's reverse-geocoding to show a place name. Coordinates are not sent to any server operated by the app's operator. Manual location selection is not yet available.
- **Calendar preferences:** selected Hebrew-calendar settings, location, and calculation conventions.
- **App preferences:** language, appearance, accessibility-related choices, and other local settings.
- **Purchases:** if optional Pro purchases are introduced, Apple may process purchase and subscription information. The app should use StoreKit and must not collect or store payment-card details.
- **Diagnostics/analytics:** no analytics or advertising SDK is planned for the initial release. If this changes, identify the SDK, exact data collected, purposes, retention, sharing, and consent controls here and in App Store Connect before release.

## 3. How data is used

Data is used only to provide app functionality: managing alarms, displaying selected settings, calculating calendar information, presenting widgets/Live Activities, troubleshooting when explicitly enabled, and processing optional purchases. Data must not be sold or used for targeted advertising.

## 4. Storage and sharing

The intended initial architecture stores alarm definitions and preferences locally on the device. Widget and Live Activity content may be shared with the app's extension through an app-group container only if required. The final implementation must document any iCloud synchronization, remote service, third-party zmanim provider, analytics, crash reporting, or other external transfer before release. Do not claim “no data collected” in App Store Connect until the production binary and all SDKs have been audited.

## 5. Location and permissions

Location access is optional. The app should request it only when the user chooses location-based zmanim, explain the purpose in context, and offer manual location entry. Users can change permission in iOS Settings. Denying location must not prevent unrelated alarm features from working.

## 6. Retention and deletion

Locally stored alarm settings and preferences remain on the device until the user deletes them or removes the app, subject to iOS behavior and backups. If any server-side account or data storage is added, this section must be rewritten to specify retention periods, deletion methods, backup retention, and how users can request deletion.

## 7. Children

The initial product is not intended to collect personal information from children. The final age rating, audience, and any child-directed features must be reviewed before submission. Do not add advertising or behavioral analytics targeted at children.

## 8. Security

The app should use platform security facilities, request only necessary permissions, avoid collecting credentials, and minimize data access. No system can guarantee absolute security.

## 9. Your choices and rights

Users can deny or revoke system permissions in iOS Settings and can delete local app data by removing the app. If personal data is processed by an operator or service provider, provide an accessible contact route for privacy requests and applicable rights under relevant law, including the GDPR where applicable.

## 10. International transfers and third parties

The initial design does not require an operator account or advertising service. If any third-party service is added, disclose its identity, role, data categories, transfer basis, and applicable safeguards here before release.

## 11. Changes

This policy will be updated when the app's functionality or data practices change. The current version must be published at a stable HTTPS URL and linked both inside the app and in App Store Connect.

## 12. Contact

For privacy questions: **[PRIVACY CONTACT EMAIL TO BE COMPLETED BEFORE RELEASE]**  
Data controller/operator: **[LEGAL NAME AND POSTAL ADDRESS TO BE COMPLETED AFTER LEGAL REVIEW]**

---

## Release blockers for this draft

- Replace every bracketed placeholder with verified operator/contact details.
- Have the actual data flows, permissions, extensions, dependencies, and production build audited.
- Location lookup: confirmed. Coordinates and time zone are sent to Hebcal.com (and Apple's geocoder). Review Hebcal's own terms/privacy practices and state them here.
- Confirm purchase/StoreKit implementation and whether any diagnostics are included.
- Publish the final reviewed policy at a stable HTTPS URL.
- Ensure the in-app Privacy Policy link and App Store Connect URL point to the same live policy.
- Complete App Store Connect privacy disclosures based on the submitted binary, not this draft.
