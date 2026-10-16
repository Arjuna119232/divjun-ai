---
name: bug-bounty-scope-triage
description: Cara mengubah daftar scope + kelas kerentanan dari program bug bounty menjadi rencana uji yang ranked by (reward x probabilitas) dan BISA dijalankan dari HP/Termux saja. Gunakan saat user menempelkan scope bounty (GoPay, DANA, ZECIBLE, dll) lalu minta "pilih yang bisa dapat reward" atau "mana yang Modules worth it". Termasuk jebakan scope wildcard, dan kenapa harus target web asset (CDP) sebelum app (SSL pinning).
---

# Bug Bounty Scope Triage

Dipakai berulang untuk DANA, ZECIBLE, GoPay. Prinsipnya sama: user cuma punya
HP + Termux, jadi rekomendasi yang tidak bisa dieksekusi dari HP = rekomendasi
yang tidak berguna.

## 1. Baca scope dengan глазаenialis

**Severity dari program = payoff ceiling, bukan prioritas.** Yang penting:
- Asset mana yang **wildcard API** (permukaanattack paling luas, bug paling banyak)
- Asset mana yang **panel login/merchant** (IDOR + broken authz paling sering)
- Asset mana yang **entitas kecil wildcard** (kurang riset = saingan sedikit)

## 2. Cek jebakan scope SEBELUM nge-test

| Jebakan | Cara deteksi |
|---|---|
| Wildcard overlap | Kalau `*.X.com` (Critical) DAN `*.y.X.com` (Medium) dua-duanya terdaftar → kemungkinan `y` **dikecualikan** dari `*.X.com`. Jangan diasumsikan. |
| Entitas berbeda | `.findaya.com`, `.gtflabs.io`, `.mab.co.id` = badan hukum/entitas korporat terpisah. Hanya string persis yang di-scope. |
| Yang TIDAK ada = out of scope | `*.gojek.com`, `*.tokopedia.com`, `*.gopay.co.id` (tanpa `-`) tidak ada di daftar GoPay → jangan disentuh. |

## 3. Ranking: (severity x probability x competition) / effort

Tier 1 — bayar besar, proving ground jelas:
1. **IDOR** di wildcard API (Critical). Butuh 2 akun milik sendiri.
2. **Business logic** di sistem keuangan — selalu bayar besar dan listing-nya
   eksplisit di program (voucher multi-klaim, amount tampering, tanpa potongan).
3. **IDOR / broken authz di panel merchant** (High).

Tier 2 — murah & sering kelewat:
4. **Exposed secrets**: `.env`, `.git/config`, sourcemap, admin panel di wildcard
   entitas kecil.
5. **Hardcoded secret di APK** — HANYA kalau bisa dipakai akses asset in-scope.

Tier 3 — perlu effort lebih, payoff middling:
6. Insecure storage / logcat leak (mobile).
7. Subdomain takeover (`*.go-pay.co.id`).

## 4. ⛔ Hard rule: no real impact = no bounty

Pelajaran DANA (report `#YWH-PGM3199-327` ditutup): *"payload was never injected
and never executed in a user's session"* → **RTFS**.

Jadi:
- Hardcoded API key yang tidak bisa dipakai = **ditolak**
- TLS pinning tidak ada, tapi tidak ada payload sensitif yang bocor = **ditolak**
- Bug "level kode saja" = **ditolak**

**Aturan:** sebelum nulis laporan, sudah punya PoC yang menunjukkan **efek nyata**
cross-account / cross-tenant / lintas ROLE. Kalau belum, cari dulu — jangan
submitaris lebih dulu laluefs sniffed.

## 5. Aturan yangWAJIB berlaku di laporan
- ⛔ `*/otp`, `*/request-otp`, `*/send-otp` = **DITOLAK** (kirim SMS OTP sungguhan
  ke nomor orang). Ini berlaku juga untuk repo "tools" yanguxe orang bagikan.
- Non-qualifying umum: DoS, missing headers, clickjacking, user enumeration,
  rate-limit, self-XSS, open redirect tanpa dampak, blind SSRF, CVE tanpa PoC.

## 6. Strategi capture dari HP (bagian paling penting secara praktis)

**Targetkan WEB asset dulu, bukan app.**

Alasannya teknis, bukan soal:choose:
- App Android punya **strong SSL pinning** → tanpa root tidak bisa MITM.
- Web asset jalan di Chrome → **CDP (Chrome DevTools Protocol) memberi full
  request/response** tanpa pinning sama sekali.
- Setelah ketemu endpoint-nya di DevTools, **replay pakai curl** = testing
  IDOR/business-logic jadi murah.

Setup Termux (proven):
```bash
proot-distro login ubuntu          # WAJIB: adb native Termux rusak
# di dalam ubuntu: apt install adb
adb forward tcp:9222 localabstract:chrome_devtools_remote
curl -s http://127.0.0.1:9222/json  # dari Termux langsung bisa
```

Untuk API yang HANYA dipanggil app:
1. Cari apakah alur yang sama ada di versi web → capture via CDP.
2. Kalau tidak: static analysis APK (decompile di Termux sudah pernah terbukti
   untuk APK 66MB) → peta endpoint → uji black-box dengan curl.
3. Pembaca hasil: `404` = tidak ada · `401/403` = ada tapi perlu auth ·
   `429` = ada (rate limit) · `200` dengan data = **temuan**.

## 7. 🎯 Cari peta endpoint di GitHub DULU (lewat dari mana pun)

Ini langkah dengan **EV tertinggi per menit** di seluruh workflow bounty — dan
jarang dilakukan orang, makanya temuannya hampir belum ada yangBD.

```bash
gh search code "domain-target.com" --limit 30 --json repository,path,url
gh search code "domain-target.com/v1" --limit 30 --json repository,path
```
Clone kandidat (`--depth=1`) lalu tarik string path:
```bash
grep -rhoaE "['\"\`]/v[0-9]+/[A-Za-z0-9_/{}$.:-]+" . | tr -d "'\"\`" | sort -u
grep -rhoaE "https://[a-z0-9.-]*target\.com[A-Za-z0-9_/.{}$-]*" . | sort -u
```
Repo yang paling berguna:
| Jenis repo | Yang didapat |
|---|---|
| **SDK OpenAPI ter-generate** (`*sdk*`, `*api*` di dalam satu org) | peta endpoint lengkap + nama host + skema auth |
| Repo "otomatis"/automation orang | payload nyata + urutan request yang berhasil |
| Repo yang commit **Chrome profile / HAR / log** | URL, header, body response aslinya |
| `trickest/inventory`, `projectdiscovery/public-bugbounty-programs`, `rix4uni/scope` | daftar subdomain + konfirmasi scope |

**Cara baca hasilnya:**
- Endpoint dengan **path param** (`/{id}/...`) = kandidat IDOR.格里怀
- Endpoint **WRITE** dengan path param (`/cancel`, `/delete`, `/refund`) = IDOR
  ber-impact monetary → **paling dihargai**.
- Endpoint yang butuh Authorization = kandidat **auth bypass**.
- Klaim orang di README (mis. "header X bisa dilepas") = **hipotesis, wajib
  dibuktikan sendiri**. Jangan tulis laporan dari klaim orang.

## 8. ⛔ Privasi pelapor — ATURAN KERAS (settled 10 Okt 2026)
Laporan YesWeHack **dipublikasikan** setelah submit. Kalau lampiran memuat
nomor HP / akun / token milik pelapor sendiri, itu identitas bocor ke publik.

- Workspace bounty → `$HOME/bb/<program>/` mode `700`, **BUKAN** `/storage`
  (FUSE mengabaikan chmod → selalu 660, file jadi terbuka untuk semua app).
- `.gitignore` di root workspace: `capture/ *.har *.token *.session *.env
  private/ tools/*/chrome_profile/`.
- **Redact wajib** sebelum tulis laporan:
  `+628XXXXXXXXX` · `<order_id>` · `<token>` · `Merchant A` · `[REDACTED]`
- Screenshot harus di-crop/blur dulu.
- Clone repo pihak ketiga itu aman (publik, bukan data user). Yang dilarang
  adalah **mendorong** hasil capture atau laporan berisi data user ke git.
- Kalau user minta commit repo bounty → default **JANGAN**, tanya dulu.

## 9. Garis yang tidak boleh dilewati
- **JANGAN** nge-bombardir `validate-otp`, `validate-pin`, `*/send-otp`,
  `*/request-otp`, `phone/verify` → itu tebakan OTP/PIN orang = keyboard orang.
  Cukup **1 request tanpa token** untuk membuktikan auth bypass.
- **JANGAN** touched akun/data orang lain di luar program. Cuma akun milik sendiri.
- Non-prod (`stg`, `sandbox`, `internal`, `uat`) ada di dalam wildcard secara
  teknis, tapi banyak program **melarangnya**. Cek teks program.

## 10. Output yang bagus untuk user

- Ranking + alasan singkat per item (1-2 kalimat)
- ⚠️ daftar eksplisit yang **tidak**.对 ambil waktu
- Peringatan scope trap kalau ada
- Satu langkah berikutnya yang konkret, bukan "mau lanjut?"