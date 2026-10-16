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