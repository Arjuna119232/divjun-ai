import 'package:divjun_ai/domain/entities/memori.dart';
import 'package:divjun_ai/services/memory_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mengunci isi system prompt.
///
/// Isi system prompt dikirim ke provider di SETIAP permintaan, jadi orang
/// yang "membersihkan" satu kalimat tanpa sadar bisa mengubah perilaku app
/// tanpa test ini menyadarinya. Test ini sengaja memeriksa 9 aturan dari user
/// satu per satu.
void main() {
  const MemoryService ms = MemoryService();

  String prompt({
    bool agent = true,
    bool web = true,
    List<EntriMemori> memori = const <EntriMemori>[],
    String tambahan = '',
    String skill = '',
  }) =>
      ms.systemPrompt(
        namaPengguna: 'Uji',
        agentAktif: agent,
        promptTambahan: tambahan,
        memori: memori,
        bisaWeb: web,
        panduanSkill: skill,
      );

  group('system prompt', () {
    test('memuat identitas dan gaya bahasa Indonesia', () {
      final String p = prompt();
      expect(p, contains('DIVJUN AI'));
      expect(p, contains('Bahasa Indonesia'));
      expect(p, contains('Uji'));
    });

    test('9 aturan menjalankan selalu ikut, walau agent nonaktif', () {
      for (final bool agent in <bool>[true, false]) {
        final String p = prompt(agent: agent);
        expect(p, contains('Aturan menjalankan:'), reason: 'agent=$agent');
        //tiap aturan punya penanda nomor sendiri supaya hilang satu saja ketahuan
        for (final String penanda in <String>[
          '1. Kamu punya batas langkah',
          '2. URL gagal dibuka',
          '3. Kalau batas langkah hampir habis',
          '4. Kalau semua sumber gagal',
          '5. Kalau model ditolak provider',
          '6. Kata kunci pencarian harus spesifik',
          '7. Format jawaban rapi',
          '8. Kalau permintaan terlalu umum',
          '9. Keamanan: jangan rekomendasikan',
        ]) {
          expect(p, contains(penanda), reason: 'hilang: $penanda');
        }
      }
    });

    test('aturan menyebut batas 2 percobaan URL', () {
      expect(prompt(), contains('Maksimal 2 percobaan'));
      expect(prompt(), contains('BERHENTI mencari web'));
    });

    test('larangan jawaban kosong / error mentah ada', () {
      expect(prompt(), contains('Jangan pernah jawaban kosong'));
    });

    test('blok tool hanya muncul saat agent aktif', () {
      expect(prompt(agent: true), contains('Kamu punya akses tool'));
      expect(prompt(agent: false), isNot(contains('Kamu punya akses tool')));
    });

    test('blok memori dan instruksi tambahan tetap masuk', () {
      final String p = prompt(
        memori: <EntriMemori>[
          EntriMemori(
            id: 'm1',
            isi: 'User suka kopi susu',
            kategori: KategoriMemori.preferensi,
            dibuat: DateTime(2026, 1, 1),
          ),
        ],
        tambahan: 'Selalu balas singkat.',
      );
      expect(p, contains('Memori jangka panjang user'));
      expect(p, contains('User suka kopi susu'));
      expect(p, contains('Selalu balas singkat.'));
    });

    test('prompt tidak kosong walau tanpa memori, skill, dan tambahan', () {
      final String p = prompt(memori: const <EntriMemori>[]);
      expect(p.trim(), isNotEmpty);
      expect(p, contains('Aturan menjalankan:'));
    });
  });
}