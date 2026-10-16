---
name: lan-device-id-without-root
description: Cara mengidentifikasi perangkat (TV/HP/laptop/IoT) yang tersambung di jaringan WiFi rumahuser sendiri dari Termux TANPA root, ketika arp-scan/netdiscover tidak bisa dipakai. Memb Covers cara dapat IP lokal tanpa netlink, PTR reverse-DNS lewat dnsmasq router OpenWrt, dan sebaiknya port signature untuk klasifikasi TV vs laptop vs HP. Gunakan saat user minta "cek ada berapa TV/HP/laptop di jaringan WiFiku" atau "siapa saja yang nyambung ke WiFi".
---

# Identifikasi perangkat LAN tanpa root (Android/Termux)

## 0. Yang mustahil, jangan dicoba

Tanpa root di Android, semua tool ARPtentang gagal:

| Cara | Hasil |
|---|---|
| `arp-scan` | butuh raw socket → `Permission denied` |
| `netdiscover` | sama |
| `/proc/net/arp` | `Permission denied` |
| `ip addr` di PATH Termux | `command not found` |
| `/system/bin/ip addr` | `Cannot bind netlink socket: Permission denied` |
| `ip neigh` | sama |
| `nslookup` / `dig` / `host` | **tidak terpasang** di Termux user |
| mDNS reverse (224.0.0.251:5353) | balasan 0 dari Android app sandbox |
| SSDP M-SEARCH | 0 — jangan andalkan |

Artinya **tidak ada MAC address** dari Termux. Tapi kita tetap bisa identifikasi
dengan 2 sumber yangpengganti: **DHCP hostname dari dnsmasq router** + **port signature**.

## 1. Cari subnet (WAJIB, jangan tebak)

```bash
node -e "const os=require('os');const n=os.networkInterfaces();for(const k in n){for(const a of n[k]){if(a.family==='IPv4')console.log(k,a.address,a.mac)}}"
```

`getifaddrs` di Node **TIDAK butuh netlink** → selalu jalan.
Lalu konfirmasi gateway respond: `curl -s -o /dev/null -w "%{http_code}\n" http://GATEWAY/`

## 2. Scan hidup (cepat, ~8 detik untuk /24)

```bash
nmap -sn -n -T4 --min-rate 800 -PS22,80,443,445,554,8008,8080,8081,5000,32400,8009,2022 192.168.110.0/24
```

⛔ **Jebakan nmap:** target dipisah **SPASI**. Koma = `WARNING: No targets were
specified, so 0 hosts scanned` — dan command berikutnya terlihat "sukses".
⛔ `-sn` dengan `-PS<ports>` lebih andal daripada ping broadcast.

## 3. Kunci utama: PTR ke router dnsmasq

Router OpenWrt/LuCI = dnsmasq, dan dnsmasq **balas PTR dengan nama DHCP**.
Android memakai hostname = **nama model** ("POCO-M7-Pro-5G", "Galaxy-A32"),
Apple memakai "iPhone" atau kode model ("I2502").

`nslookup` tidak ada di Termux, tapi `dns.promises.Resolver` punya:

```js
const r = new dns.promises.Resolver();
r.setServers(['192.168.110.1']);   // router = server DNS
await r.reverse('192.168.110.65'); // -> ['POCO-M7-Pro-5G.lan']
```

Hostname custom (bukan nama model) =device yang nama-mesinnya disetel manual →
**kandidat kuat laptop/PC/TV**, bukan HP.

## 4. Klasifikasi pakai port signature

HP Android/iOS modern = firewall **semua** port → 0 port terbuka. Itu bukan
"device mati", itu normal. Jadi **nol port terbuka = kemungkinan besar HP**.

| Perangkat | Port signature |
|---|---|
| LG webOS TV | `8000/tcp`, **8008**, 8009 |
| Samsung Tizen TV | **8002**, 8001, 55000 (UPnP) |
| Roku TV | **8060**, 7000 (AirPlay), 9100 |
| Apple TV | **7000**, 49152-65535 |
| Chromecast | 8008, 8009, 9100 |
| Plex | 32400 |
| DLNA/UPnP umum | **554** (RTSP), **1900/udp** |
| Printer | 9100, 631 (IPP), 515 |
| Windows/PC | **445**, 139, 135, **3389**, 5985 (bisaaja tertutup Windows Firewall) |
| Linux/SSH | 22 |
| Router/ONT | 80, 443, 7547 (TR-069) |

```bash
nmap -n -T4 --open -p 17500,7000,8008,8009,8060,32400,9090,554,139,445,135,3389,5985,9121,9100,631,515,80,443 192.168.110.X
```

## 5. Jebakan output nmap yang harus dipahami

`nmap --open` **hanya mencetak host yang punya port terbuka**. Kalau output cuma
`Nmap done: 13 IP addresses (13 hosts up) scanned` tanpa baris "scan report",
itu artinya **memang 0 host punya port terbuka** — bukan error dan bukan
"scan gagal". Jangan conclude "perangkatnya tidak ada".

`nmap -p-` di 25 host butuh >5 menit di HP → pakai daftar port target saja.

## 5b. Tambahan yang sudah dites (11 Okt 2026) — jangan ulangi

**Router web UI = login-gated, TIDAK ada halaman status tanpa login:**

| Endpoint | Hasil |
|---|---|
| `http://GATEWAY/` | 200, 1.5 KB = halaman login |
| `/cgi-bin/luci` | 200, 47 KB = halaman login (86x "password/login") |
| `/cgi-bin/luci/admin/status/overview` | 404 |
| `/cgi-bin/luci/admin/status/dhcp` | 404 |
| `/cgi-bin/luci/admin/system/hostname` | 404 |
| `/ubus`, `/cgi-bin/luci/rpc/sys` | 404 |
| ONT `192.168.1.1` | 200 tapi 13x password/login |

Jadi **tidak ada bypass**. Satu-satunya jalan = password admin router (consent).

**Fingerprint TTL + RTT** (gratis, tanpa login, sangat berguna saat PTR kosong):
```bash
ping -c2 -W1 192.168.110.X
```
- **TTL 64** = stack Linux/Android (HP, Android TV, Raspberry Pi, printer).
- **TTL 128** = Windows (PC/laptop Windows).
- **RTT tinggi (70-160 ms)** = perangkat dalam **power-save / doze** -> ciri HP
  yang sedang tidak aktif. Sedang aktif = ~5 ms.

**DNS brute-force hostname ke router = sia-sia.** Sudah dites dengan wordlist
~80 nama (desktop, laptop, tv, chromecast, roku, printer, nas, dll) pada
`.lan/.local/.home` -> semua `ENOTFOUND`. dnsmasq hanya melayani nama yang
terdaftar di DHCP. Sanity check selalu: `resolve4('<nama-device>.lan')` harus
balik IP -> kalau gagal berarti DNS yang dipakai bukan router yang benar.

## 6. Cara pasti 100% (perlu izin user)

Baca **DHCP lease table + MAC** di router (LuCI → Status → DHCP Leases, atau
`/cgi-bin/luci/admin/status/overview`). MAC → vendor memberi jawaban pasti
(Xiaomi/Samsung/Apple = HP, Raspberry Pi/Tuya = IoT/TV stick, Intel/Realtek =
laptop). ⛔ **Butuh login router = aset pribadi user → SELALU tanya izin dulu**
sebelum menyentuh password admin.

### Kalau user TIDAK TAU password router

Jangan reset router (menghapus semua setelan ={memperanje} aset rumah). Tiga
jalur ganti yang **benar-benar bekerja**:

1. **Tanya user siapa pemiliknya.** Nama DHCP custom (`tjp`, `naulidata`,
   `tamatama`) sangat sering = nama device yang*diatur manual* oleh pemiliknya
   (nama panggilan, nama anak). Userdingsan sendiri lebih cepat dari scan.
2. **Metode toggle WiFi (100% akurat, butuh koordinasi orang).**
   Scan baseline → minta satu device **matikan WiFi** → scan ulang → IP yang
   hilang = device itu. ~1 menit per device. Bisa di.batch: 3-4 HP dimatikan
   sekaligus, scan, nyalakan satu-satu.
3. **Reset router** (factory reset) = jalur terakhir, HANCURKAN semua setelan
   WiFi user. Hanya kalau user minta.

### Cara cek apakah router punya info lain tanpa login

`nmap -p- GATEWAY` (1 host, ~2 menit di HP) sering memunculkan service yang tidak
diumpikan: MQTT broker (1883/8883/9883), SNMP (161/udp), printer sharing.
⛔ **MQTT anonim biasanya DITOLAK** (`ECONNRESET` sebelum CONNACK). Kalau
diterima tanpa auth, SUBSCRIBE `#` beberapa puluh detik = topic `shelly/...`,
`tele/TASMOTA_xxx/#`, `zigbee2mqtt/...` langsung **membuka nama smart-device** —
cara terbaik menemukan TV stick / smart-home yang TIDAK ada di DHCP.
PENTING: TCP yang accept tapi 0 byte & bukan HTTP = broker/service bukan web,
jangan dipaksa di-curl.

## 7. Yang HARUS disebut jujur ke user

- Perangkat **mati/power off** tapi masih punya DHCP lease → tidak terlihat.
- Perangkat yang hanya konek ke **band 5 GHz** vs 2.4 GHz — scan /24 menutup
  keduanya, jadi aman.
- Guest network / VLAN terpisah = subnet berbeda, perlu scan juga.
-_scan di subnet ISP (`192.168.1.0/24` di Indihome) = perangkat di sisi ONT,
  bukan "jaringan WiFi user". Sebut terpisah bila relevan.
