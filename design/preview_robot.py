# -*- coding: utf-8 -*-
"""Render robot fallback + mock layout onboarding/login ke PNG.

Tujuannya BUKAN menggambar ulang app, tapi memeriksa gambar yang digambar
`CustomPainter` di `lib/shared/widgets/aset_robot.dart`: proporsi kepala/badan/
lengan, posisi tulisan "DIVJUN AI" di dada, dan apakah lengan melambai terlihat
terhubung. Semua koordinat diambil dari painter yang sama (kotak 100x100).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

KOTAK = 100  # sistem koordinat painter
SKALA = 6  # px per unit untuk render besar
LEBAR = 1080

BRAND = (91, 91, 214)
BRAND_DEEP = (59, 59, 168)
BRAND_SOFT = (230, 230, 255)
MINT = (0, 191, 166)
INK = (11, 11, 16)

F_BODY = "/system/fonts/RobotoFlex-Regular.ttf"
F_HEAD = os.path.expanduser(
    "~/divjun-flutter/assets/fonts/PlayfairDisplay-SemiBold.ttf"
)


def font(path, ukuran, bold=False):
    f = ImageFont.truetype(path, ukuran)
    if bold:
        try:
            f.set_variation_by_name("Bold")
        except Exception:
            pass
    return f


def grad_vert(img, kotak, atas, bawah, radius):
    """Rounded rect dengan gradasian vertikal (PIL tidak punya gradient shape)."""
    x0, y0, x1, y1 = kotak
    w, h = int(x1 - x0), int(y1 - y0)
    if w <= 0 or h <= 0:
        return
    grad = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(grad)
    for yy in range(h):
        t = yy / max(1, h - 1)
        d.line(
            [(0, yy), (w, yy)],
            fill=tuple(int(atas[i] + (bawah[i] - atas[i]) * t) for i in range(3)),
        )
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    img.paste(grad, (int(x0), int(y0)), mask)


def rounded(img, kotak, warna, radius, outline=None, lebar=1):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(kotak, radius=radius, fill=warna, outline=outline, width=lebar)


def robot(size_px, pose, t=0.25,标签=False):
    """Robot sesuai geometri _RobotPainter (sistem 100)."""
    s = size_px / KOTAK
    img = Image.new("RGBA", (size_px, size_px), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = size_px / 2
    cy = size_px / 2 + math.sin(t * 2 * math.pi) * 1.2 * s

    def P(x, y):
        return (cx + x * s, cy + y * s)

    # cahaya
    for i in range(14, 0, -1):
        r = 40 * i / 14 * s
        a = int(34 * (1 - i / 14))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BRAND + (a,))
    # bayangan
    d.ellipse([cx - 20 * s, cy + 39 * s, cx + 20 * s, cy + 45 * s], fill=(0, 0, 0, 70))

    # lengan digambar SESUDAH badan (sama seperti painter)
    grad_vert(img, (cx - 20 * s, cy + 2 * s, cx + 20 * s, cy + 36 * s), BRAND, BRAND_DEEP,
              int(11 * s))

    lengan = {
        "melambai": ((0.30, 24), (-2.45 + math.sin(t * 2 * math.pi) * 0.38, 26)),
        "berpikir": ((0.45, 24), (-2.80, 18)),
        "bekerja": ((1.05, 24), (-1.05, 24)),
        "mengingat": ((0.35, 24), (-2.30, 26)),
    }[pose]

    grad_vert(img, (cx - 7 * s, cy - 10 * s, cx + 7 * s, cy + 6 * s), BRAND_DEEP,
              BRAND_DEEP, int(4 * s))
    for x, (a, ln) in zip((-20, 20), lengan):
        ex, ey = x - math.sin(a) * ln, 11 + math.cos(a) * ln
        p0, p1 = P(x, 11), P(ex, ey)
        d.line([p0, p1], fill=BRAND_DEEP, width=max(2, int(6 * s)))
        d.ellipse([p0[0] - 3.6 * s, p0[1] - 3.6 * s, p0[0] + 3.6 * s, p0[1] + 3.6 * s],
                  fill=BRAND_DEEP)
        d.ellipse([p1[0] - 4.2 * s, p1[1] - 4.2 * s, p1[0] + 4.2 * s, p1[1] + 4.2 * s],
                  fill=(255, 255, 255, 255))

    # layar dada
    rounded(img, (cx - 14 * s, cy + 9 * s, cx + 14 * s, cy + 24 * s),
            BRAND_SOFT + (36,), int(4 * s), outline=(255, 255, 255, 77), lebar=1)
    if 标签:
        f = font(F_BODY, max(6, int(6.2 * s)))
        tx, ty = P(0, 16)
        w = d.textlength("DIVJUN AI", font=f)
        d.text((tx - w / 2, ty), "DIVJUN AI", font=f, fill=(255, 255, 255, 235))
    d.ellipse([cx - 1.8 * s, cy + 27.2 * s, cx + 1.8 * s, cy + 30.8 * s],
              fill=(255, 255, 255, 90))

    # antena
    d.line([P(0, -32), P(0, -40)], fill=BRAND_DEEP, width=max(2, int(2 * s)))
    d.ellipse([cx - 3 * s, cy - 45 * s, cx + 3 * s, cy - 39 * s], fill=MINT + (255,))

    # kepala
    # penanda pose (sama persis dengan _penandaPose di painter)
    if pose == "berpikir":
        for i in range(3):
            f = (t * 3 + i * 0.25) % 1
            r = (1.5 + i * 0.8) * s
            bx, by = P(12 + i * 7, -40 - f * 9)
            a = max(0, min(255, int(255 * (0.75 - f * 0.6))))
            d.ellipse([bx - r, by - r, bx + r, by + r], fill=MINT + (a,))
    elif pose == "bekerja":
        px_, py_ = P(37, 12)
        for dxp, sgn in ((-7, -1), (7, 1)):
            d.line([(px_ + dxp * s, py_), (px_ + dxp * s, py_ + 4 * s)], fill=MINT, width=2)
            d.line([(px_ + dxp * s, py_), (px_ + (dxp - sgn * 4) * s, py_)], fill=MINT, width=2)
    elif pose == "mengingat":
        d.line([P(37, -13), P(42, -8)], fill=MINT, width=3)
        d.line([P(42, -8), P(48, -17)], fill=MINT, width=3)

    grad_vert(img, (cx - 19 * s, cy - 32 * s, cx + 19 * s, cy - 6 * s),
              (255, 255, 255), BRAND_SOFT, int(9 * s))
    rounded(img, (cx - 14 * s, cy - 27 * s, cx + 14 * s, cy - 13 * s),
            INK + (224,), int(6 * s))
    kedip = (t % 1) > 0.94
    tinggi = 0.8 if kedip else 3.1
    for x in (-6.2, 6.2):
        rounded(img, (cx + (x - 2.2) * s, cy + (-20 - tinggi) * s,
                      cx + (x + 2.2) * s, cy + (-20 + tinggi) * s), MINT + (255,), int(2.2 * s))
    return img


def sheet():
    poses = ["melambai", "berpikir", "bekerja", "mengingat"]
    judul = {"melambai": "melambai (login)", "berpikir": "berpikir (h1)",
             "bekerja": "bekerja (h2)", "mengingat": "mengingat (h3)"}
    pad = 40
    ukuran = 220
    img = Image.new("RGB", (pad + len(poses) * (ukuran + pad), ukuran + 150), (14, 14, 22))
    d = ImageDraw.Draw(img)
    f = font(F_BODY, 22)
    for i, p in enumerate(poses):
        x = pad + i * (ukuran + pad)
        img.paste(robot(ukuran, p, t=0.15, 标签=True), (x, 40), robot(ukuran, p, 0.15, True))
        d.text((x, 40 + ukuran + 12), judul[p], font=f, fill=(210, 210, 235))
    # baris kedua: pose melambai pada 3 fase ayunan
    for k, t in enumerate((0.0, 0.12, 0.25)):
        im = robot(160, "melambai", t=t, 标签=True)
        img.paste(im, (pad + k * 200, 320), im)
        d.text((pad + k * 200, 492), f"ayunan t={t}", font=font(F_BODY, 18), fill=(170, 170, 200))
    return img


if __name__ == "__main__":
    out = os.path.expanduser("~/divjun-flutter/design/pratinjau-robot.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    s = sheet()
    s.save(out)
    print("tersimpan", out, s.size)