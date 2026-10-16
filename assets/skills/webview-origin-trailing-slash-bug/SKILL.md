---
name: webview-origin-trailing-slash-bug
description: Why a Capacitor Android WebView app shows permission granted on Android but getUserMedia (camera) and Geolocation never work - the WebView-level ChromeClient check compares the origin string with a trailing slash. Covers the fix, security limits that must NOT be loosened, and how to actually compile-and-run Android Java in Termux using stubs plus reflection. Use when camera capture or GPS/location silently fails even though the Android permission dialog was accepted.
---

# WebView origin mismatch: permission granted, feature dead

## The symptom

Users report: "I accepted the permission, but the camera / GPS doesn't work."
Settings shows the permission as granted. No error anywhere.

## The actual cause — a trailing slash

Android has **two independent permission layers** for these APIs:

| Layer | Who decides | What it controls |
|---|---|---|
| Android runtime permission | user via system dialog | app process access to hardware |
| **WebView permission** | `WebChromeClient` callbacks | whether the page's JS may use the API |

Accepting the first does nothing for the second. If your `ChromeClient` denies,
`navigator.mediaDevices.getUserMedia()` and `navigator.geolocation.*` fail forever
with **no message** — `request.deny()` is silent.

The classic bug is comparing the origin as a raw string:

```java
private static final String[] ALLOWED_ORIGINS = {
  "capacitor://localhost", "http://localhost", "https://localhost"
};

private boolean isOwnOrigin(String origin) {
  if (origin == null) return false;
  for (String allowed : ALLOWED_ORIGINS) {
    if (allowed.equalsIgnoreCase(origin)) return true;   // <-- BUG
  }
  return false;
}
```

But the WebView supplies the origin **with a trailing slash**:

```
ALLOWED_ORIGINS   ->  "https://localhost"
Uri.toString()    ->  "https://localhost/"
equalsIgnoreCase  ->  false
```

**All three** Capacitor origins end in `/`, so all three were denied. That is why
camera and GPS were completely broken while the permission screen said "granted".

`onGeolocationPermissionsShowPrompt` has the identical problem: it passes the raw
origin string, so `callback.invoke(origin, false, false)` denies geolocation
every single time.

## The fix

Normalize before comparing, then also compare scheme + host:

```java
private boolean isOwnOrigin(String origin) {
  if (origin == null) return false;
  String bersih = origin.trim();
  while (bersih.endsWith("/")) bersih = bersih.substring(0, bersih.length() - 1);
  for (String allowed : ALLOWED_ORIGINS) {
    if (allowed.equalsIgnoreCase(bersih)) return true;
    if (akuSamaSkemaHost(bersih, allowed)) return true;   // handles paths
  }
  return false;
}

private boolean akuSamaSkemaHost(String a, String b) {
  Uri ua = Uri.parse(a), ub = Uri.parse(b);
  if (ua == null || ub == null || ua.getScheme() == null || ub.getScheme() == null) return false;
  if (!ua.getScheme().equalsIgnoreCase(ub.getScheme())) return false;
  String ha = ua.getHost() == null ? "" : ua.getHost();
  String hb = ub.getHost() == null ? "" : ub.getHost();
  return ha.equalsIgnoreCase(hb);
}
```

## Do NOT loosen this

This check is a security boundary. It stops a page loaded in your WebView (via a
redirect, an iframe, or user-supplied URL) from silently grabbing the camera or
location. These must all still be **denied** — add tests for each:

- `https://localhost.evil.example.com/`  — suffix trick
- `http://evil.example.com/`
- `ftp://localhost/`  — right host, wrong scheme
- `""` and `null`

Never fix the bug by switching to `request.grant(request.getResources())` or by
granting everything unconditionally.

Also grant only the resources you actually use, and always grant on the UI
thread.

## Verify the Java for real in Termux

`javac` **is available** on Termux (17.x). You do not need the Android SDK to
test pure logic — stub the classes and call the real method.

1. Write minimal stubs (behaviour must be close enough to matter):
   - `android.net.Uri` — `parse()`, `getScheme()`, `getHost()`, `toString()`
   - `android.os.Bundle`
   - `android.webkit.WebSettings`, `WebView`, `WebChromeClient`,
     `PermissionRequest` (abstract), `GeolocationPermissions`
   - `android.app.Activity` — needs `runOnUiThread(Runnable)` to actually run
   - `com.getcapacitor.Bridge`, `BridgeActivity`, `BridgeWebChromeClient`
2. Compile the **real** production file together with the stubs:
   `javac -d out -proc:none -nowarn <stubs> native/MainActivity.java`
3. Drive it from a `probe` class using **reflection** on the private method:
   `getDeclaredMethod("isOwnOrigin", String.class)` + `setAccessible(true)`.
4. Also run the **old** logic side by side and assert it *fails* on the real
   origins. That is what proves you found the root cause instead of guessing.
5. Keep the outcome as a committed test (mirror the algorithm in JS + assert the
   Java source still normalizes and no longer contains the raw comparison).

## The other trap in this same area

A `document.getElementById('x')` stored in a `const` at module top level, plus a
function that reads it called **before** the declaration, throws:

```
ReferenceError: Cannot access 'btnDaftar' before initialization
```

In a `type="module"` file a top-level throw kills the whole page — including
login. Always declare before first use, and add a test asserting the declaration
index comes before the first call index.

## Also note

If you request only a **subset** of what the plugin offers (e.g. camera but not
photos) and gate on the missing one too:

```js
if (status.camera !== 'granted' || status.photos !== 'granted') { /* always true */ }
```

…then `requestPermissions()` fires on every tap. After two denials Android stops
showing dialogs, and users blame the OS. Audit the gate against the manifest.