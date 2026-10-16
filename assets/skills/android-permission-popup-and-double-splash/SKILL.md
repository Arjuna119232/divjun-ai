---
name: android-permission-popup-and-double-splash
description: Fix "permission popup doesn't appear" and "splash screen shows twice" in a Capacitor Android WebView app. Explains the two real root causes (requesting a permission that is no longer in the manifest, which silently wedges Android's dialog; and having both a native and a web splash), and gives a Play-policy-compliant permission onboarding sheet with tests and CI guards. Use when the user says popup izin hilang, izin tidak muncul, permission dialog not showing, or splash tampil dua kali.
---

# Permission popup missing & double splash (Capacitor Android)

Both symptoms are common in Capacitor apps and neither is what users assume.

## Symptom 1 — "the permission popup disappeared"

### The real cause: asking for a permission that isn't in the manifest

The exact chain that kills the dialog:

1. Version N **removes** a permission from the manifest (often for Play Store
   policy, e.g. broad media permissions).
2. Code keeps calling `requestPermissions({ permissions: ['photos'] })`.
3. The permission is not declared, so the OS auto-denies it.
   `checkPermissions()` therefore returns **not granted, forever**.
4. The guard `if (status.camera !== 'granted' || status.photos !== 'granted')`
   is **always true**, so `requestPermissions()` is called on every feature tap.
5. After the user denies twice, **Android stops showing the dialog entirely.**
   No error, no log. Users report "the popup is gone".

The user experiences a dialog that worked once and then vanished. Nothing
actually changed in Android.

### The fix, in order

1. **Audit every `requestPermissions` against the manifest.** Remove permissions
   that are not declared and not needed.
2. **Ask only for what the code actually uses.** If photos are captured via
   `navigator.mediaDevices.getUserMedia` (WebView path), only
   `android.permission.CAMERA` is needed. `Camera.getPhoto` with
   `source: Photos` is what needs `READ_MEDIA_IMAGES` — don't request it if
   you never call that.
3. **Add a first-launch onboarding sheet** that explains each permission in
   plain language *before* the system dialog appears. Google Play requires this
   rationale; blind permission prompts are a rejection risk.
4. **One permission, one dialog, in order.** Requesting three at once makes
   Android show them as a stack and is easy to dismiss wholesale.
5. **Handle permanent denial explicitly.** If a permission is already
   "don't ask again", calling `requestPermissions()` again is a silent no-op.
   Guide the user to Settings via Capacitor's `App.openSettings()`.

### Design rules for the sheet

- Show **once per install**, guarded by a `localStorage` key. Never re-nag.
- Offer "Nanti saja" (not just a close X) and record the skip.
- **Nothing is blocked.** If the user declines, every other feature still works —
  only the permission-dependent one degrades. Say so in the copy.
- Show honest live status per permission (granted / denied / not yet). Never
  render "allowed" that isn't.
- Delay first paint of the sheet slightly so it doesn't collide with other
  startup UI (splash, consent).

Also remember: **Android 13+ (API 33) never grants `POST_NOTIFICATIONS`
automatically.** Without an explicit request, push notifications silently never
reach the user.

## Symptom 2 — "the splash screen shows twice"

An app usually ends up with **both**:

- a **native splash** (Android launch theme `AppTheme.NoActionBarLaunch`,
  plus Android 12+ `windowSplashScreenAnimatedIcon`), shown from process start
  until the WebView is ready, and
- a **web overlay** (`#splash-screen` in HTML + JS that hides it after ~1s),
  which appears after the DOM is ready.

The user sees two splash screens in a row plus a wasted second. **Pick one.**
Keep the native one (it exists before any JS runs and matches the platform), and
delete the overlay plus its CSS. Make sure any greeting/animation that was
chained off the splash still runs — just trigger it on readiness instead.

Remove dead CSS too: `@keyframes` only used by the deleted overlay.

## Test it without a device

Run the module in `node:vm` with a fake Capacitor plugin layer and a small fake
DOM. Cover:

- permissions are requested in the intended order, one per call
- already-granted permissions are never re-requested
- the onboarding shows exactly once
- nothing is requested in a browser (no native platform)
- status output never fabricates "granted"
- the removed permission string appears nowhere in `www/`
- the splash overlay is absent from every HTML file

### Two traps that cost real time in `node:vm`

1. **Cross-realm objects break `deepStrictEqual`.** Objects created inside the
   vm have a different `Array`/`Object` prototype than the test realm, so
   `assert.deepEqual` fails with "same structure but not reference-equal" even
   when the contents match. Round-trip through JSON first.
2. **A fake DOM whose `addEventListener` is a no-op will hang the suite.**
   If the module returns a Promise that settles on a click, store the handlers
   and expose a `klik()` helper — otherwise the test never completes.

## Add CI guards so it cannot regress

In the project's validator script:

- reject a page containing `id="splash-screen"` (only the native splash is allowed)
- reject `requestPermissions({...photos` anywhere in `www/`
- if a page's **own** `<script src>` list includes JS that references a global
  module, require that module to be in the same list

For that last one, parse the actual `<script src>` attributes and resolve them.
Scanning the whole `assets/js` directory produces false positives on every page.

## Pitfall while testing guards

`git checkout <file>` to undo a test edit **destroys uncommitted work** in that
file. Copy to `$TMPDIR` with `cp`, then `cp` back.