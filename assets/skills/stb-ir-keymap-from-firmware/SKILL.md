# SKILL: Menarik Kode IR Remote STB dari Firmware (bukan menebak)

## Kapan pakai
User minta "remote APK untuk STB <merk> <tipe>" atau "cari kode remote <merk>".
Kode IR TIDAK PERNAH ada di web, dan TIDAK BISA ditebak. Satu-satunya sumber
benar = **keymap.xml di dalam firmware resmi STB itu sendiri**.

## Kenapa Approaches Lama Gagal
- Cari di Google/DuckDuckGo → cuma artikel-tutorial kosong tanpa kode hex.
- `com.android.consumerir` Play Store → app pihak ketiga, kode proprietary, sering paywall.
- Tebak dari merk → SALAH. Two unit merk sama bisa punya remote berbeda.

## Metode yang Terbukti (ATBM STB, Sept 2026)

### 1. Ambil firmware resmi dulu
Sumber: `jendelatv.id` (halaman firmware per STB) → link **Google Drive folder**.
Parsing listing Drive tanpa API key:

```python
s = open('gd.html').read()
d = (s.replace('\\x22','"').replace('\\x5b','[')
      .replace('\\x5d',']').replace('\\/','/'))
pat = re.compile(r'"([-\w]{25,50})",\["([-\w]{25,50})"\],"([^"]{2,90}?)","([^"]{2,40}?)"')
# hasil: (file_id, parent_id, nama, mime)
```

Link download langsung (test pakai range request,，不要 full download buat cek):
```
https://drive.usercontent.google.com/download?id=<FILE_ID>&export=download&confirm=t
```

### 2. Scan SEMUA zlib stream di firmware
File STB berbasis Linux = squashfs/jffs2 yang isinya **zlib-compressed**.
`strings` langsung GAGAL — file-nya bukan teks.

```python
for m in re.finditer(rb'\x78[\x01\x5e\x9c\xda]', data):   # zlib header
    out = zlib.decompressobj().decompress(data[m.start():m.start()+900000])
    if b'GUIK' in out: full += out
```
→ 943 stream di firmware 4MB. `keymap.xml` ada di dalamnya.
⚠️ Cek `len(full) > 0` sebelum parse — firmware Sunplus (bukan ATBM) sering
   TIDAK punya keymap.xml sama sekali (0 stream). Itu normal, bukan error.

### 3. Parse keymap
```xml
<group name="public">          <!-- set remote #1 -->
  <key name="GUIK_M">0xbf97</key><!--menu-->
```
- `0xbf..` = NEC address 0xBF (remote set 1)
- `0xbb..` = NEC address 0xBB (remote set 2)
- Komentar `<!--...-->` = NAMA FUNGSI tombol. **Simpan ini**, jangan buang —
  itu yang bikin lo tahu `GUIK_U` = mute, bukan asal tebak.

### 4. Verifikasi file bukan placeholder
```bash
head -c 32 file.bin | od -A n -t x1      # magic header
tr -d '\0' < file.bin | wc -c            # bytes non-null vs ukuran
```
Magic yang valid: `b5 6f 00 24` = Sunplus 2519 · `aa 55 aa 55` = ATBM.

## Jebakan
- ⚠️ Hanya `keymap.xml` sebagai NAMA FILE di tabel → isi file-nya di stream
  lain. Jangan berhenti di `strings file | grep keymap`.
- ⚠️ `zlib.decompressobj()` bisa return partial tanpa error. Kumpulkan
  SEMUA stream, jangan ambil yang pertama cocok.
- ⚠️ Semua file firmware 4MB bukan berarti isinya sama. Cek SHA256 tiap file.
- ⚠️ Nama file `amikinkin`/`2591k` = sinyal file，它来自 grup Facebook, bukan
  resmi — cek header magic sebelum percaya.

## Output untuk user
Selalu accompanied by: nama file + ukuran + **cara cek chipset di STB**,
karena flash firmware salah chipset = unit mati permanen.