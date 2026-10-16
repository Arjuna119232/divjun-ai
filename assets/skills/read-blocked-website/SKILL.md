---
name: read-blocked-website
description: Cara membaca isi website yang memblokir IP kita (umumnya server Indonesia / WAF Asia) dari Termux — pakai Jina Reader dengan header x-respond-with: html, lalu Wayback CDX + sitemap, lalu parse window.__NUXT__ untukFinding API_BASE_URL. Gunakan saat user mengirim link dan asks "apa saja alat/menu/fungsinya", atau saat curl ke situs itu balik HTTP 000 / "closing connection #0" padahal DNS-nya resolve.
---

# Membaca website yang memblokir IP kita

## Gejala khas (bukan DNS rusak)
```
* Host xxx:443 was resolved.
* IPv4: <IP>  → TCP connect OK
* SSL connection using TLSv1.3 ...        ← handshake SUCCEEDS
* closing connection #0                    ← server TUTUP tanpa balas HTTP
```
`curl -w` = **HTTP 000**, `size_download` 0, tapi `time_connect`/`ttfb` sangat kecil.
Artinya: **bukan** firewall kita, **bukan** DNS, **bukan** cert. Server menolak
berdasarkan IP.asal (umumnya hosting ID/Asia yang hanya serve trafik domestik).
UA browser, `--http1.1`, HTTP/2, ganti port, retry 3× — **semua gagal**. Berhenti coba.

## Urutan benar (jangan skip ke bawah)

### 1. Jina Reader — rahasia utamanya: `x-respond-with: html`
`r.jina.ai` **TIDAK** diblokir (servernya di luar ID, tapi situsnya tetapreply
karena Jina pakai browser sungguhan).
```bash
curl -s -m 120 -H "x-respond-with: html" -A "Mozilla/5.0" \
  "https://r.jina.ai/https:// situs-target.com/" -o page.html -w "HTTP %{http_code} size %{size_download}\n"
```
- Tanpa header itu → **markdown**, dan konten SPA yang render-client jadi hilang
  (cuma kelihatan footer).。这就是 bedanya.
- `-H "x-timeout: 30"`-delay tambahan kalau perlu (header opsional, kadang butuh key).
- Output `x-respond-with: html` = **HTML hasil render penuh** (bisa 5–8 MB). Itu
  yang paling berguna: nav, href, iframe, dan payload Nuxt ikut terbawa.
- Jina **menolak** URL `.js` / `application/javascript` → `422 AssertionFailureError`.
  Jadi janganAKA-through-Jina buat file JS.

### 2. Kalau Jina markdown-nya kosong → ambil HTML-nya
Semua link nav ada di HTML. Target yang perlu dijawab biasanya ketemu di:
- `href="..."` → daftar route/menu
- teks `<title>`, heading, tombol
- `<script src="/_nuxt/dist/*.js">` → peta halaman (nama chunk)

### 3. API base URL dari payload Nuxt (WAJIB untuk tahu datanya dari mana)
Di dalam HTML render itu ada `window.__NUXT__=(function(a,b,c,d,e){...}("",null,true,false,"/"))`.
`e` = argumen ke-5 = **`API_BASE_URL`**, `config:{ASSET_URL:"https://ois...",API_BASE_URL:e}`.
Jika `e = "/"` → backend-nya **onext host yang sama**, jadi ada route `/api/...`.
Kalau `e` = URL absolute → itu host backend-nya (biasanya CMS).

Contoh nyata: `lawson-indonesia.com` → `ASSET_URL=https://ois.lws.co.id`,
`API_BASE_URL="/"`, state punya `store:{storeLists:[]}` (server-side kosong,
diisi client setelah `fetch`) — itu sebabnya Jina markdown cuma dapat footer.

### 4. Cara dapat HTML SPAs yang **tidak** bisa Jina render
Wayback:
```bash
# sitemap → daftar halaman_resmi (paling murah, sering cukup)
curl -s "https://web.archive.org/web/2024id_/https://SITUS/sitemap.xml"
# CDX → semua URL yang pernah di-crawl
curl -s "https://web.archive.org/cdx/search/cdx?url=SITUS.com*&output=text&fl=original,timestamp,statuscode&collapse=urlkey&limit=400"
# satu bundle JS (pakai timestamp yang SUDAH ada di CDX, else 404)
curl -s -o x.js "https://web.archive.org/web/20260807201204id_/https://SITUS/_nuxt/dist/CHUNK.js"
```
⚠️ `id_` = raw original (tanpa toolbar). Timestamp harus **persis ada di CDX**;
`.../web/2026id_/...` untuk file yang belum pernah di-crawl = **404**.
⚠️ Archive.org suka **"Temporarily Offline"** kalau terlalu sering dipanggil →
space 5–10 detik antar request, cache hasilnya ke `$TMPDIR` supaya ga di-fetch ulang.
⚠️ Halaman SPA yang diarsip = **cuma shell**, isinya render-client hilang. Berguna
untuk `<script src>` + asset, **tidak** berguna untuk isi menu.

### 5. Proxy lain (yang JALAN dari Termux, urutan falling-back)
| Proxy | Untuk | Catatan |
|---|---|---|
| `api.allorigins.win/raw?url=<urlenc>` | HTML/JS | sering **522** (Cloudflare) |
| `api.codetabs.com/v1/proxy?quest=<urlenc>` | HTML | **522** |
| `corsproxy.io/?url=` | apa pun | **401** butuh API key |
| `r.jina.ai` + `x-respond-with: html` | HTML render | ✅ **yang paling andal** |

## Jebakan
- `nslookup`/`dig`/`openssl` **tidak ada** di Termux. Pakai `python -c "import socket; print(socket.gethostbyname_ex(host)[2])"`.
- Jangan pakai `head -c` piped from a curl yang `set -o pipefail` → apont of failure = Habis N request, situs sering**mulai tolak sementara** (429/000). Naikkan timeout, jangan cepat-cepat retry.
- Corps besar hasil Jina bisa **7–8 MB** — jangan `print()` whole file, pakai regex + `re.sub(r'\s+',' ')` untuk cuplikan 200–400 karakter.
- Bahasa: user Indonesia, balas **Bahasa Indonesia Latin**.Istilah teknis (href, SPA, payload) tetap English.

## Checklist jawaban yang bagus
1. Sebut menu/fitur **persis seperti muncul di nav**, bukan nebak dari nama domain.
2. Pisahkan **tool interaktif** (peta/pencari/form) vs **halaman baca**.
3. Sebut **tautan keluar** (B2B, karier, sosmed, app) — sering justru itu yang user cari.
4. Honest note: bagian yang **tidak bisa gw verifikasi** (API butuh auth, konten
   render-client) ditulis apa adanya + alasannya. Jangan mengarang isi.