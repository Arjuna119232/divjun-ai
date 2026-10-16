---
name: phone-signal-fusion
description: Combine phone signals for caller identification without paid caller-ID databases. Covers why Truecaller/Eyecon/CallApp/GetContact APIs cannot be scraped, why WhatsApp and Telegram cannot be checked by phone number (tested 2026), and the far more valuable local signals: Android call log, contacts, SMS body extraction, plus a relation score. Also documents Android permissions needed (READ_CALL_LOG, READ_SMS). Use when building caller ID, spam detection, phone reputation, or "who is calling me" features.
---

# Phone Signal Fusion — Menggabungkan Sinyal Tanpa Database Bayar

Pelajaran dari NEXTRACE (`/storage/emulated/0/Fonts/intelegen-webview`), 7 Okt 2026.

## Yang TIDAK bisa dipakai (sudah diuji live)

### Caller ID apps: Truecaller, Eyecon, CallApp, GetContact
Database nama panggilan mereka ada di server mereka sendiri. **Tidak ada API
publik.** API resmi (Truecaller Business, Phone Number Signal/Google) itu
berbayar dan butuh kontrak bisnis. Mencoba menembak API internal mereka:
- melanggar syarat layanan
- hasil tidak stabil (punya proteksi)
- bisa diblokir kapan saja

Yang bisa dilakukan: **link-out ke halaman web mereka**, pakai akun/izin
user sendiri. Jangan mengarang bahwa app punya datanya.

### WhatsApp dan Telegram (test 7 Okt 2026)
| Cek | Hasil | Kesimpulan |
|-----|-------|------------|
| `wa.me/{number}` | HTTP 200 untuk nomor **valid DAN tidak valid** | Tidak ada sinyal sama sekali. Both redirect ke `api.whatsapp.com/send/` |
| `t.me/{number}` | Body kosong | Tidak ada API phone-to-account |
| `t.me/{username}` | Ada og:description | Hanya berlaku untuk **username**, bukan nomor |

Jadi jangan buat fitur "cek nomor ini di WhatsApp". Tidak ada sinyalnya.
Link `wa.me/{number}` masih berguna — tapi itu membuka obrolan di app
WhatsApp, bukan pemeriksaan diam-diam.

## TAMBAHAN (7 Okt 2026): test endpoint caller-ID publik

| Endpoint | Hasil test |
|----------|-----------|
| `truecaller.com/search/{n}` | **404 Page not found** |
| `truecaller.com/api/search?searchPhone={n}` | **404** |
| `getcontact.com/number/{n}` | **404** |
| `wa.me/{n}` (nomor valid) | HTTP 200 |
| `wa.me/{n}` (pasti tidak ada) | HTTP 200 juga -> **nol sinyal** |
| `t.me/{n}` (3 nomor berbeda) | 18.369 byte **identik** -> **nol sinyal** |
| `html.duckduckgo.com/html/?q=` | "anomaly"/"challenge", 0 hasil |
| `mojeek.com/search?q=` | 349 byte = diblokir |
| `libphonenumberapi.com/api/phone-numbers/{n}` | **200, data nyata, keyless** |
| `calltracer.io/api/lookup/{n}` | **200, keyless** |

Kesimpulan: agregasi nama crowdsourced (GetContact/Truecaller/CallApp/
Eyecon) **tidak bisa** dari luar — semua endpoint publiknya sudah ditutup.
Yang bisa: operator + MCC/MNC (ITU E.212, keyless) + skor spam (keyless).

**MCC/MNC Indonesia (ITU E.212):** MCC 510. MNC: Telkomsel 01,
XL Axiata 11, Indosat Ooredoo 08, Smartfren 09.

Jangan coba scrape mesin pencari dari server — semuanya mendeteksi bot.
Dorong saja query-nya ke browser user.

## Yang LEBIH BERHARGA dan gratis: sinyal lokal

Inilah yang tidak bisa didapat tool online mana pun, karena hanya ada di
HP pengguna sendiri:

| Sinyal | Sumber Android | Izin |
|--------|----------------|------|
| Nama tersimpan | `ContactsContract` | `READ_CONTACTS` |
| Kapan + sering + lama | `CallLog.Calls` | `READ_CALL_LOG` |
| Nomor di isi SMS | `Telephony.Sms` + regex body | `READ_SMS` |
| Operator + negara | `TelephonyManager` | (nihil) |
| Skor spam kolektif | calltracer.io | (nihil) |

**Trik terbaik: ekstrak nomor dari ISI pesan SMS.** Banyak orang tidak
menyimpan nomor pengirim SMS (WhatsApp/Telegram dan aplikasi lain sudah mengarahkan), tapi
nomor itu sering muncul di isi pesan. Sinyal ini hampir tidak pernah dipakai
tool OSINT mana pun.

## Skor hubungan 0-100

Gabungkan semua sinyal jadi satu angka. Ini "seberapa kuat jejaknya dengan
perangkat ini", BUKAN "seberapa penting orangnya".

```javascript
skor 0
if tersimpan sebagai kontak      +30
if punya nama                    +10
telepon 1-2 / 3-10 / 11-40 / >40  +5/+15/+22/+28
pesan (masuk+keluar)              +min(20, n*2)
durasi total                     +min(12, detik/120)
terakhir 7/30/180 hari lalu       +12/+8/+4
terakhir > 730 hari lalu         -10
```

## Android: izin wajib

```xml
<uses-permission android:name="android.permission.READ_CALL_LOG" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.READ_CONTACTS" />
```

Request permission untuk beberapa sekaligus pakai
`RequestMultiplePermissions`, bukan satu-satu.

## Android 12+ dan peran asli

Untuk identifikasi identitas pemanggil **secara real-time**, Android 12
(API 31) punya `CallScreeningService` — app bisa menjadi caller ID default
dan menerima info panggilan masuk. Ini API resmi yang benar. Kalau memang
perlu caller ID waktu nyata, ini jalurnya, bukan scraping.

## Cara menjawab user yang minta "gabungkan Truecaller + WhatsApp + ..."

Jangan bilang tidak bisa tanpa penjelasan. Bilang:
1. Data Truecaller/Eyecon/CallApp/GetContact proprietary dan tidak ada API
   publik — link-out adalah cara sah dan sah
2. WhatsApp/Telegram sudah menutup pengecekan nomor (bukti test)
3. Tapi saya bangun fusi sinyal dari call log + kontak + SMS + operator
   yang justru lebih berharga dan gratis
4. Kalau butuh real-time, ada `CallScreeningService` resmi Android

## Catatan etika

Membaca call log dan SMS user sendiri = data milik dia, lokal, tidak
dikirim. Itu aman dan justru fitur yang paling dihargai user.
Yang tidak boleh: mengirim data ini ke server, atau memakai app ini untuk
mengikuti orang berdasarkan aktivitas sms/call orang lain.