---
name: mandatory-consent-before-registration
description: Add a privacy policy and terms & conditions page to a Capacitor web app, place them above the registration form, and require both consent checkboxes before the register button unlocks - with tests and a Play-Store-safe structure. Use when asked to add legal pages, a consent checkbox, or a "must tick before continue" gate on signup.
---

# Mandatory consent before registration

What the user asked for, and how it must be built:

> "buat kebijakan privasi dan syarat dan ketentuan, taruh di saat daftar akun baru
> di atas card daftar akun dan kasih kolom harus di centang supaya bisa lanjut"

So: both documents exist, they appear **above** the input fields (not below, not
on a separate page reachable only from settings), and **both** checkboxes must be
ticked before registration can proceed.

## Structure

```
www/pages/kebijakan-privasi.html      <- privacy policy
www/pages/syarat-ketentuan.html       <- terms & conditions
www/assets/css/base/legal.css         <- shared styling for BOTH
```

Put the legal stylesheet in `base/`, not per-page. Two nearly identical pages
duplicating 60 lines of CSS is worse than one shared file. Delete the old
per-page file and update both `<link>` tags.

Both pages must contain what Google Play and the store review expect:

- app name **and** package id (`com.x.y`)
- effective date
- what data is collected, for what, and who processes it (name your actual
  providers: Firebase, AdMob)
- how to delete the account, step by step, from inside the app
- a link to the other document (each page links to the other)
- no inline `<style>` or inline `<script>` — those break the project's own lint

## The consent block

Placed inside the registration container, **before** the first input:

```html
<div class="daftar-persetujuan">
  <p class="daftar-persetujuan-judul">Sebelum mendaftar, baca dulu:</p>
  <div class="daftar-tautan">
    <a href="kebijakan-privasi.html">Kebijakan Privasi</a>
    <span>dan</span>
    <a href="syarat-ketentuan.html">Syarat &amp; Ketentuan</a>
  </div>
  <label class="daftar-centang">
    <input type="checkbox" id="setujuPrivasi">
    <span>Saya telah membaca dan menyetujui <b>Kebijakan Privasi</b>.</span>
  </label>
  <label class="daftar-centang">
    <input type="checkbox" id="setujuKetentuan">
    <span>Saya telah membaca dan menyetujui <b>Syarat &amp; Ketentuan</b>.</span>
  </label>
  <p class="daftar-persetujuan-catatan" id="daftarCatatanPersetujuan">...</p>
</div>
```

## Two gates, not one

**Gate 1 — markup.** The button starts disabled:

```html
<button id="btnDaftar" class="btn-masuk" disabled>Daftar Akun Baru</button>
```

**Gate 2 — handler.** Never rely on `disabled` alone; it can be bypassed from
devtools or a stale DOM. Re-check inside the click handler and return early:

```js
if (!persetujuanLengkap()) {
  window.showModal({ title: 'Persetujuan Diperlukan', desc: '...', icon: '📄' });
  return;
}
```

The completeness rule is AND, not OR:

```js
function persetujuanLengkap() {
  return !!(chkPrivasi && chkKetentuan && chkPrivasi.checked && chkKetentuan.checked);
}
```

Note the distinction the user cares about: `button disabled` stops **login**;
the handler guard stops **account creation**. Say it that way when you report.

## The TDZ trap that will kill the page

This is the single most likely way to break this feature:

```js
function segarkanTombolDaftar() {
  if (!btnDaftar) return;        // reads btnDaftar
  ...
}

segarkanTombolDaftar();          // called HERE

const btnDaftar = document.getElementById('btnDaftar');   // declared AFTER
```

In a `type="module"` script that throws
`ReferenceError: Cannot access 'btnDaftar' before initialization`, and because
the file is a module the **entire page dies** — the login form stops working too.
The failure looks like "the login button does nothing", not like a consent bug.

Rule: **declare before first use.** Add a test asserting
`indexOf(declaration) < indexOf(firstCall)` so it cannot come back.

## UX details worth adding

- A hint line that changes when both are ticked, so the user knows progress is
  being registered (and it doubles as the reason the button is inert).
- `min-height: 44px` on the checkbox rows — that is the minimum comfortable tap
  target on a phone.
- Style the checkbox with `accent-color` matching the app's primary button.
- Use `textContent`, not `innerHTML`, for the hint — no reason to introduce an
  injection surface here.

## Tests to add

A single test file covering: both pages exist with the required sections; the two
pages cross-link; the consent block index is **less than** the first input's
index; both links appear before the inputs; exactly two checkboxes exist; the
button has `disabled` in the markup; the completeness check uses `&&`; the
handler re-checks; and the TDZ ordering holds.