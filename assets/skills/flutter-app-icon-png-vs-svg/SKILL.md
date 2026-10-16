# Ikon aplikasi Flutter: PNG vs SVG, dan alurnya

**Kapan dipakai:** user tanya "file gambar lu perlu PNG apa SVG?", atau mau
menghidupkan ikon app yang tadinya ditunda, atau bikin ikon dari nol.

---

## Jawaban singkat

> **PNG yang dipasang. SVG disimpan sebagai file master.**

Bukan pilihan gaya — ini	batasan keras tool dan platform.

| | Android | iOS |
|---|---|---|
| Format | PNG di `res/mipmap-*` | PNG di `Assets.xcassets/*.appiconset` |
| Master | 1024×1024 PNG | 1024×1024 PNG (App Store wajib) |
| Alpha | boleh (launcher bisa mask) | **HARUS dihapus** — alpha bikin **kotak hitam** |
| SVG | tidak dipakai | **ditolak** asset catalog |

`flutter_launcher_icons` pun hanya punya `image_path` yang isinya PNG — tidak
ada opsi SVG sama sekali.

---

## ⚠️ Jebakan yang hampir selalu kena: alpha di iOS

iOS merender ikon ber-alpha sebagai **persegi hitam**. Gejalanya ikon benar
di Android tapi hitam di iPhone.

Dua cara menutupnya:

```yaml
flutter_launcher_icons:
  image_path: "assets/icon/icon-1024.png"
  ios: true
  remove_alpha_ios: true          # ✅ paling gampang
```

Atau flatten manual saat membuat PNG-nya:

```python
from PIL import Image
src = Image.open("icon-1024.png").convert("RGBA")
flat = Image.new("RGB", src.size, (255, 255, 255, 255))   # atau warna brand
flat.paste(src, (0, 0), src)                               # alpha jadi komposit
flat.save("icon-ios-1024.png")
```

⚠️ Tapi **Android justru butuh alpha** supaya launcher bisa bebas memotong
(masking). Jadi biasanya: 2 PNG — satu RGBA untuk Android, satu flat untuk iOS
(`image_path_android` + `image_path_ios`).

---

## Alur kerja yang benar

```
gambar/edit  →  ikon.svg          (master, versioned, kecil & vektor)
             →  ikon-1024.png     (raster, 1024x1024, alfa untuk Android)
             →  ikon-ios-1024.png (raster, flat, untuk iOS)
             →  pubspec.yaml + flutter_launcher_icons
```

Generator SVG → PNG di Termux:

```bash
pkg install librsvg   # provides rsvg-convert
rsvg-convert -w 1024 -h 1024 -o icon-1024.png icon.svg
```

Atau pakai Pillow kalau sudah punya canvas piksel.

---

## Konfigurasi pubspec yang lengkap

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4

flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path_android: "assets/icon/icon-1024.png"
  image_path_ios: "assets/icon/icon-ios-1024.png"
  min_sdk_android: 21
  remove_alpha_ios: true

  # Adaptive icon Android 8+ (WAJIB dua-duanya, kalau cuma satu tidak jadi)
  adaptive_icon_background: "#1B5E20"
  adaptive_icon_foreground: "assets/icon/icon-foreground-1024.png"
  adaptive_icon_foreground_inset: 16      # default 16% — JANGAN 0

  # Android 13+ themed icon (monochrome)
  adaptive_icon_monochrome: "assets/icon/icon-mono-1024.png"

  # iOS 18+ dark/tinted
  image_path_ios_dark_transparent: "assets/icon/icon-dark-1024.png"
```

Jalankan: `dart run flutter_launcher_icons`

---

## Jebakan pengujian ikon

### 1. Lihat di ukuran sebenarnya, bukan di kanvas 1024

Launcher Android menampilkan ikon **48 dp**. Di layar 6 inch, itu cuma ~10 mm.
Elemen yang di 1024 px terlihat detail, di 48 px **jadi gumpalan**.

Cara cek: render ke 48×48 dan 96×96, lalu **LIHAT** hasilnya (skill
`visual-redesign-render-and-look`).

### 2. Elemen dengan luminansi sama = tidak terlihat

Kanopi hijau di atas hijau tua hilang total. Kalau ikon terlihat "bagiannya
hilang", cek nilai luminansi tiap elemen — bukan posisi.

### 3. Lubang/bentuk kecil jadi berubah bentuk kalau jari mancanye kecil

Lubang pin dengan rasio 0,46r + ujung pendek → bentuknya jadi **gelombang**
di ukuran kecil. Rasio aman ~0,28r dengan ujung lancip.

### 4. Foreground adaptive icon harus punya padding

Launcher Android memotong foreground jadi lingkaran/rounded-square dan menambah
masking. Tanpa padding, bagian penting ikut terpotong.
`adaptive_icon_foreground_inset: 16` (default) EVERYTINJA aman.

### 5. iOS: "should fill the entire image"

Ikon iOS **tidak boleh** punya border transparan — Apple's own docs. Berbeda
dengan Android yang boleh. Kalau pakai file yang sama, iOS akan menampilkannya
kecil dengan tepi kosong.

---

## Kalau ikon belum mau dipasang

Boleh menyimpan SVG + PNG di `design/icon/` tanpa menyentuh `pubspec.yaml`.
Tidak ada yang rusak, hanya belum dipakai. Yang penting: **jangan** claimsudah
terpasang kalau `pubspec.yaml` belum punya blok `flutter_launcher_icons` —
`flutter_launcher_icons` tidak ada di dev_dependencies berarti ikon belum
pernah di-generate.