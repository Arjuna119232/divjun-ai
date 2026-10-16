#!/usr/bin/env python3
"""Kemas source Flutter jadi ZIP untuk diedit sendiri / diuji offline.

Isi zip LANGSUNG di root (tanpa folder pembungkus) supaya Acode langsung bisa
membuka folder yang berisi pubspec.yaml.

Yang TIDAK ikut: .git, android/, ios/, build/, .dart_tool/, keystore, .env.
Yang WAJIB ikut: assets/ (font app), test/, tool/, docs/.

Exit 1 kalau ada file sensitif bocor atau file wajib hilang - "saya tidak
ikutkan .env" harus jadi KODE yang dicek, bukan niat.
"""

from __future__ import annotations

import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KELUARAN_DEFAULT = Path.home() / "Downloads"

EXCLUDE_DIR = {
    ".git", ".dart_tool", "build", "android", "ios", "linux", "macos", "windows",
    "web", ".idea", ".vscode", "dev-backups", ".github",
}
EXCLUDE_FILE_SUFFIX = {".jks", ".keystore", ".p12", ".pem", ".apk", ".aab", ".log"}
EXCLUDE_NAME = {".env", "key.properties", "keys.properties", ".DS_Store"}

WAJIB_ADA = ["pubspec.yaml", "lib/main.dart", "assets/fonts", "tool/check_source.py"]


def versi() -> str:
    teks = (ROOT / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([\w\.\+]+)\s*$", teks, re.M)
    return m.group(1) if m else "0.0.0"


def kumpulkan() -> list[Path]:
    out: list[Path] = []
    for f in sorted(ROOT.rglob("*")):
        if not f.is_file():
            continue
        rel = f.relative_to(ROOT)
        if any(part in EXCLUDE_DIR for part in rel.parts):
            continue
        if f.name in EXCLUDE_NAME or f.suffix.lower() in EXCLUDE_FILE_SUFFIX:
            continue
        out.append(f)
    return out


def main() -> int:
    versi_aplikasi = versi()
    tujuan = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        KELUARAN_DEFAULT / f"DIVJUN-AI-v{versi_aplikasi}-source.zip"
    )
    try:
        tujuan.parent.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        print(f"GAGAL: tidak bisa membuat folder {tujuan.parent}: {e}")
        print("Fallback: jalankan dengan path target, contoh:")
        print(f"  python3 {__file__} $HOME/DIVJUN-source.zip")
        return 1

    files = kumpulkan()
    if not files:
        print("GAGAL: tidak ada file yang dikemas")
        return 1

    with zipfile.ZipFile(tujuan, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(f, arcname=str(f.relative_to(ROOT)))

    # ---- verifikasi sendiri (bukan vow) ----
    masalah: list[str] = []
    with zipfile.ZipFile(tujuan) as z:
        nama = z.namelist()
        if z.testzip() is not None:
            masalah.append("arsip korup (CRC gagal)")
        for n in nama:
            dasar = Path(n).name
            if dasar in EXCLUDE_NAME or Path(n).suffix.lower() in EXCLUDE_FILE_SUFFIX:
                masalah.append(f"berkas sensitif bocor: {n}")
            if n.startswith(".git/") or "/.git/" in n:
                masalah.append(f"riwayat git bocor: {n}")
        for wajib in WAJIB_ADA:
            if not any(n == wajib or n.startswith(wajib + "/") for n in nama):
                masalah.append(f"berkas wajib hilang: {wajib}")

    ukuran = tujuan.stat().st_size
    if masalah:
        print("GAGAL, ZIP tidak dipakai:")
        for m in masalah:
            print("  - " + m)
        return 1

    print(f"OK: {tujuan}")
    print(f"    {len(files)} berkas, {ukuran / 1024 / 1024:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())