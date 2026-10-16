---
name: wifi-monitor-mode-verdict-before-dongle
description: Cara menjawab "bisa pakai WiFi HP sendiri untuk tool wireless pentest (Stryker/aircrack/wifite) tanpa beli USB dongle?" dengan VERDICT berbasis chipset + root + dokumentasi tool, bukan tebakan. Termasuk peta monitor mode internal per vendor (Qualcomm vs MediaTek) dan jalur vendor-tool MediaTek yang terbukti.
---

# Verdict: monitor mode internal vs USB dongle

Pakai ini SETIAP user tanya "gw bisa pakai WiFi HP sendiri, gak perlu beli
dongle USB?" untuk tool wireless pentest. Jawab dengan 4 cek berurutan.

## Cek 1 Apakah tool-nya sendiri punya jalur WiFi internal?

Jangan asal jawab "bisa". Baca requirement tool. Contoh nyata:

- **StrykerOSS** (zalexdev/strykerapp): docs resminya menyebut
  "Monitor-mode USB Wi-Fi adapter - Known-good: Atheros AR9271, Realtek
  88XXAU - *optional - Wi-Fi capture*". Jadi 4 dari 16 modul (semua Wireless:
  WiFi networks, Handshakes, GeoMac, WPS attacks) butuh adapter. 12 modul lain
  (Terminal, Nmap, Metasploit, Nuclei, Hydra, Dashboard, Core manager,
  Bluetooth WhisperPair, USB/HID, Web) jalan tanpa adapter.
- **Stryker punya 2 engine**: (a) `chroot` native butuh root (Magisk/KernelSU),
  (b) `qemu aarch64` rootless TCG - lambat, adapter diteruskan ke guest.
- Tool lain (Airguard, Wifite, OneShot): cek README-nya, jangan generalisasi
  dari Stryker.

## Cek 2 Root?

Semua jalur monitor mode internal WAJIB root, tanpa kecuali:

- app penguji otomatis **AmWF** (com.hitomatito.amwf) tulis di README:
  "**Root required** - Cannot modify WiFi driver parameters without root".
- repo riset `El-HOOT/MT6639-monitor-mode`: "Root method: KernelSU".

Dari Termux **unrooted**, `/sys/class/net/` dan `/sys/bus/usb/devices/` kosong
(permission Android), jadi tidak bisa verifikasi apa pun. Cek cepat:

```bash
su -c id          # "No su program found on this device" = belum root
getprop ro.soc.model
getprop vendor.wlan.firmware.version
```

## Cek 3 Vendor chip-nya support atau tidak

**Qualcomm/Snapdragon - monitor mode internal BISA.**
Cara klasik: `echo 4 > /sys/module/wlan/parameters/con_mode`
(con_mode 0 = STA/managed, 4 = monitor). Perlu driver QCACLD + firmware yang
support; firmware harus dikompile dengan flag tersebut. App **AmWF** dan repo
**kimocoder/qualcomm_android_monitor_mode** (356 star, ada
`LIST_OF_DEVICES.txt`) adalah referensi utama. Ada juga mode `sta+monitor`
(sniff sambil tetap konek) tapi butuh firmware yang dikompile begitu juga.

**MediaTek/Exynos - monitor mode internal TIDAK ada lewat jalur standar.**
AmWF eksplisit: "**Qualcomm only - Does not work on MediaTek, Exynos, or other
chipsets**".

## Cek 4 Tapi MediaTek punya jalur vendor (harus root, belum generic)

Riset Juli 2026 `github.com/El-HOOT/MT6639-monitor-mode` (MT6639 connac2,
MT6878, KernelSU) membuktikan chip MediaTek **bisa** monitor-mode tanpa USB:

| Kemampuan | Cara |
|---|---|
| Promiscuous / capture EAPOL | `iwpriv wlan0 set_sw_ctrl` (ioctl 0x0014, undocumented) |
| Hardware RF monitor | `wifitest -r` |
| TX injection | `wifitest -t` (100% success) |
| Firmware log | `/dev/fw_log_wifi` |
| Kernel packet trace | `connsys_trace_event` |
| Persistent test mode | patch NVRAM byte `0x02e0 = 0x01` di `/mnt/vendor/nvdata/APCFG/APRDEB/WIFI` + checksum |

Stack driver yang relevan:
`conninfra -> wmt_chrdev_wifi_connac2 -> wlan_drv_gen4m_<soc> -> cfg80211`.
Mode yang dideklarasikan: managed, AP, P2P-client, P2P-GO. **monitor tidak ada
di daftar itu** - cfg80211 "bohong", jalur kodenya ada tapi tidak diekspos.

JEBRAKAN dari repo itu (jangan diulang):

- `set_oid` (ioctl `0x8BEF`) dengan OID tidak dikenal -> **kernel panic**.
- Raw 802.11 frame dump masih PARSIAL (buffer BB1 di `0x7E4` kekecilan).
- Channel hopping belum ada.
- TODO mereka: "Test on other connac2 devices beyond MT6639" -> **belum
  terverifikasi di chip lain**. Selalu sebut ini kalau extrapolate.

## Cara jawab ke user

Jangan jawab "bisa" atau "tidak bisa" doang. Kembalikan:

1. **Verdict satu kalimat** untuk device itu.
2. **3 bukti**: root? vendor chip? apa yang dokumentasi tool itu bilang?
3. **Pemisahan biaya vs waktu**: dongle = sekali bayar, jadi; root + port riset
   = gratis tapi berjam-jam + bisa brick + hasil belum terbukti.
4. **Rekomendasi**: pakai tool TANPA adapter untuk yang memang bisa (12/16
   modul), beli adapter kalau butuh yang tidak bisa.

## Batasan yang jujur harus disebut

- Monitor mode internal = **untuk belajar/otilisasi**. Jangan dipakai menyerang
  jaringan orang tanpa izin.
- Monitor mode internal biasanya memutus koneksi WiFi HP (HP jadi offline).
  Kalau butuh internet bersamaan, aktifkan LTE.
- Ekstrapolasi antar-chip = belum terbukti. Bilang "perlu diuji", jangan
  janjikan.
- Untuk WPS Pixie Dust ada jalur tanpa monitor mode sama sekali
  (`Rem01Gaming/OneShot-Termux`) - cek sebelum merekomendasikan dongle.

## Perimeter device user ini

POCO M7 Pro 5G (`beryl`, MT6855, chip WiFi **MT6631** conninfra gen4m,
Android 16, **belum root**). Adapter USB = komplemen, bukan pengganti:
WiFi internal tetap handle internet, USB adapter handle monitor dan injection.