#!/usr/bin/env node
/**
 * verify-hygiene.js — cek aturan hygiene kode NEXTRACE.
 *
 * Ini linter sederhana: dia tidak bisa tau semua bug,
 * tapi bisa menangkap kelas kesalahan yang paling sering terjadi
 * saat menulis JS untuk WebView Android.
 *
 * Jalankan: node tools/verify-hygiene.js
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const JS_DIR = path.join(ROOT, 'www', 'assets', 'js');
const KT_DIR = path.join(ROOT, 'app', 'src', 'main', 'java');

let problems = 0;
function report(level, file, line, msg) {
  problems++;
  console.log('  \x1b[33m' + level + '\x1b[0m ' + file + ':' + line + '  ' + msg);
}

function walk(dir, ext, out) {
  out = out || [];
  if (!fs.existsSync(dir)) return out;
  fs.readdirSync(dir, { withFileTypes: true }).forEach((e) => {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, ext, out);
    else if (p.endsWith(ext)) out.push(p);
  });
  return out;
}

console.log('\n\x1b[1mNEXTRACE hygiene check\x1b[0m\n');

/* ------------------------------------------------------------------ */
console.log('[A] Larangan umum di seluruh kode web');

const jsFiles = walk(JS_DIR, '.js');

jsFiles.forEach((f) => {
  const rel = path.relative(ROOT, f);
  fs.readFileSync(f, 'utf8').split('\n').forEach((line, i) => {
    const n = i + 1;

    // innerHTML = selalu potentiellement berbahaya
    if (/\.innerHTML\s*=/.test(line)) {
      report('innerHTML', rel, n, 'pakai textContent lewat UI.el()');
    }

    // fetch langsung dari halaman file:// akan kena CORS
    if (/\bfetch\s*\(/.test(line) && !/\/\//.test(line.trim().slice(0, 2))) {
      report('fetch', rel, n, 'pakai Bridge.fetchUrl (CORS blokir fetch di file://)');
    }

    // alert()-blocking — tidak cocok untuk app
    if (/\balert\s*\(/.test(line)) {
      report('alert', rel, n, 'pakai UI.toast() atau tampilkan di UI');
    }

    // pola yang mudah salah: string HTML Literal + konversi
    if (/['"]<[a-z]+[^']*['"]\s*\+/.test(line) && /innerHTML|insertAdjacent/.test(line)) {
      report('html-str', rel, n, 'merangkai string HTML manual');
    }
  });
});
if (problems === 0) console.log('  \x1b[32mOK\x1b[0m tidak ada pelanggaran');

/* ------------------------------------------------------------------ */
const before = problems;
console.log('\n[B] Kontrol: setiap modul ada di MODULE_ORDER');

const appJs = fs.readFileSync(path.join(JS_DIR, 'app.js'), 'utf8');
const orderMatch = appJs.match(/MODULE_ORDER\s*=\s*\[([^\]]+)\]/);
if (!orderMatch) {
  report('mod-order', 'app.js', 0, 'MODULE_ORDER tidak ditemukan');
} else {
  const listed = orderMatch[1].match(/'([a-z]+)'/g).map((s) => s.replace(/'/g, ''));
  const onDisk = fs.existsSync(path.join(JS_DIR, 'modules'))
    ? fs.readdirSync(path.join(JS_DIR, 'modules')).filter((f) => f.endsWith('.js')).map((f) => f.replace('.js', ''))
    : [];

  onDisk.forEach((mod) => {
    if (!listed.includes(mod)) {
      report('mod-order', 'app.js', 0, 'modul "' + mod + '" ada di disk tapi tidak di MODULE_ORDER');
    }
  });
  listed.forEach((mod) => {
    if (!onDisk.includes(mod)) {
      report('mod-order', 'app.js', 0, 'MODULE_ORDER menyebut "' + mod + '" tapi file-nya tidak ada');
    }
  });
  if (problems === before) console.log('  \x1b[32mOK\x1b[0m ' + listed.length + ' modul terdaftar cocok dengan file');
}

/* ------------------------------------------------------------------ */
const before2 = problems;
console.log('\n[C] Konsistensi bridge Kotlin <-> JS');

const ktFiles = walk(KT_DIR, '.kt');
let ktMethods = [];
ktFiles.forEach((f) => {
  const src = fs.readFileSync(f, 'utf8');
  const re = /@JavascriptInterface\s+(?:\n\s*)?fun\s+([a-zA-Z_][a-zA-Z0-9_]*)/g;
  let m;
  while ((m = re.exec(src)) !== null) ktMethods.push(m[1]);
});

const allJs = jsFiles.map((f) => fs.readFileSync(f, 'utf8')).join('\n');
const jsCalls = new Set();
const callRe = /NextraceBridge\.([a-zA-Z_][a-zA-Z0-9_]*)/g;
let cm;
while ((cm = callRe.exec(allJs)) !== null) jsCalls.add(cm[1]);

ktMethods.forEach((m) => {
  if (!jsCalls.has(m)) {
    report('bridge', 'NativeBridge.kt', 0, 'method "' + m + '" tidak pernah dipanggil dari JS');
  }
});
jsCalls.forEach((m) => {
  if (!ktMethods.includes(m)) {
    report('bridge', 'JS', 0, 'NextraceBridge.' + m + '() tidak ada di Kotlin');
  }
});
if (problems === before2) {
  console.log('  \x1b[32mOK\x1b[0m ' + ktMethods.length + ' method native, semua punya pasangan JS');
}

/* ------------------------------------------------------------------ */
const before3 = problems;
console.log('\n[D] Aturan bahasa (Latin script saja)');

const NON_LATIN = /[\u4e00-\u9fff\u3000-\u303f\u0400-\u04ff\u0600-\u06ff\u0980-\u09ff\uac00-\ud7af]/;

const allText = [
  ...jsFiles,
  ...ktFiles,
  path.join(ROOT, 'www', 'index.html'),
  ...walk(path.join(ROOT, 'www', 'assets', 'css'), '.css'),
  path.join(ROOT, 'README.md'),
  path.join(ROOT, 'AGENTS.md'),
  path.join(ROOT, '.github', 'workflows', 'build.yml')
].filter((f) => fs.existsSync(f));

allText.forEach((f) => {
  const rel = path.relative(ROOT, f);
  fs.readFileSync(f, 'utf8').split('\n').forEach((line, i) => {
    if (NON_LATIN.test(line)) {
      report('non-latin', rel, i + 1, 'ada karakter non-Latin: ' + line.trim().slice(0, 50));
    }
  });
});
if (problems === before3) console.log('  \x1b[32mOK\x1b[0m semua file Latin script');

/* ------------------------------------------------------------------ */
const before4 = problems;
console.log('\n[E] Sumber tunggal file web (tidak boleh ada duplikat)');

const dupAssets = path.join(ROOT, 'app', 'src', 'main', 'assets', 'www');
if (fs.existsSync(dupAssets)) {
  report('dup', path.relative(ROOT, dupAssets), 0,
    'duplikat assets/www terdeteksi — hapus, Gradle sudah menyalin dari www/');
} else {
  console.log('  \x1b[32mOK\x1b[0m tidak ada assets/www duplikat');
}

const buildGradle = path.join(ROOT, 'app', 'build.gradle.kts');
if (fs.existsSync(buildGradle)) {
  const bg = fs.readFileSync(buildGradle, 'utf8');
  if (/\$rootDir\/www|rootDir\/"\s*\+\s*"\/www/.test(bg) || /assets\.srcDirs\([^)]*www/.test(bg)) {
    console.log('  \x1b[32mOK\x1b[0m Gradle menyalin www/ sebagai sumber tunggal');
  } else {
    report('srcset', 'build.gradle.kts', 0, 'assets.srcDirs belum menunjuk ke rootDir/www');
  }
}

/* ------------------------------------------------------------------ */
console.log('\n' + '-'.repeat(54));
if (problems === 0) {
  console.log('  \x1b[32mBERSIH\x1b[0m — tidak ada masalah hygiene');
} else {
  console.log('  \x1b[33m' + problems + ' masalah ditemukan\x1b[0m');
}
console.log('-'.repeat(54) + '\n');

process.exit(problems === 0 ? 0 : 1);
