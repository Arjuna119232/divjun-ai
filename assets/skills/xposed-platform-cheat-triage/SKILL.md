# Xposed / platform-cheat APK triage & verdict

Kapan dipakai: user bawa APK (biasanya dari Telegram) dan minta "bongkar,
buang login, supaya jalan di <app kerja/game live>". Tujuannya mengenali
APAKAH ini alat injeksi ke platform live, lalu memberi verdict jujur —
bukan patch buta. Kebanyakan kasus di sini: tool cheat driver/ojol
(Grab, Gojek/GoPartner, Shopee) dan game online.

## 1. Identifikasi cepat (3 menit, tanpa decompile penuh)

```bash
cd $TMPDIR && rm -rf x && mkdir x
unzip -qo /path/app.apk -d x
ls x/assets/xposed_init 2>/dev/null && cat x/assets/xposed_init   # ← modul Xposed!
unzip -l /path/app.apk | grep -E "assets/|\.so$" | head
aapt2 dump badging /path/app.apk | grep -E "^package|application-label|uses-permission"
aapt2 dump xmltree --file AndroidManifest.xml /path/app.apk | grep -i xposed
```

Petunjuk **Xposed module** (salah satu sudah cukup):
- `assets/xposed_init` ada → isinya nama class entry (mis. `com.x.hooks.Bts`)
- meta-data `xposedscope` / `xposeddescription` / `xposedminversion` / `xposedsharedprefs`
- `META-INF/xposed/` (varian baru)

Petunjuk **cheat/injeksi** — grep method di dex:
```bash
for d in x/classes*.dex; do strings -n 6 "$d"; done \
  | grep -iE "ghost|hook|inject|fake|spoof|autoAccept|autoGrab|setBlock|minGrab|maxGrab|token" | sort -u
```
- `Lcom/.../FxGrab` + `ghostGrab` + `hookAllGrabFeatures` + `getMinGrab/setBlockGrab`
  + saklar scope `sw_fxposedGrab` → alat manipulasi app driver ojol.
- Dilindungi NP Manager → `assets/protected_by_np/ApkControlFlowConfusion_*`.
- Login biasanya Firebase (Auth/RemoteConfig/Messaging) atau backend custom
  (punya Firebase props = tool komersial yang dijual via Telegram).

## 2. Cara baca artinya (jangan salah kategorikan)

- "Boleh mod" yang normal: fitur premium, iklan, trial, license **app
  produktivitas** milik user. Itu tetap dikerjakan (lihat skill apk-mod).
- **BUKAN "boleh mod":** app yang SELURUH fungsinya = injeksi/hook ke proses
  app LAIN yang live (ojol, game online ber-anti-cheat, sosmed). Login/scope
  gate-nya cuma lisensi jualan alat itu. Buang gate = bikin alat injeksi
  platform live gratis → itu garis merah.
- Verdict teknis yang WAJIB disampaikan (biar user paham, bukan cuma "nggak"):
  1. Xposed **praktisnya wajib root + LSPosed**. Tanpa root, di app target
     dia tidak berjalan sama sekali (buang login pun = 0).
  2. Root di HP kerja (mis. HP Grab) = akun kerja terkunci. Grab/ojol resmi
     menyatakan device modified + GPS spoofer → ban / diskualifikasi.
  3. Manipulasi platform live = pelanggaran ToS + berisiko akun & orang lain.

## 3. Jawaban (pola, Bahasa Indonesia, singkat, tanpa ceramah)

1. Bukti konkret: package, `xposed_init`, nama class/method cheat, ringkas.
2. Verdict: tidak dibangun (injek platform live) + **satu** alasan teknis
   terkuat (biasanya "Xposed butuh root; tanpa root mati").
3. Tawarkan 3 jalur legal: belajar teknik (Xposed/NP) di target buatan
   sendiri/CTF · bikin alat sendiri non-invasif · tune HP.
4. Tanya: mau "tekniknya" atau "hasilnya"? Jangan mengulang opsi di chat
   berikutnya — kunci keputusan di memori.

## 4. Jebakan

- Jangan menjanjikan "cm buang login doang" = kecil. Menghapus gate alat
  injeksi tetap membangun tool injeksi itu.
- `bts.apk` yang disalin keluar `/storage/emulated/0` bisa lambat/menggantung
  (FUSE). `unzip -l` / `unzip -p` langsung dari path sumber aman; `cp` file
  besar kadang hang.
- Jangan patok "butuh root" tanpa baca `xposed_init` — buktikan dulu.
- Kalau user bawa APK cheat driver lagi: BACA memori dulu, keputusan sudah
  final, jangan analisa ulang dari nol.
