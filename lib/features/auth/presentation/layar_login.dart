import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/providers.dart';
// app_theme.dart mengekspor app_colors, app_typography, app_motion — cukup satu
// import ini untuk ketiga token tersebut.
import '../../../core/theme/app_theme.dart';

/// Kunci penyimpanan: halaman login hanya muncul SEKALI.
///
/// Dibaca di `layar_splash.dart`, bukan di dalam LayarLogin, supaya keputusan
/// "sudah pernah masuk" tidak bergantung pada layar yang sedang dibuka.
const String kunciLogin = 'login_v1';

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

  /// Animasi masuk halaman (fade + naik sedikit), jalan sekali.
  late final AnimationController _masuk = AnimationController(
    vsync: this,
    duration: AppMotion.sangatLambat,
  )..forward();

  bool _proses = false;

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
    _fokus.dispose();
    _masuk.dispose();
    super.dispose();
  }

  Future<void> _selesai() async {
    if (_proses) return;
    setState(() => _proses = true);
    // Penanda ditulis SEBELUM pindah halaman: kalau penulisan gagal, user
    // tetap masuk (jangan menahan orang di layar login karena penyimpanan).
    await ref.read(simpanCepitProvider).tulis(kunciLogin, 'true');
    if (!mounted) return;
    context.go('/chat');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData t = Theme.of(context);
    final bool gelap = t.brightness == Brightness.dark;
    final Color permukaan = gelap ? AppColors.surfaceDark : Colors.white;
    final Color garis = gelap ? AppColors.lineDark : AppColors.lineLight;
    final Color redup =
        gelap ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      backgroundColor: gelap ? AppColors.inkDark : AppColors.surfaceLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(
                opacity: _masuk,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _Merek(),
                    const SizedBox(height: 26),
                    const _IlustrasiNapas(ukuran: 120),
                    const SizedBox(height: 26),
                    // Headline serif — satu-satunya tempat font ini dipakai.
                    Text(
                      'Masuk untuk melanjutkan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _Playfair.family,
                        fontSize: 30,
                        height: 1.18,
                        fontWeight: FontWeight.w600,
                        color: gelap ? AppColors.textDark : AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${AppConfig.appName} mengingat konteks percakapanmu '
                      'dan bisa memakai alat saat dibutuhkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.5, color: redup),
                    ),
                    const SizedBox(height: 30),
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
                      controller: _email,
                      focusNode: _fokus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
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
                    // Tombol "Lanjut" muncul hanya kalau email sudah masuk akal.
                    // Tanpa AnimatedSize, kemunculannya menggeser formulir
                    // sekaligus dan terasa seperti lompatan.
                    AnimatedSize(
                      duration: AppMotion.sedang,
                      curve: AppMotion.masuk,
                      alignment: Alignment.topCenter,
                      child: _emailSah
                          ? Padding(
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
                    const SizedBox(height: 24),
                    Text(
                      'Dengan melanjutkan, Anda menyetujui Syarat Layanan dan '
                      'Kebijakan Privasi ${AppConfig.appName}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.ui,
                        fontSize: 11,
                        height: 1.6,
                        color: redup.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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

/// Ilustrasi: cincin yang menggambar dirinya sambil bernapas.
///
/// Dua gerak dalam SATU controller - cincin luar berputar-penuh lalu
/// menghilang, cincin dalam berdenyut - supaya keduanya tidak pernah
/// kehilangan sinkronisasi (dua controller terpisah gampang meleset kalau
/// halaman dibuka-tutup).
class _IlustrasiNapas extends StatefulWidget {
  const _IlustrasiNapas({required this.ukuran});

  final double ukuran;

  @override
  State<_IlustrasiNapas> createState() => _IlustrasiNapasState();
}

class _IlustrasiNapasState extends State<_IlustrasiNapas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          return CustomPaint(
            size: Size.square(widget.ukuran),
            painter: _GambarNapas(
              t: _c.value,
              aksen: AppColors.brand,
              pudar: gelap
                  ? Colors.white.withValues(alpha: 0.10)
                  : AppColors.brand.withValues(alpha: 0.10),
            ),
          );
        },
      ),
    );
  }
}

class _GambarNapas extends CustomPainter {
  const _GambarNapas({
    required this.t,
    required this.aksen,
    required this.pudar,
  });

  /// 0..1, berulang.
  final double t;
  final Color aksen;
  final Color pudar;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset pusat = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2;
    final double napas = 1 + (math.sin(t * 2 * math.pi) * 0.035);

    // Lingkaran tipis tetap: memberi "lantai" supaya gerak cincin terbaca.
    canvas.drawCircle(
      pusat,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = pudar,
    );

    // Cincin yang menggambar dirinya: mulai dari atas, berputar penuh
    // sepanjang siklus, lalu memudar saat tuntas - jadi terasa di-ulang.
    final double lingkaran = Curves.easeInOut.transform(
      (t < 0.72 ? t / 0.72 : 1),
    );
    final Paint penaCincin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = aksen.withValues(alpha: (1 - lingkaran) * 0.9 + 0.1);
    canvas.drawArc(
      Rect.fromCircle(center: pusat, radius: r * 0.99 * napas),
      -math.pi / 2,
      2 * math.pi * lingkaran,
      false,
      penaCincin,
    );

    // Inti yang bernapas + monogram di tengahnya.
    canvas.drawCircle(
      pusat,
      r * 0.6 * napas,
      Paint()..color = aksen.withValues(alpha: 0.14),
    );
    canvas.drawCircle(pusat, r * 0.42, Paint()..color = aksen);

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: 'D',
        style: TextStyle(
          fontFamily: AppTypography.ui,
          fontSize: r * 0.46,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      pusat - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_GambarNapas old) => old.t != t || old.aksen != aksen;
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
