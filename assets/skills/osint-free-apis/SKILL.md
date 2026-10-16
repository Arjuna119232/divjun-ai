---
name: osint-free-apis
description: Which OSINT/lookup APIs are genuinely free vs paid, tested live. Use when building phone lookup, reverse phone, domain WHOIS, IP geolocation, email MX checks, or username search — especially when someone asks "which free API key should I register for". Covers keyless endpoints, redirect gotchas, and cleartext HTTP issues in Android WebView apps.
---

# OSINT API — Mana yang Benar-Benar Gratis (hasil test live)

Tested 7 Okt 2026. Semua pakai User-Agent browser (WAJIB — kalau UA lain,
Cloudflare/CDN banyak yang balas 403 dan kelihatan seperti API mati).

## Tidak butuh API key sama sekali

| Kebutuhan | Endpoint | Catatan hasil test |
|-----------|----------|--------------------|
| Nomor → operator, negara, zona waktu, tipe | `https://libphonenumberapi.com/api/phone-numbers/%2B{number}` | ** Paling bagus untuk modul phone.** `+6281234567890` → carrier Telkomsel, country ID, timezone Asia/Jakarta, type mobile |
| Spam score nomor (crowd-sourced) | `https://calltracer.io/api/lookup/{number}` | 10 request/menit/IP. `reports.spam_score` |
| Info domain | `https://rdap.org/domain/{d}` | **Wajib follow redirect (302 → https)** |
| MX record email | `https://dns.google/resolve?name={d}&type=MX` | Field `Answer[]` dengan `type: 15` |
| Lokasi IP, ISP, ASN | `http://ip-api.com/json/?fields=status,message,country,countryCode,regionName,city,zip,lat,lon,timezone,isp,org,as,reverse` | **Cuma HTTP** |
| Cuaca + zona waktu dari koordinat | `https://api.open-meteo.com/v1/forecast?latitude=&longitude=&current=&timezone=auto` | |
| Nama tempat → koordinat | `https://geocoding-api.open-meteo.com/v1/search?name=&count=5&language=id&format=json` | |
| Username lintas platform | Cek halaman profil publik, status 200 vs 404 | Tanpa API, tapi beberapa situs memblokir |

## Perlu daftar, tapi free tier-nya nyata

100 request/bulan, tanpa kartu kredit:
- `https://numverify.com/signup/free` — validitas + negara + operator (bukan nama pemilik)
- `https://abstractapi.com/api/phone-validation-api`
- `https://numlookupapi.com/`
- `https://phonevalidationapi.com/`

## Yang TIDAK ada versi gratis

- **Nama pemilik nomor** (Truecaller API, Spydialer, Whitepages API) — semua berbayar
- **Identitas lengkap seseorang** dari namanya — tidak ada sumber gratis yang sah
- Twilio Lookup: validasi format gratis, tapi paket `caller_name`/`line_status` $0,008/request

Cara jujur menanganinya: pakai data gratis yang ada, lalu arahkan pengguna ke
layanan berbayar lewat browser (pakai izin/akun mereka sendiri). Jangan pernah
tampilkan mock data seolah itu hasil lookup sungguhan.

## Jebakan teknis (penting)

1. **RDAP balas 302.** `HttpURLConnection` di Android TIDAK follow redirect
   HTTP→HTTPS secara default. Set:
   ```kotlin
   conn.instanceFollowRedirects = true
   ```
   Kalau tidak, hasil selalu gagal padahal API-nya sehat.

2. **ip-api.com cuma HTTP.** Untuk Android butuh
   `android:usesCleartextTraffic="true"` di manifest.

3. **UA wajib browser.** Kirim `Mozilla/5.0 ...` atau banyak API balas 403.

4. **WebView memblokir CORS.** `fetch()` dari `file://` ke domain luar selalu
   gagal. Pindahkan HTTP ke Kotlin `@JavascriptInterface`. Lihat skill
   `android-webview-app`.

5. **ipapi.co free trial hanya lewat email kantor** — alamat email sekali
   pakai (disposable) ditolak. Jangan sarankan ke user yang pakai Gmail
   personally kalau mau free trial.

## Cara verifikasi sebelum rekomendasi

Jangan percaya dokumentasi — test endpoint-nya:
```bash
UA="Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/131.0 Mobile Safari/537.36"
timeout 15 curl -s -H "User-Agent: $UA" "https://libphonenumberapi.com/api/phone-numbers/%2B6281234567890"
```
Kalau dapat JSON → hidup. Kalau 403/timeout → jangan daftarkan user ke sana.

## Email OSINT — holehe / Aarya / enumerasi registrasi (status 2026)

User pernah minta tool ini. Jawaban jujur: **tidak bisa di-embed, dan sudah mati.**

### Kenapa tidak bisa dipakai di dalam app
1. Holehe & Aarya itu **CLI Python**, bukan API/SDK. Cara pakai:`pip install aarya`.
   Tidak ada endpoint HTTP yang bisa dipanggil dari WebView.
2. Cara kerjanya: submit email ke endpoint "forgot password" tiap situs,
   lalu baca perbedaan respons. Itu harus diimplementasikan ulang manual
   per-situs di Kotlin kalau mau masuk app.

### Kenapa sudah mati (test live 7 Okt 2026)
Situs yang dulu membocorkan "email ini terdaftar" sudah menutupnya:

| Target | Hasil test | Keterangan |
|--------|-----------|------------|
| GitHub `/join?email=` | Tidak ada lagi "already in use" |——” |
| Chess.com `api.chess.com/pub/user/email/` | **HTTP 410 Gone** | Endpoint dihapus |
| Trello `api/checkMemberExists` | HTML login page | Ganti JSON jadi challenge |
| Behance `/email_exists/` | HTML Cloudflare | Diblokir |
| Dribbble `/users/email_available` | HTML | Diblokir |

Kesimpulan praktiknya (dipografi juga oleh Apify actor "holehe-scraper"):
*"email-registration enumeration is mostly closed now"*. Coverage holehe
turun terus antar rilis dan **tidak gagal diam-diam** — modul basi
menghasilkan jawaban negatif palsu.

### Yang MASIH hidup dan legal
| Metode | Status | Cara |
|--------|--------|------|
| **Gravatar** | ✅ 200 / 404 | MD5(email lowercase) → `gravatar.com/{hash}.json`. 404 = tak ada profil, 200 = ada (nama, lokasi, akun tertaut publik) |
| **Footprint / dork** | ✅ selalu | URL dihitung lokal, tanpa network |
| **Breach check** | ✅ | HIBP, DeHashed — butuh login sendiri, buka di browser |

Gravatar + footprint adalah inti. Link-out ke Holehe/Epiaos untuk yang
mau menjalankan tool themselves.

### Catatan etika
Enumerasi registrasi email adalah dual-use: bisa untuk mengecek akun
 sendiri, bisa untuk mengetuk target orang. Kalau diminta membangun fitur
"cek email ini terdaftar di mana-mana" untuk target orang tertentu,
minta konfirmasi konteks dulu. Yang aman: akun sendiri, breach check
kebocoran, atau investigasi yang sah.

## Email — tool yang tepat per kebutuhan (test live 7 Okt 2026)

User menanyakan "alat yang tepat untuk cek email". Jawaban_final per use case:

### A. Masuk ke app, gratis, TANPA daftar (sudah terpasang di NEXTRACE)
| Cek | Cara | Status |
|-----|------|--------|
| Format email | regex lokal | OK |
| Domain bisa terima email? | DNS-over-HTTPS `dns.google` MX | OK |
| Email sekali pakai? | daftar lokal + (opsional) keyless API | OK |
| **Identitas publik** | **Gravatar MD5** | **OK, paling bernilai** |
| Jejak / dork | URL dihitung lokal | OK, selalu hidup |

### B. Tautan ke browser (link-out, app hanya buka)
| Tool | Untuk | Test |
|------|-------|------|
| **Epieos** (epieos.com) | akun tertaut + info provider | 403 ke curl (Cloudflare), jalan di browser asli. Gratis tanpa daftar |
| **Have I Been Pwned** (web) | sudah pernah bocor | 403 ke curl, jalan di browser asli. API-nya sekarang butuh key (401) |
| **DeHashed** | riset breach lanjutan | hasil gratis terbatas |
| Holehe / Aarya / Blackbird | enumerasi registrasi | **sudah mati**, tapi tetap linker tool buat yang mau jalankan sendiri |

### C. Yang sudah TIDAK ada (jangan saran)
- **emailrep.io** — dulu API keyless gratis, sekarang cuma landing page
- Enumerasi registrasi — Chess.com 410, Trello/Behance/Dribbble/GitHub ditutup

### Rekomendasi final (kalau harus pilih satu)
**Gravatar + Have I Been Pwned via browser.** Itu kombinasi yang benar:
Gravatar kasih identitas publik yang memang sengaja dipublikasikan pemilik
email, HIBP kasih apakah pernah bocor. Holehe sudah tidak layak
disebut sebagai alat utama karena >50% modulnya sudah mati dan gagal
diam-diam.

## Tips menjawab user "API key gratis apa yang harus saya daftar?"

Jawaban jujur dan paling berguna: **hampir tidak ada**. Dari 7 modul OSINT
yang umum, hanya 1-2 yang butuh key (dan itu cuma pelengkap — operator dan
validitas). Semua yang inti — operator nomor, MX email, RDAP domain, lokasi
IP, zona waktu — gratis tanpa daftar. Jadi user tidak perlu daftar apa pun
untuk memakai app secara penuh.
