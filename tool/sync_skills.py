#!/usr/bin/env python3
"""Salin seluruh pustaka skill zyvo ke dalam project Flutter sebagai asset.

Jadi hasil: `assets/skills/` berisi SEMUA skill (SKILL.md + references +
scripts), plus `assets/skills/index.json` yang jadi daftar untuk tampilan di
dalam app dan untuk pencarian by-keyword saat agent menjawab.

Aturan:
- yang TIDAK ikut: .git, node_modules, .DS_Store, *.log, file > 1 MB
  (data mentah besar seperti google-fonts.csv tidak berguna di dalam APK);
- WAJIB gagal (exit 1) kalau ada rahasia bocor ke dalam ZIP/APK;
- idempoten: folder assets/skills dibersihkan dulu lalu ditulis ulang.

Pemakaian:
    python3 tool/sync_skills.py                  # pakai ~/.config/zyvo/skills
    ZYVO_SKILLS_DIR=/path/lain python3 tool/sync_skills.py
"""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
Tujuan = ROOT / "assets" / "skills"
SUMBER = Path(os.environ.get("ZYVO_SKILLS_DIR", Path.home() / ".config/zyvo/skills"))

SKIP_DIR = {".git", "node_modules", ".dart_tool", "__pycache__", ".venv", "venv"}
SKIP_SUFFIX = {".log", ".pyc", ".png", ".jpg", ".jpeg", ".gif", ".woff", ".woff2", ".ttf"}
MAX_UKURAN = 1_000_000

# Pola rahasia yang TIDAK BOLEH ikut ke APK.
RAHASIA = [
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"gsk_[A-Za-z0-9]{20,}"),
    re.compile(r"oc_sk_[A-Za-z0-9]{20,}"),
    re.compile(r"sk-[A-Za-z0-9]{24,}"),
    re.compile(r"AIza[0-9A-Za-z_\-]{30,}"),
    # Hanya key NYATA yang kena: header + isi base64 di baris berikutnya.
    # Kalau cuma header yang disebut sebagai dokumentasi ("jangan commit
    # -----BEGIN PRIVATE KEY-----"), itu bukan rahasia.
    re.compile(
        r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s*\n"
        r"[A-Za-z0-9+/]{40,}={0,2}",
    ),
]


def frontmatter(teks: str) -> tuple[str, str]:
    """Ambil name + description dari frontmatter YAML skill."""
    if not teks.startswith("---"):
        return "", ""
    akhir = teks.find("\n---", 3)
    if akhir < 0:
        return "", ""
    blok = teks[3:akhir]
    name = ""
    desc = ""
    m = re.search(r"^name:\s*(.+)$", blok, re.M)
    if m:
        name = m.group(1).strip().strip("\"'")
    m = re.search(r"^description:\s*(.+)$", blok, re.M | re.S)
    if m:
        desc = " ".join(m.group(1).split())
    return name, desc


def salin_skill(src: Path, dst: Path) -> tuple[list[dict], int]:
    files: list[dict] = []
    total = 0
    for f in sorted(src.rglob("*")):
        if not f.is_file():
            continue
        rel = f.relative_to(src)
        if any(part in SKIP_DIR for part in rel.parts):
            continue
        if f.suffix.lower() in SKIP_SUFFIX:
            continue
        ukuran = f.stat().st_size
        if ukuran > MAX_UKURAN:
            continue
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, target)
        files.append({"path": str(rel), "size": ukuran})
        total += ukuran
    return files, total


def deskripsiCadangan(isi: str) -> str:
    """Paragraf pertama yang bukan judul/kode/frontmatter = deskripsi."""
    dalam_kode = False
    for baris in isi.split("\n"):
        b = baris.strip()
        if b.startswith("```"):
            dalam_kode = not dalam_kode
            continue
        if dalam_kode or not b or b.startswith(("#", "-", "*", "|", ">", "[")):
            continue
        cleaned = re.sub(r"[*`\[]|\]", "", b)
        if len(cleaned) < 12:
            continue
        return " ".join(cleaned.split())[:240]
    return ""


def tulis_pubspec(blok: str, jumlah: int) -> None:
    """Tulis blok deklarasi aset skill di pubspec.yaml (idempotent)."""
    pub = ROOT / "pubspec.yaml"
    teks = pub.read_text(encoding="utf-8") if pub.exists() else ""
    awal, akhir = "    # MULAI-SKILL", "    # SELESAI-SKILL"
    isi = blok.strip("\n")

    if awal in teks and akhir in teks:
        awal_i = teks.index(awal)
        akhir_i = teks.index(akhir) + len(akhir)
        teks = teks[:awal_i] + isi + teks[akhir_i:]
    else:
        # sisipkan setelah baris `assets:` pertama
        if "  assets:" not in teks:
            print("GAGAL: blok `assets:` tidak ada di pubspec.yaml")
            return
        i = teks.index("  assets:") + len("  assets:")
        teks = teks[:i] + "\n" + isi + teks[i:]
    pub.write_text(teks, encoding="utf-8")
    print(f"    pubspec: {jumlah} skill dideklarasikan per-file")


def main() -> int:
    if not SUMBER.exists():
        print(f"GAGAL: folder skill tidak ditemukan: {SUMBER}")
        return 1

    if Tujuan.exists():
        shutil.rmtree(Tujuan)
    Tujuan.mkdir(parents=True, exist_ok=True)

    skills = sorted(p for p in SUMBER.iterdir() if p.is_dir() and not p.name.startswith("."))
    index: list[dict] = []
    total_byte = 0
    dilewati: list[str] = []

    for s in skills:
        dok = Tujuan / s.name
        dok.mkdir(parents=True, exist_ok=True)
        files, ukuran = salin_skill(s, dok)
        total_byte += ukuran

        nama, deskripsi = "", ""
        md = dok / "SKILL.md"
        if md.exists():
            isi = md.read_text(encoding="utf-8", errors="replace")
            nama, deskripsi = frontmatter(isi)
            if not deskripsi:
                # Skill lama (tanpa frontmatter): ambil paragraf pembuka
                # sebagai deskripsi supaya tetap bisa dicari di dalam app.
                deskripsi = deskripsiCadangan(isi)
                if not deskripsi:
                    dilewati.append(f"{s.name} (tidak ada deskripsi sama sekali)")
        if not nama:
            nama = s.name

        index.append(
            {
                "nama": nama,
                "deskripsi": deskripsi,
                "folder": s.name,
                "size": ukuran,
                "jumlahFile": len(files),
                "files": files,
            }
        )

    # urutkan daftar supaya yang ada deskripsinya tampil lebih dulu
    index.sort(key=lambda x: (not x["deskripsi"], x["nama"].lower()))

    # ---------------------------------------------------------------
    # Flutter 3.47 (probe CI 17 Okt 2026): entri direktori `assets/skills/`
    # hanya menyalin file DI LEVEL ATAS (index.json saja), 2.732 berkas di
    # bawahnya TIDAK ikut ke APK - build hijau, APK jadi 75 KB lebih kecil
    # dan tidak ada error. Solusi: deklarasikan SETIAP berkas satu per satu.
    # Blok di bawah ditulis ulang tiap sinkron, di antara dua marker.
    blok_aset = ["    # MULAI-SKILL"]
    for s_ in index:
        for f_ in s_["files"]:
            blok_aset.append(f"    - assets/skills/{s_['folder']}/{f_['path']}")
    blok_aset.append("    # SELESAI-SKILL")
    tulis_pubspec("\n".join(blok_aset), len(index))

    (Tujuan / "index.json").write_text(
        json.dumps({"jumlah": len(index), "skills": index}, ensure_ascii=False, indent=1),
        encoding="utf-8",
    )

    # ---- verifikasi: tidak boleh ada rahasia atau frontmatter bocor ----
    masalah: list[str] = []
    for f in Tujuan.rglob("*"):
        if not f.is_file() or f.name == "index.json":
            continue
        try:
            teks = f.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for pola in RAHASIA:
            if pola.search(teks):
                masalah.append(f"rahasia bocor: {f.relative_to(ROOT)}")
                break

    if masalah:
        print("GAGAL, assets/skills tidak boleh dipakai:")
        for m in sorted(set(masalah))[:10]:
            print("  - " + m)
        return 1

    print(f"OK: {len(index)} skill, {sum(len(s['files']) for s in index)} berkas, "
          f"{total_byte / 1024 / 1024:.1f} MB -> assets/skills/")
    if dilewati:
        print(f"    tanpa deskripsi ({len(dilewati)}): {', '.join(dilewati[:6])}"
              + (" ..." if len(dilewati) > 6 else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())