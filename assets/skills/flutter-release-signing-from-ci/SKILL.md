---
name: flutter-release-signing-from-ci
description: Cara membuat APK Flutter di GitHub Actions bertanda tangan ASLI (bukan debug key) saat android/ di-generate ulang tiap run — termasuk 3 jebakan nyata yang bikin build gagal. Pakai saat pipeline Flutter "k Successful" tapi Play Store tolak, atau apksigner menunjukkan CN=Android Debug.
---

# SIGNING RELEASE FLUTTER DI CI (android/ di-generate ulang tiap run)

## Masalah inti

`flutter create` (yang dipakai workflow untuk meng-generate `android/` tiap run)
**TIDAK membuat blok `signingConfigs` sama sekali**. Yang di-generate hanya:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Jadi tanpa patch tambahan, `flutter build apk --release` menghasilkan APK yang
ditandatangani **`CN=Android Debug`**. Build tetap hijau — itu sebabnya bug ini
sudah lama tidak ketahuan. Deteksi:

```bash
apksigner verify --print-certs app-release.apk | head -2
# V2 Signer: certificate DN: C=US, O=Android, CN=Android Debug   <-- BAJA
```

## Solusi

1. Restore keystore dari GitHub Secrets + tulis `android/key.properties`.
2. Jalankan skrip patch yang **menyuntikkan** blok `signingConfigs`.
3. Release memakai keystore itu.

## 3 JEBAKAN yang bikin build GAGAL (sudah ditemukan & diuji)

### Jebakan 1 — `java` di-shadow plugin Gradle Java
```kotlin
val keyProperties = java.util.Properties()   // ❌ Unresolved reference 'util'
```
Di `build.gradle.kts`, identifier `java` sudahoccupied oleh extension plugin
Gradle Java. WAJIB:
```kotlin
import java.util.Properties
import java.io.FileInputStream
// ...
val keyProperties = Properties()
keyProperties.load(FileInputStream(keyPropertiesFile))
```

### Jebakan 2 — `project.findProperty()` tidak membaca key.properties
```kotlin
storePassword = project.findProperty("storePassword") as String   // ❌ null → crash
```
`findProperty` hanya membaca Gradle project properties (`-P` / `gradle.properties`).
Harus:
```kotlin
storePassword = keyProperties["storePassword"] as String   // ✅
```

### Jebakan 3 — template yang dipakai untuk MOCK itu KEDUA-DUA-DARI VERSI LAMA
Sering kali versi lama punya `signingConfigs { create("release") {...} }`
(placeholder debug), versi terbaru **tidak punya sama sekali**. Kalau skrip
mengasumsikan blok itu sudah ada → `SigningConfig with name 'release' not found`.
**Selalu unduh template asli** sebelum menulis patch:
```bash
curl -sL "https://raw.githubusercontent.com/flutter/flutter/stable/packages/flutter_tools/templates/app/android-kotlin.tmpl/app/build.gradle.kts.tmpl"
```
Dan uji skrip terhadap file itu, bukan karangan sendiri.

## Jebakan bonus

- **Path `storeFile` relatif ke `android/app/`** (tempat build.gradle.kts),
  bukan ke `android/`. Kalau key.properties bilang `storeFile=app/upload-keystore.jks`
  sementara keystore ada di `android/app/upload-keystore.jks`, path-nya jadi
  `android/app/app/upload-keystore.jks` dan signing gagal.
  Pakai `storeFile=upload-keystore.jks`.
- **f-string Python**: `{` di dalam f-string harus `{{`. Kalimat seperti
  `f"... blok 'android {' ..."` → SyntaxError unterminated string.
- Idempotensi pakai **marker comment** (`// KARTA-KUBAR-SIGNING`), bukan
  regex penghitung kurung kurawal. Versi slicing-blok-rows sebelumnya
  **menghapus** baris `signingConfigs {` saat dijalankan dua kali.

## Urutan langkah di workflow

```yaml
- name: Restore upload keystore
  run: |
    mkdir -p android
    echo "${{ secrets.KK_KEYSTORE_BASE64 }}" | base64 -d > android/app/upload-keystore.jks
    cat > android/key.properties <<EOF
    storeFile=upload-keystore.jks
    storePassword=${{ secrets.KK_KEYSTORE_PASSWORD }}
    keyAlias=${{ secrets.KK_KEY_ALIAS }}
    keyPassword=${{ secrets.KK_KEY_PASSWORD }}
    EOF

- name: Apply Android patches
  run: bash tool/patch_android.sh

- name: Apply release signing
  run: python3 tool/patch_signing.py
```

## Verifikasi WAJIB setelah build (jangan percaya "build sukses")

```bash
gh release download <tag> -p '*.apk' -D cek
apksigner verify --print-certs cek/app-release.apk | head -2
# harus: CN=<nama organisasimu>, BUKAN CN=Android Debug
apksigner verify cek/app-release.apk && echo "SIGNATURE VALID"
```

## Catatan penting

- Keystore upload **tidak boleh hilang selamanya** — kalau hilang, app tidak bisa
  di-update lagi (Play Console menolak,signature tidak cocok). Backup di luar
  repo (misal `~/.config/zyvo/keys/`, chmod 600) + catat password di memori.
- Ganti dari debug ke signing asli = **tanda tangan berubah** → APK lama harus
  di-UNINSTALL dulu sebelum pasang yang baru.
- Unlock key口令 alias/password harus sama antara generate dan CI.