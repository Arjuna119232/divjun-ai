# Kemas ZIP source tanpa membocorkan kredensial

Pola dari KUNBAR Connect (`tool/pack_source.py`, 15 Okt 2026). Berlaku untuk
project apa pun yang dikemas jadi ZIP untuk diedit user di HP (Acode, dll).

## Satu perintah, bukan ritual

```bash
python3 tool/pack_source.py            # versi dibaca dari pubspec.yaml
python3 tool/pack_source.py 0.11.0     # tentukan sendiri
```

## Isi zip langsung di root

Jangan pakai folder pembungkus (`karta-kubar/...`). Acode dan extractor di HP
hanya bisa membuka folder yang berisi `pubspec.yaml`; kalau ada folder di
dalam, user harus memindah file manual. Root langsung = 0 langkah tambahan.

## Yang TIDAK boleh ikut

| Item | Alasan |
|---|---|
| `.env` | **Isinya kunci API / password database.** Wajib keluar |
| `.env.example` | Boleh ikut (nilai kosong) - justru membantu |
| `.git/` | Riwayat dan remote, bisa besar |
| `android/`, `ios/`, `build/`, `.dart_tool/` | Digenerate ulang saat build |
| `*.png` di `design/` | Artefak pratinjau render, bukan bahan aplikasi |
| `pubspec.lock` | Sering noisy antar mesin |

## Yang WAJIB ikut

`assets/` + folder aset dari user. **Kesalahan umum: membuang semua gambar
"biar kecil".** Gambar yang dipakai aplikasi akan hilang dan build gagal
dengan error membingungkan (`asset not found`), padahal zip-nya terlihat
kecil dan rapi.

Khusus Flutter: PNG di `assets/` dipakai aplikasi; SVG hanya tampil kalau
`flutter_svg` ada di `pubspec.yaml`. Kalau belum, SVG diam-diam tidak
muncul - lebih baik kirim sebagai PNG plus master SVG di luar `assets/`.

## Verifikasi WAJIB sebelum bilang "selesai"

```python
with zipfile.ZipFile(out) as z:
    rusak = z.testzip()
    bocor = [n for n in z.namelist() if n.split("/")[-1] in JANGAN]
    hilang = [x for x in WAJIB if x not in z.namelist()]
# salah satu terisi -> print GAGAL + return 1
```

**Pelajaran dari kejadian nyata:** versi pertama skrip ini membocorkan
`.env` ke dalam ZIP karena pengecualian belum ada, dan tidak ada yang
menyadari karena niatnya "saya tidak ikutkan `.env`".

> Niat bukan kode. Aturan keamanan harus jadi pemeriksaan yang gagal dengan
> exit code, bukan INGATAN.

Hal yang sama berlaku untuk daftar aturannya: "tidak commit rahasia", "jangan
hardcode API key", "jangan pakai lintasan storage untuk data sensitif".
Semuanya bisa jadi cek otomatis - dan hampir semuanya diabaikan kalau
cuma mengandalkan niat.

## Copy ke shared storage di HP

`/storage/emulated/0` = FUSE, `cp` biasa bisa timeout dan file menggantung
tanpa error yang jelas. Selalu pakai background + polling:

```bash
nohup cp src dst.tmp >/dev/null 2>&1 </dev/null & disown
for i in $(seq 1 20); do
  [ "$(stat -c %s dst.tmp 2>/dev/null || echo 0)" -ge "$SZ" ] && break
  sleep 3
done
nohup mv dst.tmp dst >/dev/null 2>&1 </dev/null & disown
```

## Tulis ulang panduan edit tiap rilis

File panduan (CARA-ACODE.md) harus menyebut versi yang dikirim dan status
jujur fitur: **sudah / setengah / belum**. Orang yang menerima ZIP itu butuh
tahu batasnya, bukan cuma cara install.

Ukuran akhir bukan tujuan - yang penting isinya benar dan tidak ada
rahasia di dalamnya.