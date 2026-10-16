/// Parser ekspresi matematika yang aman (tanpa `eval`).
///
/// Mendukung: + - * / % ^ ( ), unary minus, fungsi (sqrt, sin, cos, tan, asin,
/// acos, atan, log, ln, exp, abs, round, floor, ceil), konstanta (pi, e),
/// persen (`5%` = 0.05), pemisah ribuan (`1.000,5` = 1000.5).
///
/// Parser = recursive descent (precedence climbing), jadi tidak ada string
/// yang dieksekusi dan tidak ada celah kode injeksi.
library;

import 'dart:math' as math;

abstract final class Kalkulator {
  /// Kembalikan null kalau ekspresi tidak valid (bukan string error panjang).
  static double? hitung(String ekspresi) {
    try {
      final _Lexer lex = _Lexer(ekspresi);
      final List<_Token> token = lex.lex();
      if (token.isEmpty) return null;
      final _Parser p = _Parser(token);
      final double hasil = p.ekspresi();
      if (!hasil.isFinite) return null;
      p.sPastiAkhir();
      return hasil;
    } catch (_) {
      return null;
    }
  }

  /// Versi yang selalu mengembalikan teks siap tampil.
  static String hitungTeks(String ekspresi) {
    final double? v = hitung(ekspresi);
    if (v == null) return 'Ekspresi tidak bisa dihitung.';
    return format(v);
  }

  static String format(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e15) {
      final String s = v.toStringAsFixed(0);
      return kelompokRibuan(s);
    }
    String s = v.toStringAsFixed(6);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    final List<String> bagian = s.split('.');
    return '${kelompokRibuan(bagian.first)}.${bagian.length > 1 ? bagian[1] : ''}';
  }

  static String kelompokRibuan(String angka) {
    final bool negatif = angka.startsWith('-');
    final String isi = negatif ? angka.substring(1) : angka;
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < isi.length; i++) {
      if (i > 0 && (isi.length - i) % 3 == 0) b.write('.');
      b.write(isi[i]);
    }
    return '${negatif ? '-' : ''}$b';
  }
}

enum _Jenis { angka, iden, operasi, kurungBuka, kurungTutup, koma, persen }

class _Token {
  const _Token(this.jenis, this.teks);

  final _Jenis jenis;
  final String teks;

  /// "1.000" -> 1000 (pemisah ribuan gaya Indonesia), "1.5" -> 1.5.
  /// Aturannya: satu titik + tepat 3 digit di belakang + bagian depan
  /// maksimal 3 digit = pemisah ribuan. Selain itu titik = desimal.
  double get nilai {
    if (jenis != _Jenis.angka) return 0;
    if (!teks.contains('.')) return double.tryParse(teks) ?? 0;
    final List<String> bagian = teks.split('.');
    if (bagian.length > 2) return double.tryParse(bagian.join()) ?? 0;
    if (bagian.length == 2 &&
        bagian[1].length == 3 &&
        bagian[0].length <= 3) {
      final double? gabung = double.tryParse('${bagian[0]}${bagian[1]}');
      if (gabung != null) return gabung;
    }
    return double.tryParse(teks) ?? 0;
  }
}

class _Lexer {
  _Lexer(String sumber) {
    _s = sumber.toLowerCase().replaceAll(' ', '');
    // Koma sebagai desimal kalau diikuti angka DAN belum ada titik desimal di
    // token yang sama (kasus "1.234,56").
    _s = _normalisasiDesimal(_s);
  }

  late final String _s;
  int _i = 0;

  String _normalisasiDesimal(String masuk) {
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < masuk.length; i++) {
      final String c = masuk[i];
      if (c != ',') {
        b.write(c);
        continue;
      }
      final bool angkaSebelum = i > 0 && _angka(masuk[i - 1]);
      final bool angkaSesudah = i + 1 < masuk.length && _angka(masuk[i + 1]);
      if (angkaSebelum && angkaSesudah) {
        b.write('.');
      } else {
        b.write(',');
      }
    }
    return b.toString();
  }

  static bool _angka(String c) {
    final int? v = int.tryParse(c);
    return v != null;
  }

  List<_Token> lex() {
    final List<_Token> out = <_Token>[];
    while (_i < _s.length) {
      final String c = _s[_i];
      if (_angka(c) || c == '.') {
        final int mulai = _i;
        while (_i < _s.length && (_angka(_s[_i]) || _s[_i] == '.')) {
          _i++;
        }
        out.add(_Token(_Jenis.angka, _s.substring(mulai, _i)));
        continue;
      }
      if (_huruf(c)) {
        final int mulai = _i;
        while (_i < _s.length && (_huruf(_s[_i]))) {
          _i++;
        }
        out.add(_Token(_Jenis.iden, _s.substring(mulai, _i)));
        continue;
      }
      if (c == '%') {
        _i++;
        out.add(const _Token(_Jenis.persen, '%'));
        continue;
      }
      if ('+-*/^'.contains(c)) {
        _i++;
        out.add(_Token(_Jenis.operasi, c));
        continue;
      }
      if (c == '(') {
        _i++;
        out.add(const _Token(_Jenis.kurungBuka, '('));
        continue;
      }
      if (c == ')') {
        _i++;
        out.add(const _Token(_Jenis.kurungTutup, ')'));
        continue;
      }
      if (c == ',') {
        _i++;
        out.add(const _Token(_Jenis.koma, ','));
        continue;
      }
      throw FormatException('karakter tidak dikenal: $c');
    }
    return out;
  }

  static bool _huruf(String c) {
    final int k = c.codeUnitAt(0);
    return (k >= 97 && k <= 122);
  }
}

class _Parser {
  _Parser(this.token);

  final List<_Token> token;
  int _p = 0;

  _Token _peek() =>
      _p < token.length ? token[_p] : const _Token(_Jenis.kurungTutup, '');

  bool _bisa(String t) =>
      _p < token.length && token[_p].teks == t && token[_p].jenis == _Jenis.operasi;

  void _makan(String t) {
    if (_bisa(t)) {
      _p++;
    } else {
      throw FormatException('harus ada $t');
    }
  }

  void sPastiAkhir() {
    if (_p != token.length) {
      throw FormatException('ada sisa ekspresi');
    }
  }

  double ekspresi() {
    double nilai = ekspresiTambah();
    while (_bisa('^')) {
      _makan('^');
      // pangkat associates ke kanan
      final double pangkat = ekspresiTambah();
      nilai = math.pow(nilai, pangkat).toDouble();
    }
    return nilai;
  }

  double ekspresiTambah() {
    double nilai = ekspresiKali();
    while (_bisa('+') || _bisa('-')) {
      final String op = token[_p].teks;
      _makan(op);
      final double kanan = ekspresiKali();
      nilai = op == '+' ? nilai + kanan : nilai - kanan;
    }
    return nilai;
  }

  double ekspresiKali() {
    double nilai = ekspresiUnary();
    while (_bisa('*') || _bisa('/')) {
      final String op = token[_p].teks;
      _makan(op);
      final double kanan = ekspresiUnary();
      if (op == '/') {
        if (kanan == 0) throw FormatException('bagi dengan nol');
        nilai = nilai / kanan;
      } else {
        nilai = nilai * kanan;
      }
    }
    return nilai;
  }

  double ekspresiUnary() {
    if (_bisa('-')) {
      _makan('-');
      return -ekspresiUnary();
    }
    if (_bisa('+')) {
      _makan('+');
      return ekspresiUnary();
    }
    return ekspresiPersen();
  }

  double ekspresiPersen() {
    double nilai = ekspresiAwal();
    while (_peek().jenis == _Jenis.persen) {
      _p++;
      nilai = nilai / 100;
    }
    return nilai;
  }

  double ekspresiAwal() {
    final _Token t = _peek();
    if (t.jenis == _Jenis.angka) {
      _p++;
      return t.nilai;
    }
    if (t.jenis == _Jenis.kurungBuka) {
      _p++;
      final double v = ekspresi();
      if (_peek().jenis != _Jenis.kurungTutup) {
        throw FormatException('kurung tidak tertutup');
      }
      _p++;
      return v;
    }
    if (t.jenis == _Jenis.iden) {
      _p++;
      return _nilaiIden(t.teks);
    }
    if (t.jenis == _Jenis.operasi && t.teks == '-') {
      _makan('-');
      return -ekspresiUnary();
    }
    throw FormatException('ekspresi tidak lengkap');
  }

  double _nilaiIden(String nama) {
    // fungsi: nama(
    if (_peek().jenis == _Jenis.kurungBuka) {
      _p++;
      final double a = ekspresi();
      double b = 0;
      if (_peek().jenis == _Jenis.koma) {
        _p++;
        b = ekspresi();
      }
      if (_peek().jenis != _Jenis.kurungTutup) {
        throw FormatException('kurung fungsi tidak tertutup');
      }
      _p++;
      return _fungsi(nama, a, b);
    }
    switch (nama) {
      case 'pi':
        return math.pi;
      case 'e':
        return math.e;
      case 'tau':
        return math.pi * 2;
      default:
        throw FormatException('nilai tidak dikenal: $nama');
    }
  }

  double _fungsi(String nama, double a, double b) {
    switch (nama) {
      case 'sqrt':
      case 'akar':
        if (a < 0) throw FormatException('akar dari bilangan negatif');
        return math.sqrt(a);
      case 'sin':
        return math.sin(a);
      case 'cos':
        return math.cos(a);
      case 'tan':
        return math.tan(a);
      case 'asin':
        return math.asin(a);
      case 'acos':
        return math.acos(a);
      case 'atan':
        return math.atan(a);
      case 'log':
        return math.log(a) / math.ln10; // basis 10
      case 'ln':
        return math.log(a); // basis e
      case 'exp':
        return math.exp(a);
      case 'abs':
        return a.abs();
      case 'round':
        return a.roundToDouble();
      case 'floor':
        return a.floorToDouble();
      case 'ceil':
        return a.ceilToDouble();
      case 'pow':
        return math.pow(a, b).toDouble();
      case 'hypot':
        return math.sqrt(a * a + b * b);
      case 'min':
        return math.min(a, b);
      case 'max':
        return math.max(a, b);
      case 'mod':
        if (b == 0) throw FormatException('modulo dengan nol');
        return a % b;
      default:
        throw FormatException('fungsi tidak dikenal: $nama');
    }
  }
}
