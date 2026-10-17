import 'package:divjun_ai/domain/entities/model_ai.dart';
import 'package:divjun_ai/features/agent/loop/agent_loop.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi untuk bug "semua model gagal" (Okt 2026): katalog bawaan menunjuk
/// model Llama 3.3 70B yang di Groq sudah paket Enterprise, sehingga kunci
/// gratis ditolak di setiap permintaan.
void main() {
  group('katalog model', () {
    test('model bawaan tidak ada yang khusus berbayar sebagai default', () {
      final ModelAi d = ModelAi.defaultGratis();
      expect(d.untukGratis, isTrue);
      expect(d.dukungAlat, isTrue);
      expect(d.id, isNot('llama-3.3-70b-versatile'));
      expect(d.id, isNot('llama-3.1-8b-instant'));
    });

    test('Llama 3.3 70B ditandai perluBayar', () {
      final ModelAi? m = ModelAi.cari('llama-3.3-70b-versatile');
      expect(m, isNotNull);
      expect(m!.perluBayar, isTrue);
      expect(m.untukGratis, isFalse);
    });

    test('layakOtomatis hanya berisi model gratis + tool calling', () {
      for (final ModelAi m in ModelAi.layakOtomatis()) {
        expect(m.dukungAlat, isTrue, reason: m.id);
        expect(m.untukGratis, isTrue, reason: m.id);
      }
      expect(ModelAi.layakOtomatis(), isNotEmpty);
    });

    test('cadangan tidak mengandung model yang sama dan semua gratis', () {
      final ModelAi awal = ModelAi.defaultGratis();
      final List<ModelAi> lain = ModelAi.cadangan(awal);
      expect(lain, isNotEmpty);
      for (final ModelAi m in lain) {
        expect(m.id, isNot(awal.id));
        expect(m.untukGratis, isTrue);
      }
    });
  });

  group('auto-pilih model', () {
    List<ModelAi> katalog() => <ModelAi>[
          ModelAi.cari('openai/gpt-oss-20b')!,
          ModelAi.cari('openai/gpt-oss-120b')!,
          ModelAi.cari('llama-3.3-70b-versatile')!,
        ];

    test('tidak pernah memilih model enterprise', () {
      final ModelAi m = AgentLoop.pilihOtomatis(
        pesan: 'berapa 1.250.000 + 15% dari 3.400.000',
        katalog: katalog(),
        fallback: ModelAi.cari('openai/gpt-oss-120b')!,
      );
      expect(m.perluBayar, isFalse);
    });

    test('memilih model ringan untuk pertanyaan pendek', () {
      final ModelAi m = AgentLoop.pilihOtomatis(
        pesan: 'jam berapa sekarang',
        katalog: katalog(),
        fallback: ModelAi.cari('openai/gpt-oss-120b')!,
      );
      expect(m.id, 'openai/gpt-oss-20b');
    });

    test('memilih model besar untuk permintaan kode panjang', () {
      final ModelAi m = AgentLoop.pilihOtomatis(
        pesan: 'tulis kode flutter untuk ${'x' * 800}',
        katalog: katalog(),
        fallback: ModelAi.cari('openai/gpt-oss-120b')!,
      );
      expect(m.id, 'openai/gpt-oss-120b');
    });
  });

  group('provider gratis tanpa kunci (18 Okt 2026)', () {
    test('OVH dan Pollinations tidak butuh kunci', () {
      expect(PenyediaModel.ovh.tanpaKunci, isTrue);
      expect(PenyediaModel.pollinations.tanpaKunci, isTrue);
      expect(PenyediaModel.groq.tanpaKunci, isFalse);
      expect(PenyediaModel.openrouter.tanpaKunci, isFalse);
      for (final ModelAi m in ModelAi.bawaan) {
        if (m.penyedia == PenyediaModel.ovh ||
            m.penyedia == PenyediaModel.pollinations) {
          expect(m.perluKunci, isFalse, reason: m.id);
          expect(m.dukungAlat, isTrue, reason: m.id);
        }
      }
    });

    test('model default adalah provider tanpa kunci', () {
      final ModelAi d = ModelAi.defaultGratis();
      expect(d.perluKunci, isFalse);
      expect(d.dukungAlat, isTrue);
    });

    test('cadangan diurutkan dari provider tanpa kunci', () {
      final ModelAi awal = ModelAi.defaultGratis();
      final List<ModelAi> lain = ModelAi.cadangan(awal);
      expect(lain, isNotEmpty);
      final int iPertamaBerbayar = lain.indexWhere((ModelAi m) => m.perluKunci);
      if (iPertamaBerbayar >= 0) {
        for (final ModelAi m in lain.sublist(iPertamaBerbayar)) {
          expect(m.perluKunci, isTrue, reason: m.id);
        }
      }
    });

    test('model OpenRouter gratis ditandai :free dan punya tools', () {
      final List<ModelAi> or = ModelAi.bawaan
          .where((ModelAi m) => m.penyedia == PenyediaModel.openrouter)
          .toList();
      expect(or, isNotEmpty);
      for (final ModelAi m in or) {
        expect(m.id.endsWith(':free'), isTrue, reason: m.id);
        expect(m.dukungAlat, isTrue, reason: m.id);
        expect(m.perluBayar, isFalse, reason: m.id);
      }
    });
  });
}
