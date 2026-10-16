---
name: phone-name-lookup-reality
description: Why phone-number-to-owner-name cannot be done with free public APIs, verified by exhaustive testing. Covers every source that was tried (Truecaller, GetContact, Eyecon, CallApp, tellonym, sync.me, WhatsApp, Telegram, search engines, Wayback) and what each returned. Also documents the working solution: one-tap deep links to the free caller-ID apps, plus a web-sweep fallback with mandatory number-presence verification. Use when asked to find a phone number owner's name, build caller-ID aggregation, or when a reverse-phone-lookup feature seems "broken".
---

# Cari Nama Pemilik Nomor HP — Realitas 2026

Sudah diuji exhaustive. Kesimpulan: **tidak ada API publik gratis** yang
mengembalikan nama pemilik nomor. Ini bukan karena belum coba — ini
karena database itu sengaja tertutup.

## Yang sudah diuji (dan hasilnya)

### Caller ID databases
| Sumber | Endpoint diuji | Hasil |
|--------|----------------|-------|
| Truecaller | `truecaller.com/search/{n}` | **404** |
| Truecaller | `truecaller.com/api/search?searchPhone={n}` | **404** |
| Truecaller | `api.truecaller.com/search?q=` | tidak ada |
| GetContact | `getcontact.com/number/{n}` | **404** |
| Eyecon | `eyecon.com` homepage | 200, tapi tidak ada endpoint lookup |
| CallApp | `callapp.com` homepage | 200, tapi tidak ada endpoint lookup |
| tellonym | `tellonym.me/search/{n}` | **403** bot protection |
| sync.me | `sync.me/search/{n}` | **404** |

### Messaging apps
| Cek | Nomor valid | Nomor pasti tidak ada | Kesimpulan |
|-----|-------------|----------------------|------------|
| `wa.me/{n}` | HTTP 200 | HTTP **200 juga** | nol sinyal |
| `api.whatsapp.com/send/?phone={n}` | 220.682 B | 220.672 B | beda 10 byte = panjang nomor saja |
| `t.me/{n}` | 18.369 B | 18.369 B (**identik**) | nol sinyal |

### Search engines (phone numbers are NOT indexed with names)
| Engine | Hasil untuk `"+6287786107164"` |
|--------|------------------------------|
| Bing | 10 hasil tapi **mengabaikan nomor** — kembalikan "Disk Management in Windows", resep makanan, dll. URL di `/ck/a?u=a1<base64>` (harus di-decode) |
| Brave | mengindeks nomornya (ditemukan di halaman dataset frequency), tapi tanpa nama orang |
| DuckDuckGo HTML | bot detect ("anomaly"/"challenge"), 0 hasil |
| Mojeek | 349 B = diblokir |
| Yandex | CAPTCHA |
| Startpage | kadang |

**Uji pembuktian**: search `+12125551234` → Bing decode URL-nya jadi
`https://emis.kemenag.go.id/` (situs pemerintah Indonesia). Query diabaikan
total.

### Arsitektur
- **Wayback Machine** (`archive.org/wayback/available?url=`) → bisa
  dicek, jarang ada hasil

## Kenapa ini tidak bisa di Aggregate

Database Truecaller/GetContact dibangun dari **ratusan juta pengguna**
yang menyetujui nomor datanya. Itu **merek dagang** — makanya
API-nya berbayar (B2B contract). Tidak ada jalur sah untuk mengambilnya.

## SOLUSI YANG BENAR-BENAR BEKERJA

Keempat app itu **GRATIS untuk pemakaian pribadi**. Jadi jangan Media
mengambil datanya — minta user buka langsung, 1 ketukan:

```javascript
UI.linkRow('Truecaller', url: 'https://www.truecaller.com/search/' + digits)
UI.linkRow('GetContact', url: 'https://getcontact.com/numbersearch/' + digits)
UI.linkRow('Eyecon',     url: 'https://www.eyecon.com/')
UI.linkRow('CallApp',    url: 'https://www.callapp.com/')
UI.linkRow('WhatsApp',   url: 'https://wa.me/' + digits)
UI.linkRow('Telegram',   url: 'https://t.me/' + digits)
```

`getcontact.com/numbersearch/` adalah path yang benar (yang `/number/` 404).

## Fallback yang tetap jalan: web sweep + VERIFIKASI

Kalau nomor memang ada di internet (misal di spreadsheet publik, daftar
kontak toko, dokumen yang bocor), itu **find yang sah**. Tapi wajib
verifikasi:

```javascript
// WAJIB: hanya terima halaman yang nomornya BENAR-BENAR ada di URL.
const d9 = digits.slice(-9);
const urlHasNumber = url.indexOf(d9) !== -1 || url.indexOf(digits.slice(-7)) !== -1;
if (!urlHasNumber) return;   // false positive -> buang
```

**Tanpa filter ini**: hasil sweep `+6287786107164` menghasilkan 8 nama
sampah ("Digital Spy", "Ras Kucing", "Bisa Dipelihara") karena Bing
mengabaikan nomor dan mengembalikan halaman acak. Itu **lebih buruk
dari tidak ada** — user percaya data palsu.

Setelah filter: 0 kandidat = jawaban jujur "tidak ada di web".

## Filter noise nama

```javascript
const STOP = /Google|Android|Windows|Chrome|Search|Browser|Privacy|Terms|Settings|
  Download|Login|Home|Page|Microsoft|Apple|Amazon|Facebook|Instagram|Twitter|
  Youtube|PayPal|Contact Us|Support|Reverse Phone|Lookup|Identifier|Blocker|
  CallerID|Location|Numbers?|Free|Online|Sistem|Digital|Kucing|Ras|Bisa|Jenis|
  Dukungan|Tentang|Info|Berita|Tips|Cara|Cek|Layanan|Promo|Diskon|Jual|Beli|
  Mulai|Daftar|Masuk|Keluar|Buka|Tutup|Cari|Temu|Panduan|Tutorial/i;

function isNoise(nm) {
  return nm.length < 6 || nm.length > 32 || STOP.test(nm);
}
```

## Cara menjawab user yang minta nama pemilik

Jangan hanya bilang "tidak bisa". Bilang:
1. Data Truecaller/GetContact proprietary, endpoint publiknya sudah ditutup
2. **Tapi 4 app itu gratis untuk pribadi** — tap 1x, nama langsung muncul
3. App sudah kasih 1-klik ke semuanya
4. Kalau nomor memang ada di web, web sweep + verifikasi sudah jalan

## Verifikasi kalau ada bug
```bash
curl "http://127.0.0.1:8420/api/webname?num=%2B6281234567890"
# cek: totalHits > 0 DAN setiap pages[].url benar-benar mengandung nomor
```