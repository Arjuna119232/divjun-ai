---
name: osint-deep-pivot
description: Build deep OSINT investigation instead of adding more modules. Covers the pivot chain technique (identifier opens identifier), keyless enrichment sources that work in 2026 (GitHub public API, crt.sh certificate transparency), Admiralty Code reliability rating, and why adding a HUMINT module to an app is a mistake. Use when someone asks for "deep" OSINT, "mendalam", pivot chains, link analysis, subdomain discovery, or wants to correlate findings across tools.
---

# OSINT Mendalam = Pivot Chain, Bukan Banyak Modul

Pelajaran dari NEXTRACE (`/storage/emulated/0/Fonts/intelegen-webview`), 7 Okt 2026.

## Kesalahan yang harus dihindari

User minta "pencarian supaya mendalam". Salah jawaban = menambah 7 modul lagi
atau menambah modul HUMINT. Keduanya salah:

- **Menambah modul** tidak menambah kedalaman. 7 modul yang terpisah =
  user harus paste input yang sama ke 7 tempat.
- **Modul HUMINT di app** = modul kosong. HUMINT artinya wawancara orang.
  Tidak ada API untuk mewawancara. Otomatisasi tidak mungkin. Kalau
  dipaksakan, hasilnya form kosong yang tidak berguna.

Jawaban benar: **1 modul pivot** yang mengalikan sendiri.

## Teknik: pivot chain

Satu identifier membuka identifier lain, berulang kali. Ini yang membedakan
OSINT beneran dari "main-main modul".

```
username -> GitHub API publik -> nama, lokasi, blog, email publik, twitter
username -> 12 platform profil   -> situs mana yang dia punya
email    -> Gravatar             -> nama tampilan, lokasi, akun tertaut
domain   -> crt.sh               -> SELURUH subdomain dari sertifikat TLS
domain   -> RDAP                 -> registrar, tanggal, name server
phone    -> libphonenumberapi    -> operator, negara, zona waktu
ip       -> ip-api               -> lokasi, ISP, ASN, reverse DNS
```

UI wajib: setiap temuan punya **tombol pivot** (ketuk identifier baru ->
jalankan rantai lagi). Dan Findings tersimpan di case file supaya bisa
diekspor jadi laporan.

## Dua sumber keyless paling bernilai (test 7 Okt 2026)

### 1. GitHub public API — bridge username -> identitas
```bash
curl -H "User-Agent: Mozilla/5.0" https://api.github.com/users/{username}
```
Balikin: `name`, `location`, `bio`, `company`, `blog`, `email` (kalau user
sendiri yang mempublikasikan), `twitter_username`, `created_at`, `followers`.
Gratis, tanpa token, 60 request/jam per IP. **Paling tinggi nilai dari
semua sumber OSINT gratis** — ini satu-satunya cara lawful mendapatkan nama asli +
lokasi dari username.

### 2. crt.sh — subdomain discovery tanpa scan port
```bash
curl "https://crt.sh/?q=%25.{domain}&output=json"
```
Setiap sertifikat TLS yang terbit untuk domain tercatat permanen di log
Certificate Transparency. Jadi seluruh subdomain yang PERNAH punya sertifikat
terbuka, gratis, tanpa daftar. Hampir tidak ada tool OSINT yang memakai ini in OSINT tools.
Cocok untuk Menemukan `admin.`, `api.`, `staging.`, `vpn.`, `git.`.

## Admiralty Code — cara baku menilai temuan

User sering percaya output tool padahal bisa salah (bukti: holehe modul
mati = jawaban negatif palsu). Rating ini wajib ada.

**Keandalan sumber (A-F):**
- A Sangat dapat diandalkan — terverifikasi dari dokumen resmi
- B Biasanya dapat diandalkan — konsisten dalam riwayat
- C Cukup dapat diandalkan — perlu konfirmasi tambahan
- D Kurang dapat diandalkan — perlu dua sumber lain
- E Tidak dapat diandalkan — riwayat tidak konsisten / bias
- F Reliability tidak bisa dinilai — sumber baru

**Keyakinan informasi (1-6):**
- 1 Dikonfirmasi sumber lain
- 2 Kemungkinan benar
- 3 Mungkin benar
- 4 Meragukan (kontradiksi sumber lain)
- 5 Tidak mungkin (bertentangan dengan kenyataan)
- 6 Truth tidak bisa dinilai

Gabungkan jadi tingkat keyakinan. Ini standar NATO, bukan penilaian subjektif.

## Klasifikasi identifier

Pakai regex sederhana sebelum memanggil sumber, supaya input yang salah
tidak dikirim ke 5 endpoint sekaligus:
```
email    /^[^\s@]+@[^\s@]+\.[^\s@]+$/
ip       /^\d{1,3}(\.\d{1,3}){3}$/
domain   punya titik, bukan IP, bukan email
phone    7-15 digit
username /^[a-z0-9_.-]{2,}$/i
name     sisanya (tidak ada endpoint teknis)
```

## Cara menjawab kalau user minta HUMINT

Jujur tapi singkat: HUMINT = mengumpulkan dari manusia, tidak bisa
diotomatisasi jadi tombol di app. Yang bisa dan berguna. Instead: alat bantu
untuk manusia yang sudah turun lapangan — template wawancara, form bukti,
dan **rating keyakinan** supaya temuan tidak dipercaya mentah-mentah.
Jangan buat modul HUMINT kosong hanya karena diminta.

## Checklist-deep OSINT app

- [ ] 1 modul pivot (bukan N modul terpisah)
- [ ] Tombol pivot di setiap temuan
- [ ] Findings tersimpan + ekspor laporan
- [ ] Rating Admiralty di tiap temuan
- [ ] Klasifikasi input sebelum request
- [ ] Semua sumber keyless (tested, bukan dari dokumentasi)
- [ ] Tidak ada modul HUMINT kosong