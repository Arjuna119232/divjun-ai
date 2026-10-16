# Verifikasi Supabase dari Termux (tanpa CLI, tanpa library)

Cara memastikan sebuah Supabase project + kunci itu benar-benar hidup,
sebelum Rhys seluruh arsitektur aplikasi ke sana. Semua lewat `curl` atau
`urllib` bawaan Termux — tidak ada yang perlu di-install.

## Urutan uji yang benar (jangan dibalik)

### ❌ JANGAN menilai koneksi dari `/rest/v1/` (akar)

Di proyek dengan "new API keys", akar PostgREST membalas:

```
401 {"message":"Secret API key required","hint":"Only secret API keys can be used for this endpoint."}
```

Itu **bukan tanda kunci rusak**. Akar itu memang hanya untuk secret key,
padahal aplikasi kita wajib memakai publishable/anon key. menilai koneksi
dari endpoint ini = salah vonis key yang sehat.

### ✅ Uji 1 — apakah host hidup? `/auth/v1/health`

```bash
curl -s -w " | HTTP %{http_code}\n" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "User-Agent: Mozilla/5.0 Chrome/154.0" \
  "$URL/auth/v1/health"
# 200 {"version":"v2.x","name":"GoTrue",...}
```

### ✅ Uji 2 — apakah kunci benar-benar dipakai PostgREST? query tabel nyata

```bash
curl -s -w " | HTTP %{http_code}\n" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  -H "User-Agent: Mozilla/5.0 Chrome/154.0" \
  "$URL/rest/v1/profiles?select=id&limit=1"
```

Makna jawabannya:

| HTTP | Arti |
|---|---|
| `200` + `[]` | Kunci + RLS benar, tabel ada, tabel kosong |
| `404` `PGRST205` "Could not find the table" | **Kunci SAH**, PostgREST jalan. Yang belum ada = **tabelnya** |
| `401` | Kunci ditolak / project salah |
| `403` `42501` | RLS menolak —artinya kunci sah tapi akses ditolak |

`PGRST205` justru **kabar baik**: permintaan sampai ke database, hanya
schemanya belum ada. Jangan melapor ini sebagai "kunci rusak".

### ✅ Uji 3 — kunci ngawur harus ditolak (RLS hidup)

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "apikey: kunci-ngawur" -H "Authorization: Bearer kunci-ngawur" \
  -H "User-Agent: Mozilla/5.0 Chrome/154.0" \
  "$URL/rest/v1/profiles?select=id&limit=1"
# harus 401/403, JANGAN 200
```

### ✅ Uji 4 — Auth jalan?

```bash
curl -s -H "apikey: $KEY" -H "Authorization: Bearer $KEY" \
  "$URL/auth/v1/settings"    # melihat email signup & provider aktif
```

Publishable key bisa dipakai untuk GoTrue juga, bukan hanya PostgREST.

## Jebakan

- **Selalu pakai `User-Agent` browser.** Tanpa itu beberapa edge membalas 403
  dalam 0,0 s dan kelihatan seperti project mati.
- Tanpa `-w "HTTP %{http_code}"`, `curl -s` mengembalikan body saja dan error
  dessen tersamar jadi "respons kosong".
- Publishable key (46 char, prefix `sb_publishable_`) dan anon JWT (3 bagian
  dipisah titik) dua-duanya valid untuk proyek yang sama. Pilih publishable
  untuk proyek baru.
- Simpan kuncinya di `.env` dengan mode 600. `chmod` di
  `/storage/emulated/0` **diabaikan FUSE** (selalu 660) — file sensitif
  HARUS di `$HOME`.

## Setelah semua hijau

Tabel tetap perlu dibuat. Cara paling cepat tanpa CLI: Dashboard → SQL Editor →
New query → tempel `supabase/schema.sql` → Run. Aman dijalankan ulang
(semua `if not exists` / `drop policy if exists`).