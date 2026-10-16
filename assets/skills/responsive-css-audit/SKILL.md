---
name: responsive-css-audit
description: Audit and fix mobile layout that does not match desktop. Covers why a site looks right on desktop but broken on phone (missing breakpoints in component CSS files, not just the layout file), tap-target minimums, iOS auto-zoom prevention, bento/grid collapse rules, off-canvas drawer escape hatches, and swipe gestures that do not conflict with vertical scroll. Use when the user says a site is "not synced" between mobile and desktop, when the phone view is cramped or unclickable, or when auditing any responsive layout.
---

# Audit & Perbaiki Responsive (mobile = desktop)

Pelajaran dari NEXTRACE (`intelegen-webview/web`), 7 Okt 2026.
User: *"tampilan seluler ga sinkron dengan tampilan desktop"*.

## Cara mendiagnosis (JANGAN menebak)

```bash
cd assets/css
for f in *.css; do echo "$f -> $(grep -c '@media' "$f") breakpoint"; done
```

Pada kasus NEXTRACE:

| File | Breakpoint | Catatan |
|------|-----------|---------|
| `layout.css` | 3 | ada |
| `base.css` | 2 | ada |
| `analyzing.css` | 1 | ada |
| **`components.css`** | **0** | **<-- akar masalah** |

**Aturan: breakpoint harus ada di SETIAP file CSS.**
Orang hanya cek `layout.css` dan lupa file komponen. Kalau
`components.css` nol breakpoint, semua card / button / badge / table /
timeline akan tampil apa adanya di HP.

Pengecualian yang wajar: `tokens.css` (cuma variabel) dan
`print.css` (cuma `@media print`).

## Angka wajib untuk mobile

```css
@media (max-width: 760px) {
  /* tap target: minimal 44px (Android HIG), 48px lebih aman */
  .btn { min-height: 48px; }

  /* input: 16px mencegah iOS auto-zoom saat fokus */
  .field__control { font-size: 16px; padding: 13px 14px; }

  /* canvas/graph/globe: JANGAN < 320px */
  .canvas-wrap { height: 340px; }
}
@media (max-width: 360px) {         /* HP lama */
  .canvas-wrap { height: 300px; }
}
```

## Bento / grid: collapse, jangan diperkecil

```css
@media (max-width: 760px) {
  .b-3, .b-4, .b-5, .b-6, .b-7, .b-8, .b-9, .b-12 {
    grid-column: span 12 !important;   /* semua jadi 1 kolom */
  }
}
```
Grid bento yang hanya di-`span 3` di HP menghasilkan kolom 40px
yang tidak bisa dibaca dan tidak bisa diklik.

## Row dengan badge: jangan squeeze, WRAP

```css
@media (max-width: 760px) {
  .rrow { flex-wrap: wrap; }
  .rrow__body { flex: 1 1 100%; min-width: 100%; }
  .rrow .badge { margin-left: 0; align-self: flex-start; }
}
```
`display:flex` tanpa `wrap` = badge tertekan dan teks terpotong.

## Drawer off-canvas HARUS punya jalan keluar

Off-canvas tanpa tombol tutup = user terkunci (lapor user).
Wajib: tombol X di dalam drawer + backdrop + swipe gesture.

```css
.sidebar__close { display: none; }        /* hidden di desktop */
@media (max-width: 760px) {
  .sidebar__close { display: inline-flex; width: 36px; height: 36px; }
}
```

```javascript
let touchX = 0, touchY = 0, swiping = false;
document.addEventListener('touchstart', (e) => {
  const t = e.touches[0]; touchX = t.clientX; touchY = t.clientY; swiping = true;
}, { passive: true });
document.addEventListener('touchend', (e) => {
  if (!swiping) return; swiping = false;
  const t = e.changedTouches[0];
  const dx = t.clientX - touchX;
  const dy = Math.abs(t.clientY - touchY);
  if (dy > 60) return;                     /* scroll vertikal, bukan swipe */
  const open = sidebar.getAttribute('data-open') === 'true';
  if (dx > 70 && touchX < 60) openSidebar();
  else if (dx < -70 && open) closeSidebar();
}, { passive: true });
```

Guard `dy > 60` itu **wajib**: tanpa itu, swipe horizontal saat scroll
vertikal membuat halaman bergeser sendiri.

## Inline style = tidak bisa di-breakpoint

CSS eksternal tidak bisa menimpa `style="..."` tanpa `!important`.
Jadi kalau komponen dibuat dengan inline style (sering di JS view),
harus ada **class** untuk di-override di mobile:

```javascript
UI.el('div', { class: 'pc-wallets', style: 'display:grid;...' })
```
```css
@media (max-width: 760px) {
  .pc-wallets { grid-template-columns: repeat(3, 1fr) !important; }
}
```

Dan **berhenti** memakai `grid-template-columns: repeat(5, 1fr)` inline
— di HP jadi 5 kolom 60px yang mustahil dibaca.

## Smoke test otomatis (supaya tidak lupa lagi)

```javascript
// 1. breakpoint mobile WAJIB di tiap CSS
cssFiles.filter(f => !/^(tokens|print)\.css$/.test(f)).forEach(f => {
  const src = fs.readFileSync(f, 'utf8');
  const hasMobile = /@media[^}]*max-width:\s*(760|768|700|640|480|360)px/.test(src);
  if (!hasMobile) bad(f, 'TIDAK ADA @media max-width -> tidak responsif');
});

// 2. inline style berbahaya
const risky = /grid-template-columns:\s*repeat\(\d+/;   /* kolom tetap */
const small = /font-size:\s*(\d+)px/;                    /* < 11px      */
```

## Checklist sebelum bilang "mobile sudah sinkron"
- [ ] `@media max-width` ada di SETIAP file CSS (bukan cuma layout)
- [ ] Ada `@media (max-width: 360px)` untuk HP lama
- [ ] Semua `b-*` collapse ke `span 12` di HP
- [ ] `.btn` min-height >= 44px, `.field__control` font-size 16px
- [ ] `.canvas-wrap` height >= 320px
- [ ] `.rrow` wrap, badge turun ke bawah
- [ ] `.toast-host` full width di HP
- [ ] Drawer punya tombol close + backdrop + swipe
- [ ] `env(safe-area-inset-bottom)` dipakai untuk notch iPhone
- [ ] Smoke test punya cek breakpoint + cek inline style
- [ ] Smoke test lulus semua
