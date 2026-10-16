# DIVJUN AI - Native Flutter (Agent AI)

Rebuild total dari aplikasi WebView (HTML/JS di WebView + Kotlin wrapper) menjadi
**Flutter native** dengan agent AI yang benar-benar jalan: multi-step tool
calling, memori, streaming per token.

- Package: `com.divjun.ai` · versi `2.0.0+35` (update di atas APK lama 1.15.2)
- minSdk 24 · targetSdk 35 · Java 17
- Nama folder `android/` **tidak** ada di repo: di-generate + di-patch otomatis
  di CI oleh `tool/setup_android.py`.

## Fitur

**Chat**
- streaming token per token, berhenti kapan saja (tombol stop)
- jawaban markdown (kode, tabel, list, blockquote, tautan)
- menu panjang per pesan: salin, edit, jawab ulang, ringkas, hapus
- riwayat percakapan tersimpan di perangkat, bisa dihapus per chat

**Agent AI (native function calling)**
- loop `plan -> act -> observe` sampai 6 langkah
- 5 alat: `kalkulator`, `waktu_sekarang`, `memori`, `buka_url`, `email`
- anti-duplikasi tool call, batas jumlah tool per langkah, timeout 20 detik
- tool yang mati/dimatikan tidak pernah dikirim ke model

**Memori**
- jangka panjang: simpan / cari / hapus per entri / bersihkan semua
- pencarian lokal (kata kunci + kesegaran), hanya entri relevan yang disuntik
  ke system prompt
- jarakak storage: riwayat + memori = file JSON, ditulis atomik

**Keamanan**
- penjaga SSRF untuk tool web (blokir alamat privat, metadata awan, DNS rebound)
- memori menolak menyimpan password/token/kunci
- email tidak pernah terkirim diam-diam: AI membuat draf, user yang menekan kirim

**Antarmuka**
- Material 3 + dynamic color (Material You) + mode gelap/terang/sistem
- Inter + JetBrains Mono (dibundel, bukan diunduh saat runtime)
- splash 900 ms, skeleton shimmer, empty/error state designed
- bottom sheet dengan drag handle, ripple + haptic, animasi emphasized

## Menjalankan dari Termux (tanpa laptop)

Tidak ada Flutter di HP, jadi semua lewat GitHub Actions:

```bash
# 1. hanya cek kode (2 menit, tanpa APK)
gh workflow run flutter.yml --ref flutter-native -f analyze_only=true

# 2. build APK (universal, ditandatangani keystore asli)
gh workflow run flutter.yml --ref flutter-native -f analyze_only=false -f demo=false

# lihat hasil
gh run list --limit 1
```

Cek lokal yang bisa dijalankan di HP (< 1 detik):

```bash
python3 tool/check_source.py      # dead-file, import hilang, kurung, non-Latin, aset
python3 tool/setup_android.py --verify-only
```

`tool/check_source.py` adalah gerbang blocking yang sama seperti yang dipakai
di CI, plus `flutter analyze` dan `flutter test`.

## API key

Disuntik saat build lewat `--dart-define`, tidak pernah ada di repo:

```
--dart-define=GROQ_API_KEY=...
--dart-define=GEMINI_API_KEY=...
```

Tanpa key, app tetap jalan dalam mode demo: UI menampilkan status key kosong,
bukan crash.
