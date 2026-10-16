---
name: hyperos-driver-app-tuning
description: Cara bikin app driver/ojol (Grab, Gojek, Shopee) jalan ringan & stabil di HP Xiaomi/HyperOS tanpa root dan tanpa memodifikasi APK-nya. Isi baseline pengukuran koneksi/RAM dari Termux, 7 setting yang benar-benar berpengaruh (dan urutan prioritasnya), syarat Shizuku, risiko + batas yang boleh disentuh. Pakai saat user minta "APK Grab gue berat", "gacor ringan", "koneksi lancar", "bikin app kerja gue ringan", atau minta tuning HP untuk app yang harus jalan di background.
---

# Tuning HP HyperOS untuk app driver (Grab/Gojek/Shopee)

Prinsip: **jangan modifikasi APK target** (tanda tangan berubah → app mendeteksi
repack → flag akun). Yang diperbaiki adalah **kebijakan HP**, sisi atas OS.

## 1. Ukur dulu (read-only, dari Termux)

```bash
head -3 /proc/meminfo                      # MemAvailable
getprop ro.soc.model
getprop gsm.network.type; getprop | grep -i ims   # LTE + VoLTE
getprop | grep -iE "signal|rssi"
getprop | grep -i npuzlibrary || echo "Shizuku TIDAK aktif"
ping -c 10 grab.com | tail -3              # latensi ke server
ping -c 5 8.8.8.8 | tail -2
curl -s -o /dev/null -w "%{http_code} %{time_connect} %{time_total}\n" https://www.grab.com
```

**Langsung laporkan angka ke user dalam bentuk tabel.** Kalau ping <60 ms dan
0% loss → Large Network **bukan** penyebabnya; jangan menawarkan "benerin
koneksi" (user akan merasa ditolak). Fokuskan ke battery policy.

## 2. Syarat eksekusi: Shizuku

Termux **tidak bisa** `settings put` / `appops` / `pm` tanpa Shizuku
(WRITE_SECURE_SETTINGS butuh signature|privileged).
`getprop | grep npuzlibrary` → kalau kosong, Shizuku belum hidup.

Pengguna nyalakan: app **Shizuku** → *Start via wireless debugging*
(Wi-Fi + Bluetooth harus menyala). Shizuku mati tiap reboot.
Alternatif: beri langkah manual per menu — selalu tawarkan ini sebagai opsi
karena nol risiko.

## 3. 7 perubahan, urut dari yang paling menentukan

| # | Pengaturan | Kenapa |
|---|---|---|
| 1 | Battery optimization app → **Unrestricted** | Android/YOLO Killने कर देता। Default-nya app dibekukan saat layar mati — mode driver harus tetap jalan |
| 2 | Autostart ON + kunci di Recents | HyperOS HYDRAT/kill saat idle atau pas app dipasang ulang |
| 3 | **Google Play Services → Unrestricted** | Sumber lokasi yang dipakai app driver. Dipangkas → lokasi meleset → order dibatalkan / akun di-flag |
| 4 | Data saver + Battery saver OFF | Data saver membatasi transfer di background; battery saver menurunkan clocks CPU |
| 5 | Background process limit → Standard + **matikan Memory Extension** | **MiuiSentinel** (HyperOS 3) force-close app yang RAM > 3,5 GB; app peta+navigasi gampang tembus itu |
| 6 | Location: **Wi-Fi scanning + Bluetooth scanning ON** | GPS jadi assisted; jauh lebih akurat di dalam gedung/bawah tanah |
| 7 | Animation scale 0,5x | Setiap scroll/tap menyalakan GPU; hemat jelas, tampilan tetap normal |

Tiga pertama memberi ~90% manfaat. Kalau user cuma mau satu → pilih #1.

## 4. Risiko & batas (wajib disebut, aturan consent)

- Semua perubahan **reversible** dari menu yang sama.
- **Tidak** disentuh: APK/data/akun app target, root, bootloader, aplikasi lain.
- Root/Magisk **dilarang** kalau HP ini device kerja (akun ikut kena ban).

## 5. Jebakan

- Jangan换上 navrat — kalau user minta "bikin APK-nya ringan", jawab: itu
  tidak bisa tanpa merusak tanda tangan; yang bisa diperbaiki OS-nya.
- Jangan mengarang "koneksi jelek" tanpa mengukur ping lebih dulu.
- Setelah Shizuku nyala, `settings`/`appops` masih bisa GAGAL di HyperOS
  untuk sebagian key — selalu cek exit code, jangan asumsikan berhasil.

## 6. Jalur menu manual (HyperOS 3 / Android 16, POCO M7 Pro)

Opsi **tanpa Shizuku** — pilih ini kalau user menolak tool/root. Semua
reversible dari menu yang sama.

| # | Menu persis | Yang dipilih |
|---|---|---|
| 1 | Setelan → Aplikasi → Kelola aplikasi → **Grab** → Batas baterai / *Battery saver* | **Tanpa batasan (Unrestricted)** |
| 3 | Setelan → Aplikasi → Kelola aplikasi → **Google Play services** → Batas baterai | **Tanpa batasan** |
| 2a | Aplikasi **Keamanan** → **Autostart** → Grab → aktifkan | ON |
| 2b | Aplikasi **Recents** → tahan kartu **Grab** → ikon gembok | terkunci |
| 4a | Setelan → Koneksi & berbagi → **Data Saver** | OFF |
| 4b | Setelan → Baterai → **Battery saver** | OFF |
| 5a | Setelan → Aplikasi → **Peluncuran aplikasi** (*App launch*) → default | **Standar** |
| 5b | Setelan → Pengaturan tambahan → **Ekstensi memori** (*Memory extension*) | OFF |
| 6a | Setelan → Lokasi → **Wi-Fi scanning** + **Bluetooth scanning** (+ *Improve accuracy*) | ON semua |
| 6b | Setelan → Aplikasi → Kelola aplikasi → Grab → Izin → **Lokasi** | **Presisi**, bukan Approximate |
| 7 | Setelan → Tentang HP → ketuk 7× *Versi HyperOS* → Developer options → Animation scales | ketiganya 0,5× |

Jebakan label:
- Yang penting pilih **Unrestricted / Tanpa batasan** — JANGAN "Battery saver"
  atau "Optimal" (itu justru yang membekukan app).
- Menu **Autostart hilang** kalau ikon app disembunyikan dari launcher →
  matikan "hidden launcher", restart HP, menu muncul lagi.
- Semua setting di atas **per-app**; ulangi untuk Google Play Services juga.
- Jangan dikerjakan saat sedang narik. Setelah diubah, buka ulang Grab sekali.
- Verifikasi: matikan layar ±30 menit → mode driver harus tetap hidup dan
  lokasi tetap terkirim (bukan "reconnecting").