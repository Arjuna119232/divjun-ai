---
name: osint-nama-nomor-hp
description: Cara cari NAMA pemilik nomor HP dari sumber gratis tanpa API key — GitHub Code Search text-match adalah sumber terkuat yang ditemukan, LeakCheck untuk cek breach. Termasuk cara tes endpoint yang salah (curl -L, UA browser) dan regex ekstraksi nama dari CSV/PHP.
---

# Cari nama pemilik nomor HP — sumber gratis yang benar-benar jalan

## Ringkas: mana yang hidup, mana yang mati (tes 7 Okt 2026, Termux)

| Sumber | Status | Cara | Catatan |
|---|---|---|---|
| **GitHub Code Search + text-match** | ✅ PALING KUAT | header `Accept: application/vnd.github.text-match+json` | Mengembalikan NAMA SUNGGUHAN dari dataset publik |
| **LeakCheck public** | ✅ jalan | `leakcheck.io/api/public?check=<digits>&type=phone` | Hanya daftar FIELD bocor + nama breach, bukan isi record |
|搜索引擎 (Brave/Bing/Startpage) | ⚠️ lemah | `/api/search` | Judul/snippet bisa dibaca tapi nama sering salah baca |
| sync.me | ❌ | `sync.me/search?phone=+62…` | 301 → landing page, tidak ada hasil. Semua path `/number/`, `/phone/`, `/id/` = 404 |
| tellonym.me | ❌ | `tellonym.me/search/phone/62…` | 403 Cloudflare |
| calltracer.io | ❌ | `calltracer.io/api/lookup/<n>` | 200 tapi **body 0 byte** |
| Truecaller / GetContact / CallApp / Eyecon | ❌ proprietary | `truecaller.com/api/search` | 404. Tidak ada endpoint lookup publik |
| wa.me | ❌ | `wa.me/<digits>` | 200 untuk nomor valid DAN tidak valid → tidak ada sinyal. `og:title` cuma "Share on WhatsApp" |
| t.me | ❌ | `t.me/<digits>` | halaman generik identik untuk semua nomor. Tidak ada API phone→account |
| intelx.io phonebook | ❌ | POST `2.intelx.io/tools/phonebook` | 405 / 404 |
| tellonym, nmbr.org, thatnumber, freecarrierlookup, phone-in-use, apnacalls, offlinemsg | ❌ | — | 000 / 403 / 404 semua |
| telcod, 7sim, proapi.xyz, osint.sh, mdosch, sniff.li, opencellid | ❌ | — | 000 koneksi gagal |
| HIBP account API | ❌ butuh key | — | 401 "missing hibp-api-key" |
| EmailRep | ❌ | `emailrep.io/<n>` | 404 (expects email) |
| HudsonRock | sebagian | `cavalier.hudsonrock.com/api/json/v2/osint-tools/search-by-email?email=` | 200 untuk EMAIL saja. `search-by-phone` = 404 |
| mojeek, pastebin, github gist search, ddg-html | ❌/403 | — | Cloudflare |

**Kesimpulan honestly:** HANYA GitHub Code Search yang mengembalikan nama asli
gratis. LeakCheck memberi "data apa yang bocor" tapi tidak isi record.
Semua aplikasi Caller ID proprietary tidak bisa diakses dari web.

## Trik utama: GitHub Code Search text-match

```bash
N=6281239596551
gh api "/search/code?q=$N&per_page=30" \
  -H "Accept: application/vnd.github.text-match+json" \
  --jq '.total_count, (.items[]?|"\(.repository.full_name)|\(.path)|\(.text_matches[0].fragment)")'
```

Output nyata:
```
6
failamir/loudisland|routes/new_no_hp_to_blast.fix.csv|peserta_id,nama,no_hp 904633,Bili Obisuru,6281239596551
```

`text_matches[].fragment` = potongan file asli di sekitar kata yang cocok.
Kalau nomor ada di CSV yang juga punya kolom nama, **nama muncul di potongan
yang sama** → tidak mungkin nama fiktif masuk dari halaman lain.

Cara menemukan dataset yang berisi nomor (untuk memverifikasi kemampuan):
```bash
gh api "/search/code?q=%22nama%22+%22no_hp%22+extension:csv&per_page=5" \
  -H "Accept: application/vnd.github.text-match+json" \
  --jq '.items[]?|"\(.repository.full_name)|\(.path)"'
```

## Regex ekstraksi nama (harus dua pola)

Format yang paling sering di dataset Indonesia:

```js
// pola CSV: "Bili Obisuru,6281239596551"
const reCsv = new RegExp(
  '((?:[A-Z][A-Za-z\'\\-]{1,20}\\s+){0,3}[A-Z][A-Za-z\'\\-]{1,20})' +
  '\\s*[,\\t|]\\s*["\']?(?:-|\\+)?' + escaped, 'g');

// pola field: 'nama' => 'Bili Obisuru', ... 'no_hp' => '62812...'
const reField = new RegExp(
  '["\']?(?:nama|namalengkap|nama_lengkap|name|fullname|owner|pemilik)' +
  '["\']?\\s*(?:=>|:|=)\\s*["\']?' +
  '((?:[A-Z][A-Za-z\'\\-]{1,20}\\s+){0,3}[A-Z][A-Za-z\'\\-]{1,20})' +
  '["\']?[^\\n]{0,120}?(?:-|\\+)?' + escaped, 'g');
```

### Jebakan yang sudah pernah menggigit
1. **JANGAN pakai flag `i` di regex nama.** Flag itu ikut melonggarkan
   penangkapan nama → "Bili Obisuru" berubah jadi "bili obisuru" dan
   kapitalisasi asli hilang. Nama field JSON memang huruf kecil, jadi
   cukup tulis huruf kecil saja di bagian field.
2. **Map key lowercase bukan nama untuk ditampilkan.** Kalau dedup pakai
   `name.toLowerCase()` sebagai Map key lalu yang ditampilkan pakai key itu,
   kapitalisasi asli hilang. Simpan dua: `key` untuk dedup, `display`
   untuk output.
3. **Query Several harus dibatasi.** Tanpa batas, GitHub kena rate limit
   (403) dan `total_count` balloon jadi 24384 untuk nomor generik.

## Cara test endpoint baru (WAJIB)

```bash
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
curl -sL -o "$TMPDIR/out.txt" -w "code=%{http_code} size=%{size_download}\n" -A "$UA" -m 15 "$URL"
```

- **WAJIB `-L`** (follow redirect). Tanpa itu sync.me & tellonym cuma balas
  301 dan terlihat seperti mati padahal isinya ada di tujuan.
- **WAJIB UA browser.** Tanpa itu Cloudflare balas 403 dalam 0.0s.
- **Periksa `size_download` DAN isi body.** 200 dengan 0 byte = endpoint
  mati (calltracer begini).
- Jangan tulis output ke `/tmp` di Termux — Permission denied. Pakai
  `"$TMPDIR"`.
- Angka 000 = koneksi gagal total (DNS/TCP), bukan HTTP error.

## Token GitHub untuk server Node

Baca runtime, JANGAN hardcode:
```js
// urutan: env GITHUB_TOKEN -> ~/.config/gh/hosts.yml (oauth_token:) -> ~/.git-credentials
```
Kalau tidak ada → balas 503 dengan pesan jelas, jangan diam-diam gagal.

## Scale test: `/api/leakcheck`

`found` = jumlah record, `fields` = nama kolom yang bocor, `sources` =
`[{name, date}]` breach mana saja. Untuk nomor yang tidak ada, LeakCheck
balas `{"success": false, "error": "Not found"}` — itu **jawaban nyata,
bukan error**. Balas sebagai `ok:true, found:0`, kalau dibalas 502 frontend
tampil "gagal" padahal seharusnya "tidak ditemukan" = status dipalsukan.

## Honesty rules yang wajib dijaga

- Nama dari GitHub = data bocor publik. Tulis: "bisa jadi nomor sudah dipakai
  ulang, cocokkan dengan sumber lain".
- LeakCheck tidak memberi isi record. Jangan menulis nama dari sana.
- Kalau tidak ketemu: bilang tidak ketemu di 3 sumber, bukan "tidak bisa
  mencari nama".
- Tiap tag nama wajib punya sumber + confidence + link ke file bukti.
