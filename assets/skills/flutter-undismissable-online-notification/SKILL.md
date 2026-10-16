---
name: flutter-undismissable-online-notification
description: Cara bikin notifikasi status "ONLINE" yang tidak bisa di-swipe di app Flutter (driver/mitra/kurir) — pakai foreground service geolocator dengan setOngoing:true, plus fallback kalau izin lokasi ditolak. Termasuk jebakan API geolocator 12 vs 13 dan cara build-nya di Termux via GitHub Actions.
---

# Notifikasi permanen saat status ONLINE (Flutter, tanpa plugin tambahan)

## Permintaan yang memakai skill ini
"klo mitra/driver klik online ada notifikasi yang tidak bisa dihapus kecuali ia
nonaktifkan status online-nya".

## Kenapa harus pakai foreground service

Notifikasi biasa dari `flutter_local_notifications` **bisa di-swipe** dan akan hilang.
Satu-satunya cara baku Android supaya notifikasi benar-benar nempel adalah
**foreground service** — notifikasi-nya otomatis `FLAG_ONGOING_EVENT`.

Yang perlu diketahui: **plugin `geolocator` sudah punya service foreground-nya sendiri**.
Jadi tidak perlu `flutter_foreground_task`, tidak perlu Kotlin, tidak perlu plugin baru.

## Resep (geolocator 12.x)

```dart
_sub = Geolocator.getPositionStream(
  locationSettings: AndroidSettings(
    accuracy: LocationAccuracy.low,
    distanceFilter: 100,                       // idle: hemat baterai
    intervalDuration: const Duration(seconds: 30),
    foregroundNotificationConfig: ForegroundNotificationConfig(
      notificationTitle: 'KUNBAR Mitra • Sedang ONLINE',
      notificationText: 'Buka aplikasi lalu tekan OFFLINE untuk berhenti.',
      notificationChannelName: 'Status ONLINE',
      setOngoing: true,                        // <-- tidak bisa di-swipe
      enableWakeLock: false,
    ),
  ),
).listen(onPos, onError: (_) {});
```

Hilang hanya saat `_sub.cancel()` (ONLINE → OFFLINE / keluar / logout).

## Manifest (Android 14+ wajib)

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<service android:name="com.baseflow.geolocator.GeolocatorLocationService"
         android:foregroundServiceType="location"
         android:exported="false"/>
```

## Fallback wajib: izin lokasi ditolak

Kalau user menolak izin lokasi, **service GPS tidak bisa start** (Android 14 melempar
SecurityException) → tidak ada notifikasi sama sekali, user mengira fiturnya rusak.
Solusi: notifikasi lokal dengan `ongoing: true` (tetap tidak bisa di-swipe):

```dart
_plugin.show(999001, 'KUNBAR Mitra • Sedang ONLINE',
  'Buka aplikasi lalu tekan OFFLINE untuk berhenti.',
  const NotificationDetails(android: AndroidNotificationDetails(
    'online_status', 'Status ONLINE',
    ongoing: true, autoCancel: false, onlyAlertOnce: true,
    importance: Importance.low, priority: Priority.low,
    category: AndroidNotificationCategory.service,
  )));
```

`_plugin.cancel(999001)` saat OFFLINE. Gunakan **satu id tetap** supaya tidak menumpuk.

## Jebakan yang sudah kejadian (jangan ulangi)

1. **`geolocator` 12 ≠ 13.** `getCurrentPosition(locationSettings: ...)` **TIDAK ADA**
   di 12.x (yang pakai `geolocator_android ^4.3.0`) → compile error
   `undefined_named_parameter`. Yang benar: `getCurrentPosition(desiredAccuracy: ...)`.
   `locationSettings` baru ada di geolocator 13+.
   Verifikasi versi: `https://pub.dev/api/packages/geolocator` → cek `geolocator_android`.
2. **Sampling harus adaptif**, jangan 30 m/10 s terus-menerus saat idle - boros baterai
   dan user akan protes. Idle 100 m/30 s, ada order aktif 30 m/10 s.
3. **Restart hanya saat perlu.** Panggil `startOnline()` tiap perubahan state → jangan
   `stop()`+`start()` kalau mode & order id sama (kills service, bikin notifikasi berkedip).
   Simpan `_aktifOrder` + `_orderId`; kalau sama, return true tanpa apa-apa.
4. **`ForegroundNotificationConfig` yang-danger params:** `setOngoing` (bukan `ongoing`),
   `enableWakeLock` (bukan `wakeLock`), `enableWifiLock`. Salah nama = compile error.
5. **Channel notifikasi diberi nama sendiri** (`notificationChannelName`) - kalau
   bawaan `Background Location` yang muncul di Pengaturan HP, nama app-nya kelihatan aneh.
6. Android 13+: kalau izin notifikasi ditolak, foreground service tetap jalan tapi
   notifikasinya tidak terlihat — tetap minta izin notifikasi saat init.

## Contoh nyata (KUNBAR Mitra)
`apps/mitra/lib/services/location_service.dart` (`startOnline/stop`) +
`apps/mitra/lib/state/app_state.dart` (`_startLokasi/_stopLokasi`, dipanggil dari
`setOnline`) + `notification_service.dart` (`showOnlineStatus/cancelOnlineStatus`).
Build: GitHub Actions, `flutter build apk --release --target-platform android-arm64`,
package `id.kunbar.kunbar_mitra` → bisa berdampingan dengan app warga.

## Build dari HP (tanpa Flutter lokal)
`flutter` tidak ada di Termux → push branch terpisah (jangan `main`, build utama ikut jalan)
lalu `gh run watch`, `gh run download -n <artifact> -D <dir>`, salin ke Download pakai
`setsid cp ... & disown` + polling `stat -c %s` (FUSE di /storage sering timeout).
