# DIVJUN AI (Flutter) — AGENTS.md

## Apa ini
Rebuild total aplikasi DIVJUN AI dari **WebView (HTML/JS + Kotlin)** menjadi
**Flutter native + Agent AI**. Branch build = `flutter-native` (JANGAN push ke
`main`; `main` masih berisi app WebView lama + pipeline Gradle-nya).

- Lokasi kerja: `$HOME/divjun-flutter` (bukan `/storage` — FUSE + git lambat)
- Package: `com.divjun.ai` · versi `2.5.0+43` · minSdk 24 · targetSdk 35
- Status "seukuran Claude AI": tahap 1 (sidebar + kolom 820) ✅ v2.4.0+42 ·
  tahap 2 (blok "Berpikir" collapsible) ✅ v2.5.0+43 · tahap 3 artifacts ❌
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

## Jebakan yang sudah kejadian (jangan ulangi)
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
- **Reasoning tidak boleh jadi fallback dari teks.** Field penalaran beda per
  provider (`delta.reasoning` OVH/Pollinations, `delta.reasoning_content`
  Groq, `parts[].thought` Gemini). Detail + pola UI ada di skill
  `flutter-app-seukuran-claude`.
- `_buffer.remove(id)` SEBELUM membaca sisa buffer = seluruh teks yang sudah
  streaming hilang saat stream gagal. Ambil sisanya dulu, baru hapus.