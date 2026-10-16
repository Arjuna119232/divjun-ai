---
name: osint-web-console
description: Build a Node-backend OSINT web console when features cannot run in an Android WebView APK — CORS-free fetching, 250+ platform username sweeps, 3D globe, interactive force-directed graph, report export. Use when the user says "kalau tidak bisa di APK, buat website", or when a feature is too heavy for mobile (force layout, big crawls, SVG export, 3D). Zero npm dependencies.
---

# Website Konsol OSINT (backend Node, tanpa dependency)

Pelajaran dari `/storage/emulated/0/Fonts/intelegen-webview/web`, 7 Okt 2026.

## Kenapa sebagian fitur HARUS jadi website

| Fitur | Kenapa tidak bisa di APK WebView |
|-------|-----------------------------------|
| Force-directed graph | Butuh banyak frame/detik + zoom/pan responsif. WebView Android lambat |
| Sweep 250+ platform | Rate limit ditempuk ke IP pribadi HP. Server tidak |
| Globe 3D | Butuh WebGL + 1 MB library. HP kehabisan memori |
| Ekspor SVG/laporan | Butuh DOM besar + Blob download |
| **CORS** | **WebView memblokir `fetch()` dari `file://`. Di web tidak ada masalah sama sekali** |

Yang TIDAK boleh dipindah ke web (butuh izin Android):
call log, SMS, kontak, GPS. Mustahil dibaca dari browser.

## Arsitektur minimum yang benar

```
browser  --fetch-->  server Node  --http/https-->  API tujuan
```

Server yang ambil data, browser cuma render. CORS hilang total.

## Server Node tanpa dependency

```javascript
const http = require('http'); const https = require('https');

// WAJIB: UA browser. Tanpa ini banyak API balas 403.
headers: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 14) ... Chrome/131.0.0.0' }

// WAJIB: ikuti redirect. rdap.org balas 302 ke registry asli.
if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
  res.resume();
  return fetchExternal(new URL(res.headers.location, parsed), opts).then(resolve);
}
```

### Proteksi SSRF (WAJIB — kalau lupa, situs bisa dipakai menyerang jaringan lokal)
```javascript
function isAllowed(rawUrl) {
  const p = new URL(rawUrl);
  if (p.protocol !== 'http:' && p.protocol !== 'https:') return false;
  const h = p.hostname.toLowerCase();
  if (h === 'localhost' || h === '127.0.0.1' || h === '::1') return false;
  if (h.startsWith('10.') || h.startsWith('192.168.') || h.startsWith('172.')) return false;
  return ALLOWED_HOSTS.has(h);
}
```
Juga **path traversal** di static file server:
```javascript
const file = path.join(ROOT, path.normalize(rel).replace(/^(\.\.[/\\])+/, ''));
if (!file.startsWith(ROOT)) { res.writeHead(403).end('Forbidden'); return; }
```

### Rate limit di server
Sweep 250 platform pakai worker pool + concurrency 8. JANGAN `Promise.all` 250 sekaligus.
```javascript
async function worker() { while (cursor < targets.length) { /* cek 1 situs */ } }
await Promise.all(Array.from({ length: 8 }, worker));
```
Batas atas per request: 250. Lebih dari itu pecah jadi beberapa batch di frontend.

## Force-directed graph tanpa d3 (~250 baris)

Sendiri lebih baik daripada dependensi untuk kasus ini:
- Jarak ideal: `K = Math.sqrt((w*h)/n) * 0.55`
- Tolak-menolak: `REPULSE / d2` untuk semua pasangan
- Pegas: `(d - K) * SPRING` untuk tiap edge
- Redam `0.86`, clamp velocity ±24, 260–320 iterasi cukup untuk < 200 node
- Render: zoom/pan via `ctx.translate`/`ctx.scale`
- Deteksi node: `Math.hypot(n.x - p.x, n.y - p.y) < r + 6`

WAJIB: index node dengan `new Map()` per frame. `Array.find()` di dalam loop
edge = O(n²) dan berat untuk graph besar.

## MD5 untuk Gravatar
Jangan tulis MD5 golf di client — hampir pasti salah (saya pernah menulisnya
dan patah). Pakai `crypto` Node:
```javascript
require('crypto').createHash('md5').update(email.toLowerCase()).digest('hex')
```

## Globe 3D
`https://unpkg.com/globe.gl@2.32.0/dist/globe.gl.min.js` (~1 MB, gratis).
Selalu pasang `onerror` yang menampilkan pesan jujur, bukan Diamkan saja.

## Menjalankan di Termux
`setsid` saja TIDAK bekerja — proses langsung mati. Yang terbukti berhasil
(adalah memisahkan start dan verifikasi jadi dua command):
```bash
setsid nohup node server.js >"$TMPDIR/web.log" 2>&1 < /dev/null & disown
```
```bash
sleep 4; curl -s http://127.0.0.1:8420/api/health
```
Sediakan `/api/health` sebagai verifikasi nyata, jangan Start-Sleep lalu berharap.

**JANGAN `pkill -f "node server.js"` di command yang sama dengan start.**
Pola itu bisa membuat proses yang baru saja start ikut mati sendiri.
Pisahkan: satu command untuk stop, satu untuk start, satu untuk verifikasi.

## Checklist sebelum bilang "website selesai"
- [ ] `node --check` semua file
- [ ] Server hidup: `curl /api/health` balas JSON
- [ ] Tiap endpoint diuji nyata (bukan cuma cek 200)
- [ ] SSRF: `localhost`, `127.0.0.1`, `192.168.x`, `file://` semua DITOLAK
- [ ] Path traversal: `../../etc/passwd` dan versi encoded DITOLAK
- [ ] Tidak ada `innerHTML` di frontend (semua `textContent`)
- [ ] Semua asset static balas 200
- [ ] Buka di HP lewat `termux-open-url`
