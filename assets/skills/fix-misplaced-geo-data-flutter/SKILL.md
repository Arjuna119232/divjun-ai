---
name: fix-misplaced-geo-data-flutter
description: Cara menemukan dan memperbaiki data koordinat (mitra/toko/POI) yang salah tempat di app Flutter — verifikasi pusat wilayah ke OSM/Nominatim dulu, lalu geser semua entri satu kelompok dengan DELTA yang sama supaya sebarannya tidak rusak. Pakai saat peta menampilkan marker di lokasi yang salah atau terlalu berkelompok.
---

# Fix data koordinat yang salah tempat

## Gejala khas
- Peta menampilkan sebagian marker jauh di luar wilayah (mis. 11 km ke barat).
- Pusat peta (`_pusat` = rata-rata semua titik) ikut tertarik ke tempat salah,
  jadi SELURUH peta terlihat miring, bukan cuma satu marker.
- Alamat teks benar, tapi titik di peta tidak cocok dengan alamat itu.

## Langkah

### 1. Ukur dulu, jangan menebak
Cari pusat resmi wilayah dari sumber otoritatif. **Nominatim** (OSM) bagus:
```bash
curl -s -H "User-Agent: app/1.0" \
  "https://nominatim.openstreetmap.org/search?q=Kuningan+Barat,+Jakarta&format=json&limit=3"
```
- Cek **beberapa bentuk query** dan pastikan hasilnya konsisten.
- Ambil `lat`/`lon` dari batas administrasi kelurahan/kecamatan yang benar.

### 2. Cari pola kesalahannya
`grep` nilai koordinat dan kelompokkan per wilayah. Kalau satu kelompok punya
`lng` yang beda digit (106.72 vs 106.82) → itu **typo digit**, bukan data asli.
```
grep -rn "106\.72\|-6\.2500" lib/
```

### 3. Geser dengan DELTA YANG SAMA — jangan hitung ulang satu-satu
Ini bagian paling penting. Data POI biasanya diberi offset kecil (mis. *golden
angle*) supaya marker tidak menumpuk. Kalau kamu menghitung ulang setiap titik
ke pusat baru, **sebaran itu rusak** dan marker menumpuk jadi satu bercak.

Yang benar:
```
delta_lat = pusat_baru.lat - basis_lama.lat
delta_lng = pusat_benar.lng - basis_lama.lng
# tiap entri: lat += delta_lat, lng += delta_lng
```
Buat skrip sekali pakai, **backup file dulu**, lalu jalankan. Buktikan hanya
angka koordinat yang berubah.

### 4. Samakan SEMUA pusat default yang ikut salah
Biasanya basis salah yang sama juga di-hardcode di tempat lain:
- konstanta pusat wilayah (`titikKuninganBarat` dsb.)
- `initialCamera` peta picker
- fallback `_pusat` saat data kosong
Samakan semuanya ke koordinat baru.

### 4b. Cek tinggi/zoom peta
Kalau peta `Positioned.fill` (layar penuh), zoom 13 biasanya pas untuk rentang
~4 km. Kalau peta dibatasi tinggi (mis. 200 dp), zoom perlu diturunkan.

### 5. Verifikasi
```bash
# 0 hasil:
grep -rn "106\.72\|106\.8003\|-6\.2500\|-6\.2447" lib/
```
- Diff harus murni koordinat (12 insert / 12 delete untuk 9 entri × lat+lng).
- Kalau ada `tool/check_dart.py` (analyzer statis lokal) → jalankan.
- Lalu verifikasi sebenarnya = CI `flutter analyze` (Termux tidak punya Flutter).
- **Bongkar ulang ZIP/artefak** dan pastikan nilai lama sudah tidak ada di dalam.

## Jebakan
- **Jangan percaya mata pada diff** — saring diff dengan `grep -v` untuk
  membuktikan tidak ada perubahan selain koordinat.
- **String verifikasi bisa salah ketik.** `"-6.2365, 106.8219"` gagal cocok
  pada `lat: -6.2365, lng: 106.8219` (ada `lng: ` di tengah). Verifikasi
  dengan mencetak barisnya (`repr`), bukan mencocokkan substring yang diketik
  setengah ingat.
- `initialCamera` (any_map/MapLibre) hanya berlaku **sekali** — ganti filter
  tidak memindahkan kamera. Itu batasan library, bukan bug; jangan "perbaiki".
- Data POI dari user sering tanpa nomor telepon → jangan mengarang; sembunyikan
  tombolnya.
