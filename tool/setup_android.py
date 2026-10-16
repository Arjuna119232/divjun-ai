#!/usr/bin/env python3
"""Siapkan folder android/ untuk proyek Flutter.

Kenapa skrip, bukan commit manual: folder `android/` di-generate ulang oleh
`flutter create` di tiap build, jadi semua patching harus otomatis + idempoten.
Tanda tangan rilis juga diinjeksi di sini (keystore TIDAK pernah di repo).

Pemakaian (di CI):
    flutter create --org com.divjun --project-name ai --platforms=android /tmp/scaffold
    cp -r /tmp/scaffold/android .
    python3 tool/setup_android.py

Pemeriksaan saja (tanpa menulis):
    python3 tool/setup_android.py --verify-only
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"

PACKAGE = "com.divjun.ai"
APP_NAME = "DIVJUN AI"
MIN_SDK = 24
TARGET_SDK = 35
BRAND_HEX = "5B5BD6"
BRAND_NIGHT = "0B0B10"
MARK = "# DIVJUN-SETUP"

MASALAH: list[str] = []


def gagal(pesan: str) -> None:
    MASALAH.append(pesan)


def versi_pubspec() -> tuple[str, int]:
    teks = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([\w\.\+]+)\s*$", teks, re.M)
    if not m:
        gagal("versi tidak ditemukan di pubspec.yaml")
        return "1.0.0", 1
    bagian = m.group(1).split("+")
    nama = bagian[0]
    kode = int(bagian[1]) if len(bagian) > 1 and bagian[1].isdigit() else 1
    return nama, kode


def patch_build_gradle(versi: str, kode: int) -> None:
    f = ANDROID / "app" / "build.gradle.kts"
    if not f.exists():
        gagal("android/app/build.gradle.kts tidak ada (jalankan flutter create dulu)")
        return
    s = f.read_text(encoding="utf-8")

    def set_pola(pola: str, nilai: str, label: str) -> None:
        nonlocal s
        pola_baru = re.compile(pola)
        if pola_baru.search(s):
            s = pola_baru.sub(nilai, s, count=1)
        else:
            gagal(f"tidak menemukan {label} di build.gradle.kts")

    set_pola(r'namespace\s*=\s*"[^"]*"', f'namespace = "{PACKAGE}"', "namespace")
    set_pola(
        r'applicationId\s*=\s*"[^"]*"',
        f'applicationId = "{PACKAGE}"',
        "applicationId",
    )
    set_pola(r"minSdk\s*=\s*[^,\n]+", f"minSdk = {MIN_SDK}", "minSdk")
    set_pola(r"compileSdk\s*=\s*[^\n]+", f"compileSdk = {TARGET_SDK}", "compileSdk")
    set_pola(r"targetSdk\s*=\s*[^\n]+", f"targetSdk = {TARGET_SDK}", "targetSdk")
    set_pola(r"versionCode\s*=\s*\d+", f"versionCode = {kode}", "versionCode")
    set_pola(r'versionName\s*=\s*"[^"]*"', f'versionName = "{versi}"', "versionName")

    if MARK not in s:
        blok = f'''
{MARK}
    // --- signing: pakai android/key.properties kalau ada, selain itu debug key ---
    val keystoreProperties = java.util.Properties()
    val keystoreFile = rootProject.file("key.properties")
    val punyaKeystore = keystoreFile.exists()
    if (punyaKeystore) {{
        keystoreFile.inputStream().use {{ keystoreProperties.load(it) }}
    }}

    signingConfigs {{
        create("release") {{
            if (punyaKeystore) {{
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }}
        }}
    }}
'''
        # sisipkan blok tepat sebelum blok android {{
        cocok = re.search(r"^android\s*\{", s, re.M)
        if not cocok:
            gagal("blok android { tidak ditemukan di build.gradle.kts")
        else:
            s = s[: cocok.start()] + blok.lstrip("\n") + "\n" + s[cocok.start() :]

    # release memakai signing release hanya kalau keystore tersedia
    pola_release = r"release\s*\{(\s*)signingConfig\s*=\s*[^\n]+"
    if re.search(pola_release, s):
        s = re.sub(
            pola_release,
            r"release {\1signingConfig = if (punyaKeystore) "
            r"signingConfigs.getByName(\"release\") else signingConfigs.getByName(\"debug\")",
            s,
            count=1,
        )
    else:
        gagal("blok buildTypes.release tidak ditemukan")

    f.write_text(s, encoding="utf-8")


def patch_manifest() -> None:
    f = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
    if not f.exists():
        gagal("AndroidManifest.xml tidak ditemukan")
        return
    s = f.read_text(encoding="utf-8")

    s = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', s, count=1)

    izin_baru = (
        '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n'
    )
    if "android.permission.INTERNET" not in s:
        s = s.replace("    <application", izin_baru + "    <application", 1)
    else:
        gagal("izin INTERNET sudah ada - cek ulang tidak dobel")

    f.write_text(s, encoding="utf-8")


def patch_warna_launch() -> None:
    """Latar splash = warna brand (terang) dan hampir hitam (gelap).

    Tanpa ini: layar putih menyala 1-2 detik sebelum frame Flutter pertama.
    """
    for nilai, hexnya in (("values", BRAND_HEX), ("values-night", BRAND_NIGHT)):
        d = ANDROID / "app" / "src" / "main" / "res" / nilai
        d.mkdir(parents=True, exist_ok=True)
        colors = d / "colors.xml"
        isi = (
            '<?xml version="1.0" encoding="utf-8"?>\n'
            f"{MARK}\n"
            "<resources>\n"
            f'    <color name="launch_bg">#{hexnya}</color>\n'
            "</resources>\n"
        )
        colors.write_text(isi, encoding="utf-8")

        launch = d / "launch_background.xml"
        if not launch.exists():
            launch = ANDROID / "app" / "src" / "main" / "res" / "drawable" / (
                "launch_background.xml"
            )
        if launch.exists():
            t = launch.read_text(encoding="utf-8")
            t = re.sub(r'android:drawable="[^"]*"', 'android:drawable="@color/launch_bg"', t)
            t = re.sub(r"<item[^>]*>", '<item>', t, count=1)
            launch.write_text(t, encoding="utf-8")


def verify(versi: str, kode: int) -> None:
    f = ANDROID / "app" / "build.gradle.kts"
    if not f.exists():
        gagal("android/ belum ada - jalankan flutter create lebih dulu")
        return
    s = f.read_text(encoding="utf-8")
    cek = [
        (f'namespace = "{PACKAGE}"', "namespace"),
        (f'applicationId = "{PACKAGE}"', "applicationId"),
        (f"minSdk = {MIN_SDK}", "minSdk"),
        (f"targetSdk = {TARGET_SDK}", "targetSdk"),
        (f"versionCode = {kode}", "versionCode"),
        (f'versionName = "{versi}"', "versionName"),
        (MARK, "blok signing"),
    ]
    for pola, label in cek:
        if pola not in s:
            gagal(f"build.gradle.kts tidak punya {label} ({pola})")

    mf = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
    m = mf.read_text(encoding="utf-8") if mf.exists() else ""
    if f'android:label="{APP_NAME}"' not in m:
        gagal("label aplikasi bukan " + APP_NAME)
    if "android.permission.INTERNET" not in m:
        gagal("izin INTERNET tidak ada di manifest")
    for nilai in ("values", "values-night"):
        c = ANDROID / "app" / "src" / "main" / "res" / nilai / "colors.xml"
        if not c.exists():
            gagal(f"{nilai}/colors.xml tidak ada")


def main() -> int:
    verify_only = "--verify-only" in sys.argv
    versi, kode = versi_pubspec()

    if verify_only:
        verify(versi, kode)
    else:
        if not ANDROID.exists():
            gagal(
                "android/ tidak ada. Jalankan: flutter create --org com.divjun "
                "--project-name ai --platforms=android /tmp/scaffold && "
                "cp -r /tmp/scaffold/android ."
            )
        else:
            patch_build_gradle(versi, kode)
            patch_manifest()
            patch_warna_launch()
            # setelah patch, verifikasi lagi supaya tidak diam-diam gagal
            verify(versi, kode)

    if MASALAH:
        print("GAGAL setup android:")
        for m in MASALAH:
            print("  - " + m)
        return 1

    mode = "verifikasi" if verify_only else "patch"
    print(
        f"OK ({mode}): {PACKAGE} · v{versi}+{kode} · "
        f"minSdk {MIN_SDK} · targetSdk {TARGET_SDK}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
