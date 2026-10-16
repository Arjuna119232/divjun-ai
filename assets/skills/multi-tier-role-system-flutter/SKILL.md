---
name: multi-tier-role-system-flutter
description: Cara membangun sistem akses berjenjang (mis. 5 level: guest/warga/anggota/pengurus/admin) di aplikasi Flutter — enum role dengan level hierarchy, Session provider yang memuat user+role, bottom navigation yang berubah per role, dan route guard. Pakai saat aplikasi punya beberapa tingkat akses dan tabnya berbeda tiap level.
---

# SISTEM AKSES BERJENJANG DI FLUTTER

Pola ini dipakai KUBAR Connect (5 level). Berlaku untuk app apa pun yang
tab/menunya berbeda menurut hak akses.

## 1. Enum role dengan level numerik

`level` = indeks enum, jadi perbandingan cukup satu angka.

```dart
enum UserRole { guest, warga, anggota, pengurus, admin }

extension UserRoleX on UserRole {
  int get level => index;                 // 0..4
  bool bisa(UserRole minimal) => level >= minimal.level;
  bool get perluLogin => this != UserRole.guest;
  String get label => switch (this) { ... };
  Color get warna => switch (this) { ... };
  IconData get ikon => switch (this) { ... };
  List<String> get hakAkses => switch (this) { ... };
}
```

Urutan enum WAJIB dari yang terendah ke tertinggi — itu yang membuat
`level` bermakna.

## 2. Session = user + role (bukan dua provider terpisah)

```dart
@immutable
class Session {
  const Session({this.user, this.role = UserRole.guest});
  final AuthUser? user;
  final UserRole role;

  bool get sudahLogin => user != null;

  // Kalau belum login, role SELALU guest.
  UserRole get efektif => user == null
      ? UserRole.guest
      : (role == UserRole.guest ? UserRole.warga : role);
}
```

Penting: `efektif` mencegah bug saat UI menampilkan
"Pengurus" padahal user belum login sama sekali.

## 3. Persistensi role

Simpan di `SharedPreferences` dengan **nama** (`.name`), bukan indeks —
indeks berubah kalau enum diurut ulang.

```dart
await prefs.setString('kubar_role', roleToDb(role));   // role.name
final saved = UserRole.values.asNameMap()[tersimpan];  // baca balik
```

`asNameMap()` aman untuk nilai yang tidak dikenal (balas null, bukan crash).

## 4. Bottom navigation per role

Pisahkan **definisi tab** dari **shell**:

```
features/shell/data/app_tabs.dart        <- data: List<AppTab> tabsUntuk(role)
features/shell/presentation/app_shell.dart <- UI
```

```dart
class AppTab {
  final String label;
  final IconData icon, selectedIcon;
  final Widget screen;
  final UserRole minimalRole;
  final int? badge;
}

List<AppTab> tabsUntuk(UserRole role) {
  final dasar = <AppTab>[Beranda, Kegiatan];
  if (role.bisa(UserRole.anggota)) {
    dasar.insert(1, const AppTab(label: 'Absen', ..., minimalRole: UserRole.anggota));
  }
  dasar.add(Profil);
  return dasar;
}
```

### Jebakan indeks saat role berubah

Kalau user ganti role dari Tamu ke Anggota, jumlah tab berubah dan
`navigationIndexProvider` bisa menunjuk indeks yang tidak ada →
`RangeError` saat render. WAJIB clamp:

```dart
final int aman = index.clamp(0, tabs.length - 1);
```

Dan reset ke 0 setiap kali role berubah.

### Pakai IndexedStack

`IndexedStack(index: aman, children: [...])` menjaga scroll position tiap
tab. Kalau pakai `body: tabs[aman].screen`, scroll hilang tiap pindah tab.

## 5. Route guard

```dart
class RoleGate extends ConsumerWidget {
  final UserRole minimal;
  final Widget child;
  // ...
  if (!session.sudahLogin || !session.efektif.bisa(minimal)) {
    return AksesDitolakScreen(minimal: minimal);
  }
  return child;
}
```

Daftarkan di router:
```dart
GoRoute(path: '/absen', builder: (_, __) =>
    const RoleGate(minimal: UserRole.anggota, child: AbsenScreen()))
```

**PENTING:** guard aplikasi ini hanya untuk UX. Keamanan asli WAJIB
ditegakkan di server lewat **Row Level Security**. Guard client bisa
dibypass dengan memeriksa APK. Jangan tulis di dokumentasi bahwa guard
ini "mengamankan" data.
ditegakkan di server lewat **Row Level Security**. Guard client bisa
dibypass dengan memeriksa APK. Jangan tulis di dokumentasi bahwa guard
ini "mengamankan" data.

## 6. Role switcher untuk preview

Saat belum ada backend yang mengeset role, sediakan switcher di Profil
agar semua level bisa dilihat:

```dart
if (r == UserRole.guest) { ctrl.keluar(); } else { ctrl.simpanRole(r); }
```

Labeli sebagai "Preview level akses" + *"Alat bantu developer, nanti diganti
verifikasi dari pengurus"* supaya tidak disalahartikan fitur produksi.

## 7. Jebakan yang harus dihindari

- Dua provider terpisah (`userProvider` + `roleProvider`) bisa tidak sinkron
  (user logout tapi role masih Admin).
- Menyimpan indeks enum, bukan `.name`.
- Lupa clamp indeks tab.
  Guard client hanya untuk UX; masalah keamanan ada di server.
- Membiarkan role `guest` aktif padahal `user == null`.