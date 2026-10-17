import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:divjun_ai/data/datasources/klien_llm.dart';
import 'package:divjun_ai/data/models/chat_api.dart';
import 'package:divjun_ai/domain/entities/model_ai.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uji integrasi jalur streaming dengan adapter HTTP palsu.
///
/// Kenapa wajib: bug 17 Okt 2026 - dengan `ResponseType.stream`, `response.data`
/// adalah objek **ResponseBody**, bukan Stream. Memaksanya `as Stream<List<int>>`
/// membuat SETIAP jawaban gagal saat runtime, dan `flutter analyze` TIDAK
/// menangkapnya. Test ini memancing respons sungguhan lewat adapter, jadi kelas
/// bug ini ketahuan di CI bukan di HP user.
void main() {
  const ModelAi model = ModelAi(
    id: 'openai/gpt-oss-20b',
    label: 'GPT-OSS 20B',
    penyedia: PenyediaModel.groq,
    dukungAlat: true,
  );

  KlienLlm klienDengan(String? body, {int status = 200}) {
    final Dio dio = Dio()..httpClientAdapter = _StubAdapter(body, status);
    return KlienLlm(dio: dio, kunciGroq: 'gsk_test');
  }

  group('stream chat', () {
    test('potongan SSE dipecah jadi token per potongan', () async {
      final KlienLlm k = klienDengan(
        'data: {"choices":[{"delta":{"content":"Halo"}}]}\n\n'
        'data: {"choices":[{"delta":{"content":" dunia"}}]}\n\n'
        'data: [DONE]\n\n',
      );

      final List<PotonganBalasan> hasil = await k
          .stream(
            model: model,
            pesan: <PesanApi>[
              const PesanApi(peran: 'user', isi: 'halo'),
            ],
            suhu: 0.5,
          )
          .toList();

      final String teks = hasil.map((PotonganBalasan p) => p.teks).join();
      expect(hasil.first.galat, isEmpty, reason: 'galat: ${hasil.first.galat}');
      expect(teks, 'Halo dunia');
      expect(hasil.last.selesai, isTrue);
    });

    test('tool_call terakumulasi dari beberapa potongan', () async {
      final KlienLlm k = klienDengan(
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1",'
        '"function":{"name":"kalkulator","arguments":"{\\"ekspresi\\":"}}]}}]}\n\n'
        'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
        '"function":{"arguments":"\\"1+1\\"}"}}]}}]}\n\n'
        'data: [DONE]\n\n',
      );

      final List<PotonganBalasan> hasil = await k
          .stream(
            model: model,
            pesan: <PesanApi>[const PesanApi(peran: 'user', isi: '1+1')],
            suhu: 0.2,
          )
          .toList();

      final List<PanggilanAlat> alat = <PanggilanAlat>[];
      for (final PotonganBalasan p in hasil) {
        alat.addAll(p.alat);
      }
      expect(alat, hasLength(1));
      expect(alat.first.nama, 'kalkulator');
      expect(alat.first.argumen, '{"ekspresi":"1+1"}');
      expect(alat.first.sah, isTrue);
      expect(alat.first.argumenMap()['ekspresi'], '1+1');
    });

    test('kunci kosong ditolak tanpa menyentuh jaringan', () async {
      final KlienLlm k = KlienLlm(
        dio: Dio()..httpClientAdapter = _StubAdapter('data: [DONE]\n\n', 200),
        kunciGroq: '',
      );
      final List<PotonganBalasan> hasil = await k
          .stream(
            model: model,
            pesan: <PesanApi>[const PesanApi(peran: 'user', isi: 'halo')],
            suhu: 0.5,
          )
          .toList();
      expect(hasil.first.galat, contains('API key'));
      expect(hasil.first.kodeGalat, KodeGalat.kunciDitolak);
    });

    test('galat 404 "model tidak ada" diklasifikasi dengan benar', () async {
      final KlienLlm k = klienDengan(
        '{"error":{"message":"The model does not exist"}}',
        status: 404,
      );
      final List<PotonganBalasan> hasil = await k
          .stream(
            model: model,
            pesan: <PesanApi>[const PesanApi(peran: 'user', isi: 'halo')],
            suhu: 0.5,
          )
          .toList();
      expect(hasil.first.kodeGalat, KodeGalat.modelTidakAda);
      expect(hasil.first.galat.toLowerCase(), contains('model'));
    });

    test('galat 403 "butuh paket berbayar" dijelaskan ke user', () async {
      final KlienLlm k = klienDengan(
        '{"error":{"message":"This model requires a paid plan"}}',
        status: 403,
      );
      final List<PotonganBalasan> hasil = await k
          .stream(
            model: model,
            pesan: <PesanApi>[const PesanApi(peran: 'user', isi: 'halo')],
            suhu: 0.5,
          )
          .toList();
      expect(hasil.first.kodeGalat, KodeGalat.kunciDitolak);
      expect(hasil.first.galat, contains('berbayar'));
    });

    test('sekali() merangkai teks penuh', () async {
      final KlienLlm k = klienDengan(
        'data: {"choices":[{"delta":{"content":"O"}}]}\n\n'
        'data: {"choices":[{"delta":{"content":"K"}}]}\n\n'
        'data: [DONE]\n\n',
      );
      final HasilBalasan hasil = await k.sekali(
        model: model,
        pesan: <PesanApi>[const PesanApi(peran: 'user', isi: 'halo')],
        suhu: 0.1,
      );
      expect(hasil.galat, isEmpty);
      expect(hasil.teks, 'OK');
    });
  });
}

/// Adapter HTTP palsu: mengembalikan [ResponseBody] persis seperti Dio
/// PENTING: yang dikembalikan WAJIB `ResponseBody` (bukan `Stream`), supaya test
/// memverifikasi jalur yang benar-benar rusak di aplikasi.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, this.status);

  final String body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}