---
name: android-webview-app
description: Build Android WebView apps that actually WORK - CORS bypass via Kotlin bridge, safe DOM rendering, single-source web assets, and smoke testing without a browser. Use when creating or debugging an Android app that wraps HTML/CSS/JS in a WebView, or when fetch() fails with CORS/type errors inside a WebView. Also covers which OSINT/lookup APIs are genuinely free vs paid.
---

# Android WebView App — Build yang Benar-Benar Berfungsi

Pelajaran dari NEXTRACE (`/storage/emulated/0/Fonts/intelegen-webview`).
Baca sebelum membuat project WebView Android berikutnya.

## 10 aturan emas

1. **CORS: HTTP lewat native Kotlin, bukan `fetch()`.** WebView memblokir
   `fetch()` dari `file://` ke domain luar (gejalanya diam-diam:
   `TypeError: Failed to fetch`). Pakai `@JavascriptInterface`.
2. **Selalu jalankan HTTP di thread background** — kalau tidak,
   `NetworkOnMainThreadException` langsung crash.
3. **Pakai requestId + peta pending**, bukan satu callback global, supaya
   dua request bersamaan tidak saling menimpa.
4. **JANGAN `innerHTML` untuk data dari luar** — itu XSS. Pakai
   `textContent` lewat helper `el()`.
5. **JANGAN pernah berpura-pura punya data.** Kalau API butuh key dan
   key kosong, tulis "API key belum diisi". Jangan tampilkan mock seolah
   itu hasil asli. Ini kesalahan paling merusak: user percaya data palsu.
6. **File web dari SATU sumber.** Jangan `cp -r www/ assets/www/`.
   Biarkan Gradle menyalin lewat `sourceSets`.
7. **`node --check` semua file JS** — satu syntax error mematikan seluruh app.
8. **Teks Latin script saja** di semua file.
9. **Smoke test tanpa browser** (`vm` + DOM minimal) sebelum menyatakan selesai.
10. **Jujur soal API gratis.** Lihat tabel di bawah.

## Bridge Kotlin minimal yang benar

```kotlin
@JavascriptInterface
fun fetchUrl(url: String, requestId: String) {
    executor.execute {
        var ok = false; var body = ""; var error = ""
        try {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 15000
            conn.setRequestProperty("User-Agent", "Mozilla/5.0 ...")  // UA browser wajib
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            body = stream?.bufferedReader()?.use(BufferedReader::readText).orEmpty()
            ok = code in 200..299
        } catch (e: Exception) { error = e.message ?: "unknown" }
        val r = JSONObject()
        r.put("ok", ok); r.put("body", body); r.put("error", error)
        main.post { webView.evaluateJavascript("javascript:cb($requestId,$r)", null) }
    }
}
```

MainActivity wajib:
```kotlin
webView.settings.javaScriptEnabled = true
webView.settings.allowFileAccess = true                     // untuk android_asset
webView.settings.allowFileAccessFromFileURLs = true
webView.settings.allowUniversalAccessFromFileURLs = true
webView.addJavascriptInterface(NativeBridge(this), "NextraceBridge")
```

## Sumber tunggal file web

```kotlin
sourceSets { getByName("main") { assets.srcDirs("src/main/assets", "$rootDir/www") } }
```
`homeUrl = "file:///android_asset/index.html"`

## Scan karakter non-Latin

```bash
grep -rnP '[\x{4e00}-\x{9fff}\x{3000}-\x{303f}\x{0400}-\x{04ff}\x{0600}-\x{06ff}]' www/ app/
```

## API gratis vs berbayar untuk OSINT

| Kebutuhan | Sumber | Butuh key? |
|-----------|--------|-----------|
| Info domain | `https://rdap.org/domain/{d}` | Tidak |
| MX email | `https://dns.google/resolve?name={d}&type=MX` | Tidak |
| Lokasi IP | `http://ip-api.com/json/{ip}` | Tidak |
| Cuaca + zona waktu | `https://api.open-meteo.com/v1/forecast` | Tidak |
| Geocoding | `https://geocoding-api.open-meteo.com/v1/search` | Tidak |
| Username | Cek halaman profil publik (status 200/404) | Tidak |
| **Nomor -> nama** | Truecaller / Twilio / NumVerify | **YA, berbayar** |
| **Identitas lengkap** | Tidak ada sumber gratis yang sah | **—** |

Jangan menjanjikan data "nama pemilik" gratis. Tidak ada. Bilang terus
terang, lalu arahkan ke browser.

## Checklist sebelum bilang "selesai"

```bash
# 1. Syntax semua JS
cd www && for f in $(find assets/js -name "*.js"); do node --check "$f"; done
# 2. Smoke test (wajib 0 gagal)
node tools/smoke-test.js
# 3. Non-Latin bersih
grep -rnP '[\x{4e00}-\x{9fff}\x{3000}-\x{303f}\x{0400}-\x{04ff}\x{0600}-\x{06ff}]' www/ app/
# 4. Konsistensi bridge: tiap @JavascriptInterface punya panggilan JS
grep -A1 "@JavascriptInterface" app/src/main/java/.../NativeBridge.kt | grep "fun "
grep -rho "NextraceBridge\.[a-zA-Z]*" www/assets/js/ | sort -u
# 5. Preview lokal
(setsid python -m http.server 8484 --bind 127.0.0.1 </dev/null >"$TMPDIR/srv.log" 2>&1 &)
termux-open-url "http://127.0.0.1:8484/index.html"
# 6. Build APK asli: GitHub Actions (local butuh Android SDK)
```

Catatan server Termux: `python -m http.server` harus di-`setsid` + redirect
stdin dari `/dev/null`, kalau tidak command akan hang sampai timeout.
