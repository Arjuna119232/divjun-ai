import 'dart:math';

/// Id pendek tanpa package uuid.
abstract final class Id {
  static final Random _r = Random();
  static const String _abjad = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String pendek([int panjang = 10]) {
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < panjang; i++) {
      b.write(_abjad[_r.nextInt(_abjad.length)]);
    }
    return b.toString();
  }
}
