import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/providers.dart';
// app_theme.dart mengekspor app_colors, app_typography, app_motion — cukup satu
// import ini untuk ketiga token tersebut.
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/aset_robot.dart';

/// Kunci penyimpanan: halaman login hanya muncul SEKALI.
///
/// Dibaca di `layar_splash.dart`, bukan di dalam LayarLogin, supaya keputusan
/// "sudah pernah masuk" tidak bergantung pada layar yang sedang dibuka.
const String kunciLogin = 'login_v1';

/// Kunci penyimpanan: status centang persetujuan Syarat & Ketentuan.
///
/// Disimpan supaya user yang sudah pernah menyetujui tidak perlu mencentang
/// ulang setiap kali layar login dibuka (mis. setelah keluar akun).
const String kunciPersetujuan = 'persetujuan_v1';

/// Halaman masuk (dummy) — tampil sekali setelah onboarding.
///
/// Belum ada autentikasi sungguhan: [kunciLogin] hanya menandai bahwa user
/// sudah melewati layar ini. Struktur formnya sudah final, jadi penggantian ke
/// auth asli (Supabase/Google) hanya perlu mengisi isi [_selesai].
class LayarLogin extends ConsumerStatefulWidget {
  const LayarLogin({super.key});

  @override
  ConsumerState<LayarLogin> createState() => _LayarLoginState();
}

class _LayarLoginState extends ConsumerState<LayarLogin>
    with TickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final FocusNode _fokus = FocusNode();

  /// Pengatur posisi scroll. Dipakai untuk menarik kolom email + tombol
  /// "Lanjut" ke dalam area terlihat saat keyboard muncul.
  final ScrollController _gulir = ScrollController();
  final GlobalKey _kunciEmail = GlobalKey();
  final GlobalKey _kunciTombol = GlobalKey();

  /// Animasi masuk halaman (fade + naik sedikit), jalan sekali.
  late final AnimationController _masuk = AnimationController(
    vsync: this,
    duration: AppMotion.sangatLambat,
  )..forward();

  bool _proses = false;

  /// Status centang "Saya menyetujui Syarat & Ketentuan dan Kebijakan Privasi".
  /// Tombol lanjut mati selama ini false - gerbang wajib, bukan hiasan.
  bool _setuju = false;

  /// Tautan di dalam teks persetujuan. Dibuat sekali lalu di-dispose di
  /// [dispose]: recognizer yang dibuat di dalam `build` bocor setiap kali
  /// layar dibangun ulang (mis. tiap huruf diketik di kolom email).
  final TapGestureRecognizer _tautanSyarat = TapGestureRecognizer();
  final TapGestureRecognizer _tautanPrivasi = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _fokus.addListener(_saatFokusEmail);
    _tautanSyarat.onTap = () => _bukaLegal('syarat');
    _tautanPrivasi.onTap = () => _bukaLegal('privasi');
    // Dibaca langsung (tanpa setState) karena masih sebelum build pertama.
    _setuju =
        ref.read(simpanCepitProvider).bacaBool(kunciPersetujuan) == true;
  }

  /// Saat kolom email mendapat fokus,keyboard muncul dan tinggi body mengecil.
  /// Tanpa ini, keyboard bisa menutupi kolom yang baru saja diketuk.
  void _saatFokusEmail() {
    if (!_fokus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _tampilkanDalamLayar(_kunciEmail),
    );
  }

  /// Geser [kunci] ke area tengah-bawah viewport scroll.
  ///
  /// Aman dipanggil berkali-kali: kalau belum ada yang bisa digeser (animasi
  /// tombol belum selesai, atau belum ada frame scroll) fungsi ini diam saja.
  void _tampilkanDalamLayar(GlobalKey kunci) {
    if (!mounted || !_gulir.hasClients) return;
    final BuildContext? target = kunci.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: AppMotion.sedang,
      curve: AppMotion.masuk,
      alignment: 0.4,
    );
  }

  /// Buka satu dokumen legal lewat rute `/legal/dokumen/:id`.
  void _bukaLegal(String id) {
    context.push('/legal/dokumen/$id');
  }

  void _ubahSetuju(bool nilai) {
    setState(() => _setuju = nilai);
    // Ditulis tanpa ditunggu: mencentang tidak boleh terasa lambat. Kalau
    // penyimpanan gagal, gerbang layar ini tetap berlaku untuk sesi sekarang.
    ref
        .read(simpanCepitProvider)
        .tulis(kunciPersetujuan, nilai ? 'true' : 'false');
  }

  /// Validasi sengaja longgar: satu `@` dan satu titik setelahnya.
  /// Menolak email yang sah (mis. `nama+label@domain.co.id`) jauh lebih
  /// menyebalkan daripada membiarkan satu typo lewat di layar dummy.
  bool get _emailSah {
    final String t = _email.text.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(t);
  }

  @override
  void dispose() {
    _email.dispose();
    _fokus
      ..removeListener(_saatFokusEmail)
      ..dispose();
    _gulir.dispose();
    _masuk.dispose();
    _tautanSyarat.dispose();
    _tautanPrivasi.dispose();
    super.dispose();
  }

  Future<void> _selesai() async {
    if (_proses) return;
    if (!_setuju) {
      // Jangan diamkan: user menekan tombol lalu tidak terjadi apa-apa.
      _ingatPersetujuan();
      return;
    }
    setState(() => _proses = true);
    // Penanda ditulis SEBELUM pindah halaman: kalau penulisan gagal, user
    // tetap masuk (jangan menahan orang di layar login karena penyimpanan).
    await ref.read(simpanCepitProvider).tulis(kunciLogin, 'true');
    if (!mounted) return;
    context.go('/chat');
  }

  /// Snackbar singkat saat tombol ditekan tapi persetujuan belum dicentang.
  void _ingatPersetujuan() {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Centang persetujuan Syarat & Ketentuan dulu.'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final bool gelap = t.brightness == Brightness.dark;
    final Color permukaan = gelap ? AppColors.surfaceDark : Colors.white;
    final Color garis = gelap ? AppColors.lineDark : AppColors.lineLight;
    final Color redup =
        gelap ? AppColors.textMutedDark : AppColors.textMutedLight;

    //TINGGI KEYBOARD. Dibaca dari context DI ATAS Scaffold, jadi angkanya
    // keyboard sungguhan (bukan sisa keyboard yang sudah dipotong Scaffold).
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool keyboardTerbuka = keyboard > 0;
    final double tinggiRobot = _tinggiRobot(context, keyboardTerbuka);

    return Scaffold(
      backgroundColor: gelap ? AppColors.inkDark : AppColors.surfaceLight,
      //WAJIB: body menyusut setinggi keyboard. Tanpa ini, area bawah halaman
      // (tombol "Lanjut") tertutup di balik keyboard dan tidak bisa disentuh.
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Align(
          // Saat keyboard muncul, konten menempel di atas, bukan di tengah:
          // dengan `Center` isi 700 dp di viewport 480 dp akan terlihat terpotong
          // dan user baru bisa melihat bagian paling bawahnya dengan scroll.
          alignment: keyboardTerbuka
              ? Alignment.topCenter
              : Alignment.center,
          child: SingleChildScrollView(
            controller: _gulir,
            // Menggeser halaman saat user tarik ke atas = tutup keyboard.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              24,
              keyboardTerbuka ? 12 : 28,
              24,
              keyboardTerbuka ? 20 : 28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _masuk,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _Merek(),
                      SizedBox(height: keyboardTerbuka ? 16 : 24),
                      // Robot melambai di antara logo dan judul. Berkas Lottie-nya
                      // `assets/animations/robot_waving.json`; kalau belum ada,
                      // AsetRobot menampilkan robot cadangan yang sama bergeraknya.
                      //
                      // Tingginya diturunkan dari lebar layar HP dan dikecilkan
                      // jadi seperempat saat keyboard terbuka: ilustrasi tetap
                      // proporsional tanpa ikut mendorong kolom email ke bawah
                      // keyboard.
                      SizedBox(
                        height: tinggiRobot,
                        child: Center(
                          child: AsetRobot(
                            berkas: 'assets/animations/robot_waving.json',
                            pose: PoseRobotGambar.melambai,
                            ukuran: tinggiRobot - 12,
                          ),
                        ),
                      ),
                      SizedBox(height: keyboardTerbuka ? 16 : 24),
                      // Headline serif — satu-satunya tempat font ini dipakai.
                      Text(
                        'Masuk untuk melanjutkan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: _Playfair.family,
                          fontSize: 30,
                          height: 1.18,
                          fontWeight: FontWeight.w600,
                          color: gelap
                              ? AppColors.textDark
                              : AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${AppConfig.appName} mengingat konteks percakapanmu '
                        'dan bisa memakai alat saat dibutuhkan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: redup,
                        ),
                      ),
                      SizedBox(height: keyboardTerbuka ? 20 : 30),
                      _TombolGoogle(
                        onTap: _proses ? null : _selesai,
                        permukaan: permukaan,
                        garis: garis,
                        gelap: gelap,
                      ),
                      const SizedBox(height: 22),
                      _Pembatas(kata: 'ATAU', redup: redup, garis: garis),
                      const SizedBox(height: 22),
                      TextField(
                        key: _kunciEmail,
                        controller: _email,
                        focusNode: _fokus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        scrollPadding: const EdgeInsets.only(bottom: 120),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (_emailSah) _selesai();
                        },
                        style: TextStyle(
                          fontFamily: AppTypography.ui,
                          fontSize: 15,
                          color: gelap
                              ? AppColors.textDark
                              : AppColors.textLight,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Masukkan email Anda',
                          hintStyle: TextStyle(
                            fontFamily: AppTypography.ui,
                            fontSize: 14.5,
                            color: redup,
                          ),
                          prefixIcon: Icon(
                            LucideIcons.mail,
                            size: 18,
                            color: redup,
                          ),
                          filled: true,
                          fillColor: permukaan,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: garis),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: garis),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.brand,
                              width: 1.6,
                            ),
                          ),
                        ),
                      ),
                      // Persetujuan diletakkan DI ATAS tombol: tombol yang
                      // mengizinkan masuk harus berada setelah persetujuan.
                      const SizedBox(height: AppSpacing.md),
                      _Persetujuan(
                        nilai: _setuju,
                        onUbah: _ubahSetuju,
                        tautanSyarat: _tautanSyarat,
                        tautanPrivasi: _tautanPrivasi,
                      ),
                      // Tombol "Lanjut" muncul hanya kalau email sudah masuk akal.
                      // Tanpa AnimatedSize, kemunculannya menggeser formulir
                      // sekaligus dan terasa seperti lompatan.
                      AnimatedSize(
                        duration: AppMotion.sedang,
                        curve: AppMotion.masuk,
                        alignment: Alignment.topCenter,
                        // Setelah tombol selesai muncul, geser ke layar kalau
                        // keyboard sedang menutupi bagian bawah halaman.
                        onEnd: () {
                          if (_emailSah) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _tampilkanDalamLayar(_kunciTombol),
                            );
                          }
                        },
                        child: _emailSah
                            ? Padding(
                                key: _kunciTombol,
                                padding: const EdgeInsets.only(top: 14),
                                child: SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _proses ? null : _selesai,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.brand,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _proses
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Lanjut',
                                            style: TextStyle(
                                              fontFamily: AppTypography.ui,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tinggi area robot di halaman login.
///
/// Diturunkan dari sisi terpendek layar (bukan angka tetap) supaya proporsional
/// di HP kecil maupun tablet, dan dikecilkan drastis saat keyboard terbuka:
/// ilustrasi adalah bagian paling mahal dari halaman ini, dan yang paling
/// tidak penting saat user sedang mengisi email.
///
/// `num.clamp()` mengembalikan `num` dan itu jadi compile error kalau tromolnya
/// `double`, jadi batasnya ditulis dengan perbandingan biasa.
double _tinggiRobot(BuildContext context, bool keyboardTerbuka) {
  if (keyboardTerbuka) return 104;
  final double sisi = MediaQuery.sizeOf(context).shortestSide;
  final double h = sisi * 0.40;
  if (h < 140) return 140;
  if (h > 176) return 176;
  return h;
}

/// Nama font headline. Ditulis sekali di sini supaya penggantian font nanti
/// hanya menyentuh satu baris (keluarga fontnya dideklarasikan di pubspec).
abstract final class _Playfair {
  static const String family = 'PlayfairDisplay';
}

/// Header kecil: lambang kotak + nama app, rata tengah.
class _Merek extends StatelessWidget {
  const _Merek();

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Center(
            child: Text(
              'D',
              style: TextStyle(
                color: Colors.white,
                fontFamily: AppTypography.ui,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppConfig.appName,
          style: TextStyle(
            fontFamily: AppTypography.ui,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: gelap ? AppColors.textDark : AppColors.textLight,
          ),
        ),
      ],
    );
  }
}

/// Tombol "Lanjutkan dengan Google": lambang G digambar sendiri pakai 4 busur
/// (`Path` manual), jadi tidak perlu `flutter_svg` hanya untuk satu ikon.
class _TombolGoogle extends StatelessWidget {
  const _TombolGoogle({
    required this.onTap,
    required this.permukaan,
    required this.garis,
    required this.gelap,
  });

  final VoidCallback? onTap;
  final Color permukaan;
  final Color garis;
  final bool gelap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: permukaan,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: garis),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const _LambangGoogle(ukuran: 19),
                const SizedBox(width: 11),
                Text(
                  'Lanjutkan dengan Google',
                  style: TextStyle(
                    fontFamily: AppTypography.ui,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: gelap ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LambangGoogle extends StatelessWidget {
  const _LambangGoogle({required this.ukuran});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(ukuran),
      painter: const _GambarGoogle(),
    );
  }
}

class _GambarGoogle extends CustomPainter {
  const _GambarGoogle();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset pusat = Offset(size.width / 2, size.height / 2);
    final double r = size.width * 0.33;
    final double tebal = size.width * 0.22;
    final Rect kotak = Rect.fromCircle(center: pusat, radius: r);

    Paint pena(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal
      ..strokeCap = StrokeCap.butt
      ..color = c;

    // Sudut 0 = kanan, bertambah searah jarum jam (y kanvas ke bawah) — sama
    // dengan cara ikon resmi disusun: merah di atas, kuning di kiri, hijau di
    // bawah, biru di kanan lalu menyambung ke batang horizontal.
    // Busur diberi tumpang 1 derajat supaya sambungannya tidak menyisakan
    // garis rambut (butt cap tidak menutup celah).
    const double d2r = math.pi / 180;
    canvas.drawArc(kotak, 21 * d2r, 80 * d2r, false,
        pena(AppColors.googleGreen));
    canvas.drawArc(kotak, 100 * d2r, 91 * d2r, false,
        pena(AppColors.googleYellow));
    canvas.drawArc(kotak, 190 * d2r, 111 * d2r, false,
        pena(AppColors.googleRed));
    canvas.drawArc(kotak, 299 * d2r, 59 * d2r, false,
        pena(AppColors.googleBlue));

    // Batang biru: dari tengah ke tepi kanan, setinggi bagian tengah huruf.
    canvas.drawRect(
      Rect.fromLTWH(
        pusat.dx,
        pusat.dy - tebal / 2,
        r + tebal / 2,
        tebal,
      ),
      Paint()..color = AppColors.googleBlue,
    );
  }

  @override
  bool shouldRepaint(_GambarGoogle old) => false;
}

/// Baris persetujuan: centang + tautan ke dua dokumen legal.
///
/// Recognizer-nya milik [_LayarLogin] (dibuat sekali, di-dispose sekali) dan
/// diteruskan lewat parameter. Kalau recognizer dibuat di dalam `build`, tiap
/// ketikan huruf di kolom email menambah listener yang tidak pernah dibuang.
class _Persetujuan extends StatelessWidget {
  const _Persetujuan({
    required this.nilai,
    required this.onUbah,
    required this.tautanSyarat,
    required this.tautanPrivasi,
  });

  final bool nilai;
  final ValueChanged<bool> onUbah;
  final TapGestureRecognizer tautanSyarat;
  final TapGestureRecognizer tautanPrivasi;

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    final Color garis = gelap ? AppColors.lineDark : AppColors.lineLight;
    final TextStyle gaya = TextStyle(
      fontFamily: AppTypography.ui,
      fontSize: 12.5,
      height: 1.45,
      color: gelap ? AppColors.textDark : AppColors.textLight,
    );
    final TextStyle gayaTautan = gaya.copyWith(
      color: AppColors.brand,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.brand,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: nilai,
            onChanged: (bool? v) => onUbah(v ?? false),
            activeColor: AppColors.brand,
            checkColor: Colors.white,
            side: BorderSide(color: garis),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        // Area teks bisa diketuk untuk mencentang, jadi yang bisa ditekan bukan
        // hanya kotak kecil 22 dp (terlalu sempit untuk jari).
        Expanded(
          child: GestureDetector(
            onTap: () => onUbah(!nilai),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text.rich(
                TextSpan(
                  style: gaya,
                  children: <InlineSpan>[
                    const TextSpan(text: 'Saya menyetujui '),
                    TextSpan(
                      text: 'Syarat & Ketentuan',
                      style: gayaTautan,
                      recognizer: tautanSyarat,
                    ),
                    const TextSpan(text: ' dan '),
                    TextSpan(
                      text: 'Kebijakan Privasi',
                      style: gayaTautan,
                      recognizer: tautanPrivasi,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Garis pemisah dengan kata di tengahnya ("ATAU").
class _Pembatas extends StatelessWidget {
  const _Pembatas({
    required this.kata,
    required this.redup,
    required this.garis,
  });

  final String kata;
  final Color redup;
  final Color garis;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Container(height: 1, color: garis)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            kata,
            style: TextStyle(
              fontFamily: AppTypography.ui,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: redup,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: garis)),
      ],
    );
  }
}
