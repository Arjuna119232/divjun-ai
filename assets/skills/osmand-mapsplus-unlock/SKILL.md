# Unlock Maps+ / OsmAnd Pro di OsmAnd — patch 7 method

Skill ini lahir dari task 12 Okt 2026: user minta APK OpenStreetMap yang
"bisa diubah + fitur plus kebuka". Kesimpulannya.app OSM resmi tidak punya
premium sama sekali; target yang benar adalah **OsmAnd**.

## 1. VERDICT SOAL "APK OpenStreetMap"

Jangan mulai dari APK OSM resmi. Cek dulu tabel ini:

| App | Package | Open source | Premium? |
|---|---|---|---|
| OSM official | `com.openstreetmap.osm` | GPLv3 ya | **TIDAK ADA** |
| Organic Maps | `app.organicmaps` | Apache-2.0 ya | tidak ada |
| **OsmAnd** | `net.osmand` / `net.osmand.plus` | GPLv3 ya | **Maps+ + Pro** |

App OSM resmi = 100% gratis selamanya, tidak ada apa pun untuk dibuka.
Kalau user tetap minta "OSM yang plus-nya kebuka", jawab: yang punya Plus cuma
OsmAnd, lalu kerjakan itu.

## 2. Ambil APK: pakai build Nightly resmi, bukan Play Store

```bash
curl -L -o OsmAnd-default.apk \
  "https://download.osmand.net/latest-night-build/OsmAnd-default.apk"
```

Kenapa Nightly dan bukan APK Play Store:
- link resmi, tanpa perlu extractor/akun
- package-nya **`net.osmand.dev`** → bisa dipasang **berdampingan** dengan
  OsmAnd asli dari Play (tidak saling replace)
- flavor selalu `...nightlyFree...` (CEK dengan `strings -n 5 classes*.dex |
  grep -i nightly`)

Verifikasi (aapt2 wajib ada di Termux):
```bash
aapt2 dump badging OsmAnd-default.apk | head -2
# package: name='net.osmand.dev' versionName='5.5.0#9138m'
```

Jebakan: **Nightly TIDAK auto-unlock**. Infra devsinya
`Version.isDeveloperBuild()` = `getAppName().contains("~")`, dan label Nightly
adalah `"OsmAnd Nightly"` — tanpa `~`. Jadi tetap harus patch.

## 3. GATE-NYA TERPUSAT — DAN NAMA CLASSNYA DI-OBFUSCATE

**JAWABAN FINAL (terbukti, bukan tebak):** APK rilis OsmAnd 5.5.0 **di-R8**
sebagian. Class turunan Android (Application/Service/Activity) tetap nama asli —
itulah petunjuknya.

⚠️ **NAMA CLASS BERUBAH ANTAR NIGHTLY. BUKAN SEJAK RILIS — BANTUAN 9 JAM
DARI NIGHTLY KE NIGHTLY. Diverifikasi nyata 12 Okt 2026:**

| Build | `Version` | `InAppPurchaseUtils` |
|---|---|---|
| `5.5.0#9138m` (00:55 WIB) | `to2.smali` | `ps0.smali` |
| `5.5.0#9147m` (15:32 WIB) | **`vo2.smali`** | **`rs0.smali`** |

Di build `#9147m`, **`ps0.smali` = `WebViewClient`** — bukan InAppPurchaseUtils.
Patch Buta memakai nama lama = patch class yang salah, dan build tetap "sukses".
**Selalu petakan ulang. Tidak ada pengecualian.**

### Cara memetakan ULANG (5 menit, tanpa tebak)

**Jangan** mulai dari grep `"net.osmand"` — di build terbaru string itu dipakai
banyak class lain (`c2.smali` 8x, `Q60.smali` = uncaughtException handler, dll)
dan semuanya false positive.

Mulai dari **signature**, itu yang stabil:

```bash
grep -rn "^\.method.*(Lnet/osmand/plus/OsmandApplication;Z)Z" --include="*.smali" dec
```

Hasilnya = semua gate premium, biasanya 7 method di 2 file. File yang
**memanggil** method-method itu = `Version`. Konfirmasi tie-nya:

```bash
awk '/^\.method public static n\(Lnet\/osmand\/plus\/OsmandApplication;Z\)Z/{f=1} f{print} f&&/^\.end method/{exit}' dec/smali_classes3/vo2.smali
```

Body itu memanggil `rs0.G`, `rs0.J`, `rs0.L`, `rs0.O`, `rs0.B` → `vo2` =
Version, `rs0` = InAppPurchaseUtils. Selesai, tanpa menebak.

### PATCH FINAL — 7 method, 2 file (semua di `smali_classes3/`)
| File | Method | Arti asli |
|---|---|---|
| `vo2.smali` (=`Version`) | `n(...;Z)Z` | `isPaidVersion` (MASTER) |
| `rs0.smali` (=InAppPurchaseUtils) | `g(...;Z)Z` | `checkDeveloperBuildIfNeeded` |
| `rs0.smali` | `G(...;Z)Z` | `isFullVersionAvailable` |
| `rs0.smali` | `J(...;Z)Z` | validitas langganan (baca field `M1` = Long) |
| `rs0.smali` | `L(...;Z)Z` | `isMapsPlusAvailable` |
| `rs0.smali` | `O(...;Z)Z` | `isOsmAndProAvailable` |
| `rs0.smali` | `Q(...;Z)Z` | validitas Pro Maps (baca field `M1`) |

`J` dan `Q` **baru muncul** di `#9147m` (versi lama cuma 4). Keduanya cek
kedaluwarsa langganan lewat `System.currentTimeMillis()`, jadi patch juga menutup
"langganan kedaluwarsa".

Sebelum patch, pastikan target itu **pure predicate**: grep body-nya, kalau ada
`sput` atau pemanggilan dialog = BUKAN predicate, jangan dipatch. Semua 7 di
atas bersih (hanya baca flag + `return`).

Isi setiap method jadi:
```smali
    .locals 1

    const/4 v0, 0x1

    return v0
```
WAJIB `.locals 1` (parameter 2 = p0,p1; `.locals 0` bikin v0 menabrak p0
yg tipe-nya object -> return integer garbage).

Patch python WAJIB pakai `assert` — `str.replace()` bisa gagal diam-diam.

### ⚠️ JEBRAKAN REGEX SIGNATURE (bikin 2x gagal saat nulis patch.py)

Signature smali punya **tipe balik SETELAH** kurung tutup parameter:
`n(Lnet/osmand/plus/OsmandApplication;Z)Z`. Kalau regex-nya
`\)\n` maka **tidak akan match** dan method tidak ketemu — padahal nama file dan
method-nya sudah benar. Simpan signature PENUH (termasuk tipe balik) lalu
`re.escape()`:

```python
APP = "Lnet/osmand/plus/OsmandApplication;Z)Z"          # termasuk tipe balik
pat = re.compile(r"(\.method\s+[^\n]*\s" + re.escape(NAME) + r"\("
                 + re.escape(APP) + r"\n)(.*?)(\.end method\n)", re.DOTALL)
```

Script patcher yang sudah benar + teruji: `~/osmand-work/patch.py` (salinan juga
di folder session).

## 3d. BUKTI PATCH MASUK KE APK YANG DIKIRIM (bukan cuma "build sukses")

`apktool b` exit 0 **tidak membuktikan** patch ada di dex akhir. Decode ulang
APK yang sudah di-sign lalu pastikan method-nya benar-benar `return true`:

```bash
java -Xmx2500m -jar $J d -r -f -o vdec final.apk
awk '/^\.method public static n\(Lnet\/osmand\/plus\/OsmandApplication;Z\)Z/{f=1} f{print} f&&/^\.end method/{exit}' vdec/smali_classes3/vo2.smali
# harus keluar: .locals 1 / const/4 v0, 0x1 / return v0
```

Bukti tambahan (cepat, tanpa decode): bandingkan hash `classes3.dex` sebelum vs
sesudah patch. Contoh nyata `#9147m`: `84cd6094…` (9.27 MB) -> `857ca38b…`
(11.44 MB). APKtool rebuild dex jadi lebih besar — itu normal, bukan tanda rusak.

⚠️ `apktool d` **tidak bisa** decode file `.dex` polos (butuh zip) — error
`ZipFile.<init>`. Tetap pakai APK utuh.

## 3e. ⛔ SALIN FILE BESAR KE /storage = TIMEOUT (FUSE lambat)

`cp` 194 MB ke `/storage/emulated/0` **melebihi batas waktu tool** dan command
di-abort — file sebenarnya belum sampai / partially copied. Gejalanya:
`ls` file tidak ada padahal tidak ada error. `mv` di folder yang sama juga
bisa timeout (FUSE rename).

**Cara benar: background + polling.**

```bash
nohup cp final.apk /storage/emulated/0/Download/.tmp.copy >/dev/null 2>&1 </dev/null & disown
# tunggu sampai ukuran == ukuran sumber
for i in $(seq 1 30); do
  sz=$(stat -c %s /storage/emulated/0/Download/.tmp.copy 2>/dev/null || echo 0)
  [ "$sz" -ge $SRC_SIZE ] && { echo DONE; break; }
  sleep 10
done
nohup mv /storage/emulated/0/Download/.tmp.copy /storage/emulated/0/Download/final.apk >/dev/null 2>&1 </dev/null & disown
```

Dua jebakan tambahan:
- Mulai dari **nama titik** (`.tmp.copy`). Kalau command-nya abort di tengah,
  file yang menggantung tidak kelihatan oleh `ls` biasa - padahal ada.
  Cek `ls -la`.
- `mkdir -p "$ZYVO_SESSION_DIR"` **harus dijalankan terpisah lebih dulu**.
  Variabel itu di-export wrapper tapi folder-nya TIDAK dibuat — `cp` ke sana
  gagal dan seluruh chain `&&` ikut abort.

## 3b. BUILD DI TERMUX — SUDAH TERBUKTI BERJALAN

```bash
J=/data/data/com.termux/files/usr/bin/apktool.jar
java -Xmx2500m -jar $J d -r -f -o dec orig.apk   # decode smali saja
# ... edit smali ...
java -Xmx2500m -jar $J b dec -o rebuilt.apk      # ~2.5 menit, LANGSUNG BERHASIL
zipalign -p -f 4 rebuilt.apk aligned.apk          # pkg install -y aapt
apksigner sign --ks ks.jks --ks-key-alias a \
  --ks-pass pass:X --key-pass pass:X \
  --v2-signing-enabled true --v3-signing-enabled true \
  --min-sdk-version 24 --out final.apk aligned.apk
```

**JAWABAN "bisa tidak zyvo yang build sendiri?" = BISA.** Detailnya di
skill `build-patched-apk-on-termux`. Ringkasnya:
- `apktool.jar` Termux berisi `com/android/tools/smali/*` TAPI kelas `Main`
 -nya **sudah di-strip main method** -> tidak bisa dipanggil langsung.
- Konsekuensinya: `apktool b` (bukan baksmali standalone).
- Dekode WAJIB pakai **`-r` (no-res)**. `-s` itu `--no-src` (justru
  membalik: dex di-*copy mentah*, tidak di-baksmali).
- Karena resource di-copy mentah, **tidak ada*aapt2 yang dikompilasi** ->
  jebakan wrapper aapt2 di Termux (skill `apktool-termux-rebuild`) TIDAK muncul.
  Jadi `apktool b` langsung sukses, tidak perlu dex-swap.
- RAM: `-Xmx2500m` cukup untuk APK 200 MB. Free storage 125 GB aman.
- v1 signing otomatis FALSE karena `--min-sdk-version 24`; itu BENAR dan
  cukup (v1 hanya wajib untuk API < 24). v2+v2 sudah "Verifies".
- File `.bak` di dalam folder smali cuma warning `Unknown file type,
  ignoring` — aman, tapi lebih baik taruh di luar folder smali.

## 3c. WAJIB: uninstall dulu
Signature kita != signature OsmAnd BV. Android menolak install menimpa.
Data (peta offline, track, favorit) hilang saat uninstall. Ingatkan user.

## 4. Kenapa 2 itu cukup (peta routing yang sudah diverifikasi)

Semua ini cuma memanggil 1 dari 2 method di atas:
`DownloadValidationManager:116` (batas 7 download), `isContourLinesAvailable`,
`isDepthContoursAvailable`, `isAndroidAutoAvailable`, `isAstronomyAvailable`,
`isGridColorAvailable`, `isBuildingsCustomColorAvailable`,
`isCustomWidgetBackgroundColorAvailable`, `is3dMapsAvailable`,
`isWeatherAvailable`, `isBackupAvailable`, `isProWidgetsAvailable`,
`isVehicleMetricsAvailable`, `isColoringTypeAvailable`,
`isGradientEditorAvailable`, `PurchasesFragment:144` (anti-nag).

`isContourLinesPurchased` / `isDepthContoursPurchased` **JANGAN dipatch** —
udah dicek, seluruh repo cuma memanggilnya dari `InAppPurchaseUtils` dan
`DiscountHelper` (yang isinya cuma pop-up diskon).

## 5. Yang TIDAK bisa dibuka (jujur, jangan janji)

- **Live Updates 15 menit** → dicek SERVER. Flag terbuka, server tetap tolak.
- OsmAnd Pro bulanan → murni server.
- Signature Play Store hilang → install sebagai "sumber tidak dikenal".

## 6. Cara verifikasi setelah patch

- Menu → Download peta: kolom **"X downloads left" harus hilang**, diganti
  ukuran penyimpanan.
- Menu → Plugins: Topography + Nautical harus bisa diaktifkan.

## Jebakan umum

- `aapt2 dump badging` itu wajib; jangan percaya apk.dog/apkpure soal
  "MOD" — itunamanyanya doang.
- Hapus file `_x/` (hasil unzip dex) sebelum kirim ke user; 192MB+.
- Kalau user minta "bisa diubah sendiri", arahkan ke repo
  `github.com/osmandapp/OsmAnd` (GPLv3) — dia BISA compile sendiri dengan
  mengubah `Version.isPaidVersion` di Java-nya, cara yang lebih bersih.