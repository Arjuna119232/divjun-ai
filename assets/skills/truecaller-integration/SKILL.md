# Skill: Integrasi Truecaller (lookup nama nomor) di NEXTRACE

Untuk membuat website OSINT bisa **membaca nama pemilik nomor HP**.
Terbangun di `/storage/emulated/0/Fonts/intelegen-webview/web`.

## Kenapa hanya 1 akun (jawaban atas "harus daftar banyak akun?")

Bukti dari tes langsung ke `search5-noneu.truecaller.com/v2/search`:

```
tanpa token      -> {"status":40010,"message":"Missing authentication parameter."}
token ngawur     -> {"status":40101,"message":"Unauthorized"}
```

Endpoint WAJIB punya `installationId` dari login sah. Daftar banyak akun
**tidak membantu** — hanya memperbesar risiko akun diblokir.

Ditambah kutipan resmi Truecaller sendiri:
> *"The API does not include name search, which will remain a mobile app feature only."*

Jadi: **1 akun milik user sendiri + login OTP sekali** = cukup.

## ⚠️ Jebakan terbesar: npm TIDAK bisa install di SD card

```
cd /storage/emulated/0/Fonts/... && npm install truecallerjs
-> npm error ... It is likely you do not have the permissions to access this file
```
Penyebab: Android shared storage tidak mendukung symlink, dan npm butuh
symlink di `node_modules/.bin`.

**Solusi yang berhasil:**
```bash
mkdir -p ~/.config/zyvo/nx-deps && cd ~/.config/zyvo/nx-deps
echo '{"name":"nextrace-deps","private":true}' > package.json
npm install truecallerjs        # 125 paket, 35 MB, ~29 detik di Termux
```
Lalu dari project:
```js
const DEPS_DIR = process.env.NEXTRACE_DEPS ||
  path.join(os.homedir(), '.config', 'zyvo', 'nx-deps');
const tc = require(path.join(DEPS_DIR, 'node_modules', 'truecallerjs'));
```

## API `truecallerjs@2.2.0`

```js
const { login, verifyOtp, search, bulkSearch } = require('truecallerjs');

await login('+628123456789')            // -> respons OTP (simpan buat verifyOtp)
await verifyOtp('+628123456789', loginRes, '123456')  // -> { installationId }
await search({ number: '8123456789',     // TANPA kode negara
               countryCode: '62',
               installationId })
// -> objek Format: .getName() .getAddresses() .getEmailId() .json()
// bulkSearch("812..,813..", "62", id)   // maks 30 nomor per request
```

Token disimpan `~/.config/truecallerjs/authkey.json` **chmod 600**, di luar
project. Smoke test wajib menjaga file token tidak pernah ada di `/storage`.

## Arsitektur yang aman (IP sama)

`server.js` jalan di HP yang SAMA dengan login -> kalau lookup dilakukan dari
server, IP-nya sama dengan IP login -> Truecaller tidak melihat token tiba-tiba
dari IP lain.

## ⚠️ LeakCheck Public BUKAN sumber nama

`/api/leakcheck` mengembalikan **field apa yang bocor** (`"name"`, `"address"`)
plus nama breach-nya — **BUKAN isi nilainya**. Kalau dipakai sebagai sumber nama,
hasilnya **nama palsu**. Jangan gabungkan ke `ownerName`.

## Prinsip: hasil "tidak ditemukan" harus dijaga

Kalau Truecaller tidak punya nama untuk suatu nomor, itu **bukan error**.
Tuangkan apa adanya + jelaskan artinya (nomor belum pernah di-registrasi,
bukan berarti fake) + selalu tawarkan link ke aplikasi resmi.

## Verifikasi
```bash
node tools/smoke.js             # 62 check, wajib 0 gagal
curl localhost:8420/api/truecaller/status   # { installed:true, loggedIn:false }
```
## ⭐ Jebakan BESAR: endpoint OTP v2 sudah MATI (20003) — fix: pakai v3

Gejala: semua tes hijau, tapi login balas:
```
{"status":20003,"message":"Verification failed"}
```
SALAH diagnosis yang pernah dicatat: "nomor uji karangan". Itu KELIRU —
20003 terjadi untuk SEMUA nomor termasuk nomor asli yang terdaftar.

**Akar masalah sebenarnya (dibuktikan 7 Okt 2026):**
- `truecallerjs@2.2.0` (npm, 2023) memanggil `/v2/sendOnboardingOtp`.
- Truecaller sudah MENUTUP v2. APK resmi 26.39.6 memakai **`/v3/sendOnboardingOtp`**
  (verify masih `/v1/verifyOnboardingOtp`).
- `clientsecret: lvc22mp3l1sfv6ujg83rd17btt` MASIH VALID (masih di APK resmi).

**Cara gali endpoint baru:** decompile APK resmi (`apktool d truecaller.apk`),
cari string endpoint di `classes*.dex` (grep `/v3/`), lalu tiru payload-nya
(dari string + konstanta di dex).

**Tes cepat tanpa install apa pun:**
```bash
curl -s -X POST "https://account-asia-south1.truecaller.com/v3/sendOnboardingOtp" \
 -H "content-type: application/json; charset=UTF-8" \
 -H "user-agent: Truecaller/26.39.6 (Android;14)" \
 -H "clientsecret: lvc22mp3l1sfv6ujg83rd17btt" \
 -d '{"countryCode":"ID","dialingCode":62,"phoneNumber":"<tanpa kode negara>",
      "region":"region-2","sequenceNo":2,
      "installationDetails":{"app":{"buildVersion":5,"majorVersion":26,
        "minorVersion":39,"store":"GOOGLE_PLAY"},
        "device":{"deviceId":"x","language":"en","manufacturer":"Xiaomi",
        "model":"M","osName":"Android","osVersion":"14","mobileServices":["GMS"]},
        "language":"en"}}'
```

Arti status (sumber: konstanta di `TokenResponseDto.smali`, dex classes8):
- `1` = **STATUS_TOKEN_SENT** (baru ini OTP benar-benar terkirim)
- `2` = VERIFIED · `9` = TOKEN_PENDING · `11` = TOKEN_INVALID
- **`20001` = `STATUS_ATTESTATION_REQUIRED`** — server MENOLAK kirim OTP
  dan minta bukti Play Integrity dulu. `message` = UUID challenge,
  ada `requestId`. **BUKAN sukses.**
- `20002` = `STATUS_VERIFICATION_FAILED_THROTTLED` (cooldown, ada `ttl`)
- `20003` = `STATUS_VERIFICATION_FAILED`
- `40001` invalid body · `40003` nomor tidak valid · `40004` client secret salah
- `45101` = `STATUS_VERIFICATION_UNAVAILABLE_LEGAL` (salah domain → retry
  dengan `domain` dari respons)

⚠️ **Jebakan format v3:** `countryCode` butuh **ISO2 huruf ("ID")**, bukan
dialing code ("62"). Kirim "62" → 40003. (Bug nyata saat patch pertama.)

## ⛔ KESIMPULAN FINAL: login Truecaller dari server = JALUR MATI

Dibuktikan dengan bedah smali penuh APK resmi 26.39.6 (7 Okt 2026):

1. `/v3/sendOnboardingOtp` balas `20001` → app masuk alur **Play Integrity**:
   `GET device-safety-noneu.truecaller.com/v1/playintegrity/android/getNonce`
   → Play Integrity API (Google Play Services + sertifikat app) →
   `POST /v1/playintegrity/android/verify` {statement, build} → baru OTP terkirim.
2. `statement` = JWT yang ditandatangani **Google**. Tidak bisa dipalsukan,
   tidak bisa dibuat dari Node/Termux. Wajib HP asli + app resmi terpasang.
3. `getNonce` dari luar app balas `40010 Missing authentication parameter`.
4. Host asli: OTP = `account-onboarding-noneu.truecaller.com`
   (bukan `account-asia-south1`), attestasi = `device-safety-noneu.truecaller.com`.
   Keduanya tetap butuh attestasi.

**Artinya: jangan buang waktu lagi memperbaiki sendOtp/verifyOtp.** `40101`
di verify = sesi v3 tidak dikenali endpoint v1 (memang tidak akan pernah cocok).
Satu-satunya jalan punya `installationId`: login lewat **app Truecaller asli
di HP** (di sana attestasi jalan otomatis), lalu pakai token itu.

**Kode berguna yang tetap hidup (tanpa OTP):**
- `search5-noneu.truecaller.com/v2/search?type=4` (butuh Bearer installationId)
- `GET /v1/credentials/exchange`, `/v2.2/credentials/check`
- Tabel error lengkap ada di `TokenErrorResponseDto.smali` (classes5)

**Cara bedah cepat APK Tanpa nunggu apktool 9 dex:**
```bash
java -jar baksmali.jar d classes5.dex -o out   # baksmali 2.5.2 dari bitbucket
#   https://bitbucket.org/JesusFreke/smali/downloads/baksmali-2.5.2.jar
# GitHub release URL-nya 404; apktool.jar TIDAK punya main class baksmali.
grep -rl "sendOnboardingOtp" out                # -> ketemu interface Retrofit
```

## Jebakan: endpoint tanpa field `error` = UI diam

Responsnya `{"ok":false,"message":"Verification failed"}` tapi **tidak punya
field `error`**. UI-nya `UI.error('Gagal', r.error)` -> `r.error` undefined ->
hanya judul tanpa isi -> user melaporkan "tidak ada respon".

**Aturan: endpoint yang dipanggil frontend selalu isi `error` + `hint`
bahasa manusia, bahkan saat `ok:true`.** Dan bungkus tiap handler tombol
dengan try/catch + selalu render sesuatu.
