import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/setelan.dart';

/// Isi / ganti kunci API langsung di aplikasi.
///
/// Dipakai kalau kunci yang dibundel saat build sudah kadaluarsa, supaya tidak
/// perlu build ulang. Disimpan lokal (SharedPreferences), ditampilkan
/// tersamar (4 karakter terakhir saja).
class HalamanKunci extends ConsumerStatefulWidget {
  const HalamanKunci({super.key});

  @override
  ConsumerState<HalamanKunci> createState() => _HalamanKunciState();
}

class _HalamanKunciState extends ConsumerState<HalamanKunci> {
  late final TextEditingController _groq =
      TextEditingController(text: ref.read(setelanProvider).kunciGroq);
  late final TextEditingController _gemini =
      TextEditingController(text: ref.read(setelanProvider).kunciGemini);
  bool _lihatGroq = false;
  bool _lihatGemini = false;

  @override
  void dispose() {
    _groq.dispose();
    _gemini.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kunci API')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(
            'Kunci ini disimpan di perangkat ini saja (tidak dikirim ke '
            'manapun). Kosongkan untuk kembali memakai kunci yang dibundel '
            'saat build.',
            style: context.teks.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Groq',
            hint: 'gsk_…',
            controller: _groq,
            terlihat: _lihatGroq,
            onLihat: () => setState(() => _lihatGroq = !_lihatGroq),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Gemini',
            hint: 'AIza…',
            controller: _gemini,
            terlihat: _lihatGemini,
            onLihat: () => setState(() => _lihatGemini = !_lihatGemini),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: () async {
              HapticFeedback.lightImpact();
              final SetelanController c = ref.read(setelanProvider.notifier);
              await c.setKunciGroq(_groq.text.trim());
              await c.setKunciGemini(_gemini.text.trim());
              ref.invalidate(katalogModelProvider);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kunci disimpan di perangkat ini')),
              );
            },
            icon: const Icon(LucideIcons.save, size: 18),
            label: const Text('Simpan kunci'),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () {
              _groq.clear();
              _gemini.clear();
              setState(() {});
            },
            icon: const Icon(LucideIcons.eraser, size: 18),
            label: const Text('Kosongkan keduanya'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    required this.terlihat,
    required this.onLihat,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool terlihat;
  final VoidCallback onLihat;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !terlihat,
      autocorrect: false,
      enableSuggestions: false,
      style: AppTypography.mono(size: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: IconButton(
          icon: Icon(
            terlihat ? LucideIcons.eyeOff : LucideIcons.eye,
            size: 18,
          ),
          onPressed: onLihat,
        ),
      ),
    );
  }
}
