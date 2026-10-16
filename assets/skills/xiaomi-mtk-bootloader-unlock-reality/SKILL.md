---
name: xiaomi-mtk-bootloader-unlock-reality
description: Cara menjawab " bisa nggak unlock bootloader (UBL) HP Xiaomi/POCO/Redmi gue?" dengan verdict berbasis SoC + región + alat yang benar-benar ada, bukan tebakan. Termasuk jebakan requirement tersembunyi (butuh Windows / 2 HP), matinya jalur mtkclient per-chipset, dan slot harian 00:00 Beijing. Gunakan saat user minta unlock bootloader Xiaomi, mau root HP Xiaomi, atau tanya apakah Termux perlu UBL.
---

# Unlock Bootloader Xiaomi/POCO: verdict berbasis bukti

## Kenapa skill ini ada

User nanya "UBL bisa dipakai buat Termux?" hampir selalu背后的 intent-nya
**"gue mau root/oprek"** atau **"gw kira perlu UBL".** Dua-duanya perlu
dijawab terpisah, karena Termux **tidak pernah** butuh UBL.

## 0. GATE PERTAMA — UBL bukan syarat Termux

Termux jalan di Android **tanpa** bootloader unlocked, tanpa root, tanpa
OEM Unlocking. Jadi kalau pertanyaan aslinya "UBL buat Termux", jawab:
**tidak perlu sama sekali, sudah jalan sekarang.**

UBL hanya relevan untuk: root (patch `init_boot.img`), custom ROM, GSI,
TWRP, atau%%% flashing partisi manual.

## 1. Kumpulkan data device (WAJIB, live, dari Termux)

```bash
getprop ro.product.device          # codename
getprop ro.build.fingerprint       #.region + kode wilayah (WOQxxxM)
getprop ro.build.version.incremental
getprop ro.boot.hardware           # SoC
getprop ro.boot.flash.locked       # 1 = terkunci
getprop ro.boot.verifiedbootstate  # green = stock
getprop ro.boot.slot_suffix        # A/B slot
pm list packages | grep -E "mipicks|accountmanager"   # Mi Community?
TZ=Asia/Shanghai date "+%H:%M"    # waktu Beijing vs lokal
```

Contoh hasil POCO M7 Pro: `citrine` · `citrine_p_id_global` ·
`OS3.0.302.0.WOQIDXM` · `mt6855` · `flash.locked=1` · `verifiedboot=green`
· `_a` · Mi Community terpasang.

⚠️ **Codename ≠ modeldagang.** `beryl` = Redmi Note 14 5G, tapi
`ro.product.device` HP M7 Pro = **`citrine`**. Selalu baca fingerprint,
jangan percaya daftar di web.

⚠️ **Kode wilayah di fingerprint itu penting.** `..._id_global/...WOQIDXM`
= Indonesia. `WOQCNXM` = China (`cn` = CN ROM) — CN ROM **tidak bisa**
apply unlock lewat Mi Community sama sekali.

## 2. JALUR A — Resmi Xiaomi (harus cek requirement tersembunyi)

1. **Mi Community app** (`com.xiaomi.mipicks`) → region **Global**
   (bukan China) → level akun → "Unlock bootloader" → "Apply".
2. Slot harian: **00:00 Beijing**. Indonesia WIB = Beijing − 1 jam →
   **23:00 WIB sehari sebelumnya**. Slot habis dalam milidetik;
   butuh script 4 window paralel.
3. Setelah granted → tunggu **72 jam**.
4. Lalu **Mi Unlock Tool** — **WINDOWS ONLY**. Tidak ada build Linux/macOS.

### ⚠️ JEBAKAN PERSYARATAN TERSEMBUNYI (ini yang biasanya kills plan)

Skrip token yang jalan di Termux (`RohitVerma882/termux-miunlock`,
`offici5l/MiUnlockTool`, `MiForge/MiTool`, `flowTech-x/unlock-tool`)
semuanya **butuh 2 perangkat Android**:
- **target** = HP yang mau di-unlock, mode fastboot
- **host** = HP kedua + Termux + Termux:API, jalankan `termux-fastboot`
- penghubung = **kabel USB OTG**

Satu HP **tidak bisa** jadi host sekaligus target (kalau masuk fastboot,
Termux ikut mati).

Checklist sebelum bilang "bisa":
- [ ] User punya HP kedua yang boleh dipinjam?
- [ ] Ada kabel **USB OTG** (bukan kabel charge biasa)?
- [ ] Termux di HP kedua terpasang + Termux:API?

Kalau salah satu tidak ada → jalur ini **buntu**, jangan janjiin.

## 3. JALUR B — mtkclient / Penumbra (CEK SoC, jangan sambil coba)

Perintah: `python mtk.py da seccfg unlock`.

**SoC V6 yang bootrom-nya di-patch DI HARDWARE** (dari README resmi
shomykohai/mtkclient): **MT6781, MT6789, MT6855, MT6886, MT6895, MT6983,
MT8985**. Untuk semua itu:
- butuh DA loader dari stock fastboot ROM (`images/`),
- *"This only works with UNFUSED devices currently."*
- *"For all devices with DAA, SLA and Remote-Auth activated **no public
  solution currently exists**"*.

Semua Xiaomi MTK sejak ~2020 punya DAA + SLA + Remote-Auth aktif →
**jalur B praktis mati** untuk HP Xiaomi modern.

RPMB magic bypass (Jz8Root/xiaomi-hyperos-bootloader-unlock) terbukti
hardware di **MT6781 (fleur), MT6769Z (fire), MT6833 (gold)** saja.
Sector RPMB berbeda per SoC (57344 / 65504) — **jangan buta erase**.

## 3b. Tool yang benar-benar jalan dari Termux (bukan cuma teori)

| Tool | Repo / install | Fungsi | Status |
|---|---|---|---|
| **pymitool** ⭐ | `pip install pymitool` → `mitool` → `miunlock` | MiUnlockTool (bypass + token `encryptData` + `fastboot oem unlock`) + MiBypassTool + MiAssistant. Rilisan 1.6.1 (16 Sep 2026), provenance GitHub Actions terverifikasi. | CHANGELOG **penuh perbaikan khusus Termux** (`termux-adb`, path `/sdcard/encryptData`, popup `termux-api`) → dirancang jalan di HP. Butuh Termux:API. |
| Xiaomi-HyperOS-BootLoader-Bypass | `MlgmXyysd/...` (PHP 8 + php-adb, 4.8k★) | Bypass quota Mi Community | ⚠️ **BYPASS ≠ UNLOCK.** README-nya sendiri: *"After successful binding, you can use the official unlock tool"*; FAQ: *"only bypasses the restrictions added for HyperOS. You still need to comply with the restrictions for MIUI"* → tunggu **168h** tetap ada. |
| termux-miunlock | `RohitVerma882/termux-miunlock` | Ambil token saja | Butuh **2 HP** (host Termux + target) + kabel USB OTG |
| unlock-tool | `flowTech-x/unlock-tool` | Kirim request slot 00:00 Beijing, 4 window paralel | Phone-only ✅, tapi hasilnya cuma *izin*, bukan unlock |

### ⛔ LAST MILE — ini yang tidak bisa dihilangkan

`fastboot oem unlock` **wajib dikirim saat HP ada di mode bootloader**.
Saat itu Android tidak berjalan → Termux ikut mati → **1 HP tidak bisa jadi
host + target bersamaan**. Jadi selalu ada syarat eksternal:
- 2 HP Android + kabel USB OTG, **atau**
- 1 PC Windows.

Video "Cara Unlock Bootloader Xiaomi HyperOS Tanpa Mi Community"
(youtu.be/GzP12_8o30U) = tool bypass di atas. Judulnya janji "tanpa Mi
Community", dan itu **benar untuk bagian quota/qualification** — tapi
bukan berarti tanpa Mi Unlock Tool.

### ✅ Yang BISA 100% dari HP sendiri: **langkah binding**

Binding cuma butuh **adb ke HP** — bukan fastboot. Termux bisa bicara
dengan adbd HP-nya sendiri lewat loopback:

```bash
adb connect 127.0.0.1:5555     # phone → phone sendiri
```

Ini sudah terbukti bekerja (dipakai untuk `adb forward tcp:9222
localabstract:chrome_devtools_remote` → CDP hidup dari Termux).
Artinya quota harian **23:00 WIB** bisa dihabisi tanpa slot lottery.

⚠️ **Jebakan Termux yang nyata:** `adb` bawaan Termux **rusak** —
`CANNOT LINK EXECUTABLE "adb": cannot locate symbol
_ZNSt6__ndk113__hash_memoryEPKvm`. `pkg install android-tools` tidak
memperbaiki. Yang jalan: `proot-distro login ubuntu && apt install adb`
(≈1.5 GB, tapi(rootfs besar) perlu dicek dulu apakah sudah ada).

## 4. Risiko yang wajib disebut (konsent)

- Unlock = **factory reset**, semua data hilang (verified boot wipe).
- Xiaomi resmi: HP ter-unlock **tidak dapat OTA HyperOS lagi** (kecuali
  re-lock + flash firmware asli).
- **Widevine turun ke L3** (bukan L1) — flag TEE bisa permanen.
- Bank/OVO/GoPay/e-wallet/DRM/app integrity bisa mati.
- Warranty void.
- Risiko **hard brick** kalau erase/write partisi salah.

## 5. Kalau memang butuh root sekarang

Jangan wedge HP kerja. Saran yang benar:
1. Pinjam/p beli HP kedua murah untuk oprek ( Redmi Note lama / Poco yang
   SoC-nya **bukan** V6 = lebih mudah unlock).
2. Pakai **HP kedua** itu sebagai host Termux untuk jalur A — sekaligus
   menyelesaikan 2 requirement sekaligus.
3. Keep HP utama di stock: OTA aman, bank aman, akun kerja aman.

## 6. Halaman yang布里 dipakai verifikasi

- Xiaomi BL FAQ resmi: https://www.mi.com/uk/support/faq/details/KA-07238/
- mtkclient README (daftar V6): https://github.com/shomykohai/mtkclient
- RPMB bypass + tabel SoC proven:
  https://github.com/Jz8Root/xiaomi-hyperos-bootloader-unlock
- Forum讨论 XDA (device-specific, baca device lo):
  https://xdaforums.com/t/guide-bootloader-unlock-xiaomi-mtk-hyperos-miui14-no-mi-unlock-tool-no-168h-wait-rpmb-bypass.4784527

## Jebakan bahasa/ketelitian (dari pengalaman)

- ⛔ Jangan tulis "UBL berhasil tanpa PC" — selalu sebut syarat 2nd device.
- ⛔ Jangan pakai daftar "Xiaomi bisa UBL" dari web tanpa cek SoC-nya;
  aftermarket unlock ≠ official unlock.
- ⛔ `ro.product.device` ≠ codename di halaman firmware ROM.
- ⛔ Zona waktu: cek dengan `TZ=`, jangan karang offset.
