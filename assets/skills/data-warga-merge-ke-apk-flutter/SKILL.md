# Skill: data lokasi warga → app Flutter (peta POI)

Pengguna sering mengirim daftar tempat (warung, pasar, agen gas, depot air)
dari WhatsApp / AI lain, lalu minta APK-nya di-update. Datanya biasanya
**lebih akurat** dari data yang sudah ada di app.

## Kapan skill ini dipakai

- Pengguna mengirim daftar POI + koordinat dalam chat (bukan mengedit kode).
- Koordinat di app terlihat meleset / peta menunjuk lokasi keliru.
- Migrate data dari sumber lain (Google Maps via AI, catatan warga, OSM).

## Alur (jangan skip urutan)

### 1. Bandingkan dengan data yang sudah ada, jangan menimpa
Cocokkan per (nama + kelurahan + RT/RW), **bukan nama saja**. Dua toko
beda bisa bernama sama ("Warung Madura" di Kuningan Barat vs Pela Mampang).
Dua entri beda bisa jadi satu toko ("Agen Galon Le Minerale Krisnadi" vs
"AGEN GAS dan AQUA KRISNadi", sama-sama RT.5/RW.4). Kalau beneran duplikat,
gabung dan **tulis catatan info** bahwa mereka digabung — jangan diam-diam
hapus (aturan pengguna: jangan ada yang dipangkas).

### 2. Hitung centroid kelurahan dari titik yang DIPERCAYAKAN
Buat tabel lat/lng rata-rata per kelurahan dari data warga saja. Ini
jadi pembanding di langkah 3 sekaligus titik pusat peta.

### 3. Geocode sisa yang tidak punya koordinat (Nominatim, keyless)
```bash
curl -s -H "User-Agent: app/1.0 (email)" \
 "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&countrycodes=id\
&viewbox=<lonMin>,<latMax>,<lonMax>,<latMin>&bounded=1&q=<query>"
```
- `viewbox` + `bounded=1` **wajib**: tanpa itu hasil bisa jatuh di kelurahan
  lain (terbukti: "Jalan Kemang Utara" → Duren Tiga, bukan Bangka).
- Terima hasil hanya kalau ≤ **700 m** dari centroid kelurahannya.
- Cek `display_name`: kalau yang kena bukan jalan yang ditanyakan (mis. query
  "Mampang Prapatan XV" tapi kena "Jalan Kuningan Barat IV" / sekolah),
  **tolak** — jaraknya kecil tidak berarti benar.
- Variasikan ejaan: `Jl.` vs `Jalan`, angka romawi vs "Satu/Tiga".
- Rate limit ≥ 1.2 detik.

### 4. Pisahkan dua jenis titik di DATA, jangan disamakan diam-diam
Tiap entri punya flag kejujuran:
- `titikPerkiraan: false` = koordinat asli warga.
- `titikPerkiraan: true` = geocode / perkiraan lama → **tampilkan di UI**.
Kalau titik lama >1 km di luar kelurahannya, taruh di jalur terdekat +
offset ~20 m dan tetap tandai perkiraan (lebih baik daripada pin di Lastly).

### 5. Jam buka juga harus jujur
Dulu semua jam buka dikarang (`06:00 - 22:00`) sehingga lencana "Tutup
sekarang" **salah** untuk pasar yang buka sampai 22.30. Aturannya:
- Ada data warga → pakai, tampilkan lencana buka/tutup.
- Tidak ada → `"Belum dikonfirmasi"` + **tampilkan lencana apa pun** (tidak
  ada getter `jamBukaPasti`, UI akan berbohong).

### 6. Data Dart = hasil generate, bukan ditulis manual
Skema: `tool/data_<x>.json` → `tool/gen_<x>.py` → file Dart. Generator
**wajib refuse to write** kalau ada yang salah (enum tak dikenal, pola
tanggal salah, karakter non-Latin, dua pin < 5 m, id/nama ganda).
Tentang-this detail yang sering hilang:
- **Helper di ekor file harus dipertahankan.** Kalau file punya
  `nama`, `cari`, `terdekat` setelah daftar, generator WAJIB membacanya
  lagi sebelum menulis. Kalau hilang, build breakage jauh dari sumber dan
  gejalanya cuma "UNUSED-IMPORT" yang mengyram.
- **Verifikasi tulis**: baca balik file hasil, bandingkan jumlah entri +
  jumlah helper. Sekali `write_text()` hilang saat patching → skrip tetap
  print "OK" padahal berkas lama utuh.
- Regex non-Latin yang benar:
  `re.compile("[^\x00-\x7F\u00C0-\u024F\u2018\u2019\u201C\u201D\u2013\u2014\u2026\u2022\u00B0]")`.
  Salah tulis jadi `[^\x00-\x024f-ɏ…]` → semua huruf Latin kena flag.

### 7. Verifikasi berlapis (Urutan penting)
```bash
python3 tool/gen_mitra_usaha.py     # exit 1 = file Dart utuh
python3 tool/check_dart.py          # 0 masalah
python3 tool/check_nonlatin.py      # 0 masalah
gh workflow run build.yml --ref <branch> -f analyze-only=yes -f release=no
# baru setelah hijau:
gh workflow run build.yml --ref <branch>   # APK
```

## Jebakan `any_map` 1.0.0 + MapLibre

| Hal | Fakta |
|---|---|
| Tombol zoom bawaan | **Tidak ada** — harus controller |
| `onCameraMove` | **Tidak diteruskan** adapter MapLibre ke peta asli → jangan pakai |
| Cara zoom | `onMapCreated` → `getCameraPosition()` → `animateCamera(AnyCameraPosition(target:, zoom: ±1))` |
| `initialCamera` | Berlaku **sekali**; ganti filter tidak memindahkan kamera (batas library) |
| Pin presisi | `AnyMarker(position: AnyLatLng(lat, lng), anchor: AnyMarkerAnchor.center)` — tanpa ini ikon bergeser dari titik |
| Tap per-marker | **Tidak ada**; pakai `onTap` lalu cari mitra terdekat dalam radius |
| Batas zoom | `minZoom`/`maxZoom` diteruskan; clamp manual juga perlu (hasil tipe `double`, bukan `num`) |

## Jebakan yang sudah kejadian nyata (jangan diulang)

1. **`write_text` hilang saat patch skrip** → print OK, berkas tidak berubah.
   Selalu verifikasi dengan membaca balik.
2. **Generator menimpa seluruh file** → helper yang dipakai 3 layar hilang.
   Gejalanya cuma `UNUSED-IMPORT` yang mengyram.
3. **False positive enum**: konstanta terakhir enum selalu diakhiri `;`
   (`xCircle;`). Kalau cuma `.rstrip(",")` → 9 berkas dilaporkan error palsu.
   `.rstrip(",;")`.
4. **Geocode salah kelurahan** → wajib `viewbox` + `bounded=1` + cek
   `display_name`.
5. **Duplikat dengan nama berbeda** → duplikat pin kalau tidak digabung.
6. **Jam buka karangan** → lencana "tutup" yang salah.
7. `num.clamp()` mengembalikan `num` → **compile error** kalau masuk `double`.

## Fault injection untuk cek baru

Setiap cek di `tool/check_dart.py` harus dibuktikan dengan menyuntik bug
sungguhan dan melihat exit 1. Cek yang selalu balas "0 masalah" tanpa
bukti = tidak berarti apa-apa. Dan pakai `assert target in s` saat menyuntik:
suntikan yang tidak cocok diam-diam bikin tesmu yang salah, bukan checker's.