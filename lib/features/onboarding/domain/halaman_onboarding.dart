/// Isi 3 halaman onboarding. Dipisah dari UI supaya teks bisa diubah tanpa
/// menyentuh animasi.
library;

import 'package:flutter/material.dart';

/// Jenis ilustrasi yang digambar kode (tanpa aset gambar).
enum GambarOnboarding { obrolan, orbitAlat, kartuSkill }

class HalamanOnboarding {
  const HalamanOnboarding({
    required this.judul,
    required this.judulAksen,
    required this.subjudul,
    required this.gambar,
    required this.poin,
  });

  /// Baris pertama judul (putih).
  final String judul;

  /// Potongan judul bergradien (mis. "jawabannya mengalir").
  final String judulAksen;

  final String subjudul;
  final GambarOnboarding gambar;

  /// Dua atau tiga poin singkat, digabung dengan judul/subjudul sebagai
  /// penjelasan tambahan (bukan bullet panjang yang jadi paragraf).
  final List<String> poin;

  String get judulLengkap => '$judul $judulAksen';
}

/// Tiga halaman = tiga capability yang benar-benar ada di app, tidak janji
/// kosong. Kalau ada fitur baru, tambah facility di sini, bukan di UI.
const List<HalamanOnboarding> halamanOnboarding = <HalamanOnboarding>[
  HalamanOnboarding(
    judul: 'Tanya apa saja,',
    judulAksen: 'jawabannya mengalir',
    subjudul:
        'Setiap token tampil seketika. Blok "Berpikir" bisa lu buka sendiri '
        'kalau mau lihat proses model sebelum jawaban.',
    gambar: GambarOnboarding.obrolan,
    poin: <String>['Blok berpikir terpisah dari jawaban', 'Riwayat percakapan tersimpan'],
  ),
  HalamanOnboarding(
    judul: 'Agent yang',
    judulAksen: 'benar-benar mengerjakan',
    subjudul:
        'Bukan cuma ngetik. Dia sendiri memilih alat yang perlu dipakai lalu '
        'menjalankannya sampai selesai.',
    gambar: GambarOnboarding.orbitAlat,
    poin: <String>['Kalkulator, web, memori, email', 'Mode agent bisa dimatikan kapan saja'],
  ),
  HalamanOnboarding(
    judul: 'Pustaka skill',
    judulAksen: 'siap pakai',
    subjudul:
        'Skill yang cocok dengan pertanyaan lu disuntik sebagai prosedur kerja '
        '- panduan cara mengerjakan, bukan sumber jawaban siap saji.',
    gambar: GambarOnboarding.kartuSkill,
    poin: <String>['Berjalan lokal, tanpa server', 'Semua skill bisa dibaca & diubah'],
  ),
];

/// Warna aksen tiap halaman - dipakai ilustrasi dan judul bergradien.
const List<List<Color>> aksenHalaman = <List<Color>>[
  <Color>[Color(0xFF00BFA6), Color(0xFF5B5BD6), Color(0xFFFF6B4A)],
  <Color>[Color(0xFF7C4DFF), Color(0xFF00BFA6), Color(0xFF5B5BD6)],
  <Color>[Color(0xFFFFA726), Color(0xFFFF6B4A), Color(0xFF5B5BD6)],
];