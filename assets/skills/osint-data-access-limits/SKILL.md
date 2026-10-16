---
name: osint-data-access-limits
description: The physical limits of OSINT — no tool has direct access to telecom operator data or Dukcapil (Indonesian civil registry). Explains why HLR, active-status, roaming, porting, and owner-name lookups are unavailable, and what actually works instead (correlating public/crowdsourced/leaked data with source attribution and confidence rating). Use when planning OSINT features, promising data capabilities, or explaining why a lookup feature cannot deliver what a user expects.
---

# Batas Fisik Data OSINT

Sudah settled 7 Okt 2026. Ini bukan opini — ini hasil test semua endpoint
yang ada, dan konsistannya dengan arsitektur industri.

## Klaim inti

> Tidak ada website yang punya akses langsung ke data operator atau Dukcapil.
> Semua tool OSINT cuma **menggabungkan (correlate) data yang sudah bocor,
> publik, atau crowdsourced** dari banyak sumber.

## Kenapa begitu (arsitektur, bukan karena gagal coba)

| Data | Dimiliki oleh | Bisa diakses publik? |
|------|---------------|---------------------|
| HLR (Home Location Register) | operator | ❌ tidak ada API |
| Status ACTIVE / CONNECTED | operator | ❌ hanya dari HLR |
| Roaming, porting | operator | ❌ hanya dari HLR |
| Data pelanggan / nama pemilik | operator + data crowdsourced | ❌ proprietary |
| Dukcapil (registry warga ID) | negara | ❌ tidak ada API |
| Nomor tersimpan di HP orang | perangkat masing-masing | crowdsourced via Truecaller dll |

Database Truecaller/GetContact dibangun dari **ratusan juta pengguna yang
menyetujui nomor datanya**. Itu **merek dagang** → API-nya B2B berbayar.

## Yang JUJUR bisa dilakukan

1. **Pivot chain dari identifier publik**
   username → GitHub API (nama asli, lokasi) → domain blog → subdomain →
   email → Gravatar → nama tampilan

2. **Korelasi lintas sumber**
   satu nomor bisa muncul di call log, SMS, dan web. Korelasi itulah nilainya.

3. **Data yang benar-benar publik & resmi**
   RDAP (registrasi domain dari registry), DNS MX, Certificate Transparency
   (subdomain), data operator dari libphonenumber (MCC/MNC — ITU publik)

4. **Spam reputation kolektif**
   CallTracer, Google Play Protect — agregat laporan pengguna

## Konsekuensi untuk desain fitur

WAJIB ada di setiap blok hasil:
- **Sumber**: dari mana data ini
- **Confidence**: seberapa kuat buktinya (Admiralty A-F/1-6)
- **Status jujur**: kalau tidak ada API → tulis "tidak bisa diverifikasi"

JANGAN PERNAH:
- isi mock yang menyamar jadi hasil asli
- tulis "TERDAFTAR" / "TIDAK TERDAFTAR" kalau responsnya identik untuk
  kedua kasus (WhatsApp & Telegram: 200 untuk keduanya → nol sinyal)
- Ambil nama dari halaman web tanpa verifikasi nomor benar-benar ada

## Cara menjelaskan ke user

Jangan hanya bilang "tidak bisa". Urutan yang worked:

1. Konfirmasi sudut pandang mereka (benar)
2. Jelaskan kenapa secara arsitektur (bukan sekadar gagal)
3. Tunjukkan yang **bisa** dan sudah jalan
4. Beri jalan 1-klik ke sumber yang benar-benar punya datanya
5. Kalau mau data operator asli → itu perlu API berbayar / kerja sama

## Kalau user tetap mau data operator asli

Pilihan sah (tidak ada jalan gratis):
- **NumVerify / AbstractAPI / phonevalidationapi** — 100 request/bulan free,
  hanya validitas + operator, BUKAN nama pemilik
- **Truecaller Business API** — paket identitas, kontrak B2B
- **Phone Number Signal (Google)** — tujuan SMS, butuh partnersip
- **operator sendiri** — HLR hanya untuk operator

Selalu sebut biayanya di depan. Jangan janjikan dulu lalu lusa.