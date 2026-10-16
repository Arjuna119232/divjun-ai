---
name: scrape-indonesian-prepaid-price-lists
description: Cara mengambil daftar harga paket kuota Telkomsel / tri / AXIS dari halaman web operator, dan tiga jebakan parser yang membuat data palsu (newlines diratakan, rowspan hilang, parser teks menyeberang baris). Gunakan saat membuat halaman harga kuota, agregator promo, atau scrape tabel harga apa pun dari HTML statis.
---

# Scrape daftar harga paket pra-bayar Indonesia

## Kenapa skill ini ada

Tidak ada operator yang punya API publik harga kuota. Satu-satunya cara adalah
membaca halaman harga lalu parse. Masalahnya bukan "gagal akses" — semuanya
bisa diambil — tapi **parser yang salah diam-diam mengarang paket**.

## Temuan per operator (tes live 9 Okt 2026)

| Operator | Domain yang benar | Status |
|---|---|---|
| Telkomsel | `www.telkomsel.com` | ✅ server-rendered, tabel + list, parse langsung |
| AXIS | `www.axis.co.id` | ✅ server-rendered, format baris teks "1,5 GB masa aktif 1 hari: Rp4.700" |
| tri (3) | `tri.co.id` | ⚠️ SPA — harga di-render JS, TIDAK ada di HTML |

 Jebakan domain tri:
- `www.tri.id` → **DNS NXDOMAIN**
- `tri.id` → **domain PARKED** (ParkLogic 404), TCP 443 terbuka tapi isinya halaman parked
- `tri.co.id` → situs asli, tapi shell SPA ~9.7 KB. API internal
  `/api/v1/3business/page/` menolak GET (405) dan POST tanpa payload (500).
- Kesimpulan: tri **tidak bisa** diambil dari sumber resmi tanpa browser.
  Pakai agregator statis (`berakalmod.com`, `chatbotcell.com`) dan **labeli
  "agregator", janganigui sebagai resmi**.

Contoh URL yang terbukti hidup:
- `telkomsel.com/promo/hotpromo` (1 tabel, zona A–D, rowspan)
- `telkomsel.com/jelajah/.../Promo-SERU-Internet-...` (3 tabel sederhana)
- `telkomsel.com/jelajah/.../paket-super-seru-...` (0 tabel, list `Super Seru 40K: 18 GB, Rp40.000`)
- `axis.co.id/blog/kuota-internet-paling-murah` (0 tabel, 125 harga)
- `axis.co.id/produk/paket-internet/paket-warnet` (0 tabel, unlimited)

## Tiga jebakan yang HARUS dihindari

### 1. `\s+` di stripTags menghapus batas baris

```js
// SALAH — meratakan newline jadi spasi, jadi pola bisa menyeberang baris
const text = html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ');
```

Akibatnya `"Rp15.000"` di baris 1 dipasangkan dengan `"70GB"` di baris 8 →
paket fiktif yang terlihat sangat meyakinkan.

**Perbaikan:** pecah HTML jadi daftar baris, dan hanya whitespace horizontal
yang diratakan. Newline tidak boleh pernah hilang.

```js
function toLines(html) {
  return String(html)
    .replace(/<\/(td|th|li|p|tr|h[1-6]|div|table|ul|ol|section)>/gi, '\n')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .split('\n')
    .map((l) => l.replace(/[ \t\r]+/g, ' ').trim())
    .filter(Boolean);
}
```

Lalu parser teks memproses **satu baris satu per satu**. Secara struktur,
lagi mustahil menggabungkan data dari dua baris berbeda.

### 2. Slice `text.slice(i-25, i+25)` menyeberang baris

Mencari masa aktif dengan potongan bebas rumored dari teks penuh → durasi
terambil dari paket sebelah. Paket AXIS keluar sebagai "400GB / 1 jam" padahal
halaman itu tidak punya paket 400 GB.

**Perbaikan:** karena sudah kerja per-baris, cukup `parseDays(barisIni)`.

### 3. rowspan di `<table>` = masa aktif hilang diam-diam

Sel "Masa Berlaku" di Hot Promo memakai `rowspan`, jadi 5 baris berikutnya tidak
punya sel durasi. Tanpa propagasi rowspan, semua paket jadi `days=null` dan
tidak bisa dinilai.

```js
let col = 0;   // WAJIB DI LUAR forEach
cellHtml.forEach((c) => {
  const rs = (attrs.match(/rowspan="?(\d+)/i) || [])[1];
  while (span[rowIdx + ':' + col]) col++;
  cells[col] = text;
  if (rs) for (let k = 1; k < Number(rs); k++) span[(rowIdx + k) + ':' + col] = text;
  col += width;
});
```

**Bonus bug yang menyamar:** `let col = 0;` ditulis **di dalam** forEach →
`col += width` jadi sia-sia, semua sel menimpa `cells[0]`, hanya sel terakhir
yang selamat. Gejalanya: kuota dan durasi `null` di semua baris tanpa error.

## Regex yang benar untuk "GB ... Rp" dalam satu baris

```js
// [^\n]{0,45}? mengizinkan tanda baca ("GB,", "GB masa aktif")
// tapi DILARANG melewati baris
/(?:([A-Za-z][A-Za-z0-9\s\-]{2,30}?)\s*:)?\s*([\d.,]+)\s*GB(?:[^\n]{0,45}?)\s*Rp\s?\.?([\d.]{3,14})/i
```

Jangan pakai `(?:\s[^\n]{0,40}?)?` — `\s` wajib dan TIDAK bisa mencocokkan koma
setelah "GB", jadi `"Super Seru 40K: 18 GB, Rp40.000"` gagal match.

## 규칙: jangan pernah mengarang masa aktif

Kalau halaman tidak menulis durasi → `days = null` dan tampilkan
"tidak tertulis". Uintuk paket unlimited → pisahkan, jangan masukkan ke
perbandingan per-GB karena tidak bisa dihitung.

## Verifikasi wajib

Bandingkan hasil parser dengan tabel yang|Published search. Kalau satu baris
tidak cocok, parser yang salah — bukan sumbernya. Semua URL di atas sudah
dites dan hasilnya cocok 1:1 dengan tabel publik.
