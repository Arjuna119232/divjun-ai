import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_env.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/presentation/layar_onboarding.dart';

/// Halaman "Tentang".
///
/// Menu "Tampilkan lagi onboarding" dihapus dari halaman Pengaturan utama
/// (v3.0.0) dan dipindah ke sini sebagai trik: ketuk nomor versi 5x.
/// Alasannya fitur ini hanya untuk pengguna yang perlu, bukan untuk semua.
class LayarTentang extends ConsumerStatefulWidget {
  const LayarTentang({super.key});

  @override
  ConsumerState<LayarTentang> createState() => _LayarTentangState();
}

class _LayarTentangState extends ConsumerState<LayarTentang> {
  int _ketukan = 0;
  static const int _butuhKetukan = 5;

  void _onKetukVersi() {
    HapticFeedback.selectionClick();
    _ketukan++;
    // direset supaya tidak memicu sendiri jauh di kemudian hari
    if (_ketukan > 8) {
      _ketukan = 0;
      setState(() {});
      return;
    }
    setState(() {});
    // Pemicu sebenarnya. Tanpa baris ini, ketukan hanya mengubah angka di
    // layar dan tidak pernah membuka apa pun - funsi ini jadi tidak terpakai.
    if (_ketukan >= _butuhKetukan) {
      _bukaOnboardingLagi();
    }
  }

  Future<void> _bukaOnboardingLagi() async {
    setState(() => _ketukan = 0);
    HapticFeedback.mediumImpact();
    // Kunci dihapus dulu supaya "/onboarding" yang dibuka manual tetap
    // menyimpan status selesai saat user menekan "Mulai" (lihat LayarSplash).
    await ref.read(simpanCepitProvider).hapus(kunciOnboarding);
    if (!mounted) return;
    context.push('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final int sisa = _butuhKetukan - _ketukan;

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: AppRadius.br20,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'D',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: AppTypography.ui,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppConfig.appName,
                  style: context.teks.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Baris versi: diketuk 5x untuk memunculkan onboarding lagi.
                GestureDetector(
                  onTap: _onKetukVersi,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Versi ${AppEnv.appVersion}',
                          style: context.teks.labelSmall,
                        ),
                        if (_ketukan > 0) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '$sisa lagi',
                            style: context.teks.labelSmall?.copyWith(
                              color: context.cs.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Container(
            decoration: BoxDecoration(
              color: context.cs.surfaceContainerLow,
              borderRadius: AppRadius.br16,
              border: Border.all(
                color: context.cs.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Apa yang bisa DIVJUN', style: context.teks.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                ...<String>[
                  'Menjawab pertanyaan dan menulis draf email.',
                  'Mengingat fakta yang kamu minta untuk diingat.',
                  'Membuka halaman web saat perlu info terbaru.',
                  'Menghitung dan mengolah data sederhana.',
                ].map(
                  (String t) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          LucideIcons.check,
                          size: 15,
                          color: context.cs.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(t)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}