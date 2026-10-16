---
name: generator-code-drops-tail-helpers
description: Generator skrip yang menulis ulang berkas kode besar (Dart/PHP/JS) bisa menghapus helper di ekor file sehingga build rusak JAUH dari sumber - cara mendeteksi, memperbaiki, dan mengunci dengan penjaga deklarasi yang hilang + fault injection.
---

# Generator yang dropping helper di ekor berkas

## Gejala

Berkas hasil generate "berhasil" (skrip print OK, `write_text` tidak error,
`check_dart.py` = 0 masalah) tapi build gagal **di berkas lain**:

```
lib/features/mitra_usaha/presentation/mitra_usaha_screen.dart:101:24: error:
  Undefined name 'jumlahKategori'.
```

Dua commit terakhir sudah memakai fungsi itu, jadiLayak curiga — cari
`git show HEAD:<berkas>`:

```bash
git show HEAD:lib/.../mitra_usaha_lokal.dart | grep -c jumlahKategori   # 0 = hilang
git show HEAD:lib/.../mitra_usaha_screen.dart | grep -c jumlahKategori # 1 = dipakai
```

## Akar sebab

Skrip generator menulis ulang seluruh isi berkas, tapi tidak tahu bagian mana
yang bukan miliknya. Dua jebakan yang umum:

1. **Penanda berbasis komentar teks.** `helper = isi_lama[isi_lama.index("/// Jumlah mitra per kelurahan."):]`
   Kalau helper baru diletakkan **satu baris di atas** penanda itu, helper baru
   ikut terpotong. Penanda komentar bukan batas yang bisa dipercaya — hanya
   posisi yang bisa digeser manusia kapan saja.
2. **Validasi setelah menulis.** Semua cek jalan di atas `DST.write_text()` →
   skrip `exit 1` tapi **berkas rusak sudah tertinggal di disk**, dan saja →
   berkas lama utuh diam-diam.

## Perbaikan (3 bagian)

1. **Batas ekstraksi = penutup struktural, bukan komentar.** Untuk Dart yang
   menaruh daftar di atas:

   ```python
   penutup = re.search(r"^\];\s*$", isi_lama, re.M)
   helper = isi_lama[penutup.end():] if penutup else ""
   ```

2. **Semua validasi pindah ke ISI BARU, sebelum `write_text`.**

3. **Penjaga "deklarasi hilang".** Kumpulkan semua deklarasi tingkat atas file
   lama, bandingkan dengan file baru, selisihnya = `exit 1`:

   ```python
   AWAL_SIMBOL = re.compile(
       r"^(?:final|const|int|double|String|bool|void|"
       r"Map<[^>\n]*>|List<[^>\n]*>|MitraUsaha\??)"
       r"\s+([a-zA-Z_][A-Za-z0-9_]*)", re.M)
   hilang = sorted(sebelum - simbol_atas(isi_baru))
   if hilang: sys.exit(f"deklarasi hilang: {hilang}")
   ```

   Ini yang menangkap deregisterasi tak sengaja: begitu helper hilang sekali,
   pemanggilnya di berkas lain tidak pernah ikut hilang.

4. **Bukti tulis tetap ada**, tapi dipindah ke belakang: `kembali != isi_baru`
   → exit 1. Percaya output "OK" tanpa baca balik pernah menyesatkan.

## Verifikasi wajib: fault injection

Skrip yang "selalu print OK" belum tentu benar. Sabotase batas ekstraksi lalu
buktikan skrip menolak **dan berkas tetap utuh**:

```bash
cp berkas.dart "$TMPDIR/backup.dart"
python3 - <<'PY'
import pathlib
p = pathlib.Path("berkas.dart"); s = p.read_text()
i = s.rindex("\n];"); p.write_text(s[:i] + "\n];  // sabotase" + s[i+3:])
PY
python3 tool/gen.py; echo "EXIT=$?"      # harus: GAGAL + EXIT=1
grep -c "^int jumlahKategori" berkas.dart  # harus tetap ada
cp "$TMPDIR/backup.dart" berkas.dart        # pulihkan
```

Juga uji idempoten: jalankan generator 2x, `diff -q` harus IDENTIK.
Generator yang tidak idempoten = generator yang mengubah isi diam-diam tiap kali
dijalankan.

## Aturan umbrella

- **Jangan pernah membangun/analisis sebelum generator dijalankan** setelah
  data diubah — urutan di `PROGRESS.md`: generator → `check_dart.py` →
  `check_nonlatin.py` → CI.
- Kalau `check_dart.py` hijau tapi CI `Analyze` gagal, **akehnya bukan
  checkernya bodoh — mungkin berkasnya benar-benar rusak** dan gap-nya di
  kelas yang berbeda (helper hilang dari generator).
- Skrip generator =Fail loudly, bukan fail quietly. `sys.exit(1)` + pesan
  berisi nama simbol persis yang hilang.