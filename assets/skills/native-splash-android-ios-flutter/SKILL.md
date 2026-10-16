---
name: native-splash-android-ios-flutter
description: Mengganti splash screen Flutter buatan sendiri dengan splash NATIVE Android 12+ (Theme.SplashScreen) dan iOS (UILaunchScreen) supaya hanya logo + warna solid, maksimal 1,2 detik, tanpa frame putih. Termasuk perhitungan mask circle 192dp yang sering bikin logo terpotong, dan 8 jebakan verifier yang ditemukan lewat fault injection. Gunakan saat user minta "splash sesuai standar 2026", "splash native", "hapus animasi splash", "zero visual jump", atau mengeluh splash kepanjangan / logo kepotong / ada kedip putih saat app dibuka.
---

# Splash native untuk Flutter (Android 12+ & iOS)

## Kenapa Flutter perlu effort ekstra

Flutter menggambar frame pertamanya sendiri. Jadi:
- Splash native hanya menutupi **sampai frame pertama Flutter** digambar.
- Kalau tujuan rute baru diputuskan setelah frame pertama, aplikasi sempat
  menggambar satu halaman penuh (biasanya kosong) sebelum halaman yang benar.
- Solusinya: baca prefs **sebelum `runApp`**, set `initialLocation` langsung.

## Geometri Android 12+ (angka yang sering dilupakan)

```
kotak drawable        288 dp
mask lingkaran       192 dp diameter  (= 288 * 2/3)  -> jari-jari 96 dp
canvas 512 px        ->  1 px = 288/512 = 0,5625 dp
jari-jari mask       ->  96 / 0,5625  = 170,7 px
```

Logo **harus** punya radius true <= 96 dp, kalau tidak Android memotongnya
diam-diam (build hijau, splashibi login catastrophrophe yang baru terlihat di
perangkat).

### Mengukur radius TRUE, bukan half-diagonal bounding box

Logo figuratif (pohon, warga, pin) punya sudut kotak yang KOSONG. Half-diagonal
akan says overestimated → logo hanya jadi 58 dp dari 96 dp (kelihatan kecil).
Hitung jarak terbesar dari titik tengah ke piksel alpha > 0:

```python
a = img.split()[3]
cx, cy = (w - 1) / 2, (h - 1) / 2
r = max(math.hypot(x - cx, y - cy) for y in range(0, h, 2)
                          for x in range(0, w, 2) if a.load()[x, y] > 8)
```

Sebaliknya, untuk aset berbentuk LINGKARAN (badge), half-diagonal justru
says overestimated lebih parah — sudut kotak justru yang transparan.

## iOS: ukuran intrinsik, bukan mask

`UILaunchScreen` memakai ukuran intrinsik gambar dalam POINT. PNG Android
512 px akan tampil 512 pt dan memenuhi layar. Buat aset terpisah 160 pt,
dengan @2x dan @3x di asset catalog.

Aset iOS **tidak boleh** diverifikasi terhadap mask circle Android — keduanya
dua sistem yang berbeda total.

## Pola di proyek yang build-nya di CI

Kalau `android/` dan `ios/` di-generate ulang tiap CI run oleh `flutter create`,
semua file native **hilang**. Wajib patch script idempoten, bukan edit manual.
Lihat pola `tool/patch_signing.py` yang sudah dipakai proyek KUNBAR Connect.

## 8 jebakan verifier (semua ditemukan dengan fault injection)

**Aturan utama: jangan pernah menulis cek yang membandingkan konstanta dengan
dirinya sendiri, dan jangan pernah mencari teks yang juga muncul di komentar.**

1. `find("installSplashScreen")` → nama yang sama ada di baris `import`, posisinya
   selalu lebih dulu → cek urutan **selalu lulus**. Cari `installSplashScreen()`.
2. Cek urutan membaca **komentar** `// ... SEBELUM super.onCreate()` →
   `super.onCreate` ketemu di komentar → cek selalu **gagal**. Buang komentar dulu.
3. Cek XML cari `Theme.SplashScreen` → kalimat sama ada di
   `<!-- ... (Theme.SplashScreen) -->` → cek selalu **lulus**. Buang `<!-- -->`.
4. `Color(0xFF1B5E20)` diambil 6 digit → alpha `FF` ikut terambil → warna brand
   selalu dianggap tidak cocok. Tangkap 8 digit `AARRGGBB`, ambil 6 terakhir.
5. Verifikasi bandingkan konstanta dengan dirinya sendiri → ganti `BRAND_HEX` →
   yang ditulis DAN yang diharapkan ikut berubah → **selalu lolos**.
   Bandingkan ke sumber kebenaran di kode app (`app_colors.dart`).
6. Batas durasi dicek dari file XML → file ditulis ulang tiap jalan → nilainya
   selalu sama → cek sia-sia. Cek dari konstanta.
7. Fault injection yang mengganti konstanta **sekaligus** mengganti ekspektasi
   = self-consistent = lolos. Uji guard dengan merusak **output**, bukan script,
   dan tambahkan flag `--verify-only` supaya file tidak diperbaiki sendiri.
8. `putalpha` saat preview = **mengganti** alpha (harusnya dikalikan dengan mask).
   Pakai `ImageChops.multiply` → kalau tidak muncul lingkaran hitam misterius.

## Urutan yang benar (MainActivity.kt)

```kotlin
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()   // WAJIB sebelum super.onCreate()
        super.onCreate(savedInstanceState)
    }
}
```

Template Flutter terbaru = `class MainActivity : FlutterActivity()` **tanpa
body** (satu baris). Regex harus menangani dua bentuk: dengan dan tanpa `{`.

## Tanpa `setKeepOnScreenCondition`

Kalau dipanggil dengan kondisi `true`, splash ditahan → bisa lewat 1,2 detik.
Tanpa pemanggilan, splash hilang tepat saat frame pertama → durasi = waktu
startup, selalu di bawah batas.

## Yang tidak bisa 100%epenuhi

Warna splash hijau ke halaman pertama berlatar terang **tidak bisa** nol
transisi di Flutter: OS menutupnya dengan crossfade ~200 ms. Yang bisa
dijamin = tidak ada frame putih/kosong. Kalau benar-benar perlu identik:
ubah `Scaffold(backgroundColor:)` halaman pertama jadi warna brand (1 baris
per file, tapi seluruh desain terang ikut berubah).

## Teks di splash: batas keras API (dari docs resmi, sudah diverifikasi 15 Okt 2026)

**Android 12+ tidak punya API teks sama sekali.** Hanya dua slot gambar:

| Slot | Atribut | Ukuran | Keterangan |
|---|---|---|---|
| Ikon tengah | `windowSplashScreenAnimatedIcon` | 288dp, muat **circle 192dp** | Mask wajib |
| Yang paling bawah | `android:windowSplashScreenBrandingImage` | **200×80 dp** | ⚠️ ATRIBUT **PLATFORM**, hanya API 31+ |

- `core-splashscreen` **tidak** meng-backport branding image ke Android 11 ke bawah.
- Branding image wajib ada di **semua density** (`hdpi` 1,5× / `xhdpi` 2× /
  `xxhdpi` 3× / `xxxhdpi` 4×). Kalau hanya satu, Android pakai yang terkecil → teks pecah.
- **JANGAN** taruh branding image di `drawable-nodpi`: nodpi = 1 px = 1 dp,
  jadi file 600 px akan jadi **600 dp** — delapan kali lebih besar dari slotnya.

Cara menampilkan nama aplikasi: **gambar sendiri di dalam drawable ikon**
(lockup emblem + wordmark di dalam circle 192dp). Konsekuensinya emblem harus
dikecilkan, karena sudut kotak lockup itulah yang menyentuh batas mask.

**iOS**: `UILaunchScreen` hanya menerima `UIColorName`, `UIImageName`,
`UIImageRespectsSafeAreaInsets`, dan elemen border. **Tidak ada teks, tidak ada
kontrol posisi** — gambar selalu dipusatkan. Semua elemen harus digabung jadi
satu gambar, dan kredit "di paling bawah" **tidak bisa** di iOS.

### Mengukur tinggi teks

Jangkarkan teks di tengah (`anchor="lm"`), lalu ukur tinggi dari bbox AKTUAL
piksel alpha yang terisi — bukan dari ukuran font. Meng pakai tinggi font
membuat baris meleset karena ascender Roboto jauh lebih tinggi dari huruf yang
terlihat.

### Memusatkan blok

Jangan patok posisi (`y = canvas * 0.68`). Hitung tinggi tiap elemen dari
tinggi visual yang terukur, lalu pusatkan. Begitu font atau emblem diganti,
posisi yang dipatok meleset keluar mask — dan build tetap hijau.

**Hitung tinggi setiap elemen bergantian, termasuk jarak emblem ke baris
pertama.** Kalau jaraknya lupa dihitung, emblem menimpa teks — dan ini cuma
terlihat kalau kamu render lalu LIHAT, bukan dari kode.

### Menentukan ukuran font: SEARCH, bukan tebakan

Untuk lockup beberapa baris di dalam circle 192dp, jangan mengira-ngira.
Brute-force kecil yang maximize ukuran teks dengan syarat (radius terpakai,
radius minimum emblem, gap minimum) berjalan dalam <2 detik kalau tinggi
teks di-cache dulu — render ulang tiap iterasi membuatnya timeout.

Cap height Roboto Bold ≈ **0,73 × font size** untuk huruf kapital, tapi
ukur dari bbox alpha kalau bisa.

### Branding image: format & guard

Slot 200×80 dp **tidak ikut berskala dengan lebar layar** (selalu 200dp),
jadi ukuran font dipilih agar proporsinya di dalam kotak itu, bukan mengikuti
ukuran layar. Teks occupies ~70% lebar slot.

Selalu ukur rasio isi slot dari bbox alpha dan guard:
- **>90%** lebar slot → tepi glyph terpotong
- **<45%** → kekecilan, tidak terbaca

### Kalau user minta "hapus yang ini" tapi sudah tidak ada

Cek dulu sebelum_edit. Kalau elemen yang dimaksud **sudah hilang** karena
refactor sebelumnya, jangan diam-diam bikin perubahan kosong — bilang terus
terang bahwa memang sudah tidak ada, lalu kerjakan bagian permintaannya yang
**masih relevan** (misal format teks yang perlu dikembalikan ke gaya awal).

Untuk spinner: bedakan spinner di jalur yang diminta vs di layar lain.
`CircularProgressIndicator` yang ada di guard rute tertentu **bukan** bagian
dari yang diminta, dan menghapusnya bisa reinstate bug yang sudah diperbaiki.
Jelaskan ke user, jangan hapus diam-diam.

## Checklist verifikasi

Lihat `tool/splash-checklist.md` di KUNBAR Connect untuk checklist lengkap per
aturan, plus pratinjau browser di `design/browser/splash-native.html`.
