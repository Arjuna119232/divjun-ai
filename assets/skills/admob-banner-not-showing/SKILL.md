---
name: admob-banner-not-showing
description: Diagnose and fix an AdMob banner that shows "loading forever" or never appears in a Capacitor Android app. Covers the two root causes (missing app-ads.txt with the wrong asset path, and marking the banner as shown before bannerAdLoaded fires), plus watchdog, honest failure state, and CI guards. Use when the user says "iklan memuat terus", "iklan tidak muncul", "banner AdMob kosong", or asks where to put app-ads.txt.
---

# AdMob banner: "memuat terus" / tidak muncul

Two independent causes produce the exact same symptom. **Check both.**

## Cause 1 — `app-ads.txt` missing (or in the wrong place)

Without app-ads.txt AdMob serves **nothing**: `showBanner()` is called, no
creative ever arrives, the banner sits empty. The SDK does not log an error.

Content is one line, the publisher ID must match the AdMob app ID:

```
google.com, pub-XXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```

(`f08c47fec0942fa0` is Google's authorized seller ID — it is the same for every
publisher. Take the publisher ID from AdMob console → Settings, or derive it
from `appId` by stripping the `ca-app-pub-` prefix.)

### THE TRAP: the asset path

`npx cap copy` copies `www/` → `android/app/src/main/assets/public/`.
So putting the file in `www/app-ads.txt` lands it at
`assets/public/app-ads.txt`, and **the Google Mobile Ads SDK does not read
that.** It reads `assets/app-ads.txt`.

So a Capacitor app needs BOTH:
1. `native/app-ads.txt` — the source of truth in the repo.
2. A build step that copies it to `android/app/src/main/assets/app-ads.txt`,
   run **after** `cap copy` (which is the step that would otherwise clobber
   things). This is the single most commonly missed piece.

### Full verification needs a domain

The bundled asset makes the SDK check inventory. Full AdMob verification is a
separate thing: AdMob crawls `https://<your-domain>/app-ads.txt` using the
developer website listed on the **Google Play** listing. Status flips to
Approved after Google crawls it — **allow at least 24 hours**. Until then the
app is not verified and may still not fill. If the user has no domain, Google
officially suggests **Firebase Hosting** as the host.

## Cause 2 — the code marks the banner "shown" too early

`showBanner()` resolving means **"View created and request sent"**. It does NOT
mean a creative arrived. The creative comes later via the
**`bannerAdLoaded`** event.

If you set your "displayed" flag and collapse/hide the placeholder right after
`await showBanner()`, then:
- the placeholder collapses to the banner's height,
- its "loading" text is hidden by the collapsed CSS,
- and nothing re-requests, because the position/margin looks already correct.

Result: a permanent empty box. Users describe it as "memuat terus".

**Golden rule: status `shown` is only legal after `bannerAdLoaded` fires.**
Snap the placeholder to the banner height only in that handler.

## Also ship these, or the symptom comes back

- **Watchdog.** If `bannerAdLoaded` never fires (SDK edge case, listener
  registered too late), reset the state after ~15 s and re-request. Otherwise
  one lost event wedges the app in "loading" forever. Clear the watchdog on
  every load/failure event.
- **Honest terminal state.** After N failed loads, hide the placeholder
  entirely. A missing ad slot is normal; a permanently spinning empty box is
  not. Do not fake content.
- **Explicit states** on a `data-*` attribute so CSS can style each:
  `idle → loading → shown`, plus `failed`. Give `loading` a subtle pulse and
  respect `prefers-reduced-motion`.
- **Guard in CI.** Fail the build if app-ads.txt is missing, has no data line,
  has a line that does not match the IAB format, or its publisher ID does not
  match the app ID in the AdMob config. A silently-wrong publisher ID looks
  exactly like "no ads" and is invisible in the build log.
- **New ad units take time.** A freshly created unit can stay empty for a while
  after app-ads.txt is correct. Say so honestly instead of endless debugging.

## Test it without a device

Run the banner JS in `node:vm` with a virtual clock (fake `setTimeout`/
`setInterval`, a queue you advance manually) and a stubbed plugin whose
`addListener` records handlers. Then you can fire `bannerAdLoaded` by hand and
assert the real regression: *not* shown before the event, shown after it.

Cover: not-shown-before-load, shown-after-load, watchdog re-request, and
hidden-after-retries-exhausted.

## Rules for the stub

The stub must **not** auto-fire `bannerAdLoaded` by default if you want to test
the "no creative ever arrives" path — make it an option (`muatOtomatis`) so both
paths are testable. Fire the event on a timer so ordering matches the real SDK
(View first, creative later).