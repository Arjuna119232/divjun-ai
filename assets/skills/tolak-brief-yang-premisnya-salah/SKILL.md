# Menolak instruksi yang premisnya salah — buktikan, lalu kerjakan bagian yang Bernilai

Pola yang dipakai 15 Okt 2026 saat user meminta "bikin folder `apps/warga/`,
copy+refactor code existing, reuse dari `packages/shared/`".

## Kenapa ini penting

Instruksi_user sering datang dalam bentuk "brief" yang rapi tapi **berasal
dari asumsi tentang repo yang tidak ada**. Kalau langsung dieksekusi:

- duplikasi kode (dua APK untuk satu aplikasi)
- pekerjaan berjam-jam yang tidak menghasilkan apa pun yang dilihat pengguna
- pemindahan yang harus dibongkar lagi sebulan kemudian

Yang benar: **buktikan premisnya dengan perintah, laporkan yang tidak cocok,
lalu kerjakan bagian yang bernilai di semua interpretasi.**

## Langkah

1. **Uji tiap premis dengan perintah nyata, bukan Reading between the lines.**

```bash
ls packages apps 2>&1 | head -2      # "No such file or directory" = tidak ada
find lib -name "*.dart" | wc -l      # 54 file
grep -ln "lib/\|android/" tool/*.py .github/workflows/*.yml
```

2. **Hitung biaya restructure**, jangan cuma bilang "mahal". Angka konkret
   membuat user percaya: "6 file tooling + CI asumsi repo root = app root".

3. **Cek apakah fitur yang diminta "dihapus" benar-benar ada.** Kalau tidak
   ada, katakan. Menghapus tidak ada = 0 baris perubahan, dan itu informasi
   berguna (artinya daftar user menyalin template orang lain).

4. **Rewrite brief-nya dalam bahasa engineering**, lalu kerjakan bagian yang
   bernilai ny Regardless: dalam contoh ini "bikin APK warga yang lebih baik"
   tetap bisa jalan walau bentuk folder-nya nanti berubah.

5. **Jangan menahan pekerjaan.** Setelah koreksi, langsung eksekusi bagian
   yang pasti dibutuhkan. User dinilai dari hasil, bukan dari ketelitian.

## Contoh nyata (KUNBAR Connect)

| Premis user | Kenyataan di repo |
|---|---|
| "buat folder `apps/warga/`" | Repo cuma punya `lib/`. Satu app = satu APK |
| "reuse dari `packages/shared/`" | `packages/` tidak pernah ada |
| "hapus fitur admin" | Cuma 1 layar (`pengurus_screen`), sudah diputuskan pindah ke web |
| "hapus fitur mitra" | Fitur mitra tidak pernah ada di app ini (sisa template ojol) |
| "pakai design system existing" | ✅ Benar, dan itu yang dipakai |

Setelah pembuktian: tetap dibangun fitur yang benar-benar hilang (UMKM +
Lapor Darurat), yang bernilai di semua opsi struktur folder.

## Pelajaran tambahan

- **"Shared code" lintas bahasa tidak nyata.** APK Dart dan web Node tidak
  bisa berbagi file kode. Yang benar-benar bisa dibagi hanya **skema SQL +
  kontrak API**. Kalau user minta `packages/shared/` berisi kode, koreksi ke
  skema.
- **Urutan yang murah:** bangun fitur dulu, restructure belakangan. Pemindahan
  saat repo masih satu produk itu mekanis; memindahkan repo yang sudah grown
  itu mahal. Tetap saja, katakan alasannya supaya user bisa menolak.