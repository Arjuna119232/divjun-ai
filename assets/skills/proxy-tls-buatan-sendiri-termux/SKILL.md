# Skill — Proxy TLS Buatan Sendiri di Termux ( Alternatif mitmproxy)

Dipakai saat butuh membaca traffic HTTPS dari HP sendiri (login, sesi, API
pola) **tanpa** mitmproxy, tanpa Rust, tanpa root.

## Kapan dipakai
`mitmproxy` gagal di Termux karena `cryptography` butuh backend `maturin`
(Rust). Tapi `pkg install python-cryptography` **sudah** menyediakan modulnya
(jadi `import cryptography` jalan). Yang tidak ada hanya mitmproxy-nya.
→ Tulis proxy minimal sendiri, ~150 baris, pakai `cryptography` yang sudah ada.

## Resiko dan cara menguranginya
- **JANGAN** `--no-build-isolation` untuk paket lain — itu tetap memaksa build.
  Error yang harus dikenali: `BackendUnavailable: Cannot import 'maturin'`
  → artinya memang butuh toolchain, jangan dipaksa.
- Proxy hanya listening di `127.0.0.1` (loopback) → tidak buka port ke WiFi.
- Log **JANGAN** menyimpan body yang memuat kredensial. Filter di layer
  `should_log()`.

## Checklist keamanan wajib sebelum menjalankan proxy (WAJIB ke user)
1. Jelaskan risiko konkret, bukan "aman kok".
2. Sebutkan apa yang TIDAK akan disentuh (mis. tidak ada transfer uang,
   tidak ada OTP spam, hanya satu kali login).
3. Sebutkan **daftar pembersihan** dan lassen user tahu persis cara membersihkannya.
4. Jangan eksekusi sebelum user bilang lanjut.

## Pola pengaman yang dipakai
- `skipSendOtp:true` → tidak memicu SMS pada nomor user.
- Satu kali percobaan login saja. Login gagal berulang = risiko akun terkunci.
- Kalau perlu ganti nomor HP / transfer / top up → **tidak pernah dieksekusi**,
  hanya dip-mentioned sebagai temuan.
- CA private key hanya ada di Termux user; setelah selesai hapus CA dari Android.

## ⚠️ Fakta perangkat yang menambah risiko
Chrome Android **mempercayai** sertifikat CA user-store (beda dari app lain
yang sejak Android 7 tidak percaya user CA). Jadi selama CA terpasang, traffic
Chrome bisa di-intercept siapa pun yang punya private key-nya. Karena itu
**lepas CA begitu selesai**.