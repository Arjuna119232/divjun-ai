---
name: apktool-termux-rebuild
description: Cara build APK hasil patch smali di Termux saat `apktool b` gagal di tahap resources (aapt2 wrapper rusak) — ganti dex langsung di APK asli pakai Python zipfile.
when_to_use: Saat patch smali di Termux, `apktool b` sudah berhasil smali semua dex tapi gagal di "Building resources" dengan error `could not exec` / `brut_util_Jar_*.tmp` / "Syntax error: Unterminated quoted string".
---

# Rebuild APK patched di Termux (bypass aapt2 failure)

## Gejala
`apktool b dec -o out.apk`:
```
I: Smaling smali_classes5 folder into classes5.dex...
I: Building resources...
brut.androlib.exceptions.AndrolibException: brut.common.BrutException:
  could not exec (exit code = 2): [.../brut_util_Jar_XXX.tmp, compile, --dir, .../dec/res, ...]
W: .../brut_util_Jar_XXX.tmp: 4: Syntax error: Unterminated quoted string
```

## Kenapa terjadi
Apktool 2.9.x menulis **shell script wrapper sementara** untuk memanggil
`aapt2`, lalu exec-nya. Di Termux wrapper itu rusak (path/JAVA_HOME/quoting),
dan `aapt2` mungkin belum terpasang (`pkg install -y aapt2` memang membantu
tapi TIDAK menyelesaikan masalah wrapper).

`TMPDIR="$HOME/tmpbuild"` atau `java -Djava.io.tmpdir=...` **tidak menolong** —
java.util log path berubah, tapi wrapper tetap sama rusaknya.

## Solusi yang WORKS: dex-swap, jangan rebuild resource
Kalau patch cuma menyentuh **smali** (bukan `res/`), resource APK asli masih
sah. Tidak perlu compile ulang resource sama sekali.

1. Build tetap jalan sampai "Building resources" GAGAL — **smali sudah
   menghasilkan dex** di `dec/build/apk/classes*.dex`. Jangan hapus.
2. Copy APK asli → working, lalu tukar tiap dex dengan Python:
```bash
cd "$TMPDIR/claude"
python3 - <<'PY'
import zipfile, os
src, dst = 'app.apk', 'patched.apk'
newdex = {f'classes{i}.dex' if i else 'classes.dex':
          f'dec/build/apk/classes{i}.dex' if i else 'dec/build/apk/classes.dex'
          for i in ['', 2, 3, 4, 5]}
zin = zipfile.ZipFile(src); zout = zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED)
for it in zin.infolist():
    data = open(newdex[it.filename],'rb').read() if it.filename in newdex \
           else zin.read(it.filename)
    zi = zipfile.ZipInfo(it.filename, date_time=it.date_time)
    zi.compress_type = it.compress_type
    zi.external_attr = it.external_attr
    zout.writestr(zi, data)
zout.close(); zin.close()
PY
```
3. Sign (lihat skill `apk-sign-termux`).

## Verifikasi patch benar-benar masuk (WAJIB)
```bash
python3 -c "
import zipfile
d = zipfile.ZipFile('patched.apk').read('classes.dex')
print('claude_max gone:', b'claude_max' not in d)
"
```
Cek string yang SEHARUSNYA hilang setelah patch — kalau masih ada, patch
tidak masuk ke dex yang benar.

## Jebakan smali saat edit via python
Tanda **titik koma di akhir** wajib ada, dan python `replace`/index mudah
memotongnya:
- SALAH: `.method ... z(Lynn;)Lp5x` (tanpa `;`)
- SALAH: `sget-object v0, Lp5x;->x:Lp5x` (tanpa `;`)
Error yang muncul: `no viable alternative at input 'Lp5x'` di kolom method
header ATAU di baris sget-object. Perbaiki: tambah `;` di akhir dua baris itu.

## Tips
- `zip` CLI tidak ada di Termux → selalu Python `zipfile`.
- `/tmp` di Termux bukan `/tmp` Linux biasa; pakai `$TMPDIR`
  (`/data/data/com.termux/files/usr/tmp`).
- Simpan `MOD_NOTES.md` di folder yang sama dengan APK hasil.
