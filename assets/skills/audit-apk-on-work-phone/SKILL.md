---
name: audit-apk-on-work-phone
description: Audit manual APK-by-hand di Termux sebelum install ke HP kerja user (mis. HP yang jadi alat nafkah). Cek sha256, permissions, domain tujuan, akses data pribadi, dan apakah app butuh root. Gunakan skill ini setiap user minta install APK di HP yang dipakai untuk kerja/pendapatan.
---

# Audit APK sebelum pasang di HP kerja

Pakai skill ini setiap user mau install APK di HP yang dipakai untuk
menghasilkan uang (driver ojek online, kerja freelance, aplikasi kerja). HP begitu punya
risiko yang TIDAK ADA di HP biasa: satu keputusan salah = kehilangan bulanan,
dan ruginya baru ketahuan saat user mau buka akun.

## Kenapa wajib audit manual (bukan cuma "ada di Play Store")

Play Store / APKPure hanya memberi "tidak ada malware terdeteksi" dari scanner
statis. Itu TIDAK menjawab 3 pertanyaan yang paling penting:

1. Apakah APK ini **menyentuh data aplikasi lain** (SMS, contacts, akun)?
2. Apakah APK ini **butuh root**, dan apakah root itu berbahaya di HP ini?
3. Berapa **beban runtime**-nya (CPU/RAM/baterai/storage)?

## 5 langkah audit di Termux

Semua perkakas sudah ada: `aapt2`, `apktool`, `curl`, `unzip`, `strings`.

```bash
cd /data/data/com.termux/files/usr/tmp/zyvo && mkdir -p apkcheck && cd apkcheck

# 1. UNDUH dari URL RESMI (GitHub releases / situs developernya), bukan mirror
curl -sL -o app.apk "URL_RESMI" -w "http=%{http_code} size=%{size_download}\n"

# 2. VERIFIKASI INTEGRITAS - bandingkan dengan sha256 yang dipublikasikan
#    developer (biasanya ada di manifest/rilis resmi)
sha256sum app.apk
# kalau cocok -> file asli. Kalau tidak cocok -> STOP, jangan dipasang.

# 3. PERMISSIONS + BADGING
aapt2 dump permissions app.apk
aapt2 dump badging app.apk

# 4. DOMAIN TUJUAN - ini yang membedakan app bersih vs app nakal
mkdir -p x && unzip -qo app.apk -d x
cat x/classes*.dex | strings -n 6 \
  | grep -oE "https?://[a-zA-Z0-9._~:/?#@!$&'()*+,;=%-]{6,}" \
  | sed -E 's#(https?://[^/]+).*#\1#' | sort | uniq -c | sort -rn

# 5. APAKAH MENYENTUH DATA / APLIKASI LAIN?
cat x/classes*.dex | strings -n 5 \
  | grep -iE "content://sms|content://contacts|content://call_log|getAccounts|AccountManager" \
  | sort -u
```

Bonus cek struktur:
```bash
unzip -l app.apk | grep -iE "\.so$|rootfs|\.img|tar\.gz|\.imgz"
```
File rootfs/VM besar = app ini **makan GB dan RAM**, bukan app ringan.

## Tafsir hasil

| Temuan | Arti | Tindakan |
|---|---|---|
| sha256 tidak cocok | file disisipkan | STOP |
| Domain tak dikenal (telemetry/ad/C2) | risiko | cek satu per satu |
| `content://sms`, `getAccounts` | baca data pribadi | tolak untuk HP kerja |
| `REQUEST_INSTALL_PACKAGES` | bisa pasang APK lain | tanya dulu |
| `MANAGE_EXTERNAL_STORAGE` | akses semua file | wajar untuk tool, tapiperhatikan |
| Root di metadata / `su` di README | butuh root | cek dulu apakah root aman di HP ini |

## Tiga pertanyaan WAJIB dijawab sebelum bilang "aman install"

1. **Apakah HP ini alat nafkah?** Kalau ya, cek kebijakan perusahaan tempat
   user bekerja soal root, device modification, dan VPN/proxy.
2. **Apakah app minta Location?** Kalau ya, cek apakah juga minta
   `ACCESS_MOCK_LOCATION` - itu yang bikin GPS spoofer ikut terdeteksi.
3. **Beban runtime-nya?** VM/emulator/chroot = pegang CPU 100%, panas, boros
   baterai. Kalau HP ini dipakai navigasi sambil kerja, jangan jalan bersamaan.

## Kasus nyata yang sudah selesai (10 Okt 2026) - StrykerOSS

Hasil audit: **BERSIH, install aman dari sisi malware.**

- sha256 cocok persis dengan `stryker_manifest.json` resmi (`d57a4c36...`).
- Semua domain tujuan = github.com, zalexdev.com, tile peta OpenTopoMap,
  nmap.org, exploit-db.com. NOL domain telemetry/ad-network.
- TIDAK ada akses SMS/kontak/akun. TIDAK ada `DexClassLoader` (tidak ada
  obfuscation loader).
- Permissions wajar untuk tool: Location, Bluetooth, Record audio, storage,
  `REQUEST_INSTALL_PACKAGES`.
- TIDAK minta `ACCESS_MOCK_LOCATION` -> tidak akan terdeteksi GPS spoofer.
- Tidak butuh root untuk engine rootless. Docs sendiri: "Requires Nothing.
  Stock device, nothing flashed."

**Jebakan nyatanya bukan malware, tapi 3 hal lain:**

1. ~2 GB storage + QEMU TCG emulation = CPU 100%, panas, boros baterai.
2. Chroot engine butuh root -> root = **akun kerja terkunci** kalau HP kerja.
3. Visibilitas: kalau HP dipinjam atau diperiksa, tool pentest + `changemac` +
   `checker.py` (PoC CVE) terlihat buruk secara reputasi.

## KUNCI: cek kebijakan perusahaan tempat user bekerja

Sebelum bilang "aman", cek dulu apakah perusahaan tempat user cari nafkah
melarang root / device modification. Contoh nyata:

- **Grab Driver** (grab.com/id): "Modifying your device (rooting, jailbreaking,
  or installing Xposed) ... you will not be able to access your driver account
  if you're using a modified device." Trust & Safety: "Banning of modified
  devices - those accessing their Grab account with modified devices are unable
  to login." GPS spoofer app juga bisa kena ban.
- Police/military/school/kantor govt: biasanya jauh lebih ketat.

**Kesimpulan umum untuk HP kerja**: root =terlarang. Aplikasi rootless (tanpa `su`)
biasanya aman. Sarankan user JANGAN me-root HP penghasil udaranya, dan JANGAN
menjalankan tool berat saat sedang mengendarai.

## Format laporan ke user

1. **Verdict aman / tidak aman** - satu kalimat.
2. **3 bukti konkret** (sha256, domain, permissions) - bukan "katanya aman".
3. **Yang TIDAK akan gw sentuh** - reassurance bahwa install ini tidak merusak
   app yang sudah ada.
4. **Risiko nyata** yang BUKAN dari malware (beban resource, kebutuhan root,
   reputasi).
5. **Cleanup** kalau ternyata mau di-uninstall.

## Cara install APK dari Termux (PASTI PAS)

`pm install` **GAGAL** dari Termux - error `SecurityException: need
MANAGE_USERS or CREATE_USERS permission`. Termux tidak punya izin tersebut di
Android 10+. Yang berhasil adalah membuka installer sistem:

```bash
cp -f app.apk /storage/emulated/0/Download/NamaApp.apk
chmod 644 /storage/emulated/0/Download/NamaApp.apk
am start -a android.intent.action.VIEW \
  -d "file:///storage/emulated/0/Download/NamaApp.apk" \
  -t "application/vnd.android.package-archive" \
  --activity-clear-task
```

Lalu user **harus tap tombol Install sendiri** di layar. Tidak bisa diotomatiskan
dari Termux. Cara cek sudah terpasang:

```bash
pm list packages | grep <paket>     # pm list packages sendiri BOLEH dari Termux
```

Loop dengan timeout biar user tidak kelamaan nunggu:

```bash
for i in $(seq 1 12); do
  sleep 5
  pm list packages 2>/dev/null | grep -q "<paket>" && { echo "TERINSTALL"; break; }
done
```

## Versi terbaru harus dicek ulang, jangan pakai hasil riset lama

Sebelum install, selalu tanya GitHub API + manifest resmi. Contoh nyata: riset
awal memberi 6.0.1 (13 Agu 2026), tapi **6.5** (3 Okt 2026) yang terbaru dan
APK-nya 94 MB (rootless VM image sudah dibundel, jadi tidak perlu unduh 428 MB
terpisah). Ukuran APK melonjak drastis = ada payload besar yang berubah.

```bash
curl -s "https://api.github.com/repos/<owner>/<repo>/releases/latest" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['tag_name']); [print(a['browser_download_url']) for a in d.get('assets',[])]"
```

## Cek domain egress (data yang DIKIRIM ke luar)

Scan domain hanya melihat tujuan. Yang penting: **data apa yang dikirim ke
sana**. Contoh nyata di Stryker 6.5: `api.onlinehashcrack.com` = layanan
crack hash pihak ketiga. Kalau user memakai modul itu, data capture-an dikirim
ke server orang. Jika wifi target bukan milik sendiri, itu masalah etika dan
bisa jadi masalah hukum. Sebutkan eksplisit ke user.
