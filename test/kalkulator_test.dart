import 'package:divjun_ai/features/agent/tools/kalkulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kalkulator.hitung', () {
    test('penjumlahan dengan pemisah ribuan gaya Indonesia', () {
      expect(Kalkulator.hitung('12.500 + 3.400'), 15900);
      expect(Kalkulator.hitung('1.000.000 / 4'), 250000);
    });

    test('tanda kurung dan prioritas operasi', () {
      expect(Kalkulator.hitung('(80 + 20) / 4 * 1.5'), 37.5);
      expect(Kalkulator.hitung('2 + 3 * 4'), 14);
      expect(Kalkulator.hitung('2 ^ 3 ^ 2'), 512); // asosiasi ke kanan
    });

    test('fungsi dan konstanta', () {
      expect(Kalkulator.hitung('sqrt(144)'), 12);
      expect(Kalkulator.hitung('log(1000)'), closeTo(3, 0.0001));
      expect(Kalkulator.hitung('ln(e)'), closeTo(1, 0.0001));
      expect(Kalkulator.hitung('round(3.6)'), 4);
      expect(Kalkulator.hitung('floor(3.9)'), 3);
      expect(Kalkulator.hitung('abs(-7)'), 7);
    });

    test('persen dan unary minus', () {
      expect(Kalkulator.hitung('20% * 1500000'), 300000);
      expect(Kalkulator.hitung('-5 + 3'), -2);
      expect(Kalkulator.hitung('-2 ^ 2'), -4);
    });

    test('koma desimal dan titik sebagai desimal', () {
      expect(Kalkulator.hitung('1,5 + 1,5'), 3);
      expect(Kalkulator.hitung('1.5 + 1.5'), 3);
    });

    test('input rusak tidak melempar exception', () {
      expect(Kalkulator.hitung(''), isNull);
      expect(Kalkulator.hitung('abc'), isNull);
      expect(Kalkulator.hitung('10 / 0'), isNull);
      expect(Kalkulator.hitung('(1 + 2'), isNull);
      expect(Kalkulator.hitung('1 + 2)'), isNull);
      expect(Kalkulator.hitung('sqrt(-1)'), isNull);
      expect(Kalkulator.hitung('1 000 000'), isNull); // spasi ditolak
    });
  });

  group('Kalkulator.format', () {
    test('memakai pemisah ribuan titik', () {
      expect(Kalkulator.format(15900), '15.900');
      expect(Kalkulator.format(1000000), '1.000.000');
      expect(Kalkulator.format(-2500), '-2.500');
    });

    test('desimal dibersihkan', () {
      expect(Kalkulator.format(37.5), '37.5');
      expect(Kalkulator.format(1 / 3), '0.333333');
      expect(Kalkulator.format(2.0), '2');
    });
  });

  test('hitungTeks selalu mengembalikan teks', () {
    expect(Kalkulator.hitungTeks('1 + 1'), '2');
    expect(
      Kalkulator.hitungTeks('zzz'),
      'Ekspresi tidak bisa dihitung.',
    );
  });
}
