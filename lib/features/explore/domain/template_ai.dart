import 'package:flutter/material.dart';

/// Satu ide template AI dari https://github.com/Shubhamsaboo/awesome-llm-apps.
///
/// `promptStarter` adalah teks pembuka yang disalin ke papan klip lalu
/// ditempel di kolom chat DIVJUN AI untuk mencoba ide itu.
class IdeTemplate {
  const IdeTemplate({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.kategori,
    required this.ikon,
    required this.link,
    this.promptStarter,
  });

  final String id;
  final String judul;
  final String deskripsi;
  final String kategori;
  final IconData ikon;
  /// https://github.com/Shubhamsaboo/awesome-llm-apps/tree/main/<path>
  final String link;
  final String? promptStarter;
}
