# Flutter iOS: siapkan jalur build tanpa pernah build

**Kapan dipakai:** user minta "file iOS-nya prepared dulu, fokus Android, nanti
kalau Android sudah pas baru build iOS — jangan sampai harus koding ulang."

**Kenapa skill ini ada:** orang 默认 이재茫 답"iOS butuh Mac, jadi nggak
bisa dari HP" lalu berhenti di situ. Itu benar separuh dan>** harmful kalau
dijawab begitu saja — karena biayaKI International**

---

## 1. Klaim yang harus dibongkar (dengan sumber)

| Klaim | Status |
|---|---|
| "Flutter harus koding ulang untuk iOS" | ❌ SALAH. `lib/` dipakai apa adanya. `flutter build ipa` tanpa ubah kode. |
| "iOS butuh Mac" | ⚠️ benar soal **mesin build**, salah soal **grp** — GitHub Actions punya runner macOS. |
| "APK gede biar bisa Android + iOS" | ❌ SALAH. APK **tidak pernah bisa** dipasang di iOS. iOS butuh `.ipa` (Mach-O), bukan `.apk` (ELF). Ukuran APK 0 hubungannya. |
| "Build iOS harus bayar" | ✅ **Gratis.** Repo PUBLIK → GitHub Actions standard runner gratis & tak terbatas. |

Sumber resmi (verifikasi 13 Okt 2026):
- `docs.github.com/actions/reference/runners/github-hosted-runners` →
  *"The use of standard GitHub-hosted runners is free and unlimited on public repositories."*
- `docs.github.com/billing/.../product-billing/github-actions` → *"free in public repositories"*.
  Repo privat hanya dapat kuota Free 2.000 menit, dan **macOS dibayar 10x** → hanya 200 menit.
  ⚠️ Cek `visibility` repo SEBELUM menjanjikan gratis: `gh repo view --json visibility`.
- `developer.apple.com/help/account/basics/about-your-developer-account` →
  free Personal Team: profil **kedaluwarsa 7 hari**, **maks 3 app per device**.
- Paid Apple Developer Program **$99/tahun** = satu-satunya biaya riil, dan itu
  untuk **distribusi**, bukan untuk build.

⚠️ `macos-14` (M1) **dipensiunkan 2 Nov 2026** (changelog 2026-10-01) → pakai
`macos-15` atau `macos-latest`.

---

## 2. Arsitektur yang benar: generate, jangan commit

Folder native **tidak pernah di-commit**. Semua yang Komitmen hanyalah:
Dart + workflow + **script patch yang deterministik**. Di runner macOS:

```yaml
- name: Generate iOS platform
  run: |
    flutter create --org <ORG> --project-name <NAME> --platforms=ios /tmp/scaffold
    cp -r /tmp/scaffold/ios .
    test -f ios/Runner/Info.plist || { echo "FAIL: ios/ tidak lengkap"; exit 1; }
```

Alasannya persis sama dengan pipeline Android yang sudah jalan: folder native
yang di-commit pasti usang begitu Flutter rilis template baru, dan `project.pbxproj`
berantakan setiap kali patch script menyentuhnya. Generate ulang = selalu ikut
template terbaru, diff review-able, dan tidak ada konflik merge.

---

## 3. Script patch: `plistlib` untuk Info.plist, regex untuk teks

Jangan pakai `sed` untuk `Info.plist`. `plistlib` aman terhadap urutan key,
escape, dan tipe data. Regex hanya untuk file teks (Podfile, pbxproj).

```python
import plistlib
plist = plistlib.load(open(INFO, "rb"))
plist["CFBundleDisplayName"] = "My App"
plistlib.dump(plist, open(INFO, "wb"))
```

### Yang WAJIB ada di Info.plist

| Key | Kenapa wajib |
|---|---|
| `CFBundleDisplayName` | Nama di bawah ikon. **jangan** pakai package id |
| `NSCameraUsageDescription` | iOS **memblokir** kamera tanpa ini |
| `NSLocationWhenInUseUsageDescription` | idem untuk lokasi |
| `NSPhotoLibraryUsageDescription` | idem untuk galeri/foto |
| `CFBundleURLTypes` | deep link `myscheme://` (go_router/app_links) |
| `UISupportedInterfaceOrientations~ipad` | iPad; default Flutter cuma iPhone |

⚠️ Cocokkan permission iOS dengan permission yang **benar-benar** diminta di
AndroidManifest — janganaskad. Kalau Android cuma minta CAMERA + FINE_LOCATION,
jangan tambahkan photo di iOS (ketidakselarasan = app行为 berbeda antar platform).

### Jebakan: `CFBundleName` vs `CFBundleDisplayName`

`CFBundleName` dibatasi **15 karakter** oleh App Store saat submit.
`CFBundleDisplayName` tidak dibatasi (jadi yang dipakai untuk nama bonito).

### Jebakan: bundle id jangan ditulis, tapi di-VERIFY

`flutter create --org X --project-name Y` menurunkan bundle id ke `X.Y`.
Kalau suatu saat derivasi template berubah, script yang **menulis** id akan
menutupi masalah dan menghasilkan IPA dengan id yang salah — baru ketahuan saat
gagal upload ke App Store. Jadi:

```python
if plist.get("CFBundleIdentifier") != EXPECTED_ID:
    sys.exit(f"FAIL: bundle id {actual!r} != {EXPECTED_ID!r} — perbaiki --org/--project-name")
```

Fail keras di CI jauh lebih murah daripada id salah yang lolos.

### Podfile & pbxproj

```
platform :ios, '13.0'          # Flutter 3.22+ = lantai iOS 13
IPHONEOS_DEPLOYMENT_TARGET = 13.0;
```

Di Podfile template barisnya bisa **dikomentari** (`# platform :ios, '12.0'`) →
regex harus menangani dua-duanya (`^#\s*platform` DAN `^platform`).

---

## 4. Trigger manual-only

```yaml
on:
  workflow_dispatch:      # ⛔ JANGAN tambahkan `push:`
```

`workflow_dispatch` = hanya jalan kalau ada yang klik / `gh workflow run`.
Tanpa ini, tiap commit ke `main` membakar 10 menit runner macOS dan menghasilkan
IPA yang tidak diminta. Kalau repo publik, runner-nya gratis — tapi tetap jangan
dibakar otomatis.

---

## 5. Jebakan YAML GitHub Actions (sabitkan 2x)

### a. `: ` di dalam plain scalar

```yaml
run: flutter build ipa --no-codesign || echo "WARN: gagal, artefak .app tetap valid"
                            ↑ ParserError: mapping values are not allowed here
```

Fix: bungkus seluruh value dengan `'...'` atau `"..."`.

```yaml
run: 'flutter build ipa --no-codesign || echo "gagal, artefak .app tetap valid"'
```

### b. Edit tool merusak indentasi block sequence

Saat `Edit` mengganti blok `- name: ...`, indentasi sering hilang jadi kolom 0 →
`expected <block end>, but found '-'`. **Selalu validasi ulang:**

```bash
python3 -c "
import yaml
d=yaml.safe_load(open('.github/workflows/x.yml'))
on = d[True] if True in d else d.get('on')
print('trigger =', list(on.keys()))
"
```

`on:` di YAML 1.1 diparse sebagai boolean `True` — jangan `d['on']`, bisa
`KeyError`.

---

## 6. Verifikasi tanpa Mac

Bikin tiruan `ios/` yang plausibel, lalu jalankan script. Ini menguji logika
patch tanpa perlu runner:

```python
# Info.plist tiruan: CFBundleIdentifier id.kubarkonek.app, DisplayName "App"
# Podfile tiruan      : "# platform :ios, '12.0'"
# pbxproj tiruan      : IPHONEOS_DEPLOYMENT_TARGET = 12.0;
```

Tiga tes wajib:
1. **Run 1** → semua patch diterapkan, exit 0
2. **Run 2** → **tidak ada perubahan sama sekali** (idempoten: tidak dobel
   `CFBundleURLTypes`, tidak dobel permission)
3. **Bundle id sengaja dirusak** → `FAIL: ...` + **exit 1**

Idempotensi wajib diuji karena script dipanggil ulang tiap run, dan
`entry.setdefault(...).append(...)` tanpa guard akan menumpuk.

---

## 7. Yang TIDAK bisa disiapkan (bilang jujur)

- **Tanda tangan** → butuh akun Apple Developer. Tidak ada caraorylation.
- **TestFlight / App Store** → butuh akun + review Apple.
- **Enterprise certificate gratis** → JANGAN pernah menawarkan. Dicabut Apple
  dalam gelombang besar → semua app mati mendadak untuk semua orang.
- **Icon & launch screen iOS** → butuh PNG resolusi Apple, bukan yang Android.

Sampaikan sebagai tabel: ✅ sudah gratis / ⏳ butuh akun / ⛔ butuh biaya.