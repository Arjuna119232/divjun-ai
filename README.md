# DIVJUN AI

Chatbot AI (OpenCode Zen/Go) + direktori alat AI dalam satu aplikasi Android.

## Rilis di GitHub
1. Unggah seluruh isi folder ini (termasuk `.github`) ke repository GitHub.
2. Buat rilis: `git tag v1.1.0 && git push origin v1.1.0`. APK otomatis terlampir di halaman Releases.
3. Tanpa pengaturan tambahan, APK ditandatangani kunci debug (tetap bisa dipasang).

## Tanda tangan sendiri (disarankan, agar pembaruan bisa menimpa versi lama)
```
keytool -genkeypair -v -keystore divjun.jks -alias divjun -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 divjun.jks
```
Simpan sebagai Secrets repository: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Simpan file `divjun.jks` di tempat aman; jangan diunggah ke repository.

## Gradle Wrapper (gradlew)
Build di GitHub tidak membutuhkan wrapper (Gradle 8.7 dipasang oleh workflow). Untuk build lokal atau Android Studio, jalankan workflow **Buat Gradle Wrapper** sekali di tab Actions; `gradlew`, `gradlew.bat`, dan folder `gradle/wrapper` akan otomatis ditambahkan ke repository. Setelah itu lakukan `git pull`.
