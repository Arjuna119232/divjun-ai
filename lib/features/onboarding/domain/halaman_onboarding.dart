/// Isi 3 halaman onboarding. Dipisah dari UI supaya teks bisa diubah tanpa
/// menyentuh animasi.
library;

import 'package:flutter/material.dart';

/// Pose robot. Dipakai sebagai gambar cadangan kalau berkas animasi belum
/// tersedia, jadi tiap halaman tetap punya robot dengan gerak berbeda.
enum PoseRobot { melambai, berpikir, bekerja, mengingat }

/// Ikon baris info (halaman 3). Dipetakan ke LucideIcons di layer UI supaya
/// domain tidak ikut mengimpor paket ikon.
enum IkonInfo { otak, jam, kilau }

/// Satu baris info bergaya kartu kecil (mis. "Konteks percakapan").
class BarisInfo {
  const BarisInfo({required this.ikon, required this.teks});

  final IkonInfo ikon;
  final String teks;
}

class HalamanOnboarding {
  const HalamanOnboarding({
    required this.judul,
    required this.judulAksen,
    required this.subjudul,
    required this.aset,
    required this.pose,
    required this.poin,
    this.kartu = const <BarisInfo>[],
  });

  /// Baris pertama judul (putih).
  final String judul;

  /// Potongan judul bergradien (mis. "jawabannya mengalir").
  final String judulAksen;

  final String subjudul;

  /// Berkas animasi robot (Lottie). Kalau belum ada, UI menggambar robot
  /// dengan [pose] sebagai cadangan - lihat `AsetRobot`.
  final String aset;

  /// Pose gambar cadangan.
  final PoseRobot pose;

  /// Dua atau tiga poin singkat, digabung dengan judul/subjudul sebagai
  /// penjelasan tambahan (bukan bullet panjang yang jadi paragraf).
  final List<String> poin;

  /// Kartu kecil yang tampil DI ATAS judul (hanya halaman 3).
  final List<BarisInfo> kartu;
}

/// Tiga halaman = tiga capability yang benar-benar ada di app, tidak janji
/// kosong. Kalau ada fitur baru, tambah facility di sini, bukan di UI.
///
/// Nama berkas animasi sudah disiapkan di `assets/animations/`. User cukup
/// menaruh file `.json` (atau `.mp4`) dengan nama yang sama; sampai itu ada,
/// robot yang digambar kode yang tampil.
const List<HalamanOnboarding> halamanOnboarding = <HalamanOnboarding>[
  HalamanOnboarding(
    judul: 'Tanya apa saja,',
    judulAksen: 'jawabannya mengalir',
    subjudul:
        'Setiap token tampil seketika. Blok "Berpikir" bisa Anda buka sendiri '
        'kalau mau melihat proses model sebelum jawaban.',
    aset: 'assets/animations/robot_thinking.json',
    pose: PoseRobot.berpikir,
    poin: <String>['Blok berpikir terpisah dari jawaban', 'Riwayat percakapan tersimpan'],
  ),
  HalamanOnboarding(
    judul: 'Agent yang',
    judulAksen: 'benar-benar mengerjakan',
    subjudul:
        'Bukan cuma ngetik. Dia sendiri memilih alat yang perlu dipakai lalu '
        'menjalankannya sampai selesai.',
    aset: 'assets/animations/robot_working.json',
    pose: PoseRobot.bekerja,
    poin: <String>['Kalkulator, web, memori, email', 'Mode agent bisa dimatikan kapan saja'],
  ),
  HalamanOnboarding(
    judul: 'Ingat detail,',
    judulAksen: 'tak perlu diulang',
    subjudul:
        'Hal yang Anda minta diingat disimpan, lalu dipakai lagi di percakapan '
        'berikutnya tanpa perlu Anda jelaskan dari awal.',
    aset: 'assets/animations/robot_memory.json',
    pose: PoseRobot.mengingat,
    poin: <String>['Tersimpan di HP Anda', 'Bisa Anda lihat & hapus kapan saja'],
    kartu: <BarisInfo>[
      BarisInfo(ikon: IkonInfo.otak, teks: 'Yang Anda minta diingat'),
      BarisInfo(ikon: IkonInfo.jam, teks: 'Konteks percakapan'),
      BarisInfo(ikon: IkonInfo.kilau, teks: 'Bisa dihapus kapan saja'),
    ],
  ),
];

/// Warna aksen tiap halaman - dipakai robot, judul bergradien, dan titik aktif.
const List<List<Color>> aksenHalaman = <List<Color>>[
  <Color>[Color(0xFF6E8BFF), Color(0xFF9B6EFF)],
  <Color>[Color(0xFF9B6EFF), Color(0xFF00BFA6)],
  <Color>[Color(0xFF00BFA6), Color(0xFF6E8BFF)],
];