#!/usr/bin/env python3
"""Pratinjau halaman Login (v3.0.2) tanpa Flutter.

Angka dp di bawah ini adalah SALINAN dari `layar_login.dart`. Tujuannya bukan
menggambar cantik, tapi menjawab tiga pertanyaan yang tidak bisa dijawab dari
membaca kode:

  1. Apakah headline Playfair masih terbaca setelah digabung padding 24?
  2. Apakah ada elemen yang saling menumpuk / meluber keluar layar?
  3. Apakah lambang "G" dari 4 busur benar-benar terbaca sebagai huruf G?

Jalankan:  python3 design/preview_login.py
Hasil:     design/pratinjau-login.png
"""
from PIL import Image, ImageDraw, ImageFont

SCALE = 2  # digambar 2x lalu diperkecil -> tepi huruf halus
OUT = "design/pratinjau-login.png"

# --- token warna (dari lib/core/theme/app_colors.dart) ----------------------
BRAND = (0x5B, 0x5B, 0xD6)
INK_DARK = (0x0B, 0x0B, 0x10)
SURFACE_DARK = (0x12, 0x12, 0x18)
SURFACE_LIGHT = (0xFB, 0xFB, 0xFD)
LINE_DARK = (0x26, 0x26, 0x2F)
LINE_LIGHT = (0xE7, 0xE7, 0xEE)
TEXT_DARK = (0xF2, 0xF2, 0xF7)
TEXT_LIGHT = (0x14, 0x14, 0x1A)
MUTED_DARK = (0x9A, 0x9A, 0xA8)
MUTED_LIGHT = (0x6B, 0x6B, 0x78)
G_BLUE = (0x42, 0x85, 0xF4)
G_GREEN = (0x34, 0xA8, 0x53)
G_YELLOW = (0xFB, 0xBC, 0x05)
G_RED = (0xEA, 0x43, 0x35)
WHITE = (0xFF, 0xFF, 0xFF)

ASSETS = "assets/fonts"
INTER_R = f"{ASSETS}/Inter-Regular.ttf"
INTER_M = f"{ASSETS}/Inter-Medium.ttf"
INTER_SB = f"{ASSETS}/Inter-SemiBold.ttf"
INTER_EB = f"{ASSETS}/Inter-ExtraBold.ttf"
PLAYFAIR_SB = f"{ASSETS}/PlayfairDisplay-SemiBold.ttf"


def font(path, px):
    return ImageFont.truetype(path, int(px * SCALE))


def bungkus(d, teks, f, maxw):
    """Bungkus teks jadi baris-baris, diukur dari font aslinya.

    Memakai lebar piksel nyata, bukan perkiraan jumlah huruf: Playfair jauh
    lebih lebar dari Inter, jadi perkiraan panjang karakter akan menipu.
    """
    kata, baris, kini = teks.split(), [], ""
    for k in kata:
        coba = f"{kini} {k}".strip()
        if d.textlength(coba, font=f) <= maxw or not kini:
            kini = coba
        else:
            baris.append(kini)
            kini = k
    if kini:
        baris.append(kini)
    return baris


def lampang_g(d, cx, cy, size):
    """Lambang Google: 4 busur + batang biru (sudut sama dengan Dart)."""
    r = size * 0.33
    tebal = size * 0.22
    kotak = [cx - r, cy - r, cx + r, cy + r]
    for mulai, sapu, w in ((21, 80, G_GREEN), (100, 91, G_YELLOW),
                           (190, 111, G_RED), (299, 59, G_BLUE)):
        d.arc(kotak, mulai, mulai + sapu, fill=w, width=int(tebal))
    d.rectangle([cx, cy - tebal / 2, cx + r + tebal / 2, cy + tebal / 2], fill=G_BLUE)


def panel(W, H, gelap, email_isi):
    img = Image.new("RGB", (int(W * SCALE), int(H * SCALE)),
                    INK_DARK if gelap else SURFACE_LIGHT)
    d = ImageDraw.Draw(img)
    permukaan = SURFACE_DARK if gelap else WHITE
    garis = LINE_DARK if gelap else LINE_LIGHT
    redup = MUTED_DARK if gelap else MUTED_LIGHT
    teks = TEXT_DARK if gelap else TEXT_LIGHT
    pad = 24 * SCALE
    maxw = min(W - 48, 420) * SCALE
    kiri = (W * SCALE - maxw) / 2
    y = 28 * SCALE

    def tengah(teks_, f, warna, puncak=0):
        nonlocal y
        for b in bungkus(d, teks_, f, maxw):
            d.text((kiri + maxw / 2, y + puncak), b, font=f, fill=warna,
                   anchor="ma")
            y += f.size * 1.18

    # --- _Merek ---
    kotak = 30 * SCALE
    x0 = kiri + (maxw - (kotak + 10 * SCALE + d.textlength("DIVJUN AI",
                 font=font(INTER_EB, 15)))) / 2
    d.rounded_rectangle([x0, y, x0 + kotak, y + kotak], radius=9 * SCALE,
                        fill=BRAND)
    d.text((x0 + kotak / 2, y + kotak / 2), "D", font=font(INTER_EB, 15),
           fill=WHITE, anchor="mm")
    d.text((x0 + kotak + 10 * SCALE, y + kotak / 2), "DIVJUN AI",
           font=font(INTER_EB, 15), fill=teks, anchor="lm")
    y += kotak + 26 * SCALE

    # --- _IlustrasiNapas (satu frame: cincin 60% + inti bernapas) ---
    uk = 120 * SCALE
    cx, cy = kiri + maxw / 2, y + uk / 2
    d.ellipse([cx - uk * 0.43, cy - uk * 0.43, cx + uk * 0.43, cy + uk * 0.43],
              outline=(255, 255, 255) if gelap else BRAND, width=1 * SCALE)
    d.arc([cx - uk * 0.495, cy - uk * 0.495, cx + uk * 0.495, cy + uk * 0.495],
          -90, -90 + 360 * 0.6, fill=BRAND, width=int(2.4 * SCALE))
    d.ellipse([cx - uk * 0.30, cy - uk * 0.30, cx + uk * 0.30, cy + uk * 0.30],
              fill=tuple(int(BRAND[i] * 0.14 + (INK_DARK if gelap else
                        SURFACE_LIGHT)[i] * 0.86) for i in range(3)))
    d.ellipse([cx - uk * 0.21, cy - uk * 0.21, cx + uk * 0.21, cy + uk * 0.21],
              fill=BRAND)
    d.text((cx, cy), "D", font=font(INTER_EB, 28), fill=WHITE, anchor="mm")
    y += uk + 26 * SCALE

    # --- headline + subjudul ---
    tengah("Masuk untuk melanjutkan", font(PLAYFAIR_SB, 30), teks)
    y += 12 * SCALE
    tengah("DIVJUN AI mengingat konteks percakapanmu dan bisa memakai alat "
           "saat dibutuhkan.", font(INTER_R, 13.5), redup)
    y += 30 * SCALE

    # --- tombol Google ---
    tg = 52 * SCALE
    d.rounded_rectangle([kiri, y, kiri + maxw, y + tg], radius=14 * SCALE,
                        fill=permukaan, outline=garis, width=1 * SCALE)
    tl = d.textlength("Lanjutkan dengan Google", font=font(INTER_SB, 14.5))
    isi = 19 * SCALE + 11 * SCALE + tl
    xg = kiri + (maxw - isi) / 2
    lampang_g(d, xg + 9.5 * SCALE, y + tg / 2, 19 * SCALE)
    d.text((xg + 30 * SCALE, y + tg / 2), "Lanjutkan dengan Google",
           font=font(INTER_SB, 14.5), fill=teks, anchor="lm")
    y += tg + 22 * SCALE

    # --- pembatas ATAU ---
    fk = font(INTER_SB, 10.5)
    lk = d.textlength("ATAU", font=fk)
    d.line([kiri, y + 7 * SCALE, kiri + maxw / 2 - lk / 2 - 12 * SCALE,
            y + 7 * SCALE], fill=garis, width=1 * SCALE)
    d.line([kiri + maxw / 2 + lk / 2 + 12 * SCALE, y + 7 * SCALE,
            kiri + maxw, y + 7 * SCALE], fill=garis, width=1 * SCALE)
    d.text((kiri + maxw / 2, y + 7 * SCALE), "ATAU", font=fk, fill=redup,
           anchor="mm")
    y += 22 * SCALE

    # --- kolom email ---
    tf = 56 * SCALE
    d.rounded_rectangle([kiri, y, kiri + maxw, y + tf], radius=14 * SCALE,
                        fill=permukaan, outline=garis, width=1 * SCALE)
    d.text((kiri + 16 * SCALE, y + tf / 2), "\u2709", font=font(INTER_R, 15),
           fill=redup, anchor="lm")
    d.text((kiri + 42 * SCALE, y + tf / 2),
           email_isi or "Masukkan email Anda", font=font(INTER_R, 14.5),
           fill=teks if email_isi else redup, anchor="lm")
    y += tf

    if email_isi:
        y += 14 * SCALE
        d.rounded_rectangle([kiri, y, kiri + maxw, y + 52 * SCALE],
                            radius=14 * SCALE, fill=BRAND)
        d.text((kiri + maxw / 2, y + 26 * SCALE), "Lanjut",
               font=font(INTER_SB, 15), fill=WHITE, anchor="mm")
        y += 52 * SCALE

    y += 24 * SCALE
    tengah("Dengan melanjutkan, Anda menyetujui Syarat Layanan dan Kebijakan "
           "Privasi DIVJUN AI.", font(INTER_R, 11),
           tuple(int(redup[i] * 0.6 + (INK_DARK if gelap else SURFACE_LIGHT)[i]
                     * 0.4) for i in range(3)))
    return img.resize((int(W), int(H)), Image.LANCZOS), y / SCALE


bayang, akhir = panel(360, 800, True, "mahen@example.com")
bayang2, akhir2 = panel(412, 915, False, "")
# Detail lambang G: 96 px, supaya bentuknya benar-benar bisa dinilai.
det = Image.new("RGB", (96 * SCALE, 96 * SCALE), WHITE)
lampang_g(ImageDraw.Draw(det), 48 * SCALE, 48 * SCALE, 96 * SCALE)
det = det.resize((96, 96), Image.LANCZOS)

kanvas = Image.new("RGB", (360 + 412 + 60 + 160, 950), (30, 30, 34))
kanvas.paste(bayang, (20, 20))
kanvas.paste(bayang2, (400, 20))
kanvas.paste(det, (830, 20))
d2 = ImageDraw.Draw(kanvas)
d2.text((830, 130), "G x96", fill=(200, 200, 210))
kanvas.save(OUT)
print(f"OK {OUT} | tinggi isi 360x800 = {akhir:.0f}dp (muat: {akhir <= 800})")
print(f"            412x915 = {akhir2:.0f}dp (muat: {akhir2 <= 915})")
