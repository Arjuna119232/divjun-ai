# DIVJUN AI (Flutter) — AGENTS.md

## Apa ini
Rebuild total aplikasi DIVJUN AI dari **WebView (HTML/JS + Kotlin)** menjadi
**Flutter native + Agent AI**. Branch build = `flutter-native` (JANGAN push ke
`main`; `main` masih berisi app WebView lama + pipeline Gradle-nya).

- Lokasi kerja: `$HOME/divjun-flutter` (bukan `/storage` — FUSE + git lambat)
- Package: `com.divjun.ai` · versi `3.2.0+54` · minSdk 24 · targetSdk 36
- Sertifikat rilis SHA-256 `c3923241b05990b2575e215090f037e09be5d1da5cc715b1ef11ded4cb18feb7`
  (CN=DIVJUN AI). APK dengan sertifikat lain TIDAK bisa update di atas v2.8.0.
- Status "seukuran Claude AI": tahap 1 (sidebar + kolom 820) ✅ v2.4.0+42 ·
  tahap 2 (blok "Berpikir" collapsible) ✅ v2.5.0+43 · tahap 3 artifacts ✅ v3.2.0+54
- UI v3.0.1: **overlap splash diperbaiki** — lambang + nama app kini SATU
  `Column` ber-center; sebelumnya dua anak `Center` terpisah di dalam `Stack`
  sehingga saling tumpang. Ditambah kredit "FROM : 0XMAHEN" di atas progress
  bar. Onboarding: judul 29→26sp, **grid latar dihapus** (garisnya bikin teks
  ramai), halaman 3 diganti dari "Pustaka skill" → "Ingat detail" (memori)
  karena UI skill disembunyikan dari user.
- **UI skill & koneksi AI disembunyikan dari user** (permintaan user, backend
  tetap utuh): entri `Pustaka skill` + `Koneksi AI` di `sidebar_obrolan.dart`,
  menu `Keahlian Agen` di `layar_chat.dart`, baris `Keahlian Agen` DAN
  `Pengaturan Lanjut` di `layar_setelan.dart` DIHAPUS. Rute `/skills`,
  `/koneksi`, `/setelan/lanjutan` sengaja tetap terdaftar di router supaya
  file tidak jadi DEAD-FILE = hanya bisa dibuka via deep link (tidak ada lagi
  entry di UI biasa). `_IlustrasiSkill` → `_IlustrasiMemori`, enum `kartuSkill`
  → `kartuMemori`.
  ⚠️ Konsekuensi yang diterima user: tanpa "Pengaturan Lanjut" user tidak bisa
  memasang API key manual — app tetap jalan lewat penyedia tanpa kunci
  (OVHcloud / Pollinations), jadi tidak ada fitur yang benar-benar hilang.
- **Login dummy v3.0.2** (`lib/features/auth/presentation/layar_login.dart`):
  alur jadi `/splash → /onboarding → /login → /chat`. Rute `/login` memakai
  `AppTransisi.portalPage` (masuk seperti portal dari onboarding).
  `kunciLogin = 'login_v1'` ditulis SEBELUM `context.go('/chat')`; dibaca di
  `layar_splash.dart` (bukan di dalam LayarLogin) supaya penanda lama tidak
  bergantung pada layar yang sedang dibuka. Isi: merek (kotak D + nama app),
  ilustrasi "napas" (`CustomPainter` cincin progres + inti berdenyut),
  headline **Playfair Display 30sp w600**, tombol "Lanjutkan dengan Google"
  (lambang G digambar dari 4 busur `drawArc` + batang biru — TANPA
  `flutter_svg`), pembatas ATAU, kolom email, tombol "Lanjut" muncul hanya bila
  email lolos regex `^[^@\s]+@[^@\s]+\.[^@\s]{2,}$`, footer legal.
  ⚠️ Validasi email sengaja longgar (1 `@` + 1 titik) — regex ketat menolak
  email sah seperti `nama+label@domain.co.id`.
  ⚠️ Sudut busur G (0 = kanan, bertambah searah jarum jam): hijau 21+80 ·
  kuning 100+91 · merah 190+111 · biru 299+59, tiap busur diberi tumpang 1°
  karena `StrokeCap.butt` menyisakan garis rambut di sambungan.
- **Font Playfair Display = di-bundle ke APK** (bukan `google_fonts`, supaya
  tidak butuh jaringan): `assets/fonts/PlayfairDisplay-Regular.ttf` (400) +
  `SemiBold.ttf` (600), family `PlayfairDisplay`. Dua instance statis itu
  dibuat dari variable font memakai fontTools (dokumen: `docs/FONTS.md`).
  Dipakai HANYA untuk headline halaman Login.
- Intro: splash 4 detik (`AppConfig.durasiSplashMs`) + 4 detik PER HALAMAN
  onboarding (`durasiHalamanOnboardingMs`, total 12 detik), auto-lanjut dengan
  garis countdown 2 px. Transisi splash->onboarding->chat = zoom-through dua
  arah + ledakan cahaya (`lib/core/theme/app_transitions.dart`).
- **Manajemen riwayat chat v3.0.2** (`permalink`-style punya Claude):
  - `Percakapan.disematkan` (json `'disematkan'`); `kontrol_chat.dart` tambah
    `sematkan(id,nilai)` & `gantiNama(id,judul)` — **keduanya TIDAK mengubah
    `diperbarui`** supaya urutan "Terbaru" stabil saat hanya menyematkan/renama.
  - Sidebar: grup **"Disematkan"** di atas, lalu grup waktu (Hari ini / 7 hari
    / bulan ini / lebih lama); ikon pin (`LucideIcons.pin`) + `moreVertical`
    + long-press → menu bottom sheet: Bagikan (`SharePlus.instance.share`),
    Ganti nama (`AlertDialog`+`TextField` terisi judul kini), Sematkan/Lepas,
    Tambahkan ke proyek (abu-abu, nonaktif), Hapus (merah).
  - `layar_chat.dart`: actions AppBar (history + menu opsi) dibungkus
    `if (state.daftar.isNotEmpty)` → sembunyi saat belum ada percakapan.
  - `gelembung_pesan.dart`: di bawah bubble jawaban AI **hanya saat status
    `selesai`** muncul `_AksiPesan` — Row ikon copy/share/play(TTS dummy)/
    thumbsUp/thumbsDown/refreshCw + disclaimer "DIVJUN AI adalah AI dan dapat
    melakukan kesalahan." (teks di LUAR bubble = metadata, bukan isi pesan).
    State `_nilai` 0/1/2 untuk umpan balik jempol.
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

## Pusat Legal + robot (v3.1.0, 19 Okt 2026)
- **Pusat Legal** (`lib/features/legal/`): `data/legal_service.dart`
  (3 dokumen + `rootBundle.loadString`), `presentation/halaman_markdown.dart`
  (`HalamanMarkdown` reuse `TampilanMarkdown` + `_Gagal` retry),
  `presentation/pusat_legal_screen.dart` (`PusatLegalScreen`).
  Teks hukum di `assets/legal/{terms,usage,privacy}.md` — **jangan** hardcode di UI.
  Rute `/legal` + `/legal/dokumen/:id`; ID tak dikenal fallback ke daftar.
- **Gerbang persetujuan login**: `kunciPersetujuan = 'persetujuan_v1'` dibaca
  di `initState` (tanpa `setState`) lalu ditulis tiap centang berubah.
  `TapGestureRecognizer` dibuat/di-dispose di `_LayarLoginState` dan
  **diteruskan** ke `_Persetujuan` — kalau dibuat di dalam `build`, tiap ketikan
  huruf menambah listener yang tak pernah dibuang. Tombol ditekan sebelum centang
  → Snackbar, **bukan** `return` diam (diam = bug "tombol mati").
- **Splash** (`_keBeranda`): `kunciLogin` dicek **DULUAN**, baru `kunciOnboarding`.
  Urutan dibalik = user yang sudah pernah login melihat 3 halaman perkenalan
  lagi tiap app dibuka.
- **Robot**: `lib/shared/widgets/aset_robot.dart` = `AsetRobot` (Lottie
  `assets/animations/robot_*.json`) + `RobotGambar` (CustomPainter cadangan).
  `lottie: ^3.2.0` **dikunci** — 3.6.1 butuh Dart `^3.11`, proyek ini `>=3.4.0`.
  Berkas animasi belum ada (user belum mengunduh) → `errorBuilder` lottie 3.2.0
  (`ImageErrorWidgetBuilder`) menurunkan ke gambar kode, jadi layar tidak pernah
  error merah. Pratinjau: `design/preview_robot.py` → `design/pratinjau-robot.png`.
- **Jebakan painter yang ketahuan hanya dari render** (lihat
  `design/pratinjau-robot.png`):
  1. **Lengan digambar SESUDAH badan.** Kalau sebelum, lengan tertutup badan →
     yang terlihat hanya 2 tonjolan.
  2. **Rotasi canvas Flutter**: titik ujung lengan = `(-L*sin(a), L*cos(a))`.
     Pratinjau Pillow sempat pakai `+sin(a)` → lengan terbalik dan review
     visual jadi salah Targets. Preview harus memakai matematika yang sama.
  3. **Kepala tanpa leher = kepala melayang**; sisipkan leher rect bridging.
  4. Semua dekorasi (gelembung/kilau/centang) harus di dalam kotak ±48 dari
     pusat, kalau tidak terpotong `SizedBox`.
  5. `num.clamp()` mengembalikan `num` → **compile error** kalau tromol `double`.
     Untuk tinggi area pakai `if (h < a) return a; if (h > b) return b; return h;`
- `widgets/ilustrasi_onboarding.dart` **dihapus** (digantikan robot). Kalau file
  tak terpakai lagi, `check_source.py` melaporkannya sebagai DEAD-FILE.
## Layout overflow + keyboard overlap (19 Okt 2026, commit 3f7b26f)
Bug yang dilaporkan user di 2 layar, keduanya sudah diperbaiki dan diverifikasi
`flutter analyze` 0 issue + 61 test hijau (CI run `39190236346`).

**Onboarding — konten terpotong di bawah layar.**
- Akar: `_tinggiRobot` pakai rasio 0.30/0.42 dengan batas bawah **120 dp**, dan
  jarak antar blok `lg` (16 dp). Di HP 393x873 dp, area robot halaman 3 jadi
  166 dp sehingga total isi halaman (robot + 3 kartu + judul + subjudul + chip)
  **melebihi** tinggi viewport → chip.poin terpotong. Chip itu yang dikeluhkan
  user, dan auto-lanjut 4 detik membuatnya praktis tak terjangkau.
- `_tinggiRobot` sekarang 0.26/0.34, batas bawah 92/104, atas 150/200.
  Jarak: `md` (12) untuk sebelum kartu + sebelum judul, `xs` (4) setelah judul,
  subjudul 13.5/1.5. Spasi `AppSpacing.sm` **setiap** kartu (termasuk kartu
  terakhir) diganti jadi spasi **antar** kartu saja (`if (i < len - 1)`).
  Terukur: halaman 3 = 557 dp dari 639 dp tersedia → **muat tanpa scroll**.
- ⛔ **Bug laten yang ikut ketemu:** `ConstrainedBox(minHeight: batas.maxHeight - 24)`
  dengan `EdgeInsets` 16+16. Kalau `maxHeight < 24`, hasilnya **negatif** dan
  `BoxConstraints` menolak nilai negatif → assertion crash. Sekarang
  `math.max(0, batas.maxHeight - atasBawah * 2)`, dan angka pengurang **harus
  sama persis** dengan padding yang dipakai di bawah (dulu 24 vs 32 → halaman
  selalu lebih tinggi 8 dp dari viewport, jadi selalu ada scroll aneh).
- Struktur utama jadi `LayoutBuilder` + dua mode, ambang `_ambangRapat = 600`:
  ≥600 dp → `Column` + `Expanded` (tombol & titik **menempel di bawah**);
  <600 dp → satu `SingleChildScrollView` (tidak ada yang terpotong).
- Footer: `SafeArea(bottom: false)` di layar, padding bawah
  `AppSpacing.lg + MediaQuery.paddingOf(context).bottom` di `_BagianBawah`,
  jadi jarak tombol ke navigasi 3-tombol vs gesture ikut benar. Ditambah
  gradasian `0x000B0B10 → 0xFF0B0B10` (warna sama dengan Scaffold) supaya
  konten yang digeser ke bawah terbaca "masuk ke tombol", bukan terpotong.

**Login — keyboard menutupi tombol "Lanjut" + teks legal dobel.**
- Teks "Dengan melanjutkan, Anda menyetujui ..." di paling bawah **DIHAPUS**
  (persetujuan sudah diwakili checkbox + tautan).
- ⛔ **`viewInsets.bottom` TIDAK boleh ditambahkan sebagai padding di dalam
  Scaffold yang `resizeToAvoidBottomInset: true`** — Scaffold sudah memotong
  tinggi body sebesar keyboard, jadi menambahnya lagi = **ruang kosong mati
  setinggi keyboard** (≈300 dp) di bawah tombol. Yang benar:
  `resizeToAvoidBottomInset: true` + `Align(alignment: topCenter)` saat
  keyboard terbuka (bukan `Center`) + `Scrollable.ensureVisible` untuk kolom
  email dan tombol.
- `AnimatedSize` tombol "Lanjut" punya `onEnd` → setelah animasi selesai, tombol
  digeser ke layar kalau keyboard sedang menutupinya. Ini yang menutup celah
  "tombol muncul tapi tidak terlihat".
- `TextField.scrollPadding: EdgeInsets.only(bottom: 120)` supaya `EditableText`
  ikut menyisakan ruang saat bring-into-view.
- `FocusNode` didaftarkan lewat `initState` (`_fokus.addListener`), **bukan**
  cascade di deklarasi field — field initializer tidak boleh menyentuh
  instance method.
- Tinggi robot diturunkan dari `MediaQuery.sizeOf(context).shortestSide * 0.40`
  (batas 140..176) dan **104 dp saat keyboard terbuka** (`_tinggiRobot`).

**Pola yang dipakai (juga untuk layar lain):** bagian mahal secara vertikal
(ilustrasi) direduksi saat keyboard aktif; alignment pindah `center → topCenter`;
elemen yang bisauttuh berubahUkuran (tombol) memanggil `ensureVisible` di
`onEnd` animasinya. Jangan pernah andalkan `Center` + `SingleChildScrollView`
sendirian untuk halaman yangkeyboard-nya bisa muncul.

## Artifak / artifacts (v3.2.0+54, tahap 3 "seukuran Claude")
Blok kode di jawaban AI kini punya kartu sendiri + layar penuh pratinjau.
- `lib/features/artifacts/domain/artifak.dart` — `PemecahJawaban.pecah()`
  memisah markdown jadi `BagianTeks` (teks / kode). Pagar ``` dan `~~~`,
  pagar penutup minimal sepanjang pembuka, info string diambil kata pertama,
  CRLF dinormalkan, blok **terbuka** saat streaming ditandai `terbuka: true`
  (kartu tidak boleh dibuka sebelum jawaban selesai).
  `Artifak.dari()` menentukan `JenisArtifak` (html/svg/markdown/kode),
  `judul` (dari `<title>` atau `'Kode SQL · 3 baris'`), `bisaPratinjau`,
  dan `dokumenHtml()` (dokumen utuh dipakai apa adanya; potongan dibungkus
  `<!doctype html>` + `background:#ffffff`; SVG dibungkus `.kanvas`).
- `presentation/isi_jawaban.dart` — dipakai bubble chat. Fast-path: satu
  bagian non-kode → langsung `TampilanMarkdown` (jalur streaming tetap ringan).
- `presentation/kartu_artifak.dart` + `presentation/halaman_artifak.dart` —
  kartu di bubble; layar `/artifak` (extra: `Artifak`) dengan tab
  Pratinjau/Kode, Salin, Bagikan. Markdown dirender `TampilanMarkdown`,
  HTML/SVG lewat `webview_flutter`.
- ⚠️ `webview_flutter` **dikunci `^4.13.0`**: 4.13.1 butuh Flutter ≥3.32,
  4.14.x butuh Dart ^3.10 (proyek `^3.9.0`). Jangan naikkan tanpa cek.
- ⚠️ `WebViewController` di `_PratinjauWeb` **bukan `late final`** — tombol
  "Coba lagi" membuat controller baru, `late final` = LateInitializationError
  justru di jalur pemulihan.
- ⚠️ `WebResourceError.isForMainFrame` dicek `!= true` (bukan `!`), supaya
  tetap kompilasi baik field-nya `bool` maupun `bool?`.
- ⚠️ `AppColors.kertas` (`#FFFFFF`) = latar dokumen pratinjau, **selalu terang**
  walau app mode gelap; jangan ganti ke `cs.surface`.
- Rute `/artifak` fallback `Artifak.kosong` (judul 'Artifak', body `_Kosong`)
  supaya deep-link / proses mati tidak crash.
- Test: `test/artifak_test.dart` (parser + judul + dokumenHtml).
