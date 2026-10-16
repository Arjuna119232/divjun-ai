# OpenCode / Zyvo di Termux — binary non-PIE ditolak Android

## Gejala
`opencode` atau binary Bun-based mati dengan:
`cannot execute: required file not found` — padahal file ada, 206 MB, `rwxr-xr-x`,
dan header-nya `ELF`.

## Akar masalah (terbukti, bukan tebakan)
Android (termasuk Android 16 / HyperOS) **hanya menerima PIE**
(Position Independent Executable).

Periksa tipe ELF dua file:
```bash
readelf -h <file> | grep Type:
```
- `Type: DYN (Shared object file)` → PIE → **JALAN** di Android.
- `Type: EXEC (Executable file)` → non-PIE → **DITOLAK**, error di atas.

`cannot execute: required file not found` = kernel tidak bisa memuat program
interpreter-nya, bukan file hilang. Jangan buru-buru `ls`/`chmod`.

Bukti tambahan kalau dipaksa lewat proot + system linker:
```
error: ... Android only supports position-independent executables (-fPIE)
```

## Cara diagnosa (urutan, jangan acak)
1. `which <cmd>` / `ls -la` → file memang ada?
2. `readelf -h <file> | grep -E 'Type|Machine'` → PIE atau bukan? ARM64 (`AArch64`) benar untuk HP.
3. Cari working copy yang sudah dipakai: `ls -la $PREFIX/libexec/*/` dan `ls -la $PREFIX/bin/`.

## Solusi yang berhasil
 Zyvo (OpenCode) **sudah terpasang** sebagai `zyvo`:
- binary asli: `$PREFIX/libexec/zyvo/zyvo.bin` (tipe DYN/PIE → jalan)
- shim: `$PREFIX/bin/zyvo` → `~/bin/zyvo` (shim Protect config saat `update`)

Buat perintah `opencode` sebagai alias:
```sh
#!/bin/sh
# di ~/bin/opencode
exec "$HOME/bin/zyvo" "$@"
```

## Jebakan yang浪费时间 (semua sudah ditabrak)
1. **`export PATH=~/.opencode/bin:$PATH` di `.bashrc`** → binary rusak menimpa
   perintah yang benar. Hapus baris itu, jangan cuma andalkan urutan PATH.
2. **PATH diwarisi dari proses induk** → `bash -lc 'command -v opencode'`
   masih menunjukkan path rusak walau `.bashrc` sudah dibersihkan. Itu normal;
   shell Termux **baru** yang membaca `.bashrc` bersih. Verifikasi dengan
   env bersih, bukan `bash -lc`:
   ```bash
   env -i HOME="$HOME" PATH="$PREFIX/bin:/system/bin" TERM=xterm bash -ic 'command -v opencode'
   ```
   `bash -lc` **tidak** membaca `.bashrc` (baca `.profile`) → `command not found`
   palsu. Yang dipakai Termux = **interaktif** (`bash -ic`).
3. **`bash -lc 'opencode --version'`** selalu gagal walau setup benar — salah
   mode shell, bukan salah setup.
4. **AppImage tidak bisa dipakai**: `--appimage-extract` gagal, dan tidak ada
   `7z`/`bsdtar`/`unsquashfs`/`squashfs-tools` di Termux
   (`pkg install squashfs-tools` → "Unable to locate package"). Repo OpenCode
   juga **tidak pernahhovet paket npm** (`@open-code-ai/cli` → 404). Jalur
   AppImage/proot-distro = buang waktu; binary yang sudah ada justru yang benar.
5. **`patchelf` sendiri rusak di Termux** → `cannot locate symbol
   _ZNSt6__ndk113__hash_memoryEPKvm`. Jadi tidak bisa "menambal" binary non-PIE
   dari dalam Termux (dan memang tidak akan mengubah tipe ELF-nya).
6. **`proot` tidak menolong** untuk non-PIE — proot hanya memalsukan filesystem,
   bukan manned type ELF kernel.
7. Clean-up: `cp` besar ke `/storage` = timeout; hitung hash di `$HOME` dulu.

## Verifikasi akhir
```bash
env -i HOME="$HOME" PATH="$PREFIX/bin:/system/bin" TERM=xterm bash -ic \
  'which opencode; opencode --version'    # harus: ~/bin/opencode + 1.17.9
```
`opencode run` / `models` / `mcp list` memang crash di 1.17.9 (bug headless) —
itu **normal**, TUI-nya tetap jalan. Jangan dipakai sebagai tes.