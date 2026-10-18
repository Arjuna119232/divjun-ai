# DIVJUN AI (Flutter) — AGENTS.md

## Apa ini
Rebuild total aplikasi DIVJUN AI dari **WebView (HTML/JS + Kotlin)** menjadi
**Flutter native + Agent AI**. Branch build = `flutter-native` (JANGAN push ke
`main`; `main` masih berisi app WebView lama + pipeline Gradle-nya).

- Lokasi kerja: `$HOME/divjun-flutter` (bukan `/storage` — FUSE + git lambat)
- Package: `com.divjun.ai` · versi `2.8.1+47` · minSdk 24 · targetSdk 36
- Sertifikat rilis SHA-256 `c3923241b05990b2575e215090f037e09be5d1da5cc715b1ef11ded4cb18feb7`
  (CN=DIVJUN AI). APK dengan sertifikat lain TIDAK bisa update di atas v2.8.0.
- Status "seukuran Claude AI": tahap 1 (sidebar + kolom 820) ✅ v2.4.0+42 ·
  tahap 2 (blok "Berpikir" collapsible) ✅ v2.5.0+43 · tahap 3 artifacts ❌
- Intro: splash 4 detik (`AppConfig.durasiSplashMs`) + 4 detik PER HALAMAN
  onboarding (`durasiHalamanOnboardingMs`, total 12 detik), auto-lanjut dengan
  garis countdown 2 px. Transisi splash->onboarding->chat = zoom-through dua
  arah + ledakan cahaya (`lib/core/theme/app_transitions.dart`).
- Keystore: **sama** dengan app lama (`KEYSTORE_BASE64` di repo secrets) →
  APK baru bisa update di atas APK lama, jangan ganti keystore.
- Audit brief vs kenyataan: `docs/REBUILD-AUDIT.md` (agent.js tidak pernah ada;
  bagian agent dibangun dari nol).

## Arsitektur (baca `docs/ARSIPTEKTUR.md` untuk diagram alur)
```
lib/
  core/        theme (token), router (go_router), constants, utils, providers.dart
  domain/      entities: Pesan/Percakapan, SetelanApp, EntriMemori, ModelAi
  data/        datasources (Dio SSE, penyimpanan), repositories, model wire
  services/    streaming_service, memory_service, tool_executor
  features/
    agent/     tools/ (5 alat), loop/agent_loop.dart (plan-act-observe)
    chat/      presentation (UI), data/kontrol_chat.dart (controller)
    settings/  presentation/layar_setelan.dart (+ helper dialog & pemilih model)
    memory/    presentation/layar_memori.dart
    home/      presentation/layar_splash.dart
```
Semua provider Riverpod terkumpul di `lib/core/providers.dart`.

## Verifikasi (WAJIB, karena tidak ada Flutter di HP)
```bash
python3 tool/check_source.py             # <1 detik, blocking di CI
python3 tool/setup_android.py --verify-only
gh workflow run flutter.yml --ref flutter-native -f analyze_only=true   # analyze + test
gh workflow run flutter.yml --ref flutter-native -f analyze_only=false -f demo=false
```
`flutter analyze` + `flutter test` = satu-satunya bukti kompilasi nyata.
`tool/check_source.py` catching 9 kelas bug: DEAD-FILE, IMPORT-EXISTS,
MISSING-IMPORT, UNUSED-IMPORT, EXT-HILANG, ICON-IMPORT, BRACE, NON-LATIN, ASSET.
Semua sudah diuji dengan fault injection.

## Aturan yang tidak boleh dilanggar
1. Tidak ada `Color(0x...)` di luar `lib/core/theme/app_colors.dart`.
2. Tidak ada ikon Material — pakai `LucideIcons` (package lucide_icons_flutter).
3. API key hanya lewat `--dart-define`; tidak pernah ada di repo.
4. Tool web wajib lewat `UrlGuard` (blokir alamat privat + cek DNS).
5. `android/`, `ios/` TIDAK pernah di-commit → di-generate `flutter create` di CI
   lalu di-patch oleh `tool/setup_android.py`.
6. Setiap file baru: `python3 tool/check_source.py` harus hijau sebelum commit.

## Aturan operasi saat update (dari user, 18 Okt 2026)
Berlaku untuk setiap update dan setiap pencarian saat mengerjakan DIVJUN AI.

**1. Hemat tool call.** Ada batas langkah. Jangan habiskan jatah untuk
   percobaan sia-sia. Evaluasi hasil tiap tool; kalau sebuah tool gagal,
   JANGAN langsung mengulangnya dengan cara yang sama.

**2. Kegagalan URL = berhenti, jangan ulangi.**
   - `buka_url` balas HTTP 404 / URL tidak bisa diakses -> jangan buka lagi.
   - URL dari hasil pencarian yang tampak tidak valid -> jangan dipaksakan.
   - Toleransi maksimal **2 percobaan**, lalu **BERHENTI** searching web.
   - Alihkan ke pengetahuan internal, atau jawab dari cuplikan (snippet)
     hasil pencarian. Snippet umumnya sudah memuat nama, alamat, harga, rating
     yang cukup untuk menjawab.

**3. Exit strategy.** Kalau jatah tool hampir habis (sekitar langkah
   4-5), berhenti searching dan susun jawaban akhir sendiri. Jangan biarkan
   sistem memutus secara paksa.

**4. Jujur saat gagal.** Kalau semua akses URL gagal, katakan terus terang.
   Diberi jawaban dari cuplikan/pengetahuan internal - **jangan pernah**
   jawaban kosong atau menempel error mentah ke user.

**5. Fallback model.** Kalau model ditolak provider lalu dialihkan, ABAIKAN
   pesan error itu dan LANJUT dari titik terakhir. Jangan ulangi percakapan
   dari awal.

**6. Pencarian harus spesifik + konteks lokal.** Untuk rekomendasi tempat,
   pakai kata kunci spesifik ("rekomendasi cafe di Cipete Jakarta Selatan"),
   bukan "tempat ngopi di Cipete".

**7. Format jawaban ke user.** Jangan tampilkan URL mentah yang panjang.
   Pakai daftar/tabel rapi: nama tempat, deskripsi singkat, dan kisaran harga bila ada.

**8. Proaktif kalau data kurang.** Permintaan terlalu umum -> berikan 3-5
   rekomendasi awal, lalu ajukan pertanyaan pempersempit (WFC? nongkrong
   malam? outdoor?). Kalau jawaban sudah valid, jangan bertanya balik.

**9. Safety & harga.** Jangan rekomendasikan tempat/tindakan yang
   melanggar hukum. Untuk harga/transaksi, selalu ingatkan user memverifikasi
   langsung ke pihak terkait karena info internet bisa kedaluwarsa.

## Jebakan yang sudah kejadian (jangan ulangi)
- **`-f demo=true` menghasilkan APK bertanda tangan DEBUG (`CN=Android Debug`)**,
  karena step `Tulis key.properties` di-skip `if: !inputs.demo` sehingga
  Gradle jatuh ke debug signing. Build tetap hijau, analyze tetap 0 issue,
  test tetap lulus - tapi APK-nya **tidak bisa update di atas rilis lama**
(INSTALL_FAILED_UPDATE_INCOMPATIBLE) dan memaksa uninstall = history chat
   hilang. Untuk rilis ke user WAJIB `-f demo=false`. Sebelum menyerahkan APK
   selalu cek:
   `apksigner verify --print-certs <apk> | grep 'certificate DN'`
   harus `CN=DIVJUN AI`, bukan `CN=Android Debug`.
- **Versi app TAK boleh ditulis tangan.** `AppConfig.versi` pernah macet di
  "2.0.0" padahal APK sudah 2.8.x, dan "build" diisi `github.run_number`
  (nomor workflow GitHub = tidak berguna buat user). Sekarang CI membaca
  versi dari `pubspec.yaml` (step `id: appver`) lalu inject
  `--dart-define=APP_VERSION=`. Satu-satunya sumber = `AppEnv.appVersion`.
- **`dart:core` MENGEKSPOR `Future` dan `Stream` dari `dart:async`**
  (sdk/lib/core/core.dart: `export "dart:async" show Future, FutureExtensions,
  Stream;`). Jadi `async`/`await`/`Future`/`Stream` TIDAK butuh import
  `dart:async`. Hanya `Timer`, `Completer`, `StreamController`,
  `StreamSubscription`, `unawaited`, dan extension method seperti
  `asBroadcastStream()` yang benar-benar butuh import itu.
- `flutter create` di template terbaru (3.4x) **tidak** menulis `versionCode`/
  `versionName` angka di `build.gradle.kts` (baca dari pubspec) → patcher harus
  adaptable, bukan `versionCode = \d+` polos.
- `late final` yang di-assign dua kali = runtime error "already initialized"
  (kalkulator sempat 100% null karena ini).
- `Options(cancelToken:)` tidak ada → `cancelToken` adalah argumen `dio.post()`.
- `String.removePrefix` tidak selalu tersedia di versi SDK ini → pakai `substring`.
- `flutter_riverpod` wajib di-import di SEMUA widget yang `ref.watch`/`ref.read`.
- `abstract final class` + static member pernah bikin simbol tak terlihat
  (router sekarang top-level `final GoRouter appRouter`).
- Lupa `git push` setelah commit = CI dijalankan di kode lama (terbukti 1x).
- **Gap `check_source.py` yang SUDAH TAHU dan belum ditutup (v3.0.0):**
  cek MISSING-IMPORT hanya mengambil identifier yang mulai huruf KAPITAL
  (`[A-Z][A-Za-z0-9_]{2,}`). Top-level provider huruf kecil seperti
  `chatProvider` / `setelanProvider` **tidak pernah dicek sama sekali**, jadi
  import `kontrol_chat.dart` yang hilang lolos 0 masalah. Percobaan
  memperluasnya ke huruf kecil menghasilkan **52 false positive** (keyword
  `return`/`switch`, method framework `setState`/`showDialog`, getter
  `label`/`aktif`) karena filter `n in semua_nama` ikut menelan keyword itu.
  Lösung yang benar butuh daftar simbol proyek yang terpisah dari
  keyword - belum dikerjakan. SAMBIL itu ada, `flutter analyze` di CI tetap
  satu-satunya oracle untuk kelas bug ini.
  Bolshep: **simbol SDK** (`HapticFeedback`, `showDialog`, `TextField`)
  juga di luar cakupan checker - hanya simbol proyek yang dicek.
- **Reasoning tidak boleh jadi fallback dari teks.** Field penalaran beda per
  provider (`delta.reasoning` OVH/Pollinations, `delta.reasoning_content`
  Groq, `parts[].thought` Gemini). Detail + pola UI ada di skill
  `flutter-app-seukuran-claude`.
- `_buffer.remove(id)` SEBELUM membaca sisa buffer = seluruh teks yang sudah
  streaming hilang saat stream gagal. Ambil sisanya dulu, baru hapus.