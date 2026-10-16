---
name: phone-session-capture-termux
description: Cara menangkap traffic web HP (Chrome DevTools Protocol / CDP) dari Termux untuk debug WebView, merekam request API, atau bounty testing — termasuk jebakan adb yang rusak di Termux dan pivot tanpa adb. Gunakan saat butuh lihat request/response halaman web yang terbuka di HP, atau saat adb gagal.
---

# Capture traffic web HP dari Termux

## ⛔ FAKTA: adb native Termux RUSAK
```
CANNOT LINK EXECUTABLE "adb": cannot locate symbol
"_ZNSt6__ndk113__hash_memoryEPKvm"
```
- Ini **konflik ABI inline namespace** (`std::__ndk1` vs `std::__1`), BUKAN
  library kurang. `pkg install libc++` **tidak memperbaiki** (udah newest).
- `pkg install android-tools` juga tidak memperbaiki.
- `pip install adbutils` (2.12.0, Python 3.14 Termux OK) **tetap butuh adb
  server binary** — dia tidak mengimplementasi server sendiri.
- Binary `platform-tools` resmi dari Google = **x86_64** → `Exec format error`
  di aarch64. Tidak bisa dipakai.

## ⛔ FAKTA: adb server di dalam PRoot juga RUSAK
`proot-distro install ubuntu` + `apt install adb` (1.0.41) → binary jalan,
tapi **adb server-nya hang**: menerima koneksi TCP di 5037 tapi **tidak pernah
balas** (curl rc=52 empty reply, raw socket recv → TimeoutError).
Network namespace sendiri **shared** (python http.server di proot bisa diakses
dari Termux, HTTP 200) — jadi bukan masalah namespace, tapi ptrace PRoot
merusak loop socket adb server. Log berhenti di `auth_inotify_init`.

**Verifikasi cepat sebelum sslalu coba lagi:**
```bash
python3 -c "import socket;s=socket.create_connection(('127.0.0.1',5037),3);s.settimeout(3);print(repr(s.recv(200)))"
# TimeoutError = adb server rusak, jangan ulangi
```

## ✅ Pivot yang berhasil: rekons tanpa browser
Buat peta endpoint dari aset publik, bukan dari capture browser:
```bash
curl -sL "https://TARGET/" -H "User-Agent: Mozilla/5.0 (Linux; Android 16) Chrome/154.0" -o /tmp/t.html
# tarik URL bundle JS
grep -oE 'src="[^"]+\.js[^"]*"' /tmp/t.html | head -30
# unduh lalu grep path API
grep -ohoE '"/(api|v[0-9])/[A-Za-z0-9_/{}$.:-]+' bundle*.js | sort -u | head -60
```
Cocok untuk panel merchant/SPV: HTML-nya public, JS-nya public, endpoint-nya
terbuka di dalam bundle.

## Kalau tetap perlu browser session (CDP)
Butuh `adb forward tcp:9222 localabstract:chrome_devtools_remote` → **butuh
adb** → **butuh pairing wireless debugging**:
1. User: Settings > About phone > tap Build number 7x → Developer options
2. User: Developer options > Wireless debugging > ON
3. User: "Pair device with pairing code" → beri **IP:PORT PAIRING** + kode
4. `adb pair IP:PORT` → `adb connect IP:PORT`
5. `adb shell am start -a android.intent.action.VIEW -d <url>` → socket
   `@chrome_devtools_remote` baru muncul (CEK ULANG `/proc/net/unix`)
6. `adb forward tcp:9222 localabstract:chrome_devtools_remote`
7. `curl http://127.0.0.1:9222/json`

⚠️ Kode pairing **expire ~5 menit** → minta kode baru tiap percobaan.
⚠️ Pairing code itu **rahasia** — jangan simpan di laporan/GitHub.

## Test screenshot tanpa root (kalau adb Prefix được)
`adb shell screencap -p /sdcard/x.png` → `adb pull` → file ada di rootfs proot,
harus `cp` ke `$HOME` dulu baru bisa dibaca tool Read.

## Kalau proot + FIFO untuk sesi panjang
Server di bawah proot **mati begitu shell ditutup**. Solusi: FIFO yang
dibuka read-write (`exec 3<> fifo`) supaya reader tidak dapat EOF.
⚠️ FIFO memotong per **baris** → perintah multi-line harus ditulis sebagai
file skrip dulu, lalu dipanggil, bukan dikirim langsung.
