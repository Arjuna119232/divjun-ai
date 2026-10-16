import 'dart:convert';

import 'package:divjun_ai/features/skills/domain/skill.dart';
import 'package:flutter_test/flutter_test.dart';

/// Index pustaka skill = aset di dalam APK. Yang diuji di sini adalah logika
/// parsing + pencarian (tidak butuh asset bundle, jadi jalan tanpa device).
void main() {
  group('parseIndeksSkill', () {
    test('baca index.json yang sah', () {
      final IndeksSkill idx = parseIndeksSkill(jsonEncode(<String, Object?>{
        'jumlah': 2,
        'skills': <Map<String, Object?>>[
          <String, Object?>{
            'nama': 'kalkulator-kota',
            'deskripsi': 'Cara hitung ongkos Ángeles',
            'folder': 'kalkulator-kota',
            'size': 2048,
            'jumlahFile': 2,
            'files': <Map<String, Object?>>[
              <String, Object?>{'path': 'SKILL.md', 'size': 1024},
              <String, Object?>{'path': 'referensi/tabel.md', 'size': 1024},
            ],
          },
          <String, Object?>{
            'nama': 'desain-ui',
            'deskripsi': 'Desain antarmuka modern',
            'folder': 'desain-ui',
            'size': 512,
            'jumlahFile': 1,
            'files': <Map<String, Object?>>[
              <String, Object?>{'path': 'SKILL.md', 'size': 512},
            ],
          },
        ],
      }));

      expect(idx.jumlah, 2);
      expect(idx.skills.length, 2);
      expect(idx.totalBerkas, 3);
      expect(idx.totalUkuran, 2560);
      expect(idx.skills.first.nama, 'kalkulator-kota');
      expect(idx.skills.first.berkas.length, 2);
    });

    test('JSON rusak / kosong tidak bikin crash', () {
      expect(parseIndeksSkill('bukan json').skills, isEmpty);
      expect(parseIndeksSkill('[]').skills, isEmpty);
      expect(parseIndeksSkill('').skills, isEmpty);
    });

    test('escape unicode & tanda kutip aman', () {
      final IndeksSkill idx = parseIndeksSkill(
        '{"jumlah":1,"skills":[{"nama":"a\\"b","deskripsi":"tab\\tbaru",'
        '"folder":"ab","size":1,"jumlahFile":1,"files":[]}]}',
      );
      expect(idx.skills.first.nama, 'a"b');
      expect(idx.skills.first.deskripsi, 'tab\tbaru');
    });
  });

  group('pencarian', () {
    late IndeksSkill idx;

    setUp(() {
      idx = parseIndeksSkill(jsonEncode(<String, Object?>{
        'jumlah': 3,
        'skills': <Map<String, Object?>>[
          <String, Object?>{
            'nama': 'flutter-ios-prepare',
            'deskripsi': 'Menyiapkan build iOS tanpa laptop',
            'folder': 'flutter-ios-prepare',
            'size': 10,
            'jumlahFile': 1,
            'files': <dynamic>[],
          },
          <String, Object?>{
            'nama': 'url-guard',
            'deskripsi': 'Blokir alamat privat saat tool web',
            'folder': 'url-guard',
            'size': 10,
            'jumlahFile': 1,
            'files': <dynamic>[],
          },
          <String, Object?>{
            'nama': 'desain',
            'deskripsi': 'Warna dan tipografi antarmuka',
            'folder': 'desain',
            'size': 10,
            'jumlahFile': 1,
            'files': <dynamic>[],
          },
        ],
      }));
    });

    test('cari berdasarkan nama/deskripsi/folder', () {
      expect(idx.cari('ios').length, 1);
      expect(idx.cari('privat').first.nama, 'url-guard');
      expect(idx.cari('DESAIN').first.nama, 'desain');
      expect(idx.cari('').length, 3);
      expect(idx.cari('tidak ada'), isEmpty);
    });

    test('relevan memilih skill yang cocok pertanyaan', () {
      final List<Skill> cocok =
          idx.relevan('carikan skill buat preparing iOS build', maks: 2);
      expect(cocok, isNotEmpty);
      expect(cocok.first.nama, 'flutter-ios-prepare');
    });

    test('relevan kosong kalau pertanyaan tidak nyambung', () {
      expect(idx.relevan('apa kabar hari ini'), isEmpty);
    });

    test('kata kunci membuang kata umum dan tanda baca', () {
      final List<String> kunci = IndeksSkill.kataKunci(
        'tolong dong_toolong cek yang ini ya',
      );
      expect(kunci.contains('tolong'), isFalse);
      expect(kunci.contains('dong_tolong'), isFalse);
    });
  });

  group('Skill.punya', () {
    test('pencocokan tidakcase-sensitive', () {
      const Skill s = Skill(
        nama: 'Apk-Mod',
        deskripsi: 'Patch aplikasi Android',
        folder: 'apk-mod',
        size: 1,
        jumlahFile: 1,
        berkas: <BerkasSkill>[],
      );
      expect(s.punya('APK'), isTrue);
      expect(s.punya('android'), isTrue);
      expect(s.punya(''), isTrue);
      expect(s.punya('flutter'), isFalse);
    });
  });
}