/// Format tanggal/waktu Bahasa Indonesia tanpa package `intl`
/// (pembacaan lokal perlu inisialisasi terpisah, tidak sebanding risikonya).
library;

abstract final class Waktu {
  static const List<String> _hari = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];
  static const List<String> _hariPendek = [
    'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
  ];
  static const List<String> _bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  static const List<String> _bulanPendek = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  static const List<String> _waktuFmt = [
    'pagi', 'siang', 'sore', 'malam',
  ];

  static String tanggal(DateTime d) =>
      '${d.day} ${_bulan[d.month - 1]} ${d.year}';

  static String tanggalPendek(DateTime d) =>
      '${d.day} ${_bulanPendek[d.month - 1]} ${d.year}';

  static String tanggalPanjang(DateTime d) =>
      '${_hari[d.weekday - 1]}, ${tanggal(d)}';

  static String jam(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String jamDetik(DateTime d) =>
      '${jam(d)}:${d.second.toString().padLeft(2, '0')}';

  static String waktu(DateTime d) => '${jam(d)} WIB';

  static String hariIni() => tanggalPanjang(DateTime.now());

  static String salam(DateTime d) {
    final int h = d.hour;
    if (h < 11) return 'Selamat ${_waktuFmt[0]}';
    if (h < 15) return 'Selamat ${_waktuFmt[1]}';
    if (h < 18) return 'Selamat ${_waktuFmt[2]}';
    return 'Selamat ${_waktuFmt[3]}';
  }

  /// "3 menit lalu", "2 jam lalu", "kemarin", "12 Mar 2026".
  static String relatif(DateTime d) {
    final DateTime sekarang = DateTime.now();
    final Duration selisih = sekarang.difference(d);
    if (selisih.inSeconds < 45) return 'baru saja';
    if (selisih.inMinutes < 60) return '${selisih.inMinutes} menit lalu';
    if (selisih.inHours < 24) return '${selisih.inHours} jam lalu';
    if (selisih.inDays == 1) return 'kemarin';
    if (selisih.inDays < 7) return '${selisih.inDays} hari lalu';
    return tanggalPendek(d);
  }

  /// "14:05" untuk bubble chat, atau tanggal kalau sudah beda hari.
  static String labelBesar(DateTime d) {
    final DateTime sekarang = DateTime.now();
    final bool bedaTahun = d.year != sekarang.year;
    final bool bedaHari = DateTime(d.year, d.month, d.day) !=
        DateTime(sekarang.year, sekarang.month, sekarang.day);
    if (bedaTahun) return tanggalPendek(d);
    if (bedaHari) return '${_hariPendek[d.weekday - 1]}, ${tanggalPendek(d)}';
    return jam(d);
  }

  static String iso(DateTime d) => d.toIso8601String();

  /// Durasi dalam Bahasa Indonesia: "840 ms", "2,4 detik", "1 menit 5 detik".
  static String durasi(int milidetik) {
    if (milidetik < 1000) return '$milidetik ms';
    final double detik = milidetik / 1000;
    if (milidetik < 60000) {
      final String teks = detik.toStringAsFixed(1).replaceAll('.', ',');
      return '$teks detik';
    }
    final int menit = milidetik ~/ 60000;
    final int sisaDetik = (milidetik % 60000) ~/ 1000;
    return '$menit menit $sisaDetik detik';
  }
}
