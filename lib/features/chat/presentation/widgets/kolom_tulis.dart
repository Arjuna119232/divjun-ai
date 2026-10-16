import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/setelan.dart';

/// Kolom input: textarea multi-baris + tombol kirim/stop.
///
/// Tombol berubah bentuk sesuai state: panah atas (kirim) -> kotak (stop).
class KolomTulis extends ConsumerStatefulWidget {
  const KolomTulis({
    super.key,
    required this.sibuk,
    required this.onKirim,
    required this.onStop,
  });

  final bool sibuk;
  final ValueChanged<String> onKirim;
  final VoidCallback onStop;

  @override
  ConsumerState<KolomTulis> createState() => _KolomTulisState();
}

class _KolomTulisState extends ConsumerState<KolomTulis> {
  final TextEditingController _c = TextEditingController();
  final FocusNode _f = FocusNode();
  bool _adaTeks = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final bool ada = _c.text.trim().isNotEmpty;
      if (ada != _adaTeks) setState(() => _adaTeks = ada);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _f.dispose();
    super.dispose();
  }

  void _kirim() {
    final String t = _c.text.trim();
    if (t.isEmpty) return;
    widget.onKirim(t);
    _c.clear();
    setState(() => _adaTeks = false);
  }

  @override
  Widget build(BuildContext context) {
    final SetelanApp setelan = ref.watch(setelanProvider);
    final bool bisaKirim = _adaTeks && !widget.sibuk;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(
          top: BorderSide(color: context.cs.outlineVariant, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: TextField(
                    controller: _c,
                    focusNode: _f,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    style: context.teks.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Tanya apa saja…',
                      hintStyle: context.teks.bodyMedium?.copyWith(
                        color: context.cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: context.cs.surfaceContainer,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 14,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.br16,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.br16,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.br16,
                        borderSide: BorderSide(
                          color: context.cs.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _TombolAksi(
                aktif: bisaKirim || widget.sibuk,
                sibuk: widget.sibuk,
                onTekan: widget.sibuk ? widget.onStop : _kirim,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                LucideIcons.sparkles,
                size: 13,
                color: context.cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  _ringkasanAlat(setelan),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.teks.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _ringkasanAlat(SetelanApp s) {
    if (!s.agentAktif) return 'Mode chat - tool dimatikan';
    final List<String> alat = <String>[
      if (s.izinkanKalkulator) 'kalkulator',
      'waktu',
      if (s.ingatMemori) 'memori',
      if (s.izinkanWeb) 'web',
      if (s.izinkanEmail) 'email',
    ];
    return 'Agent aktif · ${alat.join(', ')}';
  }
}

class _TombolAksi extends StatelessWidget {
  const _TombolAksi({
    required this.aktif,
    required this.sibuk,
    required this.onTekan,
  });

  final bool aktif;
  final bool sibuk;
  final VoidCallback onTekan;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.cepat,
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: aktif ? context.cs.primary : context.cs.surfaceContainerHigh,
        borderRadius: AppRadius.br16,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.br16,
          onTap: () {
            HapticFeedback.lightImpact();
            onTekan();
          },
          child: Center(
            child: Icon(
              sibuk ? LucideIcons.square : LucideIcons.arrowUp,
              size: 20,
              color: aktif
                  ? context.cs.onPrimary
                  : context.cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
