import 'dart:convert';

import 'package:divjun_ai/domain/entities/setelan.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mengunci aturan "tidak bisa dimatikan dari pengaturan" (v3.0.0).
///
/// Kalau suatu saat ketiga nilai ini dikembalikan ke JSON atau dibikin bisa
/// dimatikan lagi, test ini harus gagal - bukanDiam-diam mengubah perilaku.
void main() {
  group('SetelanApp - selalu aktif', () {
    test('nilai bawaan sudah aktif', () {
      const SetelanApp s = SetelanApp();
      expect(s.modeAgent, ModeAgent.auto);
      expect(s.autoRingkas, isTrue);
      expect(s.pakaiSkillPanduan, isTrue);
      expect(s.agentAktif, isTrue);
    });

    test('setelan lama yang pernah bernilai false ikut aktif (migrasi)', () {
      // Inilah yang terjadi pada pengguna yang versi lamanya mematikan sakelar.
      final SetelanApp s = SetelanApp.dariJson(<String, dynamic>{
        'modeAgent': 'chatting',
        'autoRingkas': false,
        'pakaiSkillPanduan': false,
        'suhu': 1.4,
      });
      expect(s.modeAgent, ModeAgent.auto);
      expect(s.autoRingkas, isTrue);
      expect(s.pakaiSkillPanduan, isTrue);
      expect(s.agentAktif, isTrue);
      // nilai lain tetap terbaca normal
      expect(s.suhu, 1.4);
    });

    test('tidak ada lagi autoRingkas/pakaiSkillPanduan/modeAgent di JSON', () {
      final Map<String, dynamic> j = const SetelanApp().keJson();
      expect(j.containsKey('autoRingkas'), isFalse);
      expect(j.containsKey('pakaiSkillPanduan'), isFalse);
      expect(j.containsKey('modeAgent'), isFalse);
    });

    test('salin() tidak bisa mematikan ketiga nilai tersebut', () {
      const SetelanApp s = SetelanApp();
      final SetelanApp lain = s.salin(suhu: 1.8, namaPengguna: 'Budi');
      expect(lain.suhu, 1.8);
      expect(lain.namaPengguna, 'Budi');
      expect(lain.modeAgent, ModeAgent.auto);
      expect(lain.autoRingkas, isTrue);
      expect(lain.pakaiSkillPanduan, isTrue);
    });
  });

  group('SetelanApp - bagian yang boleh diubah', () {
    test('izin alat dan tema tetap bisa diganti', () {
      final SetelanApp s = const SetelanApp().salin(
        tema: TemaMode.gelap,
        izinkanWeb: false,
        izinkanEmail: false,
        izinkanKalkulator: false,
        ingatMemori: false,
        pakaiWarnaDinamis: false,
      );
      expect(s.tema, TemaMode.gelap);
      expect(s.izinkanWeb, isFalse);
      expect(s.izinkanEmail, isFalse);
      expect(s.izinkanKalkulator, isFalse);
      expect(s.ingatMemori, isFalse);
      expect(s.pakaiWarnaDinamis, isFalse);
    });

    test('round-trip JSON mempertahankan bagian yang boleh diubah', () {
      final SetelanApp asli = const SetelanApp().salin(
        namaPengguna: 'Sari',
        promptSistemTambahan: 'balas singkat',
        tema: TemaMode.terang,
        izinkanWeb: false,
      );
      final SetelanApp kembali = SetelanApp.dariJsonTeks(
        jsonEncode(asli.keJson()),
      );
      expect(kembali.namaPengguna, 'Sari');
      expect(kembali.promptSistemTambahan, 'balas singkat');
      expect(kembali.tema, TemaMode.terang);
      expect(kembali.izinkanWeb, isFalse);
      expect(kembali.autoRingkas, isTrue);
    });

    test('JSON rusak tidak membuat aplikasi crash', () {
      expect(SetelanApp.dariJsonTeks('bukan json').modeAgent, ModeAgent.auto);
      expect(SetelanApp.dariJsonTeks(null).autoRingkas, isTrue);
      expect(SetelanApp.dariJsonTeks('').pakaiSkillPanduan, isTrue);
    });

    test('tema tak dikenal jatuh ke default, bukan error', () {
      final SetelanApp s = SetelanApp.dariJson(<String, dynamic>{
        'tema': 'ungu-neon',
      });
      expect(s.tema, TemaMode.sistem);
    });
  });
}