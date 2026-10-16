---
name: jangan-pangkas-apk-kunbar
description: Keputusan user 16 Okt 2026 - jangan menghapus file/komponen/fitur apa pun di proyek KUNBAR Connect, ukuran APK bukan pertimbangan; default build = universal (semua ABI)
metadata:
  type: project
---

# KUNBAR Connect - aturan "tidak ada yang dipangkas" (16 Okt 2026)

**Kalimat user:** "jangan ada yang dipangkas sekarang segala apapun apk dalam
proyek kunbar, tak apa ukurannya besar yang penting terbaik, sempurna dan
modern".

## Arti yang dipakai di proyek ini

1. **Jangan `git rm` komponen.** Kalau sebuah widget/theme file terasa tidak
   dipakai, daftarkan di `tool/keep_unused.txt` — JANGAN dihapus.
   `tool/check_dart.py` membaca daftar itu dan mengubah `DEAD-FILE` jadi
   **CATATAN**, bukan MASALAH yang memblokir build.
2. **File yang ada di daftar itu tetap wajib bisa dikompilasi.** Dart hanya
   mengompilasi file yang terjangkau dari `lib/main.dart`, jadi build TIDAK
   menangkap kerusakan di file SIMPANAN. Kalau dipulihkan, perbaiki semua
   drift token-nya (lihat `[[merge-zip-baru-dgn-repo-lebih-baru]]`).
3. **Ukuran APK bukan pertimbangan.** Default `build.yml` = `abi: universal`
   (arm64-v8a + armeabi-v7a + x86_64) supaya satu berkas bisa dipasang di HP
   mana pun, emulator, dan Chromebook. Pilot `arm64` (~18 MB) hanya kalau
   sedang menguji.
4. Melebihi prioritas tetap berlaku: **tidak ada fiturnya yang boleh hilang** -
   kalau ZIP baru bawa lebih sedikit fitur dari repo, yang kurang harus
   dikembalikan (lihat skill merge ZIP).

## Kenapa ini teknis aman

File `.dart` yang tidak di-import **tidak masuk ke dalam APK** - Dart
tree-shaker hanya mengompilasi graf yang terjangkau dari entrypoint. Jadi
menyimpan komponen tidak menambah ukuran APK sama sekali. Yang menambah
ukuran cuma aset gambar/animasi dan `lib/` per-ABI.

## Aturan tambahan yang menyalah

"Aman" != "boleh dibuang". Kalau menggagas lebih bagus dari yang
sekarang, **pakai/tambahkan**, jangan menimpa tanpa alasan dan jangan
menghapus yang lama.