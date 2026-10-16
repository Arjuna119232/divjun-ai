---
name: visual-redesign-render-and-look
description: Redesign something a user judges visually (app splash, camera UI, modal) in a repo with no headless browser on the phone — render the result to a PNG with Pillow, look at it with the read tool, and measure pixels instead of guessing. Covers the three bugs that look fine in code but ruin the output. Use when the user says a design is ugly/bad, or asks for "terbaik, modern, profesional", or any task where appearance is the deliverable.
---

# Redesign something you cannot preview in a browser

## The rule that matters

**Render it, look at it, measure it.** If appearance is the deliverable and
there is no headless browser, generate a PNG with Pillow, open it with the
`read` tool, and *measure pixel values*. Do not declare a visual done from
reading code — the user judges the result, not the logic.

Honest caveat: a Pillow mock is an **approximation** (emoji render as boxes,
no real backdrop-filter). It is still the right tool for **proportions,
alignment, and colour math**. Say plainly in the final report that the real
check is on the device.

## Measure, don't eyeball

Eyeballing a render tells you *something* is wrong. Measuring tells you what.
Always sample the pixel you care about and compare to the source:

```python
src = Image.open('icon.png').convert('RGBA')
print(src.getpixel((int(W*0.5), int(H*0.44))))   # source: (254,254,254,255)
print(out.getpixel((W//2, int(0.44*H))))         # output: #6E6F72  <- 56% too dark
```

## Three bugs that look perfect in code and ruin the output

### 1. Absolute-radius vignette darkens the whole canvas

```python
besar = max(w, h) * 3
r = besar * 0.5            # radius >> image size
d.ellipse((w/2 - r, ...), fill=...)   # covers everything
```

Normalise the distance instead, and build the mask small then upscale:

```python
kecil = 64
c = (kecil - 1) / 2
maks = math.hypot(c, c)
for y in range(kecil):
    for x in range(kecil):
        d_ = math.hypot(x - c, y - c) / maks
        t = max(0.0, min(1.0, (d_ - 0.45) / 0.55))
        px[x, y] = int(t ** 2.0 * strength)
topeng = topeng.resize((w, h), Image.Resampling.BILINEAR)
```

A 64×64 loop is 4096 iterations — instant, versus a per-pixel loop on a
1080×1920 canvas.

### 2. `ImageDraw` REPLACES, it does not blend

```python
for i in range(12):
    k = i / 11
    rr = c * (1 - k * 0.94)          # big -> small
    d.ellipse(..., fill=int(alpha * ((1-k)**1.7)))   # bright -> dim
```

This draws **bright first, dim last**, and each `ellipse` overwrites everything
inside it — so the centre ends up the *dimmest*. A radial glow drawn in that
order is a ring, which on screen reads as a **dark circle around the logo**.

Correct order for a centre-bright falloff: **largest & dimmest first, smallest
& brightest last.**

```python
for i in range(12):
    k = i / 11
    rr = c * (0.94 - k * 0.80)              # large -> small
    d.ellipse(..., fill=int(alpha * (k ** 1.7)))   # dim -> bright
```

Verify by sampling a horizontal line through the centre: values must fall off
monotonically outward.

### 3. Percentage positions measured against the wrong box

Camera-style guide brackets positioned in `top: 12%` of the **screen** will
never line up with a frame whose height comes from `aspect-ratio`. Make the
brackets **children of the frame**:

```html
<div class="frame">
  <span class="corner corner-a"></span> ...
</div>
```
```css
.frame { position: relative; aspect-ratio: 3 / 4; }
.corner-a { top: -2px; left: -2px; }
.corner-b { top: -2px; right: -2px; }
```

Also constrain the frame to the **safe zone**, not `inset: 0`:

```css
.bidik { position: absolute; top: 84px; bottom: 186px; left: 0; right: 0; }
.frame { height: 100%; aspect-ratio: 3 / 4; width: auto; max-width: 84%; }
```

Render it — the bottom corners were being hidden behind the control bar.

## Opaque logos need a shape

If the app icon has **no alpha channel** (check `im.split()[3].getextrema()`),
dropping it onto a dark gradient produces a big white rectangle — worse than
the flat splash it replaced. Give it a mask instead:

- **squircle** (superellipse `|x|^n + |y|^n = 1`, `n ≈ 4.6`) for modern app-icon
  feel; it also survives Android 12+'s circular icon clip without being cut.
- **circle** if that matches the brand.

Build the mask on a supersampled canvas (4×) and downscale, then combine:

```python
topeng = <draw at size*ss>; topeng = topeng.resize((size, size), LANCZOS)
alpha = ImageChops.multiply(img.split()[3], topeng)   # native & fast
```

Never loop per pixel for a mask — `ImageChops` is orders of magnitude faster and
matters in CI.

## Optional text without breaking the build

Letter-spaced text makes a splash look expensive. Pillow has no tracking, so
draw glyph by glyph:

```python
for ch in text:
    d.text((x, y), ch, font=font, fill=fill)
    x += d.textlength(ch, font=font) + tracking
```

Search several font paths and **degrade gracefully**:

```python
font = next((ImageFont.truetype(p, size) for p in CANDIDATES if Path(p).is_file()), None)
if font is None:
    print('Catatan: font tidak ditemukan — teks dilewati.')   # NOT an error
```

Check the CI log for that note to confirm the text actually rendered on the
runner. Deployed environments (Ubuntu runners, Termux, Android) have different
font sets, so this must never be fatal.

## Keep the DOM contract when restyling

When redesigning a screen, keep every `id`, `class` used by JS, and `onclick`
handler. One missing id turns a button into a silent no-op. Assert it in tests:

```js
for (const id of ['cameraOverlay', 'cameraStream']) assert.ok(html.includes(`id="${id}"`));
for (const fn of ['closeCustomCamera', 'capturePhotoFromCamera'])
  assert.ok(html.includes(`onclick="${fn}()`));
```

Also: don't switch `<div>` to `<span>` "while you're there" — inline elements
behave differently outside a flex context, and it is not what was asked.

## Avoid units that break older WebViews

- `100vmax` (Chrome 108+) → use a large px value: `box-shadow: 0 0 0 9999px rgba(...)`.
- `aspect-ratio` (Chrome 88+) is fine on any current Android WebView, but state
  it plainly if the app supports very old devices.
- `textbbox` signature is `textbbox(xy, text, font=...)` — the two-arg form fails.
## Lampiran bukti bug bounty (render ke PNG)
Triager YesWeHack/HackerOne butuh lampiran gambar. Kalau kode vulnerability ada
di bundle minified yang panjang, jangan screenshot terminal — **render manual ke
PNG bergaya dark terminal** dengan Pillow (`~/bb/make_evidence.py` sebagai contoh):
- DejaVuSansMono dari `$PREFIX/share/fonts/TTF` (ada di Termux bawaan)
- Palet: bg #0E1116, panel #161B22, teks #DEE4EC, merah #FF6A6A (baris berbahaya),
  hijau #7ED385 (bukti), cyan #6EC5F0 (judul blok)
- Isi wajib: **Asset · Endpoint · CWE · URL bundle** di header, lalu blok kode
  bernomor, lalu blok "Result" (nilai tersimpan → nilai yang dieksekusi)
- **Hindari penanda `^^^^^^^` di baris terpisah** — posisinya selalu meleset
  karena font monospace + indentasi. Lebih baik beri warna per baris.
- **Crop tinggi gambar ke isi terakhir** (`img.crop((0,0,W,H))`), jangan sisakan
  ~300px kosong di bawah — kelihatan tidak rapi.
- Simpan ke 3 tempat: `~/…`, `/storage/emulated/0/Download/<FOLDER>/`, dan
  `DCIM/Screenshots` (supaya user bisa pilih dari file picker HP tanpa Termux).

## Preview layout Flutter tanpa Flutter (14 Okt 2026, KUNBAR Connect)

Pola: `design/preview_baru.py` menggambar ulang tata letak dengan ANGKA YANG
PERSIS SAMA seperti kode Dart, pada ukuran dp HP sungguhan (360x800, 412x915)
plus inset status/nav bar. Lihat `~/karta-kubar/design/preview_baru.py`.

- **Palet WAJIB disalin dari `app_colors.dart`**, bukan diketik ulang. Hex
  karangan di pratinjau = pratinjau bohong (sudah pernah causing "layar
  lompat warna" 2 rilis berturut).
- **Font**: `pubspec.yaml` tidak membundel font → Android pakai Roboto. Render
  pakai `/system/fonts/RobotoFlex-Regular.ttf` +
  `set_variation_by_name('Bold')`, BUKAN DejaVu (metriknya beda).
- **JANGAN pernah pakai `ImageDraw.rectangle` warna latar untuk "membetulkan"
  letterSpacing.** Itu menimpa garis/grid di belakang teks dan muncul sebagai
  kotak gelap yang jelas di pratinjau. Tracking cukup: gambar per huruf.
- **Garis bantu (tengah layar, batas aman) hanya untuk pengukuran.** Render
  dua versi: bersih (dinilai user) + bergaris (kamu). Kalau tidak, garis bantu
  terbaca sebagai bagian desain dan kamu menilai gambar yang salah.
- **Gambar yang dikecilkan ke band perbandingan menciptakan "kotak hantu"**
  yang tidak ada. Untuk memastikan: sample piksel di dalam alleged box dan
  bandingkan dengan background. Kalau identik → artefak resampling, bukan bug.

### Dua bug layout yang tidak terlihat di gambar

1. **`Padding(right:)` pada item TERAKHIR di dalam `Row` yang
   `MainAxisAlignment.center`** membuat seluruh kelompok bergeser
   `jarak/2` ke kiri. Pakai `mainAxisSize: min` + padding hanya di antara item.
2. **Block yang di-center dengan `mainAxisAlignment: center` MELOMPAT**
   kalau satu sibling-nya punya tinggi variabel (mis. judul 1 baris vs 2 baris
   di 3 slide onboarding) → ilustrasi bergeser ~27dp setiap digeser.
   Solusi: kunci posisi elemen bertinggi variabel dengan
   `SizedBox(height: atas)` dihitung dari tinggi layar, lalu beri slot
   `ConstrainedBox(minHeight:)` untuk elemen variabel di bawahnya.

### Aturan pengukuran (dari pelajaran Splash KUNBAR)

- `Column` + `Spacer(flex:)` BUKAN centering. Footer ikut merebut ruang →
  blok konten meleset ke atas. Pakai `Stack` + `Center` + `Positioned(bottom:)`.
- Ukuran dalam dp harus di-derive dari
  `MediaQuery.sizeOf(context).shortestSide / 360`, di-clamp.
- Animasi = `Curves.easeOutBack` (pegas, untuk masuk) dan
  `Curves.easeInOutCubicEmphasized` (teks). Jangan `AnimatedContainer` di
  dalam `AnimatedBuilder` — nilainya sudah berubah tiap frame, animasi
  tambahan hanya menambah jank.
