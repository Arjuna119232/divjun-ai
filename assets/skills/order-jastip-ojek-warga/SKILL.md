---
name: order-jastip-ojek-warga
description: Cara membangun fitur Order Jastip & Ojek di APK KUNBAR Connect warga - peta gratis any_map+MapLibre, service yang bisa dipakai ulang oleh APK Mitra, dan jebakan Flutter/Riverpod yang hanya ketahuan oleh flutter analyze
metadata:
  type: project
---

# Order Jastip & Ojek - APK Warga (16 Okt 2026, v0.13.0+25)

Branch `feat/order-jastip-ojek`. Hasil akhir: **0 error, 0 warning** di
`flutter analyze`, APK universal 96 MB.

## Yang benar dari brief, dan yang harus dikoreksi

| Brief bilang | Kenyataan | Yang dipakai |
|---|---|---|
| `version: 6.1.0+7` | Proyek ini 0.12.2+24 | `0.13.0+25` |
| `users(id)` | Skema pakai `public.profiles(id)`, bukan `users` | FK ke `public.profiles` |
| `geolocator: ^13.0.1` | 13.x ganti `getCurrentPosition` ke `locationSettings` | `^12.0.0` + `desiredAccuracy` (sudah terbukti di APK Mitra) |
| `flutter doctor -v`, `dart format`, `--split-per-abi` | Flutter tidak ada di Termux; user minta ukuran tidak jadi masalah | analyze-only via CI + APK universal |
| `freezed` / `json_serializable` | `build_runner` tidak bisa jalan di HP, file `.g.dart` tidak pernah tercipta | model Dart biasa + `dari(Map)` / `keBaris()` |
| "Realtime" | APK belum punya sesi Supabase Auth, jadi tidak ada kredensial untuk WebSocket | polling tiap 8-10 detik lewat `StreamProvider`, abstracted di `TrackingService` |

## Peta gratis: API yang benar

- Style: `https://tiles.openfreemap.org/styles/liberty` (200 OK).
  `https://openfreemap.org/style.json` yang sering muncul di tutorial = **404**.
- `MapLibreAdapter({styleUrl})` adalah constructor **bukan const**.
- API any_map 1.0.0: `AnyMapWidget(adapter:, initialCamera: AnyCameraPosition(
  target: AnyLatLng(lat,lng), zoom:), markers: [AnyMarker(id:, position:,
  anchor: AnyMarkerAnchor.center, icon: Widget)], polylines: [AnyPolyline(id:,
  points:, color:, width:)], myLocationEnabled:, myLocationButtonEnabled:)`.
  TIDAK ada `AnyMapOptions` / `AnyMapMarker` / `children:` seperti yang dikira orang.
- `any_map_maplibre` -> `maplibre_gl ^0.25.0` -> **wajib Java 21** di CI.
  Java 17 gagal dengan `invalid source release: 21`.
- Geocoding: `https://photon.komoot.io/api?q=...&limit=6&lang=id` (keyless).
- Routing: `https://router.project-osrm.org/route/v1/foot/lng,lat;lng,lat`
  (keyless). Selalu ada cadangan haversine + label jujur "perkiraan kasar".

## 6 jebakan Dart yang hanya ketahuan `flutter analyze`

1. **`StringBuilder` tidak ada di Dart.** Yang benar `StringBuffer`.
2. **`AsyncValue.guard` belum ada di riverpod 2.5** (baru di 3.x). Pakai
   try/catch + `AsyncValue.data/error`.
3. **`final StreamProvider.autoDispose.family<X, Y>` sebagai anotasi TIPE**
   gagal di-parse (error: `Undefined class 'family'`, `getter 'autoDispose' isn't
   defined`). Tulis provider tanpa anotasi tipe, biarkan inferensi.
4. **Field widget publik tidak bisa di-promote** oleh null-check. Field
   **privat final** bisa (Dart 3.2+). Solusi: `const X({Ik? ikon}) : _ikon = ikon;`
5. **Fungsi `async*` harus balik `Stream<T>`, bukan `Future<T>`.**
6. **`context.colors` itu `ColorScheme`, bukan `AppColors`.** Token app
   (`accent`, `info`, `warning`, `success`, `social`) harus `AppColors.accent`.
   `context.colors.primary` / `.error` / `.onSurface` memang valid.

## Jebakan `dart fix --apply` di CI

Menjalankan `dart fix --apply` sebelum analyze **memperbaiki lint tapi
memicu bug baru**: `no_leading_underscores_for_local_identifiers` mengganti
`_ikon` lokal menjadi `ikon`, lalu menutupi field `ikon` -> build gagal
`referenced_before_declaration`. Aturan: kalau sebuah variabel lokal
memakai nama yang sama dengan field, itu salah sejak awal - pakai field
privat final, bukan lokal.

## Jejak pengiriman

```
1. lib/shared/models/    order, order_jastip, order_ojek, mitra_jasa,
                         order_tracking, review_order, order_ringkas
2. lib/shared/services/  lokasi_service, tarif_service, tracking_service,
                         order_repository, order_service_base,
                         jastip_service, ojek_service, review_service
3. lib/features/order/   data/order_state.dart + presentation/ (7 layar)
4. lib/core/router.dart  8 rute, semua RoleGate(minimal: warga)
5. home_screen.dart      menu besar + Order Berjalan + 2 aksi cepat
6. tool/patch_android.sh ACCESS_FINE_LOCATION + ACCESS_COARSE_LOCATION
7. .github/workflows     Java 21, analyze-only input, analyze blocking
```

## `warga_id` dan login yang belum Supabase Auth

Order masih disimpan di perangkat (`OrderLokal`, SharedPreferences). Skema
sudah siap: `warga_id uuid references public.profiles(id)` **nullable** plus
`warga_kunci text` stabil per perangkat. RLS sekarang ditulis untuk
`auth.uid()`, jadi sinkron otomatis nyalakan begitu login Supabase benar-benar
dipakai. Jangan menulis policy yang "mengizinkan" anon menulis order - itu
membuat tabel publik bisa penuh spam.