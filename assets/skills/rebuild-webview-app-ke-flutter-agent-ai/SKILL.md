---
name: rebuild-webview-app-ke-flutter-agent-ai
description: Cara rebuild aplikasi Android WebView (HTML/JS + Kotlin) menjadi Flutter native dengan agent AI dari HP/Termux tanpa Flutter lokal - termasuk pola checker statis Dart, gerbang CI, dan jebakan template Flutter terbaru. Gunakan saat user minta "rebuild app ke Flutter", "pindah dari WebView ke native", atau membangun app Flutter + AI agent dari brief yang premisnya mungkin salah.
---

# Rebuild WebView → Flutter native (dari HP, tanpa Flutter lokal)

Terbukti 16 Okt 2026: **DIVJUN AI** (`com.divjun.ai`, repo privat GitHub),
WebView 137 KB `index.html` → 47 file Dart / ~6.700 baris, analyze 0 error,
13 test lulus, APK rilis ditandatangani keystore lama.

## 1. Audit dulu, jangan percaya brief

Brief sering menyebut file/komponen yang TIDAK ADA. Cek sebelum nulis kode:

```bash
find . -iname "*agent*" -not -path "./.git/*"     # "agent.js" -> ada atau tidak?
find . -name "*.js" -not -path "./.git/*"          # berapa file JS sebenarnya?
grep -cE "tool_call|toolCalls|function_call" app/src/main/assets/*.js
gh secret list                                     # key yang BENAR-BENAR ada
```

Tulis koreksinya ke `docs/REBUILD-AUDIT.md` (tabel brief vs kenyataan + cara
verifikasi ulang), lalu eksekusi. Dua preset yang sering dipakai user:
- "Agent AI sudah ada di agent.js" -> fixer:=dead. Semua aturan main_from_zero.
- "pakai Hive/Isar" →-> files: filesystem JSON + SharedPreferences (0 codegen, 0 risiko ABI).

## 2. Struktur yang dipakai (Clean Architecture pragmatic)

`core/` (theme, router, constants, utils, providers) · `domain/entities` ·
`data/` (datasources, repositories, model wire) · `services/` (streaming,
memory, tool executor) · `features/<fitur>/{presentation,domain,data}`.
Entity domain = model domain (JANGAN dupl jadi models+entities; satu sumber).
Semua provider Riverpod di SATU file `core/providers.dart`.

## 3. Agent AI yang benar-benar jalan

- **LLM**: Groq (OpenAI-compatible) untuk tool calling + Gemini sebagai chat
  fallback. Kunci dicek lewat `gh secret list` - jangan diasumsikan ada.
- **Streaming**: Dio `ResponseType.stream` → `utf8.decoder` → `LineSplitter`,
  akumulator tool_call per index. `CancelToken` dibuat per permintaan.
- **Loop**: `plan -> act -> observe` dengan batas langkah, anti-duplikasi
  (nama+argumen sama per langkah), batas jumlah tool per langkah, timeout 20 dtk.
- **Tool**: kalkulator (parser recursive-descent, tanpa `eval`), waktu,
  memori, web (wajib penjaga SSRF), email (draf saja, tidak pernah kirim diam-diam).
- **Prompt**: memori jangka panjang hanya entri RELEVAN yang disuntik (search
  lokal kata kunci + bonus kesegaran), bukan semua entri.

## 4. Checker statis = satu-satunya gerbang cepat

`tool/check_source.py` (<1 detik) menggantikan `flutter analyze` yang butuh
2-6 menit per putaran CI. 9 cek: DEAD-FILE, IMPORT-EXISTS, MISSING-IMPORT,
UNUSED-IMPORT, EXT-HILANG, ICON-IMPORT, BRACE, NON-LATIN, ASSET.

Jebakan yang harus tahu saat menulis cek seperti ini:
1. **Import adalah STRING.** Kalau regex dijalankan di kode yang string-nya
   sudah dihapus, `import 'x.dart'` jadi `import ''` → semua file DEAD-FILE.
2. **BRACE: jangan pakai regex untuk kurung.** String interpolasi
   `'${a ? '+' : ''}'` menyulitkan. Pakai scanner karakter yang paham
   string + `${...}`. Alternatif: andalkan `flutter analyze` di CI.
3. **Deklarasi harus sadar kedalaman.** Variabel lokal `final b = ...` ikut
   terhitung → UNUSED-IMPORT jadi buta (nama `b` lokal menabrak nama file lain).
4. **Sebutan di interpolasi hilang** setelah string di-strip → untuk deteksi
   pemakaian ambil juga pola `X.` dari kode MENTAH.
5. **Import yang juga di-export** = dipakai (barrel file) → jangan dilapor.
6. **Selalu fault-injection tiap cek baru** (7 injeksi di DIVJUN). Cek yang
   selalu bilang "0 masalah" tanpa uji = tidak berarti apa-apa.

## 5. CI: analyze-only sebagai gerbang, build terpisah

```bash
gh workflow run flutter.yml --ref <branch> -f analyze_only=true   # analyze + test
gh workflow run flutter.yml --ref <branch> -f analyze_only=false -f demo=false
```
- **Workflow harus ada di branch default** supaya bisa di-dispatch. Workflow
  yang hanya ada di branch fitur = "workflow not found" (sudah kejadian 1x).
- Jangan lupa `git push` sebelum dispatch; kalau tidak, CI jalan di kode lama
  dan errornya yang muncul =error yang sudah diperbaiki (terbukti 1x).
- `analyze` + `test` blocking, baru build APK. APK = 1 file universal.

## 6. `android/` di-generate di CI + patch skrip

`flutter create --org <org> --project-name <nama> /tmp/scaffold` lalu
`cp -r /tmp/scaffold/android .` dan patch idempoten.

Template Flutter terbaru (3.4x) BERUBAH:
- `versionCode = flutter.versionCode` (baca pubspec, bukan angka hardcoded);
- `buildTypes.release { signingConfig = signingConfigs.getByName("debug") }`.

Patcher wajib: idempoten (jalan 2x = hasil sama), pakai regex yang longgar,
selalu verifikasi ulang setelah patch, dan **diuji lokal terhadap mock file**
(template diambil dari `raw.githubusercontent.com/flutter/flutter/stable/
packages/flutter_tools/templates/app/android-kotlin.tmpl/...`) sebelum CI.

## 7. Jebakan Dart/Flutter yang_found lewat analyze (semua nyata)

| Gejala | Akar | Perbaikan |
|---|---|---|
| Semua tool/agent | `late final` di-assign 2x | pakai satu ekspresi |
| `cancelToken` unknown | itu argumen `dio.post()`, bukan `Options` | pindahkan |
| `c.brightness` unknown | bukan member BuildContext | `Theme.of(c).brightness` |
| `CupertinoPageTransitionsBuilder` | perlu import cupertino.dart | tambah import |
| `removePrefix` unknown | tidak selalu ada | `substring` |
| `const` + field non-final | Percakapan punya field mutable | hapus `const` |
| `ConsumerState` undefined | lupa import riverpod di widget | tambah import |
| `FutureProvider` vs `.family` | tipe generik berbeda | `FutureProviderFamily<..>` |
| `library;` setelah import | directive harus pertama | hapus |
| `ThemeExtension<Object?>` | bound `T extends ThemeExtension<T>` | `ThemeExtension<AppTokens>` |
| `abstract final class` + static | simbol tak terlihat |top-level `final` untuk objek global |

## 8. Pen|area hidden problems
- Tes unit pure-Dart (`flutter test`) menangkap bug yang `analyze` tak lihat.
  Kalkulator: tulis transliterasi Python dulu untuk cek 24 kasus sebelum
  push → hemat 2 putaran CI.
- APK Flutter pertama di repo = `flutter create` menulis 35 file; pastikan
  `gitignore` sudah menutup `android/` SEBELUM commit pertama.
- Untuk update di atas APK lama: package id + keystore HARUS sama.

## 9. JEBRAKAN BUNDLE ASSET FLUTTER (bukti 17 Okt 2026, 3 build hilang)

Entri direktori `- assets/skills/` di pubspec **TIDAI direkursi** oleh
flutter_tools 3.47: hanya berkas di level atas yang ikut. Gejalanya SENYAP:
build hijau, APK justru **lebih kecil 75 KB**, dan 2.732 file tidak ada di
dalam APK. Tidak ada error sama sekali.

Cara memastikan (tambahkan ke workflow sebagai penjaga):
```yaml
- run: |
    flutter build bundle --release >/dev/null 2>&1 || true
    ADAKAH=$(find assets/skills -type f | wc -l)
    JADI=$(find build/flutter_assets/assets/skills -type f 2>/dev/null | wc -l)
    [ "$JADI" -lt $(( ADAKAH * 9 / 10 )) ] && { echo "GAGAL: aset tidak lengkap"; exit 1; }
```
Solusi yang dipakai: **deklarasikan per-file** (2.732 baris di pubspec,
dihasilkan otomatis oleh skrip sinkron, di antara marker
`    # MULAI-SKILL` / `    # SELESAI-SKILL`) + penjaga "tepat satu pasang
marker". Dua jebakan kedua saat menulis blok YAML itu:
1. marker harus berawalan `    # ` - tanpa itu YAML error
   ("Error on line N: Expected ':'");
2. skrip yang gagal menyisipkan blok kedua kali -> blok DUPLIKAT di pubspec,
   build hijau tapi YAML rusak. Penjaga: `count(marker) == 1`.

Pelajaran umum: **volume APK yang tidak sesuai harapan itu gejalanya, bukan
kebetulan.** APK yang lebih kecil = ada yang hilang; cek isinya sebelum
bilang selesai.

## 10. "SEMUA MODEL GAGAL" = katalog model usang (kasus nyata 17 Okt 2026)

User: *"semua model AI di APK tidak merespon apapun"*. Akar masalahnya BUKAN
kunci API dan BUKAN jaringan - tapi **model default menunjuk model yang sudah
pindah ke paket berbayar**.

- Groq lewat `docs/models`: `llama-3.3-70b-versatile` dan
  `llama-3.1-8b-instant` sekarang **Enterprise (ContactSales)**.
- Kunci gratis ditolak -> tiap request gagal -> user lihat "semua model gagal",
  padahal beberapa model lain gratis dan hidup.

Cek yang harus dilakukan sebelum menebak:
1. Baca halaman model resmi provider (`console.groq.com/docs/models`) -
   cari kolom "Enterprise" / "ContactSales" / harga.
2. **Jangan pernah hardcode ID model sebagai default.** Ambil katalog live
   dari `/v1/models` dan tandai model berbayar.
3. Auto-picker WAJIB menyaring model berbayar, bukan cuma "punya tool calling".
4. Auto-fallback: 404/403/429 -> coba kandidat berikutnya dalam satu langkah,
   dan tulis catatan jujur di jawaban ("Model sebelumnya ditolak provider;
   diganti ke X").

Perkakas yang harus ada di app apa pun yang pakai LLM berbayar:
- **klasifikasi galat terstruktur** (401/403/404/429/5xx) supaya fallback
  bisa membedakan "ganti model" vs "ganti kunci" vs "tunggu";
- **halaman Koneksi**: status kunci + tombol "Tes model" (request nyata,
  tampilkan ms + jawaban) + segarkan katalog;
- **kunci API boleh diisi user di aplikasi** (saved lokal, menimpa kunci yang
  dibundel) supaya kunci kadaluarsa tidak butuh build ulang.

Dan dua kelas bug baru yang menambah 2 siklus build (checker sekarang
menangkap keduanya dalam <1 detik):
- **UNDEF-PRIVATE**: rename method privat, call site tertinggal
  (`_kunci` -> `kunci`). Dicek dengan scan nama yang dipanggil + deklarasi.
  ⚠️ Panggil privat sering ada DI DALAM string interpolasi - jangan strip
  string untuk cek ini (cuma buang komentar).
- **SCOPE**: static member kelas A dipakai di kelas B tanpa prefiks
  (`GalatKosong` vs `KodeGalat.GalatKosong`). Nama konstanta Dart bisa
  kapital awal, jadi pola regex WAJIB menerima `[A-Za-z_$]`.

## 11. DIJ: `ResponseType.stream` => `response.data` itu ResponseBody (BUG 17 Okt 2026)

Gejala di HP user: **"type 'ResponseBody' is not a subtype of type
'Stream<List<int>>'"** - SETIEP jawaban gagal, `flutter analyze` hijau, test
lama juga hijau. Salah satu baris saja yang bikin seluruh app mati.

```dart
// SALAH (runtime error, tidak ketahuan analyze)
final s = (respons.data as Stream<List<int>>).transform(utf8.decoder);

// BENAR
final ResponseBody? body =
    respons.data is ResponseBody ? respons.data as ResponseBody : null;
final Stream<List<int>> byte =
    body.stream.map<List<int>>((Uint8List b) => b);   // LEBARKAN DULU
final Stream<String> baris =
    byte.transform(utf8.decoder).transform(const LineSplitter());
```
Tiga jebakan sekaligus di sini:
1. `.data` bukan Stream, tapi `ResponseBody`.
2. `ResponseBody.stream` bertipe `Stream<Uint8List>`, sedangkan
   `utf8.decoder` hanya mau `StreamTransformer<List<int>, String>` (kontravarian)
   -> harus `.map<List<int>>((b) => b)` dulu.
3. **Dio 5.11 tidak punya `ResponseBody.bytesToString()`** - pakai
   `await data.stream.map<List<int>>((b) => b).transform(utf8.decoder).join()`.

Body error juga `ResponseBody` (bukan JSON string) ->`_isiGalat` diam-diam
gagal parse. Perbaikannya: baca `e.response.data.stream` lalu jalankan lagi
pemetaan galat dengan teks yang sudah dibaca.

### Uji integrasi yang WAJIB ada (kelas ini tak bisa ditangkap analyze)
```dart
class _StubAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(sseDummy, 200,
          headers: {Headers.contentTypeHeader: ['text/event-stream']});
  @override
  void close({bool force = false}) {}
}
// lalu: Dio()..httpClientAdapter = _StubAdapter(...);
```
Signatur `fetch` persis begini di Dio 5.11 (lihat `lib/src/adapter.dart`).
Dengan test ini, akurasi akumulasi tool_call, `[DONE]`, dan klasifikasi galat
404/403/401 ikut terverifikasi - bukan cuma "build hijau".

Checker lokal punya aturan `DIO-STREAM` untuk menangkap pola cast
`.data as Stream<...>` (diuji dengan fault injection).
