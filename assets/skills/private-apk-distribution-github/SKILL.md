---
name: private-apk-distribution-github
description: Cara“请 organizing” mendistribusikan APK hanya ke developer sendiri tanpa bisa diunduh publik, tapi tetap bisa diperiksa Google Play Protect. Termasukjwaban: apakah Play Protect butuh URL publik? (TIDAK). Gunakan saat user minta APK-nya tidak bisa diunduh orang lain tapi tetap mau aman.
---

# DISTRIBUSI APK PRIVAT + GOOGLE PLAY PROTECT

## Pertanyaan user

> *"gw mau Google Play Protect ngebaca APK ini aman, tapi biar hanya developer
> aja yang merasakan — org luar ga bisa download/gunakan. Bisa?"*

## Jawaban: BISA, dan kedua syaratnya tidak bertentangan

### 1. Play Protect TIDAK butuh URL publik

Dari dokumentasi resmi Google
(`developers.google.com/android/play-protect/client-protections`):

> "It scans all apps on a device, **regardless of download source**, to identify
> Potentially Harmful Applications (PHAs)."
>
> "Google Play Protect offers protection for apps that are installed from
> sources **outside of Google Play**. When a user tries to install an app,
> Play Protect conducts a **real-time check**..."

Artinya: pemindaian dipicu oleh **package installer di perangkat**, bukan oleh
URL. APK yang diunduh dari draft release privat **tetap** dipindai:
- real-time check saat instalasi (lokal + backend Google)
- daily scan
- on-demand ML check

Jadi menyembunyikan file **tidak** mengurangi keamanan checks-nya.

### 2. Cara menyembunyikan APK dari publik di GitHub

`softprops/action-gh-release` → tambahkan `draft: true`.
Draft release **tidak terlihat dan tidak bisa diunduh** oleh siapa pun kecuali
collaborator yang punya write access.

Verifikasi (WAJIB — jangan percaya, buktikan):
```bash
# tanpa login sama sekali
curl -sIL -o /dev/null -w "%{http_code}\n" \
  "https://github.com/OWNER/REPO/releases/download/TAG/app-release.apk"
# harus: 404

curl -s "https://api.github.com/repos/OWNER/REPO/releases/tags/TAG" \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('message','-'))"
# harus: Not Found
```

Developer sendiri tetap bisa unduh dengan `gh release download` (pakai token).

### 3. Bersihkan APK publik yang sudah bocor

Sudah terbit tidak bisa "dibatalkan" — link yang sudah dibagikan masih hidup
sampai aset's dihapus:
```bash
gh release delete-asset <tag> app-release.apk --repo OWNER/REPO -y
# lalu verifikasi asset count = 0 dan URL lama balas 404
```

## Cara mendapatkan badge "Play Protect terverifikasi" yang sesungguhnya

Draft release **tidak** memberi lencana "verified". Kalau mau lencana resmi,
jalur resminya = **Google Play Console → Internal testing** (butuh akun
developer berbayar sekali ~$25). itu Opsional, bukan syarat.

## Peringatan jujur soal "tidak bisa dipakai orang luar"

Menyembunyikan download ≠ mencegah pemakaian. Siapa pun yang Somehow sudah
memperoleh APK-nya tetap bisa memasang. Yang bisa dijamin hanya:
- **tidak mudah didapat** (tidak muncul di pencarian publik)
- **tidak bisa di-update** oleh orang lain (tanda tangan berbeda)
- kalau mau lebih ketat: tambahkan gating di server (cek lisensi/token),
  tapi untuk app yang **sudah offline-first tanpa backend**, itu tidak ada.

Jangan janji "mustahil dipakai orang lain" — itu tidak benar secara teknis.