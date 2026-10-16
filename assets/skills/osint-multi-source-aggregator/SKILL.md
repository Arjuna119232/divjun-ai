# Skill: Aggregator Multi-Sumber OSINT

Untuk bikin tool OSINT benar-benar "100% online": tiap field diambil dari
BANYAK sumber dengan fallback berurutan, plus laporan kesehatan sumber.
Bukti dipakai di NEXTRACE (`/storage/emulated/0/Fonts/intelegen-webview/web`).

## Kapan pakai skill ini
- User minta "semua menu harus valid", "pakai semua tool OSINT", "data tiap
  menu valid" — Layer ini MEMANG jawabannya, bukan menambah endpoint.
- Saat satu endpoint mati / kena rate-limit dan hasil modul jadi kosong.

## Arsitektur: fallback PER-FIELD, bukan per-modul
: fallback di level modul (kalau sumber A gagal, pindah ke
sumber B untuk SEMUA data). Yang benar: satu field satu daftar sumber.

```js
// setiap resolveField mengembalikan { value, source, sourceUrl, confidence, attempts }
const operator = await resolveField('operator', [
  { name: 'LPN', url: 'https://libphonenumberapi.com/api/phone-numbers/' + e164,
    extract: (b) => { const d = jparse(b); return d && d.carrier ? d.carrier : null; },
    confidence: 'tinggi' }
]);
```

`attempts` menyimpan jejakaudit: sumber mana dicoba, kenapa gagal. Ini yang
membaca user bisa nilai validitas sendiri.

## Aturan yang WAJIB (bukan opsional)
1. **Confidence per field** — isi `confidence: 'tinggi'|'sedang'|'rendah'`, lalu
   hitung confidence modul dari jumlah field terisi + yang high.
2. **Health report** — `alive`/`dead` per sumber per run. Jangan pernah
   menampilkan data seolah-olah semua sumber hidup.
3. **JANGAN mock.** Kalau semua sumber gagal → `confidence: 'tidak ada'` dan
   tulis statusnya apa adanya + link-out ke situs resmi.

## Jebakan yang nyata (sudah kejadian)
### 1. Top-level `const X` BUKAN properti window
Di script klasik (non-module), `const Api = {...}` TIDAK jadi `window.Api`.
Tapi file lain yang memanggil `Api.x()` tetap jalan (global lexical scope).
Konsekuensi: file yang menunjuk `window.X` dapat `undefined` — dan karena
tidak ada error, hasilnya null total yang diam.
**Fix:** `if (typeof window !== 'undefined') window.Api = Api;` di file itu.
**Guard:** smoke test bagian "Global window" — cek expose + urutan muat.

### 2. Field yang bisa `null` harus di-filter
```js
const filled = fields.filter((f) => f.value).length;   // crash kalau ada null
const filled = fields.filter((f) => f && f.value).length;  // benar
```

### 3. Extract harus konsisten bentuk
Kalau `resolveField()` mengembalikan objek field, maka field yang diisi manual
(hasil lookup lokal) juga harus dibungkus objek field yang sama. Kalau tidak,
`'MCC/MNC = ' + m.value.mcc` gagal diam.

### 4. Source yang diblok Cloudflare dari IP server
`rdap.org` balas 403 dari IP server/VPS walau dari HP user 200.
**Cara baku: bootstrap IANA** `data.iana.org/rdap/dns.json` (cache 24 jam)
→ cari base URL untuk TLD → query registry otoritatif langsung.
⚠️ Bootstrap memberi **PREFIX URL**, bukan URL lengkap. Verisign butuh
prefix + `domain/` + nama (`.../com/v1/domain/NAMA`). Salah → HTTP 400.

### 5.  registry
IANA punya ratusan registry; hardcode semua tidak realistis.
Aman: **host yang ADA di bootstrap IANA resmi** (diambil via HTTPS dari
data.iana.org) otomatis dipakai. Penyangang tidak bisa memalsukan host.

### 6. crt.sh sering 502 / rate-limit
Cadangan: `api.hackertarget.com/hostsearch/?q=` (teks polos `host,ip`, keyless).

### 7. `pkill -f "node server.js"` di command yang sama dengan start
Pola shell ikut kena → proses ikut mati sendiri. Pakai PID:
```bash
PID=$(ps -A -o pid,args | grep -E "node .*server\.js" | grep -v grep | awk '{print $1}' | head -1)
[ -n "$PID" ] && kill "$PID"; sleep 2
setsid nohup node server.js >"$TMPDIR/web.log" 2>&1 < /dev/null & disown
```

### 8. Sandbox test `vm` + node
- `fetch()` TIDAK menerima path relatif → prepend `http://127.0.0.1:PORT`.
- `fetch` native harus di-stub ke sandbox.
- Kalau stub `Api.fetchUrl`, jangan lupa dukung path relatif DAN header.

### 9. Edit python `str.replace()` bisa gagal diam-diam
Selalu `assert old in s` SEBELUM menulis file. Kalau tidak, file tidak berubah
dan test tetap gagal dengan error yang sama.

## Verifikasi
Jalankan live test, jangan cuma cek sintaks. Target nyata:
```bash
node tools/aggregator.test.js   # cek confidence + tiap field punya sumber
node tools/smoke.js             # cek expose global + urutan muat
```

## Hasil terbukti (angka dari NEXTRACE, data nyata)
- Phone 86%: operator, negara, MCC/MNC, line type, spam
- Domain 100%: registrar, dibuat, kadaluarsa, MX, 66 subdomain
---

## Bagian 2: Fetch SEKALI per sumber, bukan per field

Kesalahan umum: `resolveField()` dipanggil N kali, tiap field bikin 1 request
ke 1 sumber. Untuk 5 field = 5 request ke API yang sama. Melemah, kena
rate-limit, lambat.

Yang benar: **ambil tiap sumber SEKALI secara parallel**, parse sekali,
lalu pilih field dari hasil yang sudah ada.

```js
async function fetchSources(list) {
  const out = {};
  await Promise.all(list.map(async (s) => {
    const res = await Api.fetchUrl(s.url, s.timeout || 11000, s.headers || null);
    out[s.name] = res.ok ? { ok: true, data: s.parse(res.body), url: s.url, ms }
                         : { ok: false, data: null, url: s.url, error: res.error };
  }));
  return out;
}

function pick(sources, order, getter, confidence) { /* first hit menang,
  attempts tetap direkam supaya transparan */ }
```
IP module: 4 request parallel (bukan 5-20 request berurutan) -> 100% confidence.

## Bagian 3: Jangan timpa `ok:false` dari validasi internal
```js
const res = await fn(input);
res.ok = true;              // SALAH: menimpa pesan "IP tidak valid"
```
Fix: `if (res.ok === false) return res;`

## Bagian 4: UX yang bikin orang percaya (bukan cuma "data ada")

1. **Label bahasa manusia**, bukan key mentah. `kode_negara` -> "Kode Negara".
   Pakai peta `FIELD_LABELS = { key: { label, group } }`.
2. **Kelompokkan** field jadi "Lokasi", "Jaringan", "Nomor", "Domain".
3. **Peringatan penting di ATAS**, bukan baris biasa. Contoh: IP terdeteksi
   VPN -> banner "Lokasi Possibly Disamarkan", dan confidence turun 25 poin.
   Ini principle of least surprise: user HARUS tahu sebelum salah baca.
4. **Field yang tak terverifikasi dikumpulkan** jadi satu panel
   "Field yang Tidak Bisa Diverifikasi (N)" -> user tidak mengira 100% lengkap.
5. **Satu kalimat penjelasan per field yang mudah disalahartikan**
   (`FIELD_EXPLAIN`): proxy_hosting, koordinat, spam, webFootprint.
6. **Placeholder ikut berubah** saat tipe input diganti -> user tidak perlu
   menebak format.
7. **Audit dibuat tertutup default** + tombol toggle. Audit itu penting tapi
   panjang; kalau langsung ditampilkan, user kewalahan.
8. **Tombol Salin** untuk koordinat + ringkasan (Clipboard API, fallback
   `execCommand`, selalu toast umpan balik).
9. **Health report** pakai bahasa manusia: "Sumber yang jatuh TIDAK berarti data
   salah - berarti sumber itu sedang tidak bisa dihubungi."

## Bagian 5: Jebakan silent-failure yang costing nyata

### A. Parameter URL di tempat yang salah = data salah, tanpa error
```
SALAH: ip-api.com/json/?fields=.../8.8.8.8   -> ABIKAN parameter IP,
       membalas IP server sendiri. HTTP 200, tidak ada error.
BENAR: ip-api.com/json/8.8.8.8?fields=...
```
Aturan: kalau API punya `/{path}/{param}?query`, path HARUS sebelum `?`.
Selalu verifikasi dengan nilai yang JELAS berbeda (mis. 8.8.8.8) lalu cek
balasannya IP-nya yang benar.

### B. Field berupa objek, bukan string
`ipwho.is` balas `timezone: { id, utc, abbr }`. `d.timezone` jadi
`[object Object]`. Cek tipe SEBELUM tampil: `typeof d.x === 'object'`.

### C. Regex validasi terlalu sempit
Regex IPv4 saja membuat IPv6 ditolak diam-diam. Dukung keduanya + beri
pesan error yang menyebut CONTOH format yang benar.

### D. Simpan helper di atas pemakaiannya
`const FIELD_LABELS` di baris 605 tapi dipakai baris 353 = TDZ risk kalau
dipanggil saat init. Pindahkan blok helper ke atas objek VIEWS.

## Bagian 6: Test yang mencegah regresi
Tambahkan check untuk silent-failure yang pernah kejadian:
- nilai yang diminta balik persis (catch "IP diabaikan")
- field bertipe objek (catch `[object Object]`)
- format koordinat (`^-?\d+\.\d+, -?\d+\.\d+$`)
- input tidak valid ditolak DENGAN pesan (catch `ok` ditimpa)
- IPv6 diterima (catch regex sempit)
