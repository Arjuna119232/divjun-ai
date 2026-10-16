# Build APK hasil patch smali langsung di Termux (HP, tanpa PC)

Skill ini lahir dari task 12 Okt 2026: user minta **zyvo yang decompile +
build sendiri**, bukan dia yang pakai APKTool M GUI. Berhasil penuh —
APK 200 MB di-patch, di-build, di-sign di HP.

## Jawaban singkat
**BISA, dan lebih cepat dari yang lo kira.** Untuk APK Android modern
(3-20 dex, 100-300 MB), total ~5 menit di POCO M7 Pro / MT6855.

## 1. Dekode smali saja (WAJIB -r, bukan -s)
```bash
J=/data/data/com.termux/files/usr/bin/apktool.jar
java -Xmx2500m -jar $J d -r -f -o dec orig.apk
```
- `-r` = `--no-res` -> decode dex ke smali, resource di-copy mentah
- `-s` = `--no-src` -> **justru membalik**: dex di-*copy mentah*, TIDAK di-baksmali.
  (Salah flag = capo-up, lo akan bingung kenapa folder `smali` tidak ada.)
- **Jangan** pakai `apktool` dari PATH untuk ini, invoke `java -jar` langsung
  supaya bisa controlled heap.

## 2. Jebakan: baksmali/smali standalone TIDAK bisa dipakai
`apktool.jar` Termux berisi `com/android/tools/smali/baksmali/Main.class`
dan `.../smali/Main.class`, **tapi method `main`-nya sudah di-strip**:
```
Error: Main method not found in class com.android.tools.smali.baksmali.Main
```
Jadi `java -cp apktool.jar com.android.tools.smali.baksmali.Main` GAGAL.
**Jangan unduh baksmali terpisah** — cukup lewat `apktool d` / `apktool b`.

## 3. Build
```bash
java -Xmx2500m -jar $J b dec -o rebuilt.apk
```
**Karena resource di-copy mentah (mode `-r`), tidak ada aapt2 yang dikompilasi.**
Efeknya: jebakan wrapper aapt2 Termux (skill `apktool-termux-rebuild`) TIDAK
muncul sama sekali. `apktool b` langsung sukses, jadi **tidak perlu dex-swap
dengan Python**. Skill itu tetap berguna untuk decode TANPA `-r`.

## 4. Align + sign
```bash
pkg install -y aapt                    # menyediakan zipalign
zipalign -p -f 4 rebuilt.apk aligned.apk

keytool -genkeypair -v -keystore ks.jks -alias a \
  -keyalg RSA -keysize 2048 -validity 10950 \
  -storepass PASS -keypass PASS \
  -dname "CN=..., O=..., C=ID"

apksigner sign --ks ks.jks --ks-key-alias a \
  --ks-pass pass:PASS --key-pass pass:PASS \
  --v2-signing-enabled true --v3-signing-enabled true \
  --min-sdk-version 24 --out final.apk aligned.apk

apksigner verify --verbose final.apk
```
- `zipalign` TIDAK ada default di Termux -> harus `pkg install -y aapt`
- v1 signing akan FALSE otomatis karena `--min-sdk-version 24`. **Itu BENAR.**
  v1 hanya wajib untuk API < 24. v2+v3 sudah "Verifies", Android 7+ bisa install.

## 5. Verifikasi patch benar-benar masuk (WAJIB, jangan lewatkan)
Decode ULANG APK final lalu grep:
```bash
java -Xmx2500m -jar $J d -r -f -o verdec final.apk
grep -A5 '^\.method public static <n>(Lnet/osmand/plus/OsmandApplication;Z)Z' \
  verdec/smali_classes3/to2.smali
```
Harus muncul persis:
```smali
.method ... 
    .locals 1

    const/4 v0, 0x1

    return v0
.end method
```
Tambahan: bandingkan ukuran `classes*.dex` sebelum vs sesudah — kalau beda,
patch masuk.

## 6. Edit smali pakai python — WAJIB assert
`str.replace()` bisa gagal **diam-diam** dan menghasilkan APK yang jalan tapi
patch-nya tidak ada. Selalu:
```python
src2 = src.replace(old_block, new_block)
assert src2 != src, "replace diam-diam gagal"
assert new_block in src2, "hasil tidak ditemukan"
```
Dan tentukan batas method lewat `.method` ... `.end method`, bukan nomor baris
(baris bergeser setelah patch sebelumnya di file yang sama).

## 7. Jebakan Registers
Method static dengan 2 parameter `(Lnet/osmand/plus/OsmandApplication;Z)Z`:
- `.locals 1` -> ada v0, p0, p1. `const/4 v0, 0x1; return v0` aman.
- **JANGAN `.locals 0`** -> v0 == p0 (tipe object). `return v0` mengembalikan
  integer garbage, gate jadi acak, app crash atau tidak terbuka.

## 8. Misc
- Kerja di `$HOME`, BUKAN `/storage/emulated/0` (FUSE: lambat untuk ribuan
  file, `chmod` diabaikan).
- File `.bak` di dalam folder smali -> warning `Unknown file type, ignoring`,
  aman; tapi lebih bersih taruh di luar folder smali.
- RAM: `-Xmx2500m` cukup untuk APK 200 MB. Semua kerja ada di swap.
- APK hasil `apktool b` selalu lebih besar (dex kejarisan ulang tanpa layout
  asli). Itu normal, bukan tanda rusak.
- Ingatkan user: signature kita != signature developer's, jadi WAJIB uninstall
  versi lama dulu, dan data app (peta offline, track) ikut hilang.