# Skill — Bug Bounty Recon pada Host In-Scope

Dipakai saat user punya program bug bounty resmi (YesWeHack/HackerOne) dan
meminta bantu mencari bug. Semua yang di sini untuk **host yang ada di scope
resmi** — di luar itu hanya boleh DICATAT sebagai paparan aset, tidak diuji.

## Aturan main (tidak bisa ditawar)
1. Baca scope + daftar **out of scope** dari user sebelum request pertama.
   `*.example.com` berarti subdomain ikut masuk; nama yang dikecualikan =
   sortedang boleh disentuh.
2. Recon pasif dulu (DNS, Certificate Transparency). Host yang NXDOMAIN di 3
   resolver (Google DoH, Cloudflare DoH, AliDNS) + `Authority:` = domain sendiri
   → itu **split-horizon/internal**, bukan bug. Bilang terus terang.
3._rate limit_ diri sendiri: 1 request per host, jeda 2 detik antar host.
   Kalau dapat 429/403_shared edge_, berhenti di host itu.
4. Dilarang: DoS, brute force, data orang lain, social engineering.
   Uji IDOR/auth hanya pada akun milik user sendiri.
5. Tidak pernah klaim temuan yang belum dibuktikan sendiri. Bedakan
   "terbukti" vs "perlu diuji".

## Pola yang berulang (apply順序)

### 1. Sidik jari bottleneck CDN dulu
CDN bot-manager sering **drop diam-diam** (timeout 0 byte, bukan 403).
Tanda: `curl` polos timeout, tapi `curl` + header browser dapat 200.
Fix: header lengkap — UA, `accept`, `accept-language`, `sec-ch-ua*`,
`sec-fetch-dest/mode/site/user`, `upgrade-insecure-requests`, dan **`--http2`**.
Buat satu wrapper (`~/bb/bbget.sh`) supaya tidak mengulang 9 flag tiap kali.
⚠️ Simpan di `$HOME`, bukan `/storage/emulated` (FUSE mengabaikan chmod).

### 2. Login host-nya bukan cuma "/" 
Scan path umum. Yang paling sering jackpot di situs mobile-in-a-webview:
`/m`, `/m/login`, `/m/home`, `/index.html`, `/<app>/`, `/n/`, `/resource/`.
Host yang balas `200` dengan ukuran berbeda antar path = ada aplikasi nyata.

### 3. Tambang bundle JS (offline, risiko nol, hasil paling tinggi)
Semua SPA modern menyisipkan config environment + secret ke dalam
`app.<hash>.js` yang **publik**. Yang dicari:
- `https?://[a-z0-9.-]+\.[a-z]{2,}` → host lain, staging, domain beda
- blok `config:[{domain:"staging...",...}]` → **peta environment**
- `liffId` / `sdkToken` / `clientId` / `apiKey` / `authorizationToken`
- `baseURL`, `axios.create({...})` → host API asli
- `"/path/..."` → peta endpoint
- `debug`, `enableTrace`, `test`, `mock`, `staging`, `sandbox`
T，规范：cek versi berbeda antar env (produksi `1.226.0`, staging `1.30.0`).
Versi lama + masih hidup = kandidat temuan "outdated/legacy exposure".
⚠️ Source map (`.js.map`) — cek juga di env non-produksi, sering hanya ada di sana.

### 4. Bandingkan antar environment (in-scope)
`m.prod`, `pre.m`, `m.sit`, `test01/02`, `gold.m` — semuanya in-scope kalau
scope-nya wildcard. Cek: header keamanan, status 404, source map, endpoint
debug (`/actuator/*`, `/swagger-ui.html`, `/v2/api-docs`, `/graphql`, `/.env`),
dan apakah build-nya lebih lama.

### 5. CORS — hanya jadi temuan kalau ada dampanya
`ACAO: *` di halaman statis = **bukan bug**. Agar bisa dilapor:
harus ada endpoint **data** (bukan asset) yang juga `ACAO:*`, ATAU服务 memakai
token yang bisa dibaca JS. Dan ingat: `ACAO:*` + cookie = browser tetap
menolak, jadi dampaknya kecil kecuali datanya publik-leak.
Selalu uji dua arah: `GET` dengan `Origin: https://evil.example` **dan**
`OPTIONS` preflight. Kalau aplikasi balas 403 → itu proteksi, laporkan sebagai
"tidak rentan", jangan dipaksakan jadi temuan.

### 6. Status code salah = Info, bukan Medium
`HTTP 200` dengan body "404 Not Found" = bug monitoring/SEO, laku kalau
program menerima informational.

### 7. Bedakan bug nyala dari kode mati (WAJIB sebelum lapor)
SPA modern = ratusan chunk.before lapor, buktikan **component-nya dipakai**:
cari prop-nya di bundle utama. Kalau 0 kemunculan → dead code → jangan lapor.
Contoh nyata: komponen `autocomplete` punya `innerHTML: highlightText()` tanpa
escaping, tapi `maxResult`/`itemText` = 0 di app.js → tidak terpakai.

### 8. Deteksi "decode-lalu-inject" (pola XSS tersembunyi di Vue)
Minified Vue memakai `t._s()` = `toString` (TIDAK escape). Yang meng-escape
halah interpolasi `_v()`. Jadi:
- `domProps:{innerHTML: t._s(x)}` → **RAW HTML, bahaya**
- `_v(" " + t._s(x) + " ")` → teks aman

Pola klasik yang lolos review:
```js
getDescription: t => { const ta = document.createElement("textarea");
                       ta.innerHTML = t;                 // entity ter-decode
                       return ta.value.replace(/\n/gm,"<br>") }
// lalu: domProps:{innerHTML: this._s(getDescription(userData))}
```
`textarea.innerHTML = x` lalu baca `.value` = **decode tanpa sanitize** → payload
`&lt;img src=x onerror=...&gt;` jadi HTML hidup. Tidak perlu DOMPurify.

⚠️ Double-check: `createElement("textarea")+innerHTML+.value` yang output-nya
dipakai untuk `_v()` (teks) = AMAN. Jangan lapor sebelum cek alur render-nya.

### 9b. ⛔ Cek dulu: aplikasi web ini consumer atau merchant gateway?
Sebelum mengejar login di web, baca **nama route**-nya:
- `/ipg/*`, `/oauth/*`, `/kyb/*`, `/easy-pay`, `/authcode`, `/cashier/*`
  → ini **merchant/OAuth payment gateway**. Akses mandiri **akan ditolak**
  ("gerbang terkunci", "gateway locked", "open another page") karena butuh
  `ipgForwardUrl` + `clientId` + `merchantId` dari merchant.
- `/h/` yang balas JSON saat di-POST = **prefix API/ajax**, bukan section halaman.
Ciri lain: `fetch(url,{credentials:"same-origin"})` ke base sendiri = BFF,
semua API-nya di host yang sama (bagus untuk scope).
Kalau ternyata merchant-only, **jangan habiskan waktu** — pindah ke app mobile
yang juga core product di scope. Web gateway tanpa link merchant = dead end.

### 10. Menambling chunk SPA tanpa browser (peta fitur = peta bug)
1. Ambil HTML entry → `<script src>` → bundle utama + `manifest.<hash>.js`.
2. Parse peta chunk webpack dari manifest:
   `"n/" + ({0:"nama",1:"nama2"}[e]||e) + "." + {0:"hash",...}[e] + ".js"`.
3. Unduh semua chunk dengan **rate limit** (`sleep 0.3`, 1 request sekaligus).
   190/268 berhasil. Nama chunk = nama fitur → langsung jadi daftar target.
4. Grep sink: `innerHTML`, `v-html`, `document.write`, `eval(`, `new Function`,
   `postMessage`, `addEventListener("message"`. Cek juga apakah ada
   **DOMPurify** (0 = tidak ada sanitasi sama sekali di aplikasi itu).

## Menulis laporan yang DITERIMA YesWeHack
Wajib ada: **judul spesifik**, **aset persis** (`host/path`), **deskripsi
DAMPAK (bukan "info bocor")**, **langkah reproduksi numbered**, **bukti nyata**
(curl + output / screenshot), **severity + alasannya**, dan **saran perbaikan**.
- Satu temuan = satu laporan. Jangan campur.
- Kalau severity-nya rendah, claim-nya harus jujur — program membenci over-claim.
- Screenshot: ambil dari HP user (real browser) kalau curl sudah di-block.

## Blocker yang harus overtly disebut user, bukan diamkan
- Butuh **akun uji** → auth bypass/IDOR/business logic mustahil tanpa sesi.
- Butuh **VPN/kredensial** → host internal mustahil tanpa jaringan internal.
Katakan terus terang di awal, jangan setelah 30 request.
## ⛔ FALSE POSITIVE WAJIB DICEK — "PRIVATE KEY" kosong di APK
Grep `-----BEGIN PRIVATE KEY-----` di dex akan kena **stub**, bukan kunci asli.
Ditemukan nyata di DANA 2.147.1 (`classes6.dex`):
```
offset 6313120 panjang 59 : -----BEGIN PRIVATE KEY----------END PRIVATE KEY-----
offset 7262779 panjang 85 : -----BEGIN PRIVATE KEY-----3PEM end marker not found...
```
**Aturan:** jangan pernah lapor sebelum mencetak isi bloknya.
- Wajib ada base64 di antara BEGIN..END (≥300 byte)
- lalu `openssl rsa -check` / bandingkan modulus
- kosong = bukan temuan → anyhow sampaikan penolakan ini ke user secara jujur

## Ekstraksi cepat dari dex tanpa decompile penuh
```python
import re, glob
for f in glob.glob('classes*.dex'):
    d = open(f,'rb').read()
    # host produksi yang dipakai app
    for m in re.finditer(rb'https?://[a-zA-Z0-9._-]{3,60}\.[a-zA-Z]{2,12}', d): ...
    # event name RPC gaya alipayplus.* / dana.*
    for m in re.finditer(rb'\b(?:alipayplus|dana|id\.dana)[a-zA-Z.]{4,80}', d): ...
```
Host pihak ketiga (alipaydev.com sandbox, faceid.qq.com, doubleclick, yellowmessenger)
hanya catatan — program tidak membayar isu di luar scope.

## CaraNFT老公
**Unduh APK:** `curl -sL "https://d.apkpure.com/b/APK/<package>?version=latest"`
(APKPure balas 302 ke `data.winudf.com/...xapk`; ikut redirect).
XAPK = zip berisi `id.dana.apk` + `config.*.apk` (locale/density/ABI).
Ekstrak base APK dengan `zipfile`, lalu `unzip` `classes*.dex` + `assets/` saja
(butuh ~50 MB, bukan full extract).

## Audit Manifest APK cepat (aapt2) — tanpa apktool full
`aapt2` sudah ada di Termux dan JAUH lebih cepat daripada `apktool d`.
```bash
aapt2 dump badging <apk> | grep -E '^(package|uses-permission|launchable)'
aapt2 dump xmltree --file AndroidManifest.xml <apk> > mf.txt
```
Format `mf.txt`: `E: activity` / `E: receiver` membuka blok;
`android:exported(...)=true|false` (bukan hex!), `android:permission=` ada/tidak.
Hitung: komponen exported yang TIDAK punya `android:permission` = access control bocor.
⚠️ Nama receiver sering ditulis SEBELUM flag exported — jangan searching
`exported` dulu lalu langsung ambil nama, ambil nama dari awal blok.

**Pemetaan bug type ke daftar qualifying YesWeHack (penting untuk form):**
| Temuan | Pilih di form |
|---|---|
| Stored/DOM XSS | `Cross-Site Scripting (XSS) with real security impact` |
| Komponen auth exported tanpa permission | `Authentication bypass & broken authentication` |
| Receiver verifikasi bisa disiarkan | `Bypassing Verification Methods` (HANYA kalau benar2 terbukti) |
| IDOR objek milik orang lain | `IDOR` |
| Bypass OTP/push-verify sungguhan | `Bypassing Verification Methods` |
**JANGAN pilih DoS / Clickjacking / UI-redressing** → keduanya non-qualifying.
Crash aplikasi karena intent eksternal = DoS = kemungkinan besar Informative.
Presentasikan bagian **access control**, bukan bagian crash-nya.

## Menentukan severity di YesWeHack (grid per Core Product)
None $0 · Low $60–300 · Medium $400–700 · High $800–2000 · Critical $2100–3000.
Special Case (sampai $5000): Account Takeover · mass extraction data sensitif
· Scraping/Automation Bypass di login-registrasi.

## Cara mengisi form YesWeHack create-report (peta field, 2026)
`yeswehack.com/programs/<program>/create-report` butuh login (non-login = 404),
jadi **field-nya harus diambil dari screenshot user**, bukan dari fetch.
Struktur:
1. **BUG DETAILS** — Bug type* · Scope* · Endpoint* · Vulnerable part* ·
   Part name* · Payload* · Technical environment* · Application fingerprint ·
   CVE · Impact(dropdown) · IPs used*(ada tombol **GET MY IP**)
2. **BUG CHARACTERISTICS** — CVSS 3.1 diisi **manual** lewat tombol
   LOW/HIGH/NONE (Attack Vector, AC, PR, UI, Scope, C, I, A).
   Ada warning resmi: *"avoid overestimating the score"* → **pilih konservatif**.
3. **BUG DESCRIPTION** — Report title* + Description* (Markdown).
   Template YesWeHack = `YWH Report Template` dengan heading WAJIB:
   `## Description` · `## Exploitation` · `## PoC` · `## Risk` · `## Remediation`.
   Lampiran di-embed pakai `![YWH-RXXX]` (ID dari hasil UPLOAD).
   Batas: JPEG/PNG maks 10 MB, video MP4/WEBM maks 100 MB.
4. **BUG CHAIN** — centang hanya kalau bug-nya chain dengan laporan lain.

Tips: `CVE` biarkan kosong kalau yang relevan CWE (CWE sudah ada di Bug type).
`Impact` pilih yang paling dekat dengan dampak nyata; jangan biarkan kosong
kalau ada opsi yang cocok.

## ⛔ Jebakan editor YesWeHack: HTML entity di-DECODE (9 Okt 2026)
Saat paste deskripsi ke field Description:
- **Inline code** (`kode`) → editor **decode** `&lt;` jadi `<`, `&gt;` jadi `>`.
  Akibatnya payload yang seharusnya ditampilkan bentuk entity-nya berubah jadi
  HTML asli, dan triager bisa salah baca.
- **Fenced code block** (``` ... ```) → entity **dipertahankan**. Ini hanya
  jalur aman.
Aturan: payload XSS/SQLi SELALU taruh di fenced code block, bukan inline backtick.
Tambah kalimat penjelas sebelum payload:
"shown in HTML-entity-encoded form exactly as it must be stored ... not live markup"
Lampiran `{YWH-RXXXXX}` hanya jadi gambar di tab **Preview**, bukan di Write.
Selalu verifikasi 2 hal di Preview sebelum submit:
(1) payload tampil sebagai teks entity, (2) lampiran benar-benar gambar.

## 🎯 WAJIB: buktikan dampak SEBELUM menulis laporan (pelajaran RTFS DANA, 9 Okt 2026)
Program berorientasi "info" (YesWeHack DANA, dll) **tidak membayar temuan level
kode**. Ditolak dengan `RTFS` = "Security best practices without real security impact".

**Kunci kalimat penolakan DANA:**
> "as you state yourself the payload was never injected ... and never executed in a
> user's session ... remains an assertion rather than a demonstrated effect"

Jadi kalimat jujur di laporan ("kami tidak bisa mereproduksi") justru **memperkecil
peluang** — bukan memperbesar. Kejujuran tetap wajib, tapi **jangan tulis laporannya
sampai ada bukti eksekusi**.

**Gate wajib sebelum submit (3 pertanyaan, jawabannya harus "ya"):**
1. Bisa gw perlakukan payload-nya sendiri di lingkungan uji?
2. Ada bukti eksekusi? (screenshot / logcat / stack trace / response API)
3. Korban = akun sendiri, dampaknya nyata?

**Contoh temuan yang LANGSUNG dipatah oleh gate ini:**
| Temuan | Status |
|---|---|
| Pola XSS di bundle publik, belum ada PoC jalan | ❌ tolak (terbukti) |
| Activity exported tanpa permission → hanya "bisa dibuka" | ❌ belum ada dampak |
| Broadcast diterima tapi receiver mengabaikannya | ❌ belum ada dampak |
| Component crash saat dipanggil dari luar | ❌ DoS = non-qualifying |
| IDOR: ganti ID di URL → dapat data akun sendiri/LAIN | ✅ layak |
| Bypass OTP: OTP palsu diterima → login berhasil | ✅ layak |

**Trik penting:** kalau program memakai status `RTFS`, itu BUKAN penolakan
permanen. `RTFS` = "Read The Fine Scope" = **kurang bukti dampak, bukan salah
program**. Ranking point tidak hilang. Perbaiki bukti, lalu kirim ulang sebagai
laporan baru.

## Membaca logika Kotlin dari smali tanpa jadx (Termux)
`jadx` tidak ada di Termux. `apktool d` (ada) sudah cukup untuk logika:
```bash
apktool d -f -o smali app.apk          # butuh 3-6 menit untuk APK 47MB
find smali -path '*ClassName.smali'   # class ada di smali_classesN (1-10)
```
Trik navigasi smali yang hemat waktu:
```bash
grep -n 'const-string' F.smali | grep -iE 'otp|token|code'  # kunci String
awk '/METHODNAME/{f=1} f{print} f&&/end method/{exit}' F     # satu method
python3 -c "s=open(F).read(); i=s.find('\"handshake_id\"');
            import re; print(list(re.finditer(r'\.method [^\n]*',s[:i]))[-1].group())"
```
`grep -rl PATTERN smali/` bisa **timeout >120 detik** kalau tree-nya besar —
selalu batasi ke `smali_classes5/` atau handful file, jangan seluruh tree.
String yang sama bisa ada di beberapa class; cari per-file.

## MembacaIntent extra di receiver ter-obfuscate
Nama class receiver bisa gekil (`ayhg`), tapi **string konstantanya tidak di-obfuscate**.
`grep -oE '"[^"]{3,50}"' F.smali | sort -u` langsung memberi nama field
(`handshake_id`, `otp`, `otpCode`, `feature-risk-challenges`).
Nilai `getStringExtra("X")` sering tidak muncul karena Kotlin memakai
`Bundle.get()`/getter kompilasi → **cari dari string konstanta, bukan dari API call**.

## Membangun konteks merchant sendiri untuk host yang IN SCOPE (9 Okt 2026)
Program bisa列表 in-scope `m.dana.id` tapi out-of-scope `*.dana.id`. Portal web
nya adalah merchant/IPG gateway yang menolak akses mandiri ("gerbang terkunci")
karena butuh `ipgForwardUrl` + `clientId` + `merchantId`.
Yang BOLEH: pakai akun merchant **milik sendiri** untuk menyusun URL valid.
Cara cari clientId sendiri: string literal `clientId` di bundle web
(`Object(x._31)(ipgForwardUrl).clientId`) atau field `extParams.clientId`.
Cache/encrypt API key **tidak boleh** dipelajari dari aset orang lain — hanya
dari akun sendiri.
⚠️ Kalau form create invoice hanya ada di host OUT OF SCOPE
(`dashboard.dana.id`), JANGAN mengujinya — cukup sebut sebagai exposure.

## ⚠️ Kapan harus AKHIRI target dan pindah program (9 Okt 2026)
Tanda tanda target mentok (bukan karena kamu belum cukup usaha):
1. Web app-nya **merchant/OAuth gateway** → akses mandiri ditolak, tanpa link
   merchant sah tidak ada apa-apa yang bisa diuji.
2. Semua temuan klien-side habis: XSS butuh bukti eksekusi, exported component
   punya gate server, crash = DoS = non-qualifying.
3. Endpoint yang pays (IDOR/OTP) ada di peta tapi tidak bisa di-reach.
4. Jalur yang pays secara teknis (panel merchant) ada di host **OUT OF SCOPE**.
Kalau 3+ tanda muncul → berhenti di target itu, **tulis ulang penEMUAN supaya
berguna** (asset map, endpoint map, payload tuning), lalu pindah ke program
dengan login web normal. Jangan mengabiskan waktu di target yang buntu.
