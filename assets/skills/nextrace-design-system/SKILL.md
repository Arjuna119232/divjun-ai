# Skill: nextrace-design-system

Spesifikasi NEXTRACE **setelah rewrite v1.1 (9 Okt 2026)**.
Lokasi: `/storage/emulated/0/Fonts/intelegen-webview/web`

> Design LAMA (aurora + glassmorphism + Inter/JetBrains) sudah DIHAPUS.
> Kalau kamu masih ingat "aurora 4 blob" atau "blur 20px", itu basi.

## Keputusan desain (settled 9 Okt 2026)

| Token | Dark | Light |
|-------|------|-------|
| `--bg` | `#0b0d12` | `#f7f8fa` |
| `--surface` | `#12151c` | `#ffffff` |
| `--surface-2` | `#171b24` | `#f4f5f8` |
| `--surface-3` | `#1e232e` | `#e8eaf0` |
| `--border` | `#232936` | `#e0e4ec` |
| `--fg` | `#e8ecf3` | `#101521` |
| `--fg-dim` | `#a2acc0` | `#515b6e` |
| `--fg-faint` | `#7b8699` | `#6b7688` |
| `--accent` | `#6366f1` | `#4f46e5` |
| `--accent-solid` | `#5457e5` | `#4f46e5` |

Font: **IBM Plex Sans** (UI) + **IBM Plex Mono** (data).
Radius kecil (4–14px) supaya terasa datar, bukan bulat.
Layout: sidebar kiri + topbar status + bento 12 kolom.

### Tiga aturan yang tidak boleh dilanggar

1. **TIDAK ada `backdrop-filter`.** Chrome Android me-blur TEKS di dalam
   elemen yang memakainya → navitem smoky, user lapor "burem" (7 Okt 2026).
   Permukaan dibuat solid, bukan transparan-di-atas-blur.
2. **TIDAK ada gradien dekoratif.** Tidak ada aurora, grain, vignette.
   Motion hanya untuk hal yang memberi informasi (scanning line, skeleton).
3. **SATU warna aksen.** Indigo. Hijau/kuning/merah hanya untuk status
   (ok/warn/danger/info), tidak untuk dekorasi.

### aksen vs aksen-solid (WCAG)

```
putih di atas #6366f1 = 4.47:1  <- GAGAL untuk teks normal (butuh 4.5)
putih di atas #5457e5 = 5.42:1  <- LOLOS
```
Jadi: `--accent` untuk **teks/garis di atas `--bg`** (UI >= 3:1),
`--accent-solid` untuk **latar tombol + teks putih** (butuh 4.5:1).
Jangan gabungkan keduanya.

## Tema: 3 mode, bukan 2

`dark` · `light` · `system`.

```html
<html data-theme="dark|light" data-theme-mode="system">
```
- `data-theme` = warna **efektif** (dipakai CSS)
- `data-theme-mode` = **pilihan user** (dipakai untuk menggambar ikon tombol)

`Shell.setMode(mode)` menyimpan mode ke `localStorage: nextrace.theme`.
`Shell.installTheme()`+Fungsi `media.addEventListener('change')` bikin
mode `system` ikut berubah saat HP masuk mode gelap/terang — realtime.

## Ikon: SVG, tidak boleh emoji

```js
Icons.svg('phone')            // <svg> mentah
Icons.el('phone', 'nav__icon')// dibungkus <span>
Icons.names()                 // daftar nama yang sah
```
Semua path viewBox 24x24, `fill: none; stroke: currentColor`, tanpa isian.
Emoji **dilarang**: bentuknya beda antar perangkat dan tidak bisa diwarnai.
Smoke test [4b] cek setiap `icon` di `MODULE_CARDS` benar-benar ada.

## Navigasi: hash, bukan history API

```
#/dashboard
#/domain/contoh.com      <- nilai ikut di URL
#/sistem  #/panduan  #/tidak-ada  -> 404
```
`app.js`: `routeFromHash()` dipanggil oleh `hashchange`; `window.NextraceGo(id, value)`
dipakai kartu dashboard, tombol pivot, dan tombol 404.

⚠️ `go()` yang pertama kali dipanggil dari `NextraceGo` **hanya mengubah hash lalu
return** — render terjadi di `hashchange`. Kalau langsung render juga,
view dirender dua kali dan input ikut terisi 2x.

## Kontrak: config.js adalah satu sumber kebenaran

```js
assets/js/config.js  -> APP, MODULE_CARDS, ANALYSIS_TABS, UTILITY_PAGES,
                        ALL_VIEW_IDS, SAMPLE
```
Jangan tambah modul di `app.js` langsung. Sidebar DAN kartu dashboard
harus membaca daftar yang sama.

`SAMPLE` dipakai untuk SEMUA placeholder + nomor uji
(`+6281234567890` / `081234567890`). **Jangan pernah pakai nomor asli
user di placeholder atau test** — itu bocor ke repo dan ke PDF.

## Halaman baru (v1.1)

- **Sistem** — status server, kuota GetContact, pemilih tema 3 mode,
  hapus semua temuan sesi.
- **Panduan & Etika** — 4 bagian: alur kerja, yang tidak bisa dilakukan,
  aturan penggunaan, daftar sumber data.
- **404** — untuk id di luar `ALL_VIEW_IDS`.

## Keamanan server (v1.1)

| Ancaman | Penutup |
|---------|---------|
| CORS `*` | **Dihapus total.** Tidak ada `Access-Control-Allow-Origin` lagi |
| DNS-rebinding | `hostAllowed()` — hanya `localhost`/`127.0.0.1`/`[::1]`, port bebas |
| Baca source server | `serveStatic` hanya boleh `/` dan `/assets/*`. `server.js` → 404 |
| XSS | CSP `script-src 'self'` + tanpa `innerHTML` + tanpa inline `<script>` |
| Clickjacking | `X-Frame-Options: DENY`, CSP `frame-ancestors 'none'` |

Dua set nama yang **tidak boleh digabung**:
- `OUTBOUND_HOSTS` — host yang boleh **dihubungi server** (anti-SSRF)
- `LOCAL_HOSTS` — Host header yang boleh **diterima** (anti-rebinding)

## Verifikasi (wajib sebelum bilang selesai)

```bash
cd /storage/emulated/0/Fonts/intelegen-webview/web
npm run check   # smoke.js (99) + aggregator.test.js (26) — WAJIB 0 GAGAL
```

Yang dijaga smoke test:
- `[2]` tidak ada file JS tak terdaftar di `index.html`
- `[4b]` semua view benar-benar di-render + semua ikon `MODULE_CARDS` ada
- `[5b]/[5c]` tidak ada `Api.*`/route yang tidak terdefinisi
- `[6]` semua `var(--x)` ada di `tokens.css`  ← tangkap `--surface-3` hilang
- `[7]` tidak ada `.aurora`, tidak ada `backdrop-filter`
- `[8]` `boot-errors.js` = script pertama, tanpa inline script
- `[9]` `@media (max-width: 760px)` ada di tiap file CSS
- `[11]` tidak ada inline style yang merusak mobile
- `[13b]` Truecaller tidak boleh muncul lagi

## Mengukur, bukan menebak

Tidak ada headless browser di Termux. Untuk warna, hitung kontrasnya:

```bash
python3 -c "
def lum(h):
    h=h.lstrip('#'); r,g,b=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    f=lambda c: c/12.92 if c<=0.03928 else ((c+0.055)/1.055)**2.4
    return 0.2126*f(r)+0.7152*f(g)+0.0722*f(b)
def ratio(a,b):
    la,lb=lum(a),lum(b); hi,lo=max(la,lb),min(la,lb); return (hi+0.05)/(lo+0.05)
print(round(ratio('#ffffff','#5457e5'),2))
"
```
Untuk proporsi/jarak, render mock dengan Pillow lalu **lihat hasilnya**
(skill `visual-redesign-render-and-look`). Tetap-living truthfully:
mock Pillow adalah perkiraan — cek akhir tetap di HP user.

## Jebakan yang sudah diperbaiki (jangan diulang)

- **TDZ**: `if (typeof window!=='undefined') window.X = X;` **harus DI
  LUAR** IIFE. Kalau di dalam, `const X` masih di Temporal Dead Zone →
  `ReferenceError: Cannot access 'X' before initialization` yang mematikan
  SEMUA modul berikutnya.
- **`const` di script klasik bukan properti `window`**, tapi tetap terbaca
  antar script lewat global lexical scope. Karena itu smoke test harus cek
  `vm.runInContext('typeof X')`, bukan `sandbox['X']`.
- **Sandbox smoke test harus punya** `document.createElementNS` (dipakai
  `Icons.svg`), `matchMedia` + `CustomEvent` (dipakai `Shell`), dan
  `location`. Kalau lupa, semua modul setelahnya "undefined".
- **`jsDir`/const lain hanya boleh dideklarasi SATU KALI** di smoke.js.
  Deklarasi kedua di blok yang lebih bawah = TDZ, dan blok yang lebih atas
  crash saat dijalankan.
- **`el.view.querySelector('#view-value')`** untuk mengisi input dari hash:
  `simpleInvestigate` sudah memakai `pendingValue` sendiri — jangan dua kali.