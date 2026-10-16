---
name: flutter-offline-first-feature-pattern
description: Pola menambah fitur baru ke app Flutter yang offline-first (belum ada backend) supaya tetap terasa nyata tanpa mengarang data palsu — memakai StateNotifier in-memory, payload QR yang benar-benar bisa di-decode, dan modeverdad siftowel administrator dari sisi anggota. Pakai saat menambah layar/fitur ke KARTA KUBAR atau app Flutter offline-first lain.
---

# POLA FITUR OFFLINE-FIRST (tanpa backend)

## Prinsip

Aplikasi belum punya server. Fitur harus **nyata secara lokal** — bukan
tombol kosong, bukan data palsu yang menyamar jadi hasil server.

Yang BISA tanpa backend:
- state in-memory selama sesi (`StateNotifierProvider`)
- QR asli yang payload-nya bisa di-decode ulang (round-trip)
- dua sisi fitur: anggota + penyelenggara/admin
- pencatatan manual + pemindaian tiruan

Yang TIDAK boleh (menipu user):
- mengaku "terhubung ke server" padahal tidak
- mengarang angka statistik dari server
- login/OTP yangDistrict terlihat berhasil padahal tidak dikirim

## 1. Pisahkan model dan state

```
lib/features/<fitur>/domain/<entitas>.dart       model + enum status
lib/features/<fitur>/data/<nama>_state.dart     Notifier + helper payload
lib/features/<fitur>/presentation/<layar>.dart  UI
```

Enum status pakai `switch` expression (Dart 3) + extension label/warna:

```dart
enum Status { hadir, izin, alpha }

extension StatusX on Status {
  String get label => switch (this) {
        Status.hadir => 'Hadir',
        Status.izin  => 'Izin',
        Status.alpha => 'Alpha',
      };
  Color get color => switch (this) { ... };
}
```

## 2. StateNotifierProvider + seed

```dart
class AbsenNotifier extends StateNotifier<List<Kehadiran>> {
  AbsenNotifier() : super(_seed());
}

final absenProvider =
    StateNotifierProvider<AbsenNotifier, List<Kehadiran>>(
        (ref) => AbsenNotifier());
```

Tambahkan `sudahAbsen(...)` supaya pencatatan tidak dobel (idempoten per
kegiatan+tanggal) — penting karena user bisa memindai dua kali.

## 3. QR yang benar-benar round-trip

Jangan pakai QR palsu di situ. Bentuk payload sendiri yang bisa di-parse balik:

```dart
String absenPayload(Activity a) =>
    'karta-kubar://absen/YYYYMMDD/<judul-terencode>';

String? parseAbsenPayload(String p) {
  if (!p.startsWith('karta-kubar://absen/')) return null;
  final bagian = p.substring('karta-kubar://absen/'.length).split('/');
  if (bagian.length < 2) return null;
  return Uri.decodeComponent(bagian[1]);
}
```

Buktikan round-trip di UI: sheet "memindai" mengambil payload →
memanggil `parseAbsenPayload` → menampilkan judul hasil decode.

## 4. Dua sisi: anggota vs penyelenggara

Satu layar dengan mode switch (ikon di `AppBar.actions`):
- **Anggota**: buka "kamera", tempel QR, decode, konfirmasi hadir
- **Penyelenggara**: tampilkan QR (pakai `qr_flutter`) untuk dipindai anggota

Sampaikan terus terang kalau kamera masih simulasi:
`Text('Demo: kamera tidak diaktifkan. Payload QR yang terbaca ditampilkan di bawah.')`

## 5. Jangan paksakan warna lewat context

Kalau sub-widget butuh warna palet, teruskan parameter
(`final Color tint`) daripada mengambil lewat `BuildContext`. Lebih mudah
diuji dan tidak memunculkan import silang.

## Jebakan yang sudah kejadian

- **Typo di dalam string** (misal `kegianatan`) — kompilasi tetap lolos karena
  string bebas. Selalu baca ulang file yang ditulis.
- **Karakter non-Latin bocor ke komentar** dari IME. Scan proyek dengan
  `ord(ch) > 0x2100`. Toleransi nol.
- **Import tak terpakai setelah refactor** (`dart:async`, `go_router`) —
  `flutter analyze` di CI sengaja non-blocking (`|| true`) sehingga tidak
  ketahuan. Bersihkan manual.
- **`ConsumerStatefulWidget` tapi `ref` tidak dipakai** → pakai
  `StatefulWidget` biasa saja.
- **Package baru**: verifikasi dulu benar-benar ada sebelum commit —
  `curl -s https://pub.dev/api/packages/<nama>` lalu cek `latest.version` dan
  `environment`. Menghemat satu putaran CI 5 menit.

## Verifikasi tanpa Flutter SDK di HP

1. Semua import resolve (regex + `os.path.exists`)
2. Kurung `{}/()` seimbang setelah strip komentar + string
3. Tidak ada karakter non-Latin
4. File yang memakai `context.text`/`context.semantic`/`context.colors`
   **wajib** import `theme/app_colors.dart` (extension `AppSemanticX` di sana)
5. Bukti akhir tetap **CI hijau** — satu-satunya pembuktian kompilasi