---
name: icon-iteration-render-and-look
description: Cara membuat ikon aplikasi dari nol di Termux — bangun SVG parametrik, render pakai rsvg-convert, LIHAT hasilnya, dan 4 jebakan visual yang selalu muncul (lubang pin jadi gembok, elemen hilang karena kontras nilai sama, figur menyatu jadi gumpalan di ukuran kecil, garis tipis jadi antena). Pakai saat diminta desain ikon/aplikasi/favicon dan hasilnya dinilai dari tampilan.
---

# ICON: RENDER, LIHAT, PERBAIKI — jangan desain di buta

## Kenapa wajib

Gambar menipu di kode. Dua "ikon final" yang sama di file SVG bisa terlihat
sangat berbeda setelah dirender. Kalau tidak pernah **melihat PNG-nya**, yang
kamu kirim ke user belum tentu layak.

## Alur kerja di Termux

```bash
# 1. Tulis generator parametrik (bukan SVG tulisan tangan)
python3 gen_icon.py v1.svg

# 2. Render — cek dulu backend yang tersedia
python3 ~/.config/zyvo/skills/logo-design/logo-design/scripts/render_png.py --which
# typical Termux: rsvg-convert
rsvg-convert -w 512 -h 512 v1.svg -o renders/v1.png

# 3. LIHAT dengan read tool
# 4. Perbaiki -> v2.svg -> render -> lihat lagi. Ulangi minimal 3x.
```

Pillow (`PIL`) tersedia dan dipakai untuk membuat lembar uji ukuran kecil.

## Uji ukuran kecilWAJIB (48px)

```bash
for s in 1024 192 96 72 48; do rsvg-convert -w $s -h $s v.svg -o renders/s-$s.png; done
python3 - <<'PY'
from PIL import Image
imgs=[Image.open(f'renders/s-{s}.png').convert('RGBA') for s in (48,72,96)]
sheet=Image.new('RGBA',(420,220),(240,244,240,255)); x=10
for im in imgs:
    sheet.alpha_composite(im.resize((im.width*4,im.height*4), Image.NEAREST),(x,10))
    x+=im.width*4+20
sheet.convert('RGB').save('renders/small-test.png')
PY
```
`Image.NEAREST` supaya yang terlihat adalah piksel ASLI ukuran kecil, bukan
hasil interpolasi yang menutupi masalah aliasing.

## 4 JEBAKAN visual yang selalu muncul

### 1. Lubang besar di bentuk tetesan = GELOMBANG (padlock)
Location pin dengan lubang sebesar 0.46r + ujung pendek lebar -> mata
membaca "gembok". Perbaikan: **lubang kecil (0.28–0.30r)** dan ujung
**panjang & lancip** (control point curve dekat ujung, bukan melebar).

### 2. Elemen hilang karena kontras nilai sama
Kanopi `#2E7D32` di atas latar `#2E7D32` = pohon tidak terlihat sama sekali
padahal secara teknis ada. Aturan: **beda minimal ~30% luminansi** antara
elemen dan latar, atau beri outline/bahan yang lebih terang.

### 3. Figur "bergulat di atas" -> bidak catur
Badan berbentuk dome setengah lingkaran + kepala menempel = siluet bidak
catur/bowling pin. Perbaikan: **bahu melengkung** (path dengan dua `Q`),
kaki sedikit melebar, kepala ada jarak kecil dari bahu.

### 4. Elemen-detail di ukuran kecil jadi noise
- Garis tipis (12–15px di kanvas 1024) -> **0.5px di 48px** = antenna/jarum.
 - Akar/dahan tipis di v4 terbaca sebagai tanduk (horns).
  Kalau tidak tetap terbaca di 48px, **buang**.
- Bar penghubung yang lebar + objek berdekatan = **gumpalan putih**.
  Solusi: perbesar jarak antar objek DAN kecilkan garis penghubung
  (mis. 18px -> 11px, opacity .95 -> .6).

## Resep parameter yang berhasil (KUBAR Connect v7)

- Kanvas 1024, emblem circle r=384 di (512,512)
- Kanopi lebar 536, y 206–416, gradien #8CCF8E -> #57A85A -> #2E7D32
- Lokasi pin: r=84, cy=318, tip=436, gradasi emas
- Batang **ditaper** (lebar atas, ramping bawah) — persegi terbaca seperti balok
- 3 figur: lebar badan 84/102/84, skala 0.78/1.08/0.86, baseline 650,
  jarak pusat ±212 dari tengah
- Busur "berpegangan tangan": y≈560, stroke 11, opacity .62

## Jangan lupa

Simpan **semua iterasi** (v1..v7) — membandingkan versi awal dan akhir
justru cerita terbaik kalau user minta "kenapa berubah".

Kalau user membatalkan ("nanti aja"), **simpan file-nya di project** di
folder `design/icon/` supaya tidak hilang saat TMP dibersihkan — jangan
tetap di `$TMPDIR`.