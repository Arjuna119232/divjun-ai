---
name: smoke-test-api-consistency
description: Kalau app web punya modul global (Api, UI, Analyzing), smoke test WAJIB交叉 cek semua method yang dipanggil ke method yang didefinisikan — di client DAN route server. TypeError pada satu pemanggilan mematikan seluruh langkah secara diam-diam.
---

# Smoke test: cegah "method tidak ada" yang mematikan fitur diam-diam

## Gejalanya
User bilang "fitur tidak jalan" / "tag nama belum muncul", tapi tidak ada error
yang terlihat. Penyebabnya: frontend memanggil method yang tidak pernah
didefinisikan. `undefined()` melempar TypeError **sebelum** `.catch()` sempat
menangkap, jadi satu baris itu mematikan seluruh chain — diam-diam.

Kasus nyata NEXTRACE (7 Okt 2026): `phone-engine.js` memanggil
`Api.webname()` dan `Api.wayback()`, keduanya tidak ada di `api.js`.
Langkah 2 mati total, tidak ada nama yang muncul.

## Tiga cek wajib di smoke test

### 1. Method modul yang dipanggil harus terdefinisi
```js
const apiSrc = fs.readFileSync('assets/js/api.js', 'utf8');
const apiDefined = new Set(
  [...apiSrc.matchAll(/^\s{4}([a-zA-Z0-9_]+):\s*\(/gm)].map((m) => m[1])
);
const calls = new Map();
for (const f of allJs) {
  if (f === 'api.js') continue;
  const src = fs.readFileSync('assets/js/' + f, 'utf8');
  for (const m of src.matchAll(/\bApi\.([a-zA-Z0-9_]+)/g)) { /* kumpulkan */ }
}
const missing = [...calls].filter(([m]) => !apiDefined.has(m));
```

### 2. Route server yang dipanggil harus ada
```js
const serverRoutes = new Set(
  [...serverSrc.matchAll(/route === '(\/api\/[a-z0-9]+)'/g)].map((m) => m[1])
);
// Path SELALU ditulis di api.js, jadi cek SELURUH file termasuk api.js
for (const f of allJs) {
  for (const m of src.matchAll(/['"](\/api\/[a-z0-9]+)['"]/g)) calledRoutes.add(m[1]);
}
```
Cek yang sama berlaku ke modul lain (`az.*` -> `analyzing.js`).

### 3. Eksekusi semua script di sandbox
Jalankan tiap file dalam `vm.runInContext` dengan DOM minimal. Ini menangkap
`ReferenceError` saat load (modul global belum ada).

### 4. Route modular: `/api/x/sub` vs `route === '/api/x'`

Regex lama `route === '(\/api\/[a-z0-9]+)'` + cek persis **tidak menangkap
sub-route**. Kalau server pakai router modular
(`route.startsWith('/api/idcaller/')`) sedangkan frontend memanggil
`/api/idcaller/lookup`, cek itu DIAM gagal-mendeteksi: route hilang tidak
pernah dilaporkan. Perbaikannya dua sisi:

```js
// sisi server: tangkap juga prefix
const serverRoutes = new Set([...serverSrc.matchAll(/route === '(\/api\/[a-z0-9\/]+)'/g)].map(m => m[1]));
for (const m of serverSrc.matchAll(/route\.startsWith\('(\/api\/[a-z0-9]+)\/?'\)/g)) serverRoutes.add(m[1]);
// sisi pemanggil: cocokkan persis ATAU sebagai sub-path
const routeRegistered = (r) => [...serverRoutes].some(s => s === r || r === s + '/' || r.startsWith(s + '/'));
```

### 5. Typo method `UI.*` / helper lain = "menu kosong", bukan error

`UI.panle(...)` **bukan ReferenceError saat script dimuat** — errornya baru
muncul saat user membuka tab itu, sehingga terlihat sebagai halaman kosong
tanpa pesan apa pun. Tangkap secara statis: ekstrak daftar export
(`return { el, clear, panel, ... }` di `ui.js`), lalu bandingkan dengan semua
pemakaian `\bUI\.(\w+)` di seluruh file JS. Blok export dipilih dengan
mengambil `return { ... }` berisi identifier polos TERBANYAK (bukan yang
pertama — bisa jadi return object kecil di tengah file).

Baca juga: `/api/idcaller/*` dan metode `UI.*` dijaga bagian [14] + [15]
`web/tools/smoke.js`.

## 6. Uji runtime TANPA browser (harness e2e) — cek statis tidak cukup

Smoke test membuktikan kode *ada*; harness membuktikan *perilakunya* benar
(urutan panggilan, kuota hemat, tidak ada route yang dipanggil sia-sia).
Pola yang terbukti (NEXTRACE `web/tools/phone-e2e.js`):

```js
const vm = require('vm');
const ctx = { console, fetch: (u, o) => String(u).startsWith('/')
  ? realFetch(BASE + u, o) : realFetch(u, o), /* ...stub lain... */ };
ctx.window = ctx; vm.createContext(ctx);
['assets/js/api.js', 'assets/js/phone-engine.js'].forEach((f) =>
  vm.runInContext(fs.readFileSync(ROOT + '/' + f, 'utf8'), ctx, { filename: f }));

// ⚠️ top-level `const X` di script TIDAK menjadi properti context object.
//    Kalau ctx.PhoneEngine → undefined. Ambil lewat runInContext:
const PhoneEngine = vm.runInContext('PhoneEngine', ctx);

const az = { step(){}, query(){}, result(){}, validate(){}, correlate(){}, fail(){}, done(){} };
const res = await PhoneEngine.run('6281239596551', az);
// buktikan: calls.includes('/api/idcaller/lookup') && !calls.includes('/api/getcontact/lookup')
```

Jebakan harness ini:
- **binding context**: lihat di atas (`runInContext('PhoneEngine', ctx)`).
- **stub `az`/`UI` lengkap**: engine memanggil `az.validate`, `az.correlate`,
  `az.step`, `az.query`, `az.result` — satu method hilang = crash di tengah run.
  Ambil daftarnya dengan `grep -o "az\.[a-zA-Z]*" file | sort -u`.
- **fetch relatif**: path `/api/...` harus di-prepend base URL, kalau tidak
  Node melempar "Failed to parse URL".
- **assert cabang yang benar**: tes "kuota hemat" hanya valid kalau syaratnya
  (nama sudah ada di direktori) benar-benar terpenuhi — tes dua kali: nomor
  yang belum ada → wajib memanggil GetContact; nomor yang sudah ada → wajib
  dilewati.

## Jebakan yang sudah pernah menggigit

- **`innerHTML` vs `textContent`**: jangan pakai `innerHTML` untuk teks dari
  sumber luar. smoke test bisa grep, tapi hanya mengabaikan yang di komentar.
- **Alias method**: dua nama untuk hal yang sama (`proxy` dan `fetchUrl`).
  Kalau hanya satu yang didefinisikan, file lain yang pakai nama kedua mati.
  Smoke test cek semua nama yang dipanggil, bukan hanya yang kamu ingat.
- **`report()` yang tidak ada**: di smoke.js sendiri pernah ada pemanggilan
  fungsi `report(...)` yang tidak pernah didefinisikan → test crash sendiri
  dan menutupi bug lain. Kalau test gagal dengan ReferenceError, perbaiki
  test-nya dulu.
- **Regex `\s{4}`**: indentasi di dalam IIFE `return { ... }` selalu 4 spasi.
  Kalau format berubah, pakai yang lebih longgar `^\s+`.

## Aturan keras

Jangan pernah memanggil method yang tidak terdaftar. Kalau memang butuh,
**tambahkan definisinya lebih dulu**, lalu jalankan smoke test.
Smoke test harus 0 gagal sebelum bilirubin.
