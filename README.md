# DIVJUN AI

Chatbot AI (Google Gemini dan Groq) + direktori alat AI dalam satu aplikasi Android.

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

## API key tertanam (Groq dan Gemini)
Jangan tulis key di dalam kode. Simpan sebagai Secrets repository: `GROQ_API_KEY` dan `GEMINI_API_KEY`
(Settings > Secrets and variables > Actions > New repository secret). Saat build, key otomatis tertanam di APK.
Untuk build lokal, buat file `keys.properties` (sudah masuk .gitignore) berisi:
```
GROQ_API_KEY=isi_key_groq
GEMINI_API_KEY=isi_key_gemini
```
Peringatan: key di dalam APK bisa diekstrak oleh siapa pun yang memegang APK-nya. Gunakan repository privat dan jangan bagikan APK ke orang lain.

## Tanda tangan APK (stabil)
File `app/divjun.jks` dipakai untuk menandatangani APK debug maupun rilis, sehingga setiap build punya tanda tangan yang sama dan bisa dipasang di atas versi lama tanpa uninstall.
Gunakan repository PRIVAT. Jika ingin kunci sendiri, buat dengan perintah di atas dan isi Secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`; Secrets didahulukan.
