---
name: keyless-osint-api-riset-terbukti
description: Cara mencari dan MEMBUKTIkan API OSINT gratis dari GitHub/web sebelum dipakai — uji langsung ke host, catat yang mati, jangan percaya daftar orang. Includes the verified dead-list for NEXTRACE and the wallet verdict.
---

# Riset API keyless — uji dulu, baru percaya

## Aturan emas

**Tidak ada yang masuk ke project sebelum diuji live.** Ambil kandidat dari
GitHub / web search, lalu `curl -L` dengan **User-Agent browser** dan lihat
responsnya. Kalau cuma 401/403/404/0-byte, tandai MATI dan tulis ke dead-list.

Dua alasan daftar web orang tidak bisa dipercaya:
1. Endpoint mati 2 tahun lalu tapi masihlama di blog.
2. Yang ditulis "gratis" sebenarnya butuh API key berbayar di balik layar.

## Polemik "tidak ada": CARI DULU DI GITHUB

Dulu saya menyimpulkan "tidak ada API publik" lalu berhenti. **User benar
memper challengelt.** Dari ~10 repo GitHub, 1 punya endpoint hidup.
Jadi sebelum menyatakan fitur mustahil:

1. `gh api -X GET search/repositories -f q="<topik>" -f sort=stars`
2. **Baca source-nya**, bukan cuma README — `gh api repos/{r}/contents/{file} --jq .content | base64 -d`
3. `gh api -X GET search/code -f q="<domain>.<tld>/api"` — cari path API yang
   dipakai tool lain. Ini yang menemukan `customer.flip.id` dan
   `api.dana.id/user/otp`.
4. Test hasilnya live (lihat di bawah).
5. Yang mati → tulis di dead-list **dengan alasannya**, supaya tidak diulang.

⚠️ Repo dengan bintang tinggi bisa saja **deprecated** (contoh
`pilarxyz/cek-rekening` ★116 = sudah dihapus). Yang membuktikan hidup itu
**endpoint-nya**, bukan popularitas repo.

## Cara uji (Termux)

```bash
UA='Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36'
t(){ f=$(mktemp); c=$(curl -sL -m 12 -o "$f" -w "%{http_code}" -A "$UA" -H 'Accept: application/json,*/*' "$1");
     printf "%-4s %7sB %-50s %s\n" "$c" "$(wc -c<"$f"|tr -d ' ')" "$(echo "$1"|cut -c1-50)" "$(head -c 85 "$f"|tr -d '\n\r\000'|tr -s ' ')"; rm -f "$f"; }
```

WAJIB: `-L` (ikut redirect) + UA browser. Tanpa `-L` dan tanpa UA, terlihat
mati padahal hidup (Cloudflare balas 403 dalam 0.0s ke UA non-browser).

⚠️ Cookie consent / "Just a moment..." juga hasil 403 — bedakan dari 403 asli.

## Cara BUKTIKAN "tidak ada sinyal" (pola untuk status yang jujur)

Jangan hanya menulis "unknown". Bandingkan **nomor asli vs nomor kontrol**
(yang pasti tidak ada), lalu tampilkan ANGKANYA:

```
WA : asli 220765B vs kontrol 220755B -> selisih 10 byte
     marker "isn't on WhatsApp": 0 di kedua sisi  => tidak ada sinyal
TG : t.me/<nomor> redirect ke telegram.org, apa pun nomornya
     (Telegram hanya melayani USERNAME, nomor HP tidak ada profilnya)
```

Diff byte-level HTML juga alat bukti yang murah:
```bash
curl -sL -m 20 -A "$UA" "https://wa.me/$REAL" -o a.html
curl -sL -m 20 -A "$UA" "https://wa.me/100000000000" -o b.html
diff <(tr '>' '>\n' < a.html) <(tr '>' '>\n' < b.html) | head -20
```
Kalau yang beda cuma nonce CSP, itu **bukan** sinyal.

## Jebakan: 200 ≠�


`shopeepay.co.id/api/v1/verify` balas **200**, tapi body-nya HTML halaman
marketing. Cek **content-type + isi**, bukan cuma status code.

## Jebakan: redirect juga ikut allowlist

`wa.me` → `api.whatsapp.com`, `t.me` → `telegram.org`, `rdap.org` → registry
TLD. Kalau tujuan redirect tidak ada di `OUTBOUND_HOSTS`, server membalas
`Redirect diblakir: Host tidak ada di allowlist` dan **body 0 byte** — kelihatan
seperti host mati padahal hidup.

Untuk butuh bukti tujuan redirect, jangan follow:
```javascript
// server.js
if (opts.stopRedirect) {
  return resolve({ ok: true, body: '', code: res.statusCode,
                   error: '', redirectedTo: next });
}
```
⚠️ Versi pertama yang saya tulis (follow redirect lalu salin hasilnya)
menggantung dan membunuh server. Kalau sebuah request handler tiba-tiba
`curl` balas 000 padahal `ps` masih lihat prosesnya, **cari opsi fetch
yang barusan diubah** sebelum menebak hal lain.

## Dead-list NEXTRACE (udah dites 9 Okt 2026 — jangan coba lagi)

| API | Hasil |
|---|---|
| `haveibeenpwned.com/api/v3/...` | 401 butuh `hibp-api-key` berbayar |
| `breacharchive.pw/api/v3/...` | connection gagal |
| `api.urlhaus.com/v1/host/` | 401 |
| `api.peeringdb.com` | 401 butuh Authorization |
| `api.geoapify.com`, `api.maptiler.com` | 401/403, perlu daftar key gratis |
| `reddit.com/user/X/about.json` | 403 |
| `instagram.com/web/api/v1/users/...` | 404 (Cloudflare) |
| `cek-rekening-olive.vercel.app` | 500, upstream mati |
| `veriphone.io`, `api.api-ninjas.com` | butuh API key |
| `bgpview.io`, `api.threatminer.org` | connection gagal dari Termux |
| `api.blockchair.com` | 430 IP diblacklist |
| `api.dana.id/user/otp`, `api.gojek.com/auth/request-otp` | 000 — dan ⛔ jangan dipakai (kirim SMS ke orang) |
| `api.ovo.id/v1/request-otp` | 404 |
| `api-rekening.lfourr.com` | 200 tapi HTML blokir, bukan JSON |
| `api.veriphone.io`, `api.api-ninjas.com`, `api.anyapi.com` | butuh API key |
| `api.ip2location.io?key=demo` | 401, demo key mati |
| `photonapi.com`, `api.4g-mobility.com`, `api.intl-api.com` | connection gagal |
| `freeapi.app`, `api.freetelecom-api.com`, `openphonenumbers.com` | 404 / mati |
| `numbercheck.live` (repo 888-number-check) | 0 byte, lead-gen tanpa API |
| `diamondhunter.com`, `cekdiamond.com`, `nomor-hp.info` | mati / redirect ke /lander |
| `api.phoneapi.io`, `api.platosh.com`, `api.aioselect.com` | connection gagal |

## Yang TERBUKTI hidup & keyless (pola untuk nambah sumber baru)

| API | Isi |
|---|---|
| `proxycheck.io/v2/{ip}?vpn=1&asn=1&risk=1` | VPN/proxy, risk score, ASN, provider |
| `internetdb.shodan.io/{ip}` | port terbuka, hostname, CPE, vuln — tanpa key! |
| `otx.alienvault.com/api/v1/indicators/{IPv4\|domain}/general` | threat intel, pulse, reputasi |
| `api.mailcheck.ai/domain/{d}` | MX, umur domain, SPF, DMARC, disposable |
| `open.kickbox.com/v1/disposable/{d}` | deteksi disposable (pendek) |
| `disposable.debounce.io/?email=` | deteksi disposable (pendek) |
| `api.certspotter.com/v1/issuances?domain=&include_subdomains=true&expand=dns_names` | CT log — cadangan crt.sh |
| `nominatim.openstreetmap.org/search?q=&format=json` | geocoding |
| `api.bigdatacloud.net/data/reverse-geocode-client?...` | reverse geocode gratis |
| `stat.ripe.net/data/prefix-overview/data.json?resource=` | BGP/RIR |
| `api.hackertarget.com/aslookup/?q=` | ASN (sudah ada di NEXTRACE) |
| `api.pwnedpasswords.com/range/{5 huruf}` | Pwned Passwords k-anonymity, tanpa key |
| `libphonenumberapi.com/api/phone-numbers/{+no}` | operator, negara, zona waktu |

## Pola integrasi yang dipakai NEXTRACE

Semua sumber baru mengikuti **gaya aggregator** supaya konsisten:

```js
// server: setiap endpoint mengembalikan
{
  ok: true,
  confidence: 95,            // 95 = 3 sumber hidup, 70 = 2, 40 = 1
  fields: {
    asn: { value: 'AS15169', source: 'proxycheck.io', confidence: 'tinggi' }
  },
  health: { alive: 3, dead: 0, sources: [{ name, ok, fail, error }] }
}
```
Kalau `alive === 0` → `ok:false` + `note` yang **menolak menyimpulkan aman**.
"Tidak ada data" ≠ "tidak ada ancaman".

## Verifikasi: jangan hanya cek status code

```bash
node tools/smoke.js   # [5d] route + host allowlist + wrapper Api.* + status jujur
curl -s "http://127.0.0.1:8420/api/threat?ip=8.8.8.8" | head -c 300
```
Harus lihat **field berisi nilai**, bukan cuma `{"ok":true}`.

## Saat menambah endpoint pihak ketiga ke allowlist

Tiga lapis wajib:
1. Tambah host ke `OUTBOUND_HOSTS` (kalau lupa → `isAllowed()` menolak).
2. Smoke testestock route + host + wrapper `Api.*`.
3. Tulis ke `AGENTS.md` tabel dead-list AGENTS.md + README.

## Saat menguji IPv4 validation

Regex `/^[0-9a-fA-F:.]{3,45}$/` **SALAH** — `abc` lolos. Pakai
`isValidIP()` yang sudah ada di `server.js`, diuji 20 kasus termasuk
IPv6 mapped (`::ffff:1.2.3.4`).