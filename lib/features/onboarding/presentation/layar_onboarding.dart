import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/halaman_onboarding.dart';
import 'widgets/ilustrasi_onboarding.dart';
import 'widgets/latar_onboarding.dart';
import 'widgets/ledakan_cahaya.dart';

/// Kunci penanda onboarding sudah pernah ditutup.
const String kunciOnboarding = 'onboarding_v3';

/// Onboarding 3 halaman, muncul sekali saat aplikasi pertama dipasang.
///
/// Alur: `/splash` membaca [kunciOnboarding]; belum ada = buka halaman ini,
/// sudah ada = langsung ke chat. Tombol "Tampilkan lagi" di Pengaturan
/// menghapus kunci lalu membuka halaman ini, tanpa mengubah apa pun.
///
/// Latar selalu gelap dan beranimasi penuh (gradasian dalam, orb melayang,
/// grid, partikel). Setelah selesai, [_OnboardingState.dispose] mengembalikan
/// gaya system bar ke tema app supaya tidak ada sisa gaya.
class LayarOnboarding extends ConsumerStatefulWidget {
  const LayarOnboarding({super.key});

  @override
  ConsumerState<LayarOnboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<LayarOnboarding>
    with SingleTickerProviderStateMixin {
  late final PageController _page = PageController();
  late final AnimationController _masuk = AnimationController(
    vsync: this,
    duration: AppMotion.sangatLambat,
  )..forward();

  int _indeks = 0;
  bool _selesai = false;
  bool _keluar = false;
  Timer? _auto;

  /// Controller transisi keluar: satu controller untuk ledakan cahaya DAN zoom
  /// layar, jadi keduanya tidak pernah meleset waktunya.
  late final AnimationController _cKeluar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  /// Garis countdown halaman: 0..1 selama 4 detik, lalu halaman berikutnya.
  /// Harus linear - kalau eased, sisa detik terasa tidak akurat.
  late final AnimationController _cHitung = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: AppConfig.durasiHalamanOnboardingMs),
  )..addStatusListener(_saatHitungSelesai);

  void _saatHitungSelesai(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _auto = null;
    _lanjutOtomatis();
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mulaiHitung());
  }

  /// Mulai ulang countdown untuk halaman sekarang. Dipanggil tiap kali
  /// halaman berganti (dan sekali saat layar pertama tampil).
  void _mulaiHitung() {
    if (!mounted || _selesai) return;
    _auto?.cancel();
    _auto = null;
    _cHitung.forward(from: 0);
  }

  void _hentiHitung() {
    _auto?.cancel();
    _auto = null;
    _cHitung.stop();
  }

  /// Auto-lanjut setelah 4 detik. Halaman terakhir langsung memicu ledakan.
  Future<void> _lanjutOtomatis() async {
    if (!mounted || _selesai) return;
    _hentiHitung();
    if (_terakhir) {
      await _tandaiSelesai();
      return;
    }
    await _page.nextPage(
      duration: AppMotion.sangatLambat,
      curve: AppMotion.emphasized,
    );
  }

  @override
  void dispose() {
    _auto?.cancel();
    _page.dispose();
    _masuk.dispose();
    _cKeluar.dispose();
    _cHitung.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  bool get _terakhir => _indeks == halamanOnboarding.length - 1;

  /// Tutup onboarding: tulis kunci, mainkan ledakan cahaya, lalu ke chat.
  ///
  /// Zoom halaman + router transisi (`AppTransisi.portal`) sengaja dibuat
  /// SETENGAH-bertumpuk: layar lama mulai membesar sebelum `go()` dipanggil,
  /// sementara halaman baru sudah disiapkan di belakang. Kalau keduanya
  /// sequential (tunggu satu selesai baru pindah), efeknya terasa seperti
  /// ganti slide, bukan menembus.
  Future<void> _tandaiSelesai({bool denganLedakan = true}) async {
    if (_selesai) return;
    _selesai = true;
    _hentiHitung();
    await ref.read(simpanCepitProvider).tulis(kunciOnboarding, 'true');
    if (!mounted) return;
    if (denganLedakan) {
      setState(() => _keluar = true);
      await _cKeluar.forward();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    if (!mounted) return;
    context.go('/chat');
  }

  Future<void> _lanjut() async {
    // Tombol ditekan = kemauan user, hentikan hitungan mundur supaya
    // halaman tidak meloncat lagi 4 detik setelahnya.
    _hentiHitung();
    if (_terakhir) {
      await _tandaiSelesai();
      return;
    }
    await _page.nextPage(
      duration: AppMotion.sedang,
      curve: AppMotion.emphasized,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget layar = SafeArea(
      child: Column(
        children: <Widget>[
          _BarisAtas(selesai: () => _tandaiSelesai(denganLedakan: false)),
          _GarisHitung(animasi: _cHitung),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: halamanOnboarding.length,
              onPageChanged: (int i) {
                setState(() => _indeks = i);
                _mulaiHitung();
              },
              itemBuilder: (BuildContext context, int i) => _KartuHalaman(
                halaman: halamanOnboarding[i],
                aksen: aksenHalaman[i],
                masuk: _masuk,
              ),
            ),
          ),
          _BagianBawah(
            jumlah: halamanOnboarding.length,
            indeks: _indeks,
            terakhir: _terakhir,
            onLanjut: _lanjut,
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B10),
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: LatarOnboarding(animate: !_keluar)),
          // Zoom keluar + memudar: layar ini "diterbang" ke depan, persis
          // kebalikan dari arah halaman chat yang datang dari 1.10.
          AnimatedBuilder(
            animation: _cKeluar,
            builder: (BuildContext context, Widget? _) {
              final double v = Curves.easeInCubic.transform(_cKeluar.value);
              return Opacity(
                opacity: 1 - v,
                child: Transform.scale(
                  scale: 1 + (0.22 * v),
                  alignment: Alignment.center,
                  child: layar,
                ),
              );
            },
          ),
          if (_keluar) Positioned.fill(child: LedakanCahaya(animasi: _cKeluar)),
        ],
      ),
    );
  }
}

class _BarisAtas extends StatelessWidget {
  const _BarisAtas({required this.selesai});

  final Future<void> Function() selesai;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.brand, AppColors.brandDeep],
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
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
          const Text(
            'DIVJUN AI',
            style: TextStyle(
              color: Colors.white,
              fontFamily: AppTypography.ui,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: selesai,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Text(
                  'Lewati',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu halaman: ilustrasi + judul (dengan potongan bergradien) + subjudul +
/// poin. Semua elemen masuk berurutan (stagger) lalu ikut parallax saat geser.
class _KartuHalaman extends StatelessWidget {
  const _KartuHalaman({
    required this.halaman,
    required this.aksen,
    required this.masuk,
  });

  final HalamanOnboarding halaman;
  final List<Color> aksen;
  final AnimationController masuk;

  /// Jeda antar elemen (detik).
  static const List<double> _jeda = <double>[0.00, 0.10, 0.20, 0.30];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints batas) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: batas.maxHeight - 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _Masuk(
                  masuk: masuk,
                  jeda: _jeda[0],
                  child: IlustrasiOnboarding(
                    jenis: halaman.gambar,
                    aksen: aksen,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Masuk(
                  masuk: masuk,
                  jeda: _jeda[1],
                  child: _JudulBergaris(
                    depan: halaman.judul,
                    aksen: halaman.judulAksen,
                    warna: aksen,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Masuk(
                  masuk: masuk,
                  jeda: _jeda[2],
                  child: Text(
                    halaman.subjudul,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontFamily: AppTypography.ui,
                      fontSize: 14,
                      height: 1.62,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _Masuk(
                  masuk: masuk,
                  jeda: _jeda[3],
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final String p in halaman.poin)
                        _PilPoin(teks: p),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fade + naik 18 px, diputar ulang tiap halaman karena tiap [_KartuHalaman]
/// punya instance sendiri.
class _Masuk extends StatelessWidget {
  const _Masuk({
    required this.masuk,
    required this.jeda,
    required this.child,
  });

  final AnimationController masuk;
  final double jeda;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double> a = CurvedAnimation(
      parent: masuk,
      curve: Interval(
        jeda,
        (jeda + 0.55).clamp(0.0, 1.0),
        curve: AppMotion.masuk,
      ),
    );
    return AnimatedBuilder(
      animation: a,
      child: child,
      builder: (BuildContext context, Widget? kid) {
        return Opacity(
          opacity: a.value,
          child: Transform.translate(
            offset: Offset(0, (1 - a.value) * 18),
            child: kid,
          ),
        );
      },
    );
  }
}

class _JudulBergaris extends StatelessWidget {
  const _JudulBergaris({
    required this.depan,
    required this.aksen,
    required this.warna,
  });

  final String depan;
  final String aksen;
  final List<Color> warna;

  @override
  Widget build(BuildContext context) {
    const TextStyle gaya = TextStyle(
      color: Colors.white,
      fontFamily: AppTypography.ui,
      fontSize: 29,
      fontWeight: FontWeight.w800,
      height: 1.14,
      letterSpacing: -0.6,
    );
    return ShaderMask(
      shaderCallback: (Rect bounds) => LinearGradient(
        colors: warna,
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text('$depan\n$aksen', style: gaya),
    );
  }
}

class _PilPoin extends StatelessWidget {
  const _PilPoin({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            LucideIcons.check,
            size: 12,
            color: Colors.white.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 7),
          Text(
            teks,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontFamily: AppTypography.ui,
              fontSize: 12.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis tipis yang menipis saat halaman menunggu auto-lanjut.
///
/// Ini yang membuat lama 4 detik terasa fair: user tahu persis kapan
/// halaman akan berganti, jadi tidak merasa diburu. Kalau autoplay tanpa
/// indikator, 4 detik terasa lama dan membosankan.
class _GarisHitung extends StatelessWidget {
  const _GarisHitung({required this.animasi});

  final AnimationController animasi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 2,
          child: AnimatedBuilder(
            animation: animasi,
            builder: (BuildContext context, Widget? _) {
              return LinearProgressIndicator(
                value: animasi.value,
                minHeight: 2,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.mint,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BagianBawah extends StatelessWidget {
  const _BagianBawah({
    required this.jumlah,
    required this.indeks,
    required this.terakhir,
    required this.onLanjut,
  });

  final int jumlah;
  final int indeks;
  final bool terakhir;
  final Future<void> Function() onLanjut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (int i = 0; i < jumlah; i++)
                AnimatedContainer(
                  duration: AppMotion.sedang,
                  curve: AppMotion.emphasized,
                  height: 4,
                  width: i == indeks ? 26 : 9,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    gradient: i == indeks
                        ? const LinearGradient(
                            colors: <Color>[AppColors.mint, AppColors.brand],
                          )
                        : null,
                    color: i == indeks
                        ? null
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: <Color>[
                    AppColors.brand,
                    Color(0xFF6E6EF0),
                    AppColors.brandDeep,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.42),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onLanjut,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        terakhir ? 'Mulai' : 'Lanjut',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: AppTypography.ui,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 9),
                      const Icon(
                        LucideIcons.arrowUpRight,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}