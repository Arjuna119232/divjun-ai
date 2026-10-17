import 'package:divjun_ai/core/boot/diagnostik.dart';
import 'package:divjun_ai/data/datasources/penyimpan_lokal.dart';
import 'package:flutter_test/flutter_test.dart';

/// Jaring pengaman boot: penyimpanan cadangan harus selalu bisa dipakai,
/// supaya aplikasi tidak pernah menggantung di layar launch selamanya.
void main() {
  test('SimpanCepit.darurat() menyimpan dan membaca di memori', () async {
    final SimpanCepit s = SimpanCepit.darurat();
    expect(s.sementara, isTrue);
    expect(s.baca('kunci'), isNull);
    await s.tulis('kunci', 'nilai');
    expect(s.baca('kunci'), 'nilai');
    await s.tulis('tanda', 'ya');
    expect(s.bacaBool('tanda'), isTrue);
    await s.hapus('kunci');
    expect(s.baca('kunci'), isNull);
  });

  test('SimpanBerkas.darurat() menulis dan membaca berkas', () async {
    final SimpanBerkas s = SimpanBerkas.darurat();
    expect(s.sementara, isTrue);
    await s.tulis('uji.json', '{"ok":true}');
    expect(s.ada('uji.json'), isTrue);
    expect(await s.baca('uji.json'), contains('ok'));
    expect(await s.ukuran('uji.json'), greaterThan(0));
    await s.hapus('uji.json');
    expect(s.ada('uji.json'), isFalse);
  });

  test('Diagnostik menyimpan pesan terakhir', () {
    Diagnostik.catat(StateError('uji'), null, konteks: 'uji');
    expect(Diagnostik.pesanTerakhir, contains('uji'));
    expect(Diagnostik.riwayat, isNotEmpty);
  });
}
