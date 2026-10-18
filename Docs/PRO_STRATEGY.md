# Pro plan: how to build it and how to get people to pay

Research date: 18 Oct 2026. Findings are marked with their source; recommendations are mine.

## What the market looks like

Other Shabbat apps on the App Store (listing pages checked, prices not stated on them, so check the live pages before you set yours):

| App | Model | Notes |
|---|---|---|
| [Shabbat Alarm Clock & Times](https://apps.apple.com/app/id6741048381) | Free + in-app purchases | Times, reminders before candle lighting, parasha reader, widgets, alarms, Apple Watch, Siri, no ads |
| [Shabbat Times](https://apps.apple.com/app/id1445098621) | Free + upgrade | Holiday times, "time travel", multiple reminders and custom location labels are behind the upgrade |
| [Chabat Clock](https://apps.apple.com/ba/app/chabat-clock/id6738277689) | Free | Alarm for Shabbat; short tones under 30 seconds that do not loop; set before Shabbat |
| [Ultimate Zmanim](https://apps.apple.com/tw/app/id452921604) | Free + in-app purchases | General zmanim, widget, watch |

Takeaway: the niche is "free to use, pay for extras". Selling the core (an alarm and the times) would be out of step and would hurt reviews. Charge for convenience and personalisation.

## What the subscription data says

From [RevenueCat's State of Subscription Apps](https://revenuecat.com/state-of-subscription-apps-2025) and write-ups ([SaaStr](https://www.saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps/), [RevenueCat on trial length](https://www.revenuecat.com/blog/growth/free-trial-length)):
- Hard paywalls convert far better than freemium: median trial-to-paid about 10.7% against 2.1% for freemium, but they only work when the app is something people already decided to buy. For a utility with free competitors, a hard paywall will mostly cost you installs and reviews.
- Longer trials convert better: about 42.5% for trials of 17+ days against 25.5% for four days or less.
- Many apps now mix subscription with a lifetime purchase (35% in the report), most often in gaming and lifestyle.
- Churn is the catch: roughly 72% of annual subscriptions cancel within a year. A one-time price suits a small utility better than a subscription people forget about.

## Recommendation

**Model: free app, one Pro unlock, with a trial.** Offer:
1. **Pro Lifetime** (one-time, non-consumable). Best fit for a utility and for an audience that dislikes recurring charges.
2. **Pro Yearly** (auto-renewing) with a 14-day free trial, for people who prefer paying less up front.
Show yearly first and lifetime as the alternative. Decide the prices after you open the live pages of the apps above; do not guess.

**Keep free (this is what earns reviews and trust):** creating and ringing alarms, Saturday repeat, candle lighting and Shabbat end for your location, the next 4 Shabbatot, the home widget, Hebrew and English.

**Put in Pro (convenience and personalisation):**
- Alternate app icons (your idea; already built, currently unlocked)
- Times for all upcoming weeks, Yom Tov and holiday times
- "Every Shabbat for X weeks" and fixed-date alarms
- Reminder before candle lighting with a chosen offset; several reminders
- Custom candle-lighting minutes and Shabbat end convention (for example 50 or 72 minutes)
- Several locations (travel, family) with labels
- Extra alarm sounds, Lock Screen widgets, Apple Watch app and Siri/Shortcuts when they exist

**When to show the paywall:** at the moment of intent, not at launch. Tapping a locked icon, adding a second alarm profile, choosing "for X weeks". One screen, benefits first, price second, "Restore purchases" visible, and a close button that always works.

**How to make people pay:**
- Show the value before the ask: let them try a Pro icon for one tap, show the full list of future Shabbatot greyed out with a lock.
- Trial starts only when they tap; remind them before it ends (Apple requires clear terms).
- Mention Family Sharing (turn it on for the lifetime product).
- Ask for a review after a good moment, such as the first alarm that rang successfully, never at launch. Reviews are the biggest driver for this kind of app.
- Price in local currency using App Store price tiers; offer an Israel price.

## How to build it (when you are ready)

1. App Store Connect, the app, **Monetization**: create the In-App Purchases (one non-consumable, one auto-renewing subscription group) with the product IDs `com.shabbatwake.ios.pro.lifetime` and `com.shabbatwake.ios.pro.yearly`, localised names and a review screenshot. Accept the Paid Apps agreement and add banking and tax details.
2. In the app: StoreKit 2 (`Product.products`, `purchase()`, `Transaction.currentEntitlements`, `Transaction.updates`), a `ProStore` that exposes `isPro`, a paywall screen, and a Restore button. Replace the stub in `ProAccess` (`App/AppIconPicker.swift`) with `ProStore.isPro`.
3. A local `.storekit` configuration file so purchases can be tested in the simulator and on a device without charging.
4. Optional: RevenueCat to handle receipts, trials and analytics; it is free below a revenue threshold. It adds an SDK, so update the privacy manifest and the App Privacy answers first.
5. App Review: subscription terms and links to the privacy policy and terms must be on the paywall; submit the IAPs together with the app version.

Not decided yet (needs your call): prices, whether to offer the yearly plan at all, and the exact Pro feature list above.
