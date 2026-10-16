---
name: port-repo-zero-dep
description: Port a GitHub Node.js repo (Express + Prisma/Postgres + JWT + bcrypt) into a zero-dependency module that runs on a phone (Termux/Android storage). Covers the stdlib replacements, where files may live (chmod on /storage is a lie), how the frontend-only-GET constraint shapes the router, status-code passthrough, and honest framing of what the database actually contains. Use when the user says "ganti sama repo X", "pakai project itu", or when npm install of a repo would fail on Termux.
---

# Port repo Node ke nol dependency (Termux/HP)

Contoh nyata: `github.com/krishnareason/IDCaller-API` → `web/idcaller.js`
NEXTRACE (7 Okt 2026). Prisma engine butuh glibc (gagal di Termux) dan
Postgres bukan sesuatu yang mau dijalankan di HP.

## 1. Baca dulu, port kedua

- Clone ke `$TMPDIR/nama`, **bukan `/tmp`** (di Termux `/tmp` sering
  ditolak permission-nya).
- Baca SEMUA: route, controller, schema Prisma, middleware auth, seed.
- Catat kontrak aslinya persis: path, field, kode status (409 duplikat,
  404 belum terdaftar, 401 belum login). Kontrak dipertahankan supaya bisa
  ditukar lagi nanti kalau server beneran dipasang.
- **Tulis jujur apa isinya.** Repo semacam ini biasanya direktori komunitas:
  isinya cuma data yang user-nya sendiri masukkan + seed palsu. Jangan
  dijanjikan sebagai "database siapa pun". Sampaikan itu ke user sebelum
  membangun, dan tulis di catatan fiturnya.

## 2. Peta pengganti (semua bawaan Node ≥18)

| Asli | Pengganti |
|---|---|
| Express + route | `if (route === '/x')` di satu handler; balas `{status, payload}` |
| body parser | baca `req.on('data'/'end')`, batas 64 KB, JSON.parse aman |
| Prisma/Postgres | satu file JSON + tulis **atomik** (`writeFileSync(tmp)` lalu `renameSync`) + debounce 200 ms |
| bcrypt | `crypto.scryptSync(pw, salt, 64)` → `'scrypt$salt$hash'`, verifikasi dengan `timingSafeEqual` |
| jsonwebtoken | HMAC-SHA256: `base64url(payload) + '.' + hmac`, cek `exp` + `timingSafeEqual` |
| UUID | `crypto.randomUUID()` (fallback `randomBytes(16)`) |
| dotenv/`.env` | tidak perlu — path cukup dari `__dirname` + `process.env.HOME` |

## 3. ⚠️ File data WAJIB di `$HOME`, bukan di `/storage`

`/storage/emulated/0` adalah FUSE Android: **chmod diabaikan**, semua file
jadi `660`. Smoke test pernah gagal dengan `izin terlalu longgar: 660` padahal
kode sudah `chmodSync(0o600)`.

- Kontak, hash password, token → `~/.config/zyvo/<nama>.json` (ext4 asli,
  chmod 600 benar-benar berlaku, `-rw-------`).
- Rahasia terpisah: `~/.config/zyvo/<nama>-secret` (generate `randomBytes(48)`
  kalau belum ada, tulis `{mode:0o600}`).
- Folder project di `/storage` hanya untuk kode.

## 4. Router dipaksa oleh frontend

`Api.call(path, params)` di NEXTRACE hanya mengirim **GET + query params**.
Repo asli memakai POST body. Jangan ubah frontend-nya — buat router yang
menerima keduanya:

```js
let body = {};
if (m === 'POST') body = await readBody(req);
url.searchParams.forEach((v, k) => { if (!(k in body)) body[k] = v; });
// tentukan AKSI dari field, bukan dari method:
const isAdd = m === 'POST' || (body.userName && body.userNumber);
```

POST tetap diterima → kontrak asli tetap kompatibel.

## 5. Jangan timpa status

Bug nyata: router `return { status: 200, payload: addContact(...) }` →
duplikat 409 dari fungsi di dalamnya jadi 200, dan client tidak pernah tahu.
Selalu: `const r = addContact(...); return { status: r.status, payload: r };`
Aturan: semua payload punya field `ok`, `error`, `hint`, `status` — lihat
skill `smoke-test-api-consistency`.

## 6. Tambah nilai tanpa merusak kontrak

Repo asli hanya bisa cari di kontak milik user sendiri → tidak berguna saat
database kosong. Tambah endpoint baru dengan path yang jelas beda:
`GET /lookup?number=` (reverse lookup lintas direktori) + `GET /status`.
Biarkan data terisi OTOMATIS: endpoint lookup sumber lain (Truecaller,
GetContact) memanggil `contribute(num, nama, sumber)` → database tumbuh
seiring dipakai, dan setiap nama tetap membawa asal-usulnya.

## 7. Smoke test yang harus ditambah

- file ada + `module.exports` expose fungsi yang dipanggil server
- `server.js` benar-benar `require` + punya router prefix-nya
- pemanggilan `contribute` ≥ jumlah sumber lookup (jangan cuma ada satu)
- tab/view terdaftar di sidebar; sumber dipakai aggregator
- **tidak ada `*.json` data di folder project**; semua password diawali
  `scrypt$`; mode file `& 0o077 === 0`
- rahasia tidak ada di folder project

Jalankan: `node tools/smoke.js` (wajib 0 gagal) + test live endpoint
register → login → tambah → duplikat(409) → lookup → contribute → lookup lagi.

## 8. Laporkan jujur

Sampaikan: apa yang port ini BISA (auth, simpan kontak, skor spam, lookup
lokal, gratis tanpa kuota) dan apa yang TIDAK (tidak punya nama telepon
siapa pun di dunia). Kalau user butuh nama pemilik, sumbernya tetap
GetContact/Truecaller — port ini hanya penyimpan hasilnya.


## Refactor "semua data lewat repository" tanpa merusak app (14 Okt 2026)

Pola yang dipakai di KUNBAR Connect: satu file `seed_data.dart` di `shared/`
dipakai 6 layar -> dipecah jadi `features/<fitur>/{domain,data}`. Berhasil, tapi
hanya kalau dikerjakan berurutan:

1. **Pindahkan model DULU, lalu isi repository, baru ganti layar.** Kalau layar
   diubah duluan, `check_dart.py` akan melaporkan puluhan MISSING-IMPORT dan
   sukar dibedakan mana yang memang salah.
2. **Hapus file lama SETELAH semua layar pindah.** Selama file lama masih ada,
   analyzer tidak tahu kalau masih ada layar yang belum pindah.
3. **Rename field = rename simbol = rapikan.** Contoh: `Activity.title` ->
   `Kegiatan.judul`. Alias itu tidak sepadan dan bikin reviewer ragu.

### Jebakan yang costing satu tahap penuh

**Ganti-string massal menyisakan prefiks.** Kode:
```python
s.replace('SeedData.activities', 'KegiatanLokal.kegiatan')   # aman
s.replace('activityCategories', 'KegiatanLokal.kategori')    # TIDAK aman
```
Kalau aslinya `SeedData.activityCategories`, hasil akhirnya
`SeedData.KegiatanLokal.kategori` - prefix `SeedData.` tertinggal karena
pengganti bukan full-token match.

**Kenapa analyzer statis tidak menangkapnya:** cek MISSING-IMPORT hanya
membandingkan "simbol yang DIDEKLARASIKAN di file proyek" terhadap import.
Setelah `seed_data.dart` dihapus, `SeedData` tidak dideklarasikan di mana pun,
jadi tidak masuk daftar - dan `SeedData.KegiatanLokal` lolos sebagai
"nama yang tidak dikenal".

**Aturan:** setelah penggantian massal, `grep -rn "<NamaKelasLama>" lib/` SEBAGAI
langkah wajib terpisah. MengItu satu grep 1 detik, sedangkan biayanya kalau
terlewat: build hijau, analyzer hijau, aplikasi crash saat dibuka.

### Bentuk yang dipakai

```
lib/core/data/hasil.dart            Hasil<T> + GalatData  (gagal = nilai)
lib/core/data/supabase_rest.dart    klien REST (tanpa paket besar)
lib/core/data/data_providers.dart   provider + factory choose source
lib/features/<f>/domain/<f>.dart    model murni, tanpa sumber data
lib/features/<f>/data/<f>_lokal.dart          data demo (sumber lokal)
lib/features/<f>/data/<f>_repository.dart     abstract + Lokal + Supabase
```
Layar hanya `ref.watch(xProvider).valueOrNull ?? const []` - tidak pernah tahu
datanya dari mana. `?? kosong` itu penting: kalau backend gagal, layar
menampilkan kosong yang jujur, bukan crash.
