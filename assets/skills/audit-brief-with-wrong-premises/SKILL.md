---
name: audit-brief-with-wrong-premises
description: Cara menangani brief dari user yang asumsinya salah (paket yang tidak ada, folder yang tidak pernah ada, fitur yang tidak mungkin) - audit dulu dengan BUKTI LIVE, tulis koreksinya ke file repo, lalu eksekusi otonom tanpa menanya. Berlaku juga untuk syarat yang secara teknis mustahil di perangkat yang dipakai.
---

# Brief dengan premis salah: audit dulu, buktikan, baru eksekusi

Pola ini muncul tiap kali user mengirim brief panjang berisi daftar dependency,
folder, dan versi. Brief itu berguna (arahnya benar) tapi **detailnya sering tidak
sesuai kenyataan di perangkatnya**. Menjalankannya mentah = buang waktu build.

## Aturan: audit dengan bukti, bukan opinion

Untuk setiap klaim di brief, cek satu dari empat sumber berikut:

| Klaim | Cara membuktikan |
|---|---|
| "paket X versi Y ada" | `https://pub.dev/api/packages/X` -> cek `versions` + `latest.pubspec.environment` |
| "paket X butuh compileSdk N" | unduh arsip: `https://pub.dev/api/archives/<pkg>-<ver>.tar.gz` -> baca `android/build.gradle` |
| "folder X ada di repo" | `ls` / `glob`, jangan percaya brief |
| "service/backend sudah jalan" | query live (PostgREST = 404 `PGRST205` = tabel belum ada) |

Contoh nyata (KUNBAR Mitra, 15 Okt 2026):
- `any_map`/`any_map_maplibre` **benar-benar ada** (verifikasi pub.dev) - jadi
  skeptis berlebihan juga salah; harus cek dua arah.
- `lib/shared/` **tidak pernah ada** di repo itu -> reuse yang nyata dari
  `lib/core/theme/`.
- Supabase **kosong** (semua tabel 404) -> "sinkron antar app" tidak bisa
  dibuktikan sebelum SQL dijalankan user.

## Jebakan versi yang hanya ketahuan saat build

1. **`permission_handler` 13.x** -> `permission_handler_android` 14.x ->
   **compileSdk 37**. Runner GitHub masih 36 -> `checkReleaseAarMetadata` gagal.
   Solusi: kunci `^12.0.3` (android impl 13.x, compileSdk 35).
2. **`maplibre_gl` butuh Java 21** (`invalid source release: 21`) sementara
   template CI lama pakai 17. Solusi: `actions/setup-java` -> `java-version: '21'`.
   Gejalanya muncul sebagai `Execution failed for task ':maplibre_gl:compileReleaseJavaWithJavac'`.
3. **`--target-platform android-arm64` tidak mengecilkan ukuran** kalau plugin
   punya `.so` untuk semua ABI (AAR ikut semua). Setelah MapLibre: 56 MB.
   Yang benar: `--split-per-abi` -> ~20 MB per ABI.

## Yang TIDAK bisa-From-HP (katakan jujur, jangan janjiin)

- `flutter doctor` / `flutter run` / `flutter analyze` lokal: **Flutter tidak ada
  di Termux**. Satu-satunya oracle = GitHub Actions.
- Menjalankan SQL/DDL di Supabase butuh SQL Editor atau service_role key.
  Yang bisa dilakukan: tulis file `.sql` + skrip cek live + instruksi 3 langkah.
- Verifikasi KTP/SIM/STNK otomatis: tidak ada API publik. Bangun form unggah +
  status + verifikasi admin, jangan janji "otomatis".

## Cara_MAGANGının laporan audit

1. Tulis ke file repo (`apps/<nama>/AUDIT-<tanggal>.md`), bukan cuma di chat.
2. Bagi: **A. yang sudah ada** (tabel) · **B. koreksi brief** (nomor + bukti) ·
   **C. verifikasi live** · **D. urutan eksekusi + risiko** · **E. yang tidak
   bisa dicapai**.
3. Setelah audit, langsung eksekusi. Jangan berhenti menunggu persetujuan
   kalau brief-nya sudah berisi aturan "eksekusi otonom".

## Gotcha kecil saat menulis file lewat tool

Teks non-Latin (CJK/Hangul) sempat nyasar 3x dari IME ke komentar/kode.jdan satu
baris komentar kehilangan `//` sehingga build gagal dengan
`Error: Expected an identifier, but got '->'`. Selalu:
- `python3 tool/check_nonlatin.py` (kalau ada) sebelum commit,
- cek struktur kurung `{}()[]` per file setelah edit python,
- dan baca ulang baris yang_error dari log CI, bukan menebak.
