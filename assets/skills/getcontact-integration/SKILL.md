# Skill: Integrasi GetContact CLI (lookup nama nomor) di NEXTRACE

Sumber KEDUA untuk field "nama pemilik" di NEXTRACE, cadangan kalau
Truecaller belum login. Terbangun di `/storage/emulated/0/Fonts/intelegen-webview/web`.

## Ringkasan jalur

```
repo xdreizein666/getcontact-cli  ->  ~/getcontact-cli/gtc.py (Python)
credential: ~/.config/gtc/credentials.json  (chmod 600, JANGAN masuk git)
bridge   : web/getcontact-bridge.js  (spawn python -> parse JSON stdout)
route    : /api/getcontact/status  dan  /api/getcontact/lookup?num=&tags=1
aggregator: ownerName providers = [Truecaller, GetContact]  (fallback per-field)
```

## Install & login (sekali saja)

```bash
# dependensi — PENTING: jangan pip install cryptography (gagal di Py3.14)
pip install requests
pkg install python-cryptography

git clone https://github.com/xdreizein666/getcontact-cli ~/getcontact-cli
cd ~/getcontact-cli
python gtc.py generate 0896xxxxxxx     # -> link wa.me + kode
# user kirim pesan WA dari NOMOR ITU, tunggu centang dua + 10 detik
# baru lanjut (Enter). kode BERUBAH tiap run - kalau proses mati, ulangi.
python gtc.py quota                    # harus "search: 200/200"
python gtc.py search 628123456789      # tes lookup
```

## Jebakan yang sudah dipetakan

1. **Verifikasi gagal `403037 "Verification not completed yet"`** =
   pesan WA belum centang dua, dikirim dari nomor BERBEDA, atau Enter
   ditekan terlalu cepat. Fix: tunggu centang dua + 10 detik, pastikan
   pengirim = nomor yang didaftarkan, lalu generate ulang (kode baru).
2. **Proses `generate` butuh input Enter interaktif** — kalau dijalankan
   dari tool shell, dia mati kena timeout. Pola yang jalan:
   `mkfifo $TMPDIR/gtc-fifo` -> satu proses `sleep 7200 >fifo` (penahan),
   proses gtc `<fifo`, lalu kirim `printf '\n' >fifo` saat user siap,
   semuanya dengan `setsid nohup ... &` supaya tidak ikut mati.
3. **Banner ASCII gtc.py masuk stdout** -> pakai env `GTC_NO_BANNER=1`
   (bridge sudah melakukannya) supaya stdout murni JSON.
4. **Endpoint asli**: `pbssrv-centralevents.com` (BUKAN api.getcontact.com
   yang 403). `/v2.8/search` = profil, `/v2.8/number-detail` = tags
   (penamaannya tertukar, sudah diluruskan di gtc.py).
5. **Kuota**: search 200/bln (reset tgl 31), numberDetail 0/0. Nomor
   layanan (mis. 6281111111111) balas nama "Telkomsel" + 200 tag —
   itu data asli, bukan bug. Jangan panggil lookup untuk yang bukan nama.

## Aturan output (WAJIB, sama dengan truecaller-bridge)

- Selalu isi `error` + `hint` pada hasil GAGAL, walau `ok:true` juga.
- Tidak ada nama -> `{ ok:true, found:false, note }` — jangan mock.
- Semua nama = crowdsourced, tulis source + confidence.
- Test hidup: `curl http://127.0.0.1:8420/api/getcontact/lookup?num=6281239596551`
  harus balas nama asli. Smoke test wajib 0 gagal (62 check).
