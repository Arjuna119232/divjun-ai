---
name: merge-zip-baru-dgn-repo-lebih-baru
description: Cara aman menggabungkan ZIP hasil kerja AI lain ke repo yang sudah lebih baru - selalu audit versi dasar ZIP dulu, jangan pakai `diff` pada file yang barusan disalin, dan kembalikan dependensi pubspec yang hilang
metadata:
  type: feedback
---

# Menggabungkan ZIP "v6.0" ke repo yang sudah lebih baru (16 Okt 2026)

**Konteks:** user kirim `KUNBAR-Connect-v6_0_0-source.zip` (3,6 MB) hasil kerja
AI lain (Acode). Repo `Arjuna119232/karta-kubar` branch `feat/ui-overhaul-v6`
sudah di v0.12.0 (PHASE A-D). Hasil akhir harus `0.12.1`.

## Temuan utama: ZIP berbasis versi LAMA, bukan versi terbaru

Isi ZIP `PROGRESS.md` sendiri "Versi aplikasi: 0.11.0+21". Artinya AI
itu bekerja dari `KUNBAR-Connect-v0.11.0-source.zip`, BUKAN dari v0.12.0 yang
kita kirim. Akibatnya **PHASE B/C/D ikut hilang** — bukan karena AI salah,
tapi karena tidak pernah menerima file itu.

Jejak: `tool/check_dart.py` di ZIP identik dgn repo (memang Phase D tooling),
tapi `lib/` dan `pubspec.yaml` versi lama. **Jadi " tooling sama" bukan bukti
"basis sama".**

## Jebakan yang memakan waktu: `diff` pada file yang BARUSAN disalin

```
for f in $(...); do diff -q "$f" "$HOME/repo/$f"; done   # SALAH
```
Loop jalan dengan `cd ~/repo` di awal, jadi `$f` relatif ke repo → membandingkan
file dengan dirinya sendiri → semua "SAMA"._tool/ dan `.github/` terlihat sama
padahal `git diff` menunjukkan 211 baris check_dart.py hilang.

**Aturan: bandingkan ZIP vs `git show HEAD:<path>`, bukan vs working tree.**

## Jebakan ke-2: `python3` multi-`replace` tanpa assert = gagal diam

Rangkaian `s.replace(a,b)` lalu `assert s != o` HANYA membuktikan "ada yang
berubah", bukan "semua target kena". Di galeri_screen 1 dari 3 replace gagal
karena replace sebelumnya sudah mengubah anchor-nya
(`_Media(` → `_MediaContoh(` ruin the `class _Media {` anchor).

**Aturan: `assert anchor in s` untuk SETIAP replace**, bukan satu assert di akhir.

## Jebakan ke-3: `extension onCls` bikin checker membaca `on` sebagai simbol

`extension on KeuanganScreen {` → parser top-level symbol regex membaca `on`
sebagai deklarasi → 12 false-positive MISSING-IMPORT di 12 file lain.
Ganti jadi fungsi top-level biasa (`Future<void> _unduhLaporan(...)`).

## Yang harus dicek SETIAP kali (bukan cuma "build hijau")

1. **`pubspec.yaml` jangan ikut tertimpa.** ZIP lama kehilangan 4 dependensi
   (`share_plus`, `cross_file`, `image_picker`, `path_provider`) →
   CI: `Undefined name 'Share'`, `Method not found: 'XFile'`. Di-backup dengan
   `git checkout -- pubspec.yaml` lalu deps ditulis ulang + versi di-bump.
2. **Simbol SDK yang butuh import khusus.** `CupertinoPageTransitionsBuilder`
   ada di library **cupertino**, bukan material → `Method not found` padahal
   `import 'package:flutter/material.dart'` sudah ada. Verifikasi lewat
   `api.flutter.dev/flutter/cupertino/...` (bukan `/flutter/widgets/...`
   yang 404).
3. **Konsistensi nama field statis.** `static const List<X> _media` vs pemakaian
   `_contoh` → `undefined name`. `check_dart.py` TIDAK menangkap ini (identifier
   privat dicek hanya untuk DEAD-FILE).
4. **Aset yang dipanggil tapi tidak ada.** `art: 'empty_galeri'` tapi
   `assets/ilustrasi/empty_galeri.svg` tidak ada → runtime crash saat galeri
   kosong, build tetap hijau. Buat SVG-nya (`rsvg-convert` render → LIHAT).

## Jebakan "kebetulan": `role.bisa(anggota) ? 'Kas' : 'Galeri'`

Kelihatan seperti bug tapi BENAR: tab `Galeri` hanya untuk tamu/warga, anggota
ke atas dapat tab `Kas` (lihat `tabsUntuk()` di `features/shell/data/app_tabs.dart`).
"Perbaikan" yang menyamakan ke `'Galeri'` justru BREAK anggota. Roads:
`_QuickItem(Ik.gallery, ...)` harus `context.push('/galeri')`, bukan `_keTab`.

## Merge yang benar untuk kasus ZIP-lama-di atas

- **BASE = ZIP** untuk `lib/`, `assets/`, `design/` (itu Override tampilan baru).
- **BASE = repo HEAD** untuk `.github/`, `tool/`, `pubspec.yaml` deps
  (lebih baru & punya `release` input + checker termkuat).
- **Kembalikan fitur yang hilang dari ZIP** dari git HEAD, lalu PORT ke layer
  widget baru (lihat `Haptics.ringan()` → `Haptics.light()`,
  `AppSheet.tampilkan(judul:,isi:)` → `AppSheet.show(builder:)`).
- **Hapus** widget ZIP yang tidak di-import siapa pun (`glass_card`,
  `modern_card`, `animated_button`) — aturan main: 0 kode mati.

## Skill baru di `tool/check_dart.py`: `PAKET-HILANG`

```python
PKG_IMPORT = re.compile(r"""import\s+'package:([a-z0-9_]+)/""")
# tiap paket yang di-import kode harus terdaftar di pubspec.yaml
```
Menutup kelas bug "dependensi hilang saat pubspec ditimpa". Fault injection
(hapus `share_plus`) → tertangkap, exit 1.

## Urutan build yang benar (Branch, bukan main)

```bash
git checkout feat/ui-overhaul-v6 && git pull --ff-only
# ... merge ...
python3 tool/check_dart.py && python3 tool/check_nonlatin.py
git push origin feat/ui-overhaul-v6          # push ke branch TIDAK memicu build
gh workflow run build.yml --ref feat/ui-overhaul-v6 -f demo=true -f abi=arm64 -f release=yes
```

## Kasus `kunbar-fix-3bug.zip` (17 Okt 2026) — 3 pelajaran baru

### 1. `num.clamp()` KEMBALIANNYA `num` → compile error yang MEMBLOKIR build

```dart
double zoom = (math.log(...) / math.ln2).clamp(11.0, 16.0);   // ❌ num → double
zoom = z < 11.0 ? 11.0 : (z > 16.0 ? 16.0 : z);               // ✅ eksplisit
```
Di proyek ini `flutter analyze` **memblokir** (tanpa `|| true`), jadi satu
type error = build gagal total. Kalau butuh angka dari `clamp`, tulis
ternary eksplisit atau tambah `.toDouble()`. Nulis `11.0/16.0` (bukan
`11`/`16`) menghapus keraguan inferensi int-literal.

### 2. Parser brace buatan sendiri TIDAK BISA dipercaya untuk Dart

Dua script berbeda (regex vs state-machine) **saling bertentangan** di
berkas yang sama — string berinterpolasi bersarang `'${e['lat']}'`
membingungkan keduanya. Jangan habiskan waktu menulis parser ketiga.

- **Gerbang lokal yang SAH cuma `tool/check_dart.py`** (punya cek `BRACE`,
  baris ~409). Kalau dia bilang `OK - 0 masalah`, sudah cukup.
- **Verifikator sebenarnya = `flutter analyze` di CI.** Jalankan
  `-f analyze-only=yes` (~2 menit, tanpa APK) sebagai oracle.

### 3. Ambil SEBAGIAN, bukan bulat — dan tulis apa yang DITOLAK

Paket itu benar di 3 bug, tapi salah koordinat (`-6.2500,106.8230` meleset
~1,3 km dari `-6.2365,106.8219`), dan `mitra_usaha.dart`-nya pakai hex
`Color` mentah + `Icons` Material (melanggar `AppColors` + `Ik`/`AppIcon`).

- File yang isinya benar → **`cp` bulat** (verifikasi `sha256sum` cocok).
- File yang cuma sebagian benar → **edit tangan**, jangan `cp`.
- Catat daftar **DITOLAK** di commit message + memori supaya tidak
  ditinjau ulang tahun depan.

### 4. Cara paling cepat tahu itu PATCH atau CABANG PENUH: signature check

Paket kedua (`kunbar-full-fix.zip`, "full fix") ternyata **cabang penuh**,
bukan patch. Unduh 20 detik untuk 4 signature ini:

| Signature | Patch (= repo sekarang) | Cabang (= repo lama) |
| --- | --- | --- |
| `titikKuninganBarat` | `-6.2365, 106.8219` | `-6.2500, 106.8230` |
| import peta | `any_map` + `any_map_maplibre` | `flutter_map` + `latlong2` |
| warna | `AppColors.primary` | `const Color(0xFF1B5E20)` |
| nama berkas | `lokasi_service.dart` | `core/services/location_service.dart` |

Kalau **empatnya flipped**, paket itu disusun dari tree lama: **jangan
merge sama sekali**, tulis tabel tolak + ambil 1 perbaikan yang benar.

Tanda tambahan yang mengonfirmasi: `version:` di `pubspec.yaml` **lebih
baru** dari isi `lib/` (paket bilang 0.14.0+28 tapi koordinatnya pre-fix) —
artinya AI itu mengambil nomor versi dari repo, bukan kodenya.

### 5. "Belum ada" ≠ "belum dicek" — cari dulu sebelum menyimpulkan

Dugaan awal: peta mitra tidak punya detail, GPS tidak menampilkan nama.
Setelah dibaca: HEAD sudah punya `_KartuTerpilih` (Positioned di bawah),
kamera auto-fit, pin per kategori, dan `reverseAlamat()` di
`lokasi_service.dart`. Yang benar-benar kurang **satu baris** —
`_jemput.text = hasil.data!.teks` mengembalikan koordinat mentah.

Jadi rebutan "fitur yang ZIP tambahkan" itu harus dicari dulu, bukan langsung
diterima. Sebutkan di laporan: mana yang ternyata sudah ada, mana yang
benar-benar hilang.
