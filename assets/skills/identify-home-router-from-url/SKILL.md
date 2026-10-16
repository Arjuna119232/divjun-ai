---
name: identify-home-router-from-url
description: Cara mengenali router sendiri dari URL (LuCI/OpenWrt, ZTE, Huawei, ASUS, TP-Link) hanya dari halaman login, tanpa login, dan bagaimana memetakan topologi dual-NAT Indihome. Gunakan saat user kirim URL lokal 192.168.x.1 atau tanya "ini apa?".
---

# Identifikasi router sendiri dari URL

Pakai skill ini saat user kirim URL lokal (`192.168.x.1`, `10.x.x.1`,
`routerlogin.net`) lalu tanya "ini apa?" atau "ini router gue bukan?".

## 3 langkah verifikasi BUKAN menebak

**1. Buktikan itu milik user, bukan halaman random.**
Bandingkan IP publik user dengan saat pertama kali dibuka:

```bash
curl -s https://ipinfo.io/json    # isi ip/org = jaringan user
```

Kalau IP publik sama -> device itu di jaringan user.

**2. Baca header + body halaman. Jangan login.**
`--resolve`/URL lokal + `-k` (https dengan sertifikat lokal) + `-i` (header).

**3. Cek signature per vendor di body/header.**

| Tanda | Arti |
|---|---|
| `/cgi-bin/luci/`, `luci-static/web/`, header CSP + HSTS | **OpenWrt / LEDE** (LuCI = Lua Configuration Interface) |
| `lighttpd` di port 80/443 | OpenWrt (LuCI default pake lighttpd) |
| charset `gbk`, `nginx (reverse proxy)` | Huawei / ZTE ONT keluaran China |
| `goform/`, `/cgi-bin/luci` ZyXEL | ZTE |
| `Main_Login.asp`, `dsl` | ZyXEL |
| `tomato`, `/cgi-bin/tomato` | Tomato firmware (flashed pada router ISP ) |

```bash
curl -sk -m 10 -i "https://IP_ROUTER/cgi-bin/luci/" | head -20
curl -sk -m 10 "https://IP_ROUTER/cgi-bin/luci/" | grep -oiE "<title>[^<]*</title>|OpenWrt|LEDE|LuCI|luci-static" | sort -u
timeout 60 nmap -sV -Pn --top-ports 12 IP_ROUTER
```

## Topologi dual-NAT Indihome (pola paling sering di Indonesia)

```
ONT Indihome  192.168.1.1  (nginx, charset gbk)  <- TIDAK boleh diubah, milik ISP
     │
router OpenWrt  192.168.110.1  (LuCI, lighttpd)  <- di-flash oleh user/teknisi
     │
HP / laptop / TV  192.168.110.x
```

Kenapa muncul? Indihome membatasi bandwidth di sisi ONT (~10 Mbps cap di
beberapa paket). Solusi komunitas: **biarkan ONT apa adanya, pasang router
kedua yang di-flash OpenWrt**. LAN OpenWrt biasanya diganti ke subnet kustom
(192.168.100.x, 192.168.110.x, 192.168.5.x) supaya tidak bentrok dengan
192.168.1.x milik ISP.

## Jebakan yang wasting time

1. **Subnet user bukan selalu `192.168.1.0/24`.** Kalau HP-nya di router
   OpenWrt, subnetnya yang dipakai user. Untuk tahu pasti: scan dua-duanya
   (`nmap -sn` dua subnet) dan lihat mana yang banyak perangkat hidup.
2. **Scan subnet besar tanpa batas = timeout.** `nmap -sn 192.168.100.0/24`
   dari Termux bisa >3 menit. Pakai `--min-hostgroup 64` atau scan per /24
   dengan `timeout 45`.
3. **Tanpa root Termux tidak bisa lihat interface.** `ip addr show wlan0`,
   `ip route`, `getprop dhcp.*` semuanya kosong. Cara dapat subnet: tebak dari
   subnet umum ISP, lalu verifikasi dengan `nmap -sn`.

## Prinsip consent (WAJIB)

Router itu **aset rumah user**. Membaca halaman login (tanpa login) =
aman. **Mencoba password default / login ke router = minta izin dulu.**
Sebutkan risikonya (mengubah setting router bisa putus internet rumah
sekeluarga), dan tawarkan cara meng reversesinya.

Kalau user memang minta diuji (misal untuk belajar bug bounty), itu
**legal kalau router itu miliknya sendiri** — tapi tetap:tanya dulu sebelum
eksekusi, dan jangan pernah diarahkan ke router tetangga.

## Cara menjawab user

1. **Verdict**: "ini router kamu sendiri, bukan halaman mencurigakan" —
   beserta bukti (IP publik sama, signature vendor cocok).
2. **Penjelasan singkat** apa itu LuCI/OpenWrt dalam 2 kalimat.
3. **Konteks**: kenapa user punya OpenWrt di atas Indihome (pola umum).
4. **Temuan keamanan yang jujur**: SSH tertutup = bagus; tapi firmware
   hasil flashing tidak dapat update keamanan ISP lagi, dan password
   default LuCI (`root`/`admin`, `admin`/`admin`) adalah salah satu vektor
   takeover perangkat paling umum di dunia.
5. **Tawaran**: kalau mau, gw bantu cek apakah password admin-nya masih
   default — atas izin kamu, di router kamu sendiri, tanpa mengubah
   apa pun.