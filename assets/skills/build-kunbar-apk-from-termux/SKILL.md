---
name: build-kunbar-apk-from-termux
description: Cara build + kirim APK KUNBAR Connect (warga) dari HP tanpa laptop - dispatch workflow, pilih ABI, unduh artifact, salin ke Download dengan pola background+polling, buka installer, dan bedsakan "sudah di-build" vs "belum di-install".
---

# Build APK KUNBAR Connect dari Termux

Repo `~/karta-kubar` (public), package `id.kubarkonek.app`, keystore asli ada di
GitHub Secrets (`KK_KEYSTORE_BASE64` dst) → **build rilis bertanda tangan
sah**, APK lama bisa di-update di atasnya (jangan uninstall).

## 1. Dispatch (branch, bukan main)

```bash
gh workflow run build.yml --ref feat/order-jastip-ojek \
  -f demo=true -f abi=universal -f release=yes -f analyze-only=no
```

- `abi=universal` = **default sesuai keputusan user 16 Okt 2026**: ukuran tidak
  jadi pertimbangan, yang penting satu berkas bisa dipasang di HP, emulator,
  dan Chromebook.
- `demo=true` menyalakan OTP demo `123456` + pengalih role pratinjau.
  **Tetap dipakai untuk APK warga** sampai backend Supabase benar-benar aktif;
  pengalih role sudah dipisah ke `AppConfig.roleSwitcher = kDebugMode` supaya
  APK rilis tidak punya tombol elevate role.
- Push ke `main` otomatis build + release. Kalau hanya mau iterasi cepat:
  `-f release=no -f analyze-only=yes` (~2 menit, tanpa APK).
- Setelah dispatch, `gh run watch <id>` lalu `gh run view <id> --json conclusion`.

## 2. Unduh artifact

```bash
gh run download <id> -n app-universal -D "$TMPDIR/apk-kunbar"
```

Nama artifact cek dulu: `gh run view <id> --json jobs` atau lihat step upload.

## 3. Salin ke /storage (WAJIB pola background + polling)

`cp` biasa ke shared storage itu FUSE dan **timeout** untuk berkas besar:

```bash
SRC=/data/data/com.termux/files/usr/tmp/apk-kunbar/app-universal.apk
DST=/storage/emulated/0/Download
SZ=$(stat -c %s "$SRC")
nohup cp "$SRC" "$DST/.apk.tmp" >/dev/null 2>&1 </dev/null & disown
for i in $(seq 1 30); do sz=$(stat -c %s "$DST/.apk.tmp" 2>/dev/null || echo 0)
  [ "$sz" -ge "$SZ" ] && break; sleep 10; done
nohup mv "$DST/.apk.tmp" "$DST/KUNBAR-Connect-v0.14.0.apk" >/dev/null 2>&1 </dev/null & disown
```

File sementara **harus mulai titik** supaya `ls` biasa tidak menampilkannya.

## 4. Buka installer + JELASKAN bedanya

```bash
am start -a android.intent.action.VIEW \
  -d file:///storage/emulated/0/Download/KUNBAR-Connect-v0.14.0.apk \
  -t application/vnd.android.package-archive
```

`am start` hanya membuka dialog installer. **User tetap harus menekan
Install.** Selalu sebut dua hal terpisah supaya tidak ada salah paham:

- "APK sudah dibangun dan ada di Download" (benar)
- "APK belum terpasang di HP" (masih perlu user tap Install)

## 5. Jebakan

- Tanda tangan berubah = APK lama wajib di-uninstall + data hilang. Jangan
  sampai `flutter create` di CI menghasilkan keystore debug (draft patch
  `// KUNBAR-SIGNING` + `tool/patch_signing.py` yangthemesain).
- Release = **draft** (`draft: true`) supaya APK tidak bisa diunduh publik;
  developer unduh dengan `gh release download` pakai token sendiri.
- `dart fix --apply` **tidak boleh** ada di pipeline (proven merusak constructor
  → kode tidak bisa di-parse). Sudah diganti `dart fix --dry-run`.
- APK hanya **Android**. Untuk iOS perlu `macos` runner; file sudah disiapkan
  di `.github/workflows/build-ios.yml` tapi **jangan trigger tanpa diminta**.