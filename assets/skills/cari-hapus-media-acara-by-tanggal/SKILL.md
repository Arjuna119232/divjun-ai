---
name: cari-hapus-media-acara-by-tanggal
description: Cara cari & hapus foto/video acara di HP Android dari Termux berdasarkan TANGGAL ACARA (bukan nama file) — termasuk file .HEIC dan .MOV yang tidak muncul di pencarian nama. Berlaku juga untuk hapus massal WA media, hasil kompres, dan folder bertema acara.
---

# Cari & hapus massal media acara (Android/Termux)

## Kenapa pencarian nama fileaja GAGAL untuk acara

Hampir semua file acara TIDAK punya kata acara di namanya:

- WhatsApp → `IMG-20260912-WA0032.jpg` / `VID-20260912-WA0048.mp4` (cuma tanggal)
- iPhone → `IMG_7908.MOV` (cuma nomor urut)
- Hasil kompres → `kompres dok. video katarnolima_63.mp4` (cuma nama aplikasi)
- FotoPanorama → `.thumbnails/25131.jpg` (nama numerik, bukan media asli)

Jadi **cari 3 lapis**: (1) metadata tanggal dalam file, (2) tanggal di nama file,
(3) nama folder bertema acara.

## Jebakan `.HEIC` / `.MOV`

`find -iname "*.heic"` di HP user HANYA menemukan 5 file dari 7.384 media —
karena iPhone/Android sering simpan HEIC dengan ekstensi Huruf besar di path
tertentu (folder `Android/media/...`, folder nama acara) dan file `.MOV`
dibenam ulang jadi `.MOV.mp4` saat di-kompres. **Jangan percaya hasil `-iname`
saja.** Tetap scan metadata SEMUA ekstensi.

## Metode utama: scan metadata (INI YANG BENAR)

Tidak perlu `exiftool`/`ffprobe` (tidak terpasang di Termux) — pakai Python stdlib.

```bash
cat > "$TMPDIR/scan_date.py" << 'PY'
import os, sys, struct, datetime, re
from concurrent.futures import ThreadPoolExecutor

EXTS = ('.jpg','.jpeg','.png','.heic','.heif','.webp','.mov','.mp4','.m4v','.3gp','.mkv','.avi')
TARGET = '2026-09-12'          # <-- ganti ke tanggal acara
EPOCH = datetime.datetime(1904,1,1,tzinfo=datetime.timezone.utc)
TZ = datetime.timezone(datetime.timedelta(hours=7))   # WIB
DATE_RE = re.compile(rb'(20\d\d)[:\-](\d\d)[:\-](\d\d)[ T](\d\d)[:\-](\d\d)[:\-](\d\d)')

def mvhd_date(data):
    """Tanggal pembuatan QuickTime/MP4 dari atom 'mvhd'."""
    i = data.find(b'mvhd')
    if i < 0 or i + 12 > len(data): return None
    p = i + 4
    ver = data[p]
    try:
        ts = struct.unpack('>Q', data[p+4:p+12])[0] if ver == 1 \
             else struct.unpack('>I', data[p+4:p+8])[0]
    except Exception:
        return None
    if ts > 4_000_000_000: return None          # bukan timestamp -> abaikan
    try:
        return (EPOCH + datetime.timedelta(seconds=ts)).astimezone(TZ).strftime('%Y-%m-%d')
    except Exception:
        return None

def check(path):
    try:
        st = os.stat(path)
        with open(path,'rb') as f:
            head = f.read(300000)                 # EXIF selalu di depan
            if st.st_size > 400000:
                f.seek(-80000, os.SEEK_END); tail = f.read()   # moov sering di belakang
            else:
                tail = b''
    except Exception:
        return None
    hits = set()
    for blob in (head, tail):
        for y,mo,d,h,mi,s in DATE_RE.findall(blob):
            iso = f'{y.decode()}-{mo.decode()}-{d.decode()}'
            if iso == TARGET: hits.add(f'{iso} {h.decode()}:{mi.decode()}:{s.decode()}')
    m = mvhd_date(head) or mvhd_date(tail)
    if m == TARGET: hits.add(m + ' (quicktime)')
    return (path, sorted(hits)) if hits else None

files = []
for root, dirs, names in os.walk('/storage/emulated/0'):
    if 'node_modules' in root or '.thumbnails' in root: continue
    for n in names:
        if n.lower().endswith(EXTS):
            files.append(os.path.join(root, n))

print('scanning', len(files), 'files', flush=True)
out = []
with ThreadPoolExecutor(max_workers=16) as ex:
    for r in ex.map(check, files):
        if r:
            out.append(r); print('HIT', r[0], r[1], flush=True)
print('DONE', len(out), 'files with date', TARGET, flush=True)
PY

nohup python3 "$TMPDIR/scan_date.py" > "$TMPDIR/scan_date.log" 2>&1 &
sleep 20; tail -3 "$TMPDIR/scan_date.log"
```

**Kasus nyata:** 5.610 file → selesai **~80 detik**, 112 file terkonfirmasi
tanggal 12 Sep 2026 (472 MB).

## Gabungkan dengan pencarian nama + folder bertema

```bash
cd /storage/emulated/0
find . -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
  -o -iname "*.heic" -o -iname "*.heif" -o -iname "*.webp" \
  -o -iname "*.mov" -o -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.3gp" \) \
  -not -path "*/node_modules/*" -not -path "*/.thumbnails/*" 2>/dev/null \
  | grep -iE "20260912|2026-09-12" | sed 's|^\./|/storage/emulated/0/|' | sort > "$TMPDIR/name_hits.txt"

cat "$TMPDIR/hit_paths.txt" "$TMPDIR/name_hits.txt" | sort -u > "$TMPDIR/union.txt"
wc -l < "$TMPDIR/union.txt"
```

Lalu **tambah** semua isi folder bertema acara (mis. `/storage/emulated/0/Opening tari/`)
karena nama foldernya sudah prove event-nya, walau tanggal file berbeda.

## Jebakan yang HARUS dijaga sebelum hapus

1. **`.thumbnails/` BUKAN media asli** — hapus boleh (cache), tapi jangan
   samakan dengan file asli. Filter `-not -path "*/.thumbnails/*"` dari daftar utama.
2. **Folder proyek** (mis. `Download/katarnolima-rw05/assets-source/media-belum-dipakai/`)
   berisi aset acara yang dipakai app. Hapus = rusak proyek. **Selalu tanya user
   terpisah** untuk folder proyek, jangan masukkan diam-diam ke daftar hapus.
3. **`stat -c %s` per file di loop** = lambat untuk ratusan file. Untuk total size
   pakai satu loop sekali jalan, bukan per-file berulang.
4. **File `.trashed-*`** = sudah di sampahgallery tapi masih ada di disk.
   Tetap hapus kalau memang diminta (user minta "semua").
5. **Nama file WhatsApp tidak selalu tidak selalu di tanggal acara** — `Pictures/WhatsApp/kegiatan-4.jpg`
   nama meaningless tapi EXIF-nya 12 Sep. Karena itu scan metadata WAJIB jalan,
   tidak cukup andalkan nama.
6. **Nggak bisa lihat isi gambar dari Termux.** Kalau criteria "menampilkan acara"
   dan tidak ada metadata yang cocok, jz-git KATAKAN: match berdasarkan tanggal,
   bukan visual. Jangan berpura-pura sudah sudah verifikasi isi.

## Aturan emas sebelum hapus massal

- Tampilkan **kelompokan + jumlah + total ukuran** dulu, bukan daftar 209 baris.
- Selalu tawarkan opsi **karantina (pindah folder)** sebelum hapus permanen —
  di `/storage` free space tidak bertambah kalau cuma dipindah, tapi file bisa
  dikembalikan kalau ada yang keliru kena.
- Hapus permanen = `rm -f` per baris dari file daftar, lalu verifikasi
  `wc -l` ulang = 0. Jangan `rm -rf` folder luas tanpa cek isi.
- Setelah hapus, Sebaiknya kosongkan juga thumbnail agar gallery tidak masih
  menampilkan bayangan: cukup hapus isi `.thumbnails/` yang relevan.

## Pindah ke karantina (pola yang dipakai, BUKAN `rm` langsung)

Sudah terbukti di HP user: 209 file / 1.866 GB ke folder
`/storage/emulated/0/_HAPUS_ACARA_120926/` **selesai < 25 detik**, 0 gagal.
Pakai `os.replace()` (rename) per file sambil **mempertahankan struktur path**,
supaya file bernama sama antar folder (WhatsApp `Video/`, `Video/Sent/`, `Video/Private/`)
nggak saling tertimpa.

```python
import os
SRC_ROOT = '/storage/emulated/0'
DEST = os.path.join(SRC_ROOT, '_HAPUS_ACARA_120926')
os.makedirs(DEST, exist_ok=True)

for p in paths:                      # paths = isi union.txt
    if not os.path.exists(p):
        continue                     # catat di `missing`, jangan diam
    rel = os.path.relpath(p, SRC_ROOT)
    dst = os.path.join(DEST, rel)    # <-- struktur asli dipertahankan
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    os.replace(p, dst)               # rename, bukan copy -> cepat di FUSE
```

Jalankan di **background** + log (`nohup python3 ... > log 2>&1 &`) lalu poll,
karena 209 file di `/storage` bisa melewati batas waktu tool kalau sinkron.

### Verifikasi WAJIB 3 angka (jangan percaya exit 0)

```bash
# 1) di lokasi asli harus 0
still=0; while IFS= read -r f; do [ -e "$f" ] && still=$((still+1)); done < "$TMPDIR/union.txt"; echo "sisa=$still"
# 2) jumlah file di karantina harus sama
find "/storage/emulated/0/_HAPUS_ACARA_120926" -type f | wc -l
# 3) ukuran karantina
du -sh "/storage/emulated/0/_HAPUS_ACARA_120926"
```

Hasil nyata: `sisa=0`, `209`, `1.9G`.

### Catatan jujur ke user
Karantina = **tidak muncul di galeri, tapi storage BELUM bertambah** (file masih di
disk). Space baru balik setelah `rm -rf` folder karantina. Katakan ini eksplisit,
jangan bikin useragir hard drive()-nya sudah lega.
