---
name: osint-full-online-stack
description: Make an OSINT site "100% full online" with working search engines, proxy rotation, retry, caching, and cooldown. Covers which search engines actually work when scraped from a server in 2026 (Bing and Brave work, DuckDuckGo and Mojeek block), their exact HTML parsing quirks (titles live in the title= attribute, not text), and 429 rate-limit handling. Use when the user insists everything must work perfectly online, or when search/scrape endpoints return zero results.
---

# OSINT "100% Full Online" — Search Stack yang Benar-Benar Jalan

Pelajaran dari `/storage/emulated/0/Fonts/intelegen-webview/web`, 7 Okt 2026.

## Mesin pencari: mana yang BISA di-scrape dari server

| Engine | Status | Parser yang benar |
|--------|--------|-------------------|
| **Bing** | ✅ 10 hasil | `<h2[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>([\s\S]{3,200}?)</a>` |
| **Brave Search** | ✅ (429 cepat) | `<a[^>]*href="([^"]+)"[^>]*title="([^"]+)"` |
| **Startpage** | ⚠️sometimes | `class="w-gl__result-title"` |
| **Marginalia** | ✅ indeks kecil | `<a[^>]*class="title"[^>]*>([\s\S]{3,200}?)</a>` |
| **DuckDuckGo HTML** | ❌ bot detect | balas "anomaly"/"challenge", 0 hasil |
| **DuckDuckGo Lite** | ❌ | 202 + halaman kosong |
| **Mojeek** | ❌ | 349 byte = diblokir |

## Jebakan yang memakan waktu

**1. Judul hasil ada di ATRIBUT `title=`, bukan isi tag.**
```javascript
// SALAH
/search-snippet-title[^>]*>([^<]{3,160})/g
// BENAR
/<a[^>]*href="([^"]+)"[^>]*title="([^"]+)"[^,}]/g
```
Dan nama class juga muncul di blok `<style>` — **harus dibuang** kalau tidak
ada `title=`. Kalau tidak difilter, parser mengambil CSS bukan hasil.

**2. `<h2>` Bing punya `class=""` di tengah.**
```html
<h2 class=""><a target="_blank" href="...">Judul</a></h2>
```
Pola `<h2><a` tidak akan cocok. Pakai `<h2[^>]*>`.

**3. HTTP 429 = rate limit, bukan blokir.**
Brave balas 429 ke server tapi 200 ke `curl`. Bedanya connection pattern.
Jangan simpai "bisa" cuma dari satu percobaan — atau "tidak bisa" dari satu 429.

## Arsitektur wajib: cache + cooldown + rotasi

```javascript
const SEARCH_CACHE = new Map();      // query -> {at, data}, TTL 5 menit

const ENGINES = [{ name, cooldown: 0, cooldownMs: 90000, url(q), parse(html) }];

// loop engine: skip yang cooldown, kalau 429 set cooldown lalu lanjut
```

Tanpa ini: 1 user = 4 request/search engine = kena 429 dalam 2 menit.

## Proxy rotation (penting untuk "jalan sempurna")

```javascript
async function fetchResilient(url, opts) {
  // 1. koneksi langsung (paling sering berhasil & paling cepat)
  const direct = await fetchExternal(url);
  if (direct.ok) return { ...direct, via: 'direct' };

  // 2. proxy dari PROXY_LIST env / proxies.txt / ProxyScrape publik
  for (const p of list.slice(0, attempts)) {
    const r = await fetchExternal(url, { viaProxy: p });
    if (r.ok) return { ...r, via: 'proxy:' + p };
    markFail(p);   // proxy gagal 2x -> keluar dari rotasi
  }
  return { ok: false, error: lastError };
}
```
Sumber proxy (berurutan prioritas):
1. `process.env.PROXY_LIST` → `"http://a:1,http://b:2"` (paling stabil)
2. `proxies.txt` di root → satu per baris
3. `api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=8000`
   → cache 10 menit, ambil 300 pertama

Untuk request lewat proxy HTTP biasa ke target HTTPS, path harus URL penuh
dan header `Host` diisi target:
```javascript
if (opts.viaProxy) { headers['Host'] = parsed.hostname; path = parsed.toString(); }
rejectUnauthorized: false;
```

## Cara menguji: jangan cuma cek HTTP 200

`200` dengan 77 KB body bisa berupa halaman rate-limit. **Uji isi:**
```bash
curl -s "http://127.0.0.1:8420/api/fetch?url=<encoded>" -o out.json
python3 -c "
import json;d=json.load(open('out.json'))
print(d['ok'], d['code'], len(d['body']))
"
```
Kalau `code: 429` padahal `curl` biasa dapat 200 → itu rate limit IP.

## Yang TIDAK bisa jadi online (jangan dipaksa)

- **Tag crowdsourced** GetContact/Truecaller/CallApp/Eyecon → endpoint publik 404
- **WhatsApp dari nomor** → `wa.me` 200 untuk nomor valid DAN tidak valid
- **Telegram dari nomor** → 18.369 byte identik untuk semua nomor
- **HLR / status ACTIVE / ROAMING** → milik operator
- **E-wallet** → tanpa API publik
- **Dukcapil** → tidak ada akses publik

Untuk semuanya: tampilkan statusnya apa adanya + tombol buka situs aslinya.
Jangan isi mock. Lebih baik kosong jujur daripada data yang pasti bohong.

## Checklist "full online"
- [ ] Semua endpoint diuji dengan **isi**, bukan cuma status code
- [ ] Cache TTL supaya tidak kena rate limit berulang
- [ ] Cooldown per engine saat 429
- [ ] Rotasi ≥3 engine (satu saja tidak cukup)
- [ ] Proxy rotation: direct → proxies
- [ ] `PROXY_LIST` envvar + `proxies.txt` didukung
- [ ] Blok yang tidak bisa diverifikasi ditulis statusnya, bukan mock
