// Markdown renderer untuk jawaban AI.
//
// Dua aturan penting:
// 1) XSS: semua teks di-escape DULU, formatasi hanya diterapkan pada placeholder
//    yang kita buat sendiri (bukan input pengguna).
// 2) Placeholder memakai karakter private-use Unicode (\uE0xx) supaya TIDAK bisa
//    terkena regex kata kunci/angka milik syntax highlighter. Kalau placeholder
//    pakai angka atau huruf, highlight akan merusak tag HTML-nya sendiri.
(function (root) {

  // Penanda harus TIDAK sama dengan karakter payload, kalau tidak placeholder
  // tidak bisa dibedakan dari penutupnya sendiri.
  var FENCE_L = '\uE000', FENCE_R = '\uE001';   // pagar blok kode
  var ST_L = '\uE002', ST_R = '\uE003';         // pagar string/komentar
  var ST_BASE = 0xE100;                            // payload mulai di sini

  function esc(s) {
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // ------------------------------------------------------------------ utama
  function md(src) {
    if (src == null || src === '') return '';
    var fences = [];
    var text = String(src).replace(/```([\w+.-]*)[ \t]*\n?([\s\S]*?)(?:```|$)/g,
      function (_, lang, body) {
        fences.push({ lang: (lang || '').trim(), body: body.replace(/\n$/, '') });
        return FENCE_L + (fences.length - 1) + FENCE_R;
      });

    var html = renderBlocks(esc(text));

    // kembalikan blok kode
    html = html.replace(new RegExp(FENCE_L + '(\\d+)' + FENCE_R, 'g'),
      function (_, i) { return codeBlock(fences[+i].body, fences[+i].lang); });

    return stripCtrl(html);
  }

  // buang karakter kontrol yang mungkin ikut dari model
  function stripCtrl(s) {
    return s.replace(/[\uE000-\uE1FF]/g, '').replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '');
  }

  // --------------------------------------------------------------- blok level
  function renderBlocks(t) {
    var lines = t.split('\n');
    var out = [], i = 0, onlyFence = /^\s*\uE000\d+\uE001\s*$/;

    while (i < lines.length) {
      var L = lines[i];

      if (!L.trim()) { i++; continue; }

      // garis horizontal
      if (/^\s*([-*_])\s*\1\s*\1[\s\-*_]*$/.test(L)) { out.push('<hr class="mhr">'); i++; continue; }

      // heading
      var h = L.match(/^(#{1,6})\s+(.*)$/);
      if (h) {
        var lv = Math.min(h[1].length + 2, 6);
        out.push('<h' + lv + ' class="mh">' + inline(h[2]) + '</h' + lv + '>');
        i++; continue;
      }

      // blockquote
      if (/^\s*&gt;\s?/.test(L)) {
        var q = [];
        while (i < lines.length && /^\s*&gt;\s?/.test(lines[i])) { q.push(lines[i].replace(/^\s*&gt;\s?/, '')); i++; }
        out.push('<blockquote class="mq">' + renderBlocks(q.join('\n')) + '</blockquote>');
        continue;
      }

      // tabel
      if (isTableRow(L) && i + 1 < lines.length && isSepRow(lines[i + 1])) {
        var res = renderTable(lines, i);
        out.push(res.html); i = res.next; continue;
      }

      // list
      if (/^\s*[-*+]\s+/.test(L) || /^\s*\d+[.)]\s+/.test(L)) {
        var ordered = /^\s*\d+[.)]\s+/.test(L);
        var re = ordered ? /^\s*\d+[.)]\s+(.*)$/ : /^\s*[-*+]\s+(.*)$/;
        var items = [];
        while (i < lines.length) {
          var mm = lines[i].match(re);
          if (mm) { items.push(mm[1]); i++; continue; }
          if (items.length && /^\s{2,}\S/.test(lines[i]) && !isTableRow(lines[i])) {
            items[items.length - 1] += '\n' + lines[i].trim(); i++; continue;
          }
          break;
        }
        var tag = ordered ? 'ol' : 'ul';
        out.push('<' + tag + ' class="ml">' +
          items.map(function (x) { return '<li>' + inline(x) + '</li>'; }).join('') +
          '</' + tag + '>');
        continue;
      }

      // paragraf
      var para = [];
      while (i < lines.length && lines[i].trim() && !isBlockStart(lines[i]) &&
        !(i + 1 < lines.length && isSepRow(lines[i + 1]) && isTableRow(lines[i]))) {
        para.push(lines[i]); i++;
      }
      if (!para.length) { out.push(inline(L)); i++; continue; }
      var joined = para.join('\n');
      // <div> tidak boleh berada di dalam <p>: pisahkan segmen teks dan blok kode
      if (onlyFence.test(joined) || new RegExp(FENCE_L).test(joined)) {
        var segs = joined.split(new RegExp('(' + FENCE_L + '\\d+' + FENCE_R + ')'));
        segs.forEach(function (seg) {
          if (!seg) return;
          if (seg.charAt(0) === FENCE_L) out.push(seg);
          else if (seg.trim()) out.push('<p class="mp">' + inline(seg).replace(/\n/g, '<br>') + '</p>');
        });
        continue;
      }
      out.push('<p class="mp">' + inline(joined).replace(/\n/g, '<br>') + '</p>');
    }
    return out.join('');
  }

  function isBlockStart(s) {
    return /^\s*#{1,6}\s/.test(s) || /^\s*[-*+]\s+/.test(s) ||
      /^\s*\d+[.)]\s+/.test(s) || /^\s*&gt;\s?/.test(s) ||
      /^\s*([-*_])\s*\1\s*\1[\s\-*_]*$/.test(s);
  }
  function isTableRow(s) { return /\|/.test(s) && /^\s*\|?[^|]*\|/.test(s); }
  function isSepRow(s) { return /^\s*\|?[\s:|-]*-[-\s:|]*\|?[\s:|-]*$/.test(s) && /-/.test(s); }

  function renderTable(lines, i) {
    function cells(row) {
      return row.replace(/^\s*\|/, '').replace(/\|\s*$/, '')
        .split(/(?<!\\)\|/).map(function (c) { return c.trim().replace(/\\\|/g, '|'); });
    }
    var head = cells(lines[i]);
    i += 2;
    var body = [];
    while (i < lines.length && isTableRow(lines[i])) { body.push(cells(lines[i])); i++; }
    var h = '<div class="mtw"><table class="mt"><thead><tr>' +
      head.map(function (c) { return '<th>' + inline(c) + '</th>'; }).join('') +
      '</tr></thead><tbody>' +
      body.map(function (r) {
        return '<tr>' + head.map(function (_, ci) {
          return '<td>' + inline(r[ci] === undefined ? '' : r[ci]) + '</td>';
        }).join('') + '</tr>';
      }).join('') +
      '</tbody></table></div>';
    return { html: h, next: i };
  }

  // -------------------------------------------------------------- inline
  function inline(s) {
    var o = esc(s), codes = [];
    o = o.replace(/`([^`\n]+)`/g, function (_, c) {
      codes.push(c); return '\u0001C' + (codes.length - 1) + '\u0001';
    });
    // link eksternal: pakai data-ext, TIDAK ada JS inline (aman dari injeksi URL)
    o = o.replace(/\[([^\]\n]+)\]\((https?:\/\/[^\s)]+)\)/g,
      '<a href="$2" data-ext="1" rel="noopener">$1</a>');
    o = o.replace(/\*\*\*([^*\n]+)\*\*\*/g, '<b><i>$1</i></b>');
    o = o.replace(/\*\*([^*\n]+)\*\*/g, '<b>$1</b>');
    o = o.replace(/(^|[\s(])\*([^*\n]+)\*(?=[\s).,!?:;]|$)/g, '$1<i>$2</i>');
    o = o.replace(/(^|[\s(])_([^_\n]+)_(?=[\s).,!?:;]|$)/g, '$1<i>$2</i>');
    o = o.replace(/~~([^~\n]+)~~/g, '<s>$1</s>');
    o = o.replace(/\u0001C(\d+)\u0001/g, function (_, i) { return '<code>' + codes[+i] + '</code>'; });
    return o;
  }

  // -------------------------------------------------------- blok kode + hl
  var KEYWORDS = {
    js: 'const let var function return if else for while class new this import from export async await try catch throw typeof instanceof extends null true false undefined switch case break continue do delete in of yield super static get set default',
    py: 'def class return if elif else for while import from as try except raise with lambda None True False and or not in is pass break continue yield global nonlocal async await assert del',
    java: 'public private protected class interface extends implements new return if else for while try catch throw throws import package static final void int long double float char boolean this super null true false enum abstract',
    kt: 'fun val var class object interface return if else for while try catch throw import package data sealed when is as null true false override private public internal protected companion',
    go: 'func package import return if else for range switch case break continue default struct interface map chan go defer nil true false var const type',
    rs: 'fn let mut const struct enum impl trait pub use mod match if else for while loop return self Self crate true false None Some',
    c: 'int float double char void long short struct union enum typedef static const return if else for while do switch case break continue sizeof',
    cpp: 'class struct public private protected virtual override template typename namespace using return if else for while switch new delete nullptr this true false int float double void',
    sh: 'if then else fi for while do done case esac function return export local',
    sql: 'select from where insert update delete create table alter drop index join left right inner outer on group by order having limit offset distinct as and or not null into values set',
    html: 'div span script style link meta title class id href src alt body head',
    css: 'color background margin padding border font display flex grid align justify width height position top left right',
    json: 'true false null',
    php: 'function return echo new class public private if else foreach as array use namespace',
    ruby: 'def class end return if else elsif unless while until each map select puts require'
  };

  function codeBlock(body, lang) {
    var l = (lang || '').toLowerCase();
    return '<div class="pre-wrap">' +
      '<div class="pre-head"><span class="pre-lang">' + esc(l || 'teks') + '</span>' +
      '<button class="pre-btn" onclick="copyPre(this)">Salin</button></div>' +
      '<pre class="mp-pre"><code>' + hl(body, l) + '</code></pre></div>';
  }

  function hl(src, lang) {
    var kw = KEYWORDS[lang];
    if (!kw) return esc(src);

    var stash = [];
    // placeholder pakai private-use: aman dari semua regex di bawah
    function keep(html) { stash.push(html); return ST_L + String.fromCharCode(ST_BASE + stash.length - 1) + ST_R; }

    var t = esc(src);
    t = t.replace(/(&quot;|&#39;|')(\\.|[^\\'\n])*?\1/g, function (m) { return keep('<span class="s">' + m + '</span>'); });
    t = t.replace(/(\/\/[^\n]*)/g, function (m) { return keep('<span class="c">' + m + '</span>'); });
    t = t.replace(/(\/\*[\s\S]*?\*\/)/g, function (m) { return keep('<span class="c">' + m + '</span>'); });
    // baru setelah string/komentar diamankan
    t = t.replace(/\b(\d+(?:\.\d+)?)\b/g, '<span class="n">$1</span>');
    t = t.replace(new RegExp('\\b(' + kw.split(' ').join('|') + ')\\b', 'g'),
      '<span class="k">$1</span>');
    return t.replace(new RegExp(ST_L + '([\uE100-\uE1FF])' + ST_R, 'g'),
      function (_, c) { return stash[c.charCodeAt(0) - ST_BASE]; });
  }

  root.divjunMd = md;
  root.divjunCodeBlock = codeBlock;
})(typeof window !== 'undefined' ? window : this);