# Splash animasi: aset apa yang benar-benar perlu diminta ke user

**Kapan dipakai:** user tanya "butuh gambar apa untuk bikin animasi splash?" —
dan hampir selalu jawabannya "GIF".

---

## Jawaban langsung

> **Kalau animasinya gw yang tulis kodenya → TIDAK PERLU gambar apa pun.**
> Kalau mau animasi artistik → **cukup 1 file: SVG.**

SVG karena vektor: bisa di-raster ke ukuran apa pun tanpa pecah, bisa
diwarna ulang, dan bisa dipakai sumber buat semua format di bawah.

---

## Kenapa GIF itu pilihan buruk (dan kenapa user tetap suka nanya)

| Masalah GIF | Akibat di aplikasi |
|---|---|
| Maks **256 warna** | hijau brand `#1B5E20` + gradasian halus = **ngeband** kelihatan |
| Alpha **1-bit** (hanya transparan/tidak) | tepi logo **bergigit**, warna latar ter-bake jadi kotak |
| Palet global | satu animasi tidak bisa cocok untuk tema terang **dan** gelap |
| Ukuran | loop 2 detik 1080p = **1–3 MB**, dan tidak bisa di-scale 4K |
| Durasi | motion 15 fps kelihatan **tersendat-sendat** |

Untuk logo di atas gradasian halus, GIF hampir selalu terlihat lebih murah
dibanding animasi vektor atau yang digambar di kode.

---

## Pilihan format (urut dari yang paling saya rekomendasikan)

### 1. Animasi di dalam kode Flutter — ⭐ paling sering paling bagus
`CustomPaint` + `AnimationController`. **Nol aset.**
- Tajam di semua ukuran & semua DPI (vektor)
- Ikut tema terang/gelang karena warnanya dari `Theme.of`
-Ukuran APK nambah 0 byte
- BisaPkg interaksi dengan state aplikasi
Skill: `splash-animation-assets-what-to-ask-for`.

### 2. Rive `.riv` — ⭐ terbaik kalau perlu motion dari desainer
- Vektor, kecil (biasanya < 50 KB), runtime (bukan video)
- **Bisa di-recolor dari Dart** → satu file untuk terang & gelap
- State machine: bisa bereaksi (mis. logo berubah saat selesai memuat)
- Dibuat di Rive Editor. ⛔ bukan `.svg` — Rive punya format sendiri.

### 3. Lottie `.json`
- Hasil ekspor After Effects, vektor, ringan
- Ecosystem besar, banyak animasi gratis siap pakai
- Warnanya bisa di-override sebagian, tapi tidak sesederhana Rive
- Perlu `lottie` di pubspec

### 4. MP4 / WebM
- Untuk animasi **sinematik** full-screen (mis. ilustrasi berputar)
- ⛔ warna & latar **ter-bake** → harus dua file (terang + gelap)
- ⛔ tidak bisa di-recolor
- ⚠️ Android butuh codec yang benar; pakai H.264 MP4 paling aman
- Butuh `video_player` atau `better_player`

### 5. APNG (bukan GIF)
- 24/32-bit penuh + alpha penuh, animasi mulus
- Tidak didukung: `Image.asset` tidak otomatis-animate APNG di semua versi;
  butuh decoding manual atau paket
- Tetap tidak bisa di-recolor dan tetap ter-bake ke tema

---

## ⚠️ Android 12+ sudah punya splash animasi sendiri

Sejak Android 12 (SplashScreen API), **launcher bisa merender ikon aplikasi
dengan animasi masuk sendiri** — tanpa file apa pun. Kalau yang dituju cuma
"logo app harus kelihatan modern saat dibuka", kemungkinan besar **tidak
perlu aset sama sekali**; yang perlu cuma configure:

```yaml
# android/app/src/main/res/values/styles.xml (atau via patch script)
<item name="android:windowSplashScreenBackground">@color/splash_bg</item>
<item name="android:windowSplashScreenAnimatedIcon">@drawable/ic_splash</item>
<item name="android:windowSplashScreenIconBackgroundColor">@color/brand</item>
```

Splash **sistem** ini gratis, mulus, dan tidak menambah ukuran APK. Tapi
lama maksnya hanya sampai activity pertama tampil, jadi untuk branding yang
lebih lama tetap butuh layar splash sendiri.

---

## Cara menjawab user

Jangan langsung bilang "butuh GIF". Tanya balik bentuknya:

> Animasi yang lo mau itu **logo-nya bergerak sendiri** (mis. berdenyut,
> berputar), atau **ada ilustrasi** yang bergerak?

- Kalau "logo bergerak" → **tidak perlu gambar**. SAYA tulis kodenya.
- Kalau "ada ilustrasi" → **kirim 1 file SVG** (bukan PNG) sebagai master.

Satu-satunya aset yang selalu berguna: **SVG master**, karena vektor bisa
direduksi ke semua format di atas tanpa kehilangan mutu.