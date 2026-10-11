/* @ds-bundle: {"format":4,"namespace":"InvTrack","components":[{"name":"HeroCard"},{"name":"InvestmentCard"},{"name":"StatTile"},{"name":"EmptyState"},{"name":"TextField"},{"name":"Button"},{"name":"Chip"},{"name":"Badge"},{"name":"BottomSheet"},{"name":"Dialog"},{"name":"Snackbar"},{"name":"GlassCard"},{"name":"GradientCard"},{"name":"PrivacyMask"},{"name":"AmountText"},{"name":"Skeleton"},{"name":"Navigation"}]} */
/* InvTrack design system: plain HTML/CSS equivalents of the Flutter widgets. Each component is a function
   that returns an HTML string styled by bundle.css. No framework, no network. Amounts are display strings:
   the app computes metrics in lib/core/calculations; this bundle only shows them. */
(function () {
  'use strict';

  /* ------------------------------------------------------------------ helpers */
  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function cls() {
    var o = [];
    for (var i = 0; i < arguments.length; i++) if (arguments[i]) o.push(arguments[i]);
    return o.join(' ');
  }
  function sty(o) {
    var s = '';
    for (var k in o) if (o[k] != null && o[k] !== '') s += k + ':' + o[k] + ';';
    return s ? ' style="' + esc(s) + '"' : '';
  }
  function icon(name, o) {
    o = o || {};
    var s = '';
    if (o.size) s += 'font-size:' + o.size + 'px;';
    if (o.color) s += 'color:' + o.color + ';';
    return '<span class="' + cls('it-icon', o.family === 'base' && 'it-icon--base', o.family === 'outlined' && 'it-icon--outlined', o.cls) + '"' +
      (s ? ' style="' + s + '"' : '') + ' aria-hidden="true">' + esc(name) + '</span>';
  }

  /* ------------------------------------------------------------------ number formats (lib/core/utils/currency_utils.dart, number_format_utils.dart) */
  function roundTo(v, d) { var f = Math.pow(10, d); return Math.round(v * f) / f; }
  function groupIN(intStr) {              // 1234567 -> 12,34,567 (lakh / crore grouping, en_IN)
    if (intStr.length <= 3) return intStr;
    return intStr.slice(0, -3).replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + intStr.slice(-3);
  }
  function groupWestern(intStr) { return intStr.replace(/\B(?=(\d{3})+(?!\d))/g, ','); }
  function num(value, maxDec, locale) {   // up to maxDec decimals, trailing zeros dropped
    var neg = value < 0;
    var parts = Math.abs(value).toFixed(maxDec).split('.');
    var ip = locale === 'en_IN' ? groupIN(parts[0]) : groupWestern(parts[0]);
    var frac = (parts[1] || '').replace(/0+$/, '');
    return (neg ? '-' : '') + ip + (frac ? '.' + frac : '');
  }
  function inr(n, o) {                    // formatCurrency(amount, '₹', 'en_IN', decimalDigits)
    o = o || {};
    var d = o.decimals == null ? 0 : o.decimals, sym = o.symbol == null ? '₹' : o.symbol, loc = o.locale || 'en_IN';
    var parts = Math.abs(n).toFixed(d).split('.');
    var ip = loc === 'en_IN' ? groupIN(parts[0]) : groupWestern(parts[0]);
    return (n < 0 && Number(Math.abs(n).toFixed(d)) !== 0 ? '-' : '') + sym + ip + (parts[1] ? '.' + parts[1] : '');
  }
  function indianParts(abs, maxDec) {     // indianCompactParts: L / Cr, a value that rounds to 100 L becomes crore
    if (abs < 1000) return { v: roundTo(abs, maxDec), u: '' };
    var whole = Math.round(abs);
    if (whole < 1e5) return { v: whole, u: '' };
    var lakhs = roundTo(abs / 1e5, maxDec);
    if (lakhs < 100) return { v: lakhs, u: 'L' };
    return { v: roundTo(abs / 1e7, maxDec), u: 'Cr' };
  }
  function westernParts(abs, maxDec) {
    var units = [[1e3, 'K'], [1e6, 'M'], [1e9, 'B'], [1e12, 'T']];
    var r = roundTo(abs, maxDec);
    if (r < 1000) return { v: r, u: '' };
    var i = 0, v = roundTo(abs / units[0][0], maxDec);
    while (v >= 1000 && i < units.length - 1) { i++; v = roundTo(abs / units[i][0], maxDec); }
    return { v: v, u: units[i][1] };
  }
  function compact(n, o) {                // formatCompact: '₹99.95 L', '₹1 Cr'; other locales '$1.23M'
    o = o || {};
    var sym = o.symbol == null ? '₹' : o.symbol, loc = o.locale || 'en_IN', d = o.decimals == null ? 2 : o.decimals;
    var p = loc === 'en_IN' ? indianParts(Math.abs(n), d) : westernParts(Math.abs(n), d);
    var signed = n < 0 && p.v !== 0 ? -p.v : p.v;
    var text = (signed < 0 ? '-' : '') + sym + num(Math.abs(signed), d, loc);
    if (!p.u) return text;
    return text + (loc === 'en_IN' ? ' ' : '') + p.u;
  }
  function smart(n, o) {                  // formatSmart: full below 1 lakh, compact from 1 lakh
    return Math.abs(n) >= 100000 ? compact(n, o) : inr(n, o);
  }
  function percent(v, o) {                // formatPercent: one decimal, optional sign
    o = o || {};
    var d = o.decimals == null ? 1 : o.decimals;
    return (o.sign && v >= 0 ? '+' : '') + v.toFixed(d) + '%';
  }
  function multiplier(v, d) { return v.toFixed(d == null ? 2 : d) + 'x'; }
  function srAmount(n, symbol) {          // AccessibilityUtils.formatCurrencyForScreenReader, en_IN
    var p = indianParts(Math.abs(n), 2);
    var text = num(p.v, 2, 'en_IN') + (p.u === 'L' ? ' lakh' : p.u === 'Cr' ? ' crore' : '');
    var name = { '₹': 'rupees', '$': 'dollars', '€': 'euros', '£': 'pounds' }[symbol || '₹'] || symbol;
    return (n < 0 && p.v !== 0 ? 'negative ' : '') + text + ' ' + name;
  }

  /* ------------------------------------------------------------------ privacy-aware amount */
  function amount(text, o) {
    o = o || {};
    return '<span class="it-amt"><span class="it-amt__v">' + esc(text) + '</span><span class="it-amt__m" role="img" aria-label="Hidden amount">' +
      (o.big ? '••••••' : '•••••') + '</span></span>';
  }

  /* ------------------------------------------------------------------ preview scaffolding */
  function panes(render, o) {
    o = o || {};
    var themes = o.themes || ['light', 'dark'], out = '<div class="it-panes">';
    themes.forEach(function (t) {
      out += '<section class="it-pane" data-theme="' + t + '"' + (o.privacy ? ' data-privacy="on"' : '') + '>' +
        '<p class="it-pane__label">' + (t === 'light' ? 'Light' : 'Dark') + (o.privacy ? ' · privacy mode' : '') + '</p>' + render(t) + '</section>';
    });
    return out + '</div>';
  }
  function wire(root) {
    root = root || document;
    root.addEventListener('click', function (e) {
      var t = e.target.closest ? e.target : e.target.parentElement;
      var pane = t.closest('.it-pane') || document.documentElement;
      var b;
      if ((b = t.closest('[data-it-privacy]'))) {
        var on = pane.getAttribute('data-privacy') === 'on';
        if (on) pane.removeAttribute('data-privacy'); else pane.setAttribute('data-privacy', 'on');
        var ic = b.querySelector('.it-icon');
        if (ic) ic.textContent = on ? 'visibility' : 'visibility_off';
        b.setAttribute('aria-label', on ? 'Hide amounts' : 'Show amounts');
        b.setAttribute('aria-pressed', on ? 'false' : 'true');
        return;
      }
      if ((b = t.closest('[data-it-single]'))) {           // filter chips, type chips, nav items: one selected per group
        var grp = b.closest('[data-it-group]');
        if (grp) {
          Array.prototype.forEach.call(grp.querySelectorAll('[data-it-single]'), function (n) {
            n.classList.remove('is-on'); n.setAttribute('aria-pressed', 'false'); n.removeAttribute('aria-current');
          });
        }
        b.classList.add('is-on'); b.setAttribute('aria-pressed', 'true');
        if (b.classList.contains('it-nav')) b.setAttribute('aria-current', 'page');
        return;
      }
      if ((b = t.closest('[data-it-clear]'))) {
        var inp = b.parentElement.querySelector('input,textarea');
        if (inp) { inp.value = ''; inp.focus(); }
        b.remove();
        return;
      }
      if ((b = t.closest('[data-it-scope]'))) {
        var all = b.getAttribute('data-it-scope') === 'all';
        b.setAttribute('data-it-scope', all ? 'realized' : 'all');
        b.querySelector('span:last-child').textContent = all ? 'Realized' : 'All';
        b.querySelector('.it-icon').textContent = all ? 'check_circle' : 'all_inclusive';
      }
    });
    // long-press on a compact amount shows the exact amount (CompactAmountText)
    var timer = null;
    root.addEventListener('pointerdown', function (e) {
      var a = e.target.closest && e.target.closest('[data-it-exact]');
      if (!a) return;
      timer = setTimeout(function () { exact(a); }, 500);
    });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach(function (n) { root.addEventListener(n, function () { clearTimeout(timer); }); });
    root.addEventListener('keydown', function (e) {
      var a = e.target.closest && e.target.closest('[data-it-exact]');
      if (a && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); exact(a); }
    });
    function exact(a) {
      var pane = a.closest('.it-pane') || document.body;
      var slot = pane.querySelector('[data-it-toast]');
      if (slot) slot.innerHTML = Snackbar({ kind: 'exact', message: a.getAttribute('data-it-exact') });
    }
  }

  /* ------------------------------------------------------------------ GlassCard */
  function GlassCard(inner, o) {
    o = o || {};
    var st = {};
    if (o.radius != null) st['border-radius'] = o.radius + 'px';
    if (o.padding != null) st.padding = o.padding;
    var tap = !!o.onTap || o.tap;
    return '<div class="' + cls('it-glass', o.flat && 'it-glass--flat', tap && 'it-glass--tap', o.focus && 'is-focus', o.cls) + '"' + sty(st) +
      (tap ? ' role="button" tabindex="0"' : '') + (o.label ? ' aria-label="' + esc(o.label) + '"' : '') + '>' + inner + '</div>';
  }

  /* ------------------------------------------------------------------ GradientCard */
  var GRADS = {
    hero: ['#5b4cdb', '#9333ea'], success: ['#059669', '#0d9488'], danger: ['#dc2626', '#ea580c'],
    archive: ['#f59e0b', '#ea580c'], primary: ['#5b4cdb', '#7c3aed'], gold: ['#d97706', '#fbbf24'], 'hero-dark': ['#1e1b4b', '#3b0764']
  };
  function hexA(h, a) {
    var n = parseInt(h.slice(1), 16);
    return 'rgba(' + ((n >> 16) & 255) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + a + ')';
  }
  function GradientCard(inner, o) {
    o = o || {};
    var g = o.gradient || 'hero', stops = GRADS[g] || GRADS.hero, glow = o.glow !== false;
    var st = { background: 'var(--gradient-' + g + ')' };
    if (glow) st['box-shadow'] = '0 8px 24px ' + hexA(stops[0], 0.4) + ', 0 16px 40px ' + hexA(stops[1], 0.2);
    if (o.padding != null) st.padding = o.padding;
    var tap = !!o.tap;
    return '<div class="' + cls('it-gcard', tap && 'it-gcard--tap') + '"' + sty(st) + (tap ? ' role="button" tabindex="0"' : '') + '>' + inner + '</div>';
  }

  /* ------------------------------------------------------------------ Button */
  function Button(o) {
    o = o || {};
    var v = o.variant || 'elevated';
    if (v === 'fab') {
      return '<button type="button" class="it-fab" aria-label="' + esc(o.label || 'Add') + '">' + icon(o.icon || 'add', { size: 24 }) + '</button>';
    }
    var st = o.color ? ' style="--it-btn-c:' + esc(o.color) + '"' : '';
    var inner = o.loading
      ? '<span class="it-btn__spin" role="progressbar" aria-label="Loading ' + esc(o.label) + '"></span>'
      : (o.icon ? icon(o.icon, { size: o.iconSize || (v === 'gradient' ? 24 : 18) }) : '') + '<span>' + esc(o.label) + '</span>';
    return '<button type="button" class="' + cls('it-btn', 'it-btn--' + v, o.loading && 'is-loading') + '"' + st + (o.disabled || o.loading ? ' disabled' : '') + '>' + inner + '</button>';
  }

  /* ------------------------------------------------------------------ StatTile */
  function trend(positive) { return positive ? 'trending_up' : 'trending_down'; }
  function StatTile(o) {
    o = o || {};
    var k = o.kind || 'metric', c = o.color;
    if (k === 'metric') {
      var ch = o.change != null
        ? '<div class="it-metric__change" style="color:' + (o.positive === false ? 'var(--it-danger-l)' : 'var(--it-success-l)') + '">' +
          icon(trend(o.positive !== false), { size: 14 }) + '<span>' + esc(o.change) + '</span></div>' : '';
      return '<div class="it-metric" role="group" aria-label="' + esc(o.label + ': ' + o.value + (o.change != null ? ', Trending ' + (o.positive === false ? 'down' : 'up') + ' ' + o.change : '')) + '">' +
        '<div class="it-metric__head">' + (o.icon ? '<span class="it-metric__icon"' + sty({ '--c': c }) + '>' + icon(o.icon, { size: 16 }) + '</span>' : '') +
        '<span class="it-metric__label">' + esc(o.label) + '</span></div>' +
        '<div class="it-metric__value">' + (o.sensitive ? amount(o.value) : esc(o.value)) + '</div>' + ch + '</div>';
    }
    if (k === 'quick') {
      return GlassCard('<div class="it-quick"><span class="it-quick__icon"' + sty({ '--c': c }) + '>' + icon(o.icon, { size: 24 }) + '</span><div>' +
        '<div class="it-quick__label">' + esc(o.label) + '</div><div class="it-quick__value">' + (o.sensitive === false ? esc(o.value) : amount(o.value)) + '</div>' +
        (o.sub ? '<div class="it-quick__sub it-hide-private">' + esc(o.sub) + '</div>' : '') + '</div></div>', { padding: '16px' });
    }
    if (k === 'mini') {
      return GlassCard('<div class="it-mini"><div class="it-mini__label">' + esc(o.label) + '</div><div class="it-mini__value" style="color:' + (o.color || 'var(--text)') + '">' +
        (o.sensitive === false ? esc(o.value) : amount(o.value)) + '</div>' + (o.sub ? '<div class="it-mini__sub">' + esc(o.sub) + '</div>' : '') + '</div>', { padding: '12px' });
    }
    if (k === 'net') {
      var accent = o.neutral ? 'var(--text-muted)' : (o.positive === false ? 'var(--it-danger-l)' : 'var(--it-success-l)');
      var badge = o.status
        ? '<span class="it-pill" style="color:var(--text-muted);background:color-mix(in srgb,var(--text-muted) 15%,transparent)">' + esc(o.status) + '</span>'
        : '<span class="it-pill it-hide-private" style="font-size:14px;font-weight:600;color:' + accent + ';background:color-mix(in srgb,' + accent + ' 15%,transparent)">' + esc(o.returnText) + '</span>';
      return GlassCard('<div class="it-netpos"><span class="it-netpos__icon"' + sty({ '--c': accent }) + '>' + icon(o.neutral ? 'hourglass_top' : trend(o.positive !== false), { size: 28 }) + '</span>' +
        '<div style="flex:1;min-width:0"><div class="it-netpos__label">' + esc(o.label) + '</div><div class="it-netpos__value">' + amount(o.value) + '</div></div>' + badge + '</div>', { padding: '16px' });
    }
    if (k === 'current') {
      return GlassCard('<div class="it-cvalue"><div class="it-cvalue__main"><div class="it-cvalue__label">' + esc(o.label) + '</div>' +
        (o.value ? '<div class="it-cvalue__amt">' + amount(o.value) + '</div>' : '') + '<div class="it-cvalue__basis">' + esc(o.basis) + '</div></div>' +
        (o.action ? Button({ variant: 'text', label: o.action }) : '') + '</div>', { padding: '0' });
    }
    if (k === 'flows') {
      return GlassCard('<div class="it-flows">' + icon('arrow_upward', { size: 16, color: 'var(--it-danger-l)' }) + amount(o.out) + '<small>&nbsp;out</small><span class="it-gap"></span>' +
        icon('arrow_downward', { size: 16, color: 'var(--it-success-l)' }) + amount(o.inn) + '<small>&nbsp;in</small><span class="it-sp"></span><small>' + esc(o.count) + '</small></div>', { padding: '0' });
    }
    if (k === 'maturity') {
      var col = o.color || 'var(--it-accent-l)';
      return GlassCard('<div class="it-cvalue"><span class="it-metric__icon"' + sty({ '--c': col }) + '>' + icon(o.icon || 'event', { size: 18 }) + '</span>' +
        '<div class="it-cvalue__main"><div class="it-cvalue__label">Maturity Date</div><div class="it-cvalue__amt">' + esc(o.date) + '</div></div>' +
        '<span class="it-pill" style="color:' + col + ';background:color-mix(in srgb,' + col + ' 15%,transparent)">' + esc(o.status) + '</span></div>', { padding: '0' });
    }
    if (k === 'hero') {
      return '<div><div style="font:500 14px/1.4 var(--font-text);color:rgba(255,255,255,.8)">' + esc(o.label) + '</div>' +
        '<div style="margin-top:8px;font:700 40px/1.1 var(--font-display);letter-spacing:-1px;color:#fff">' + esc(o.value) + '</div>' +
        (o.subtitle ? '<div style="margin-top:8px;font:400 14px/1.4 var(--font-text);color:rgba(255,255,255,.7)">' + esc(o.subtitle) + '</div>' : '') + '</div>';
    }
    return '';
  }

  /* ------------------------------------------------------------------ Badge */
  function Badge(o) {
    o = o || {};
    var k = o.kind || 'change';
    if (k === 'change') {
      var v = o.value, zero = v === 0, up = v >= 0, size = o.size || 'm';
      var isz = { s: 10, m: 12, l: 16 }[size];
      var text = (o.prefix || '') + (up && !zero ? '+' : '') + v.toFixed(2) + (o.suffix == null ? '%' : o.suffix);
      return '<span class="' + cls('it-chg', size === 's' && 'it-chg--s', size === 'l' && 'it-chg--l', zero ? 'it-chg--zero' : up ? 'it-chg--up' : 'it-chg--down', o.filled === false && 'it-chg--outline') + '">' +
        (o.icon !== false && !zero ? icon(up ? 'arrow_upward' : 'arrow_downward', { size: isz }) : '') + '<span>' + esc(text) + '</span></span>';
    }
    if (k === 'status') {
      return '<span class="' + cls('it-status', o.outlined && 'it-status--outline') + '"' + sty({ '--c': o.color || 'var(--primary)' }) + '>' + esc(o.label) + '</span>';
    }
    if (k === 'currency') {
      var sym = { USD: '$', INR: '₹', EUR: '€', GBP: '£', JPY: '¥' };
      if (o.compact || o.rate == null || !o.target) return '<span class="it-ccy">' + esc(o.code) + '</span>';
      return '<span class="it-ccy it-ccy--full">' + esc(o.code) + '<i>|</i><span>1 ' + esc(sym[o.code] || o.code) + ' = ' + esc(sym[o.target] || o.target) + Number(o.rate).toFixed(2) + '</span></span>';
    }
    if (k === 'maturity') {
      var tone = { success: 'var(--it-success-l)', warning: 'var(--it-warning-l)', accent: 'var(--it-accent-l)' }[o.tone || 'accent'];
      return '<span class="it-tag it-tag--strong"' + sty({ '--c': tone }) + '>' + (o.icon ? icon(o.icon, { size: 10 }) : '') + '<span class="it-tag__t">' + esc(o.label) + '</span></span>';
    }
    if (k === 'type') return '<span class="it-tag"' + sty({ '--c': o.color }) + '>' + esc(o.label) + '</span>';
    if (k === 'closed') return '<span class="it-tag it-tag--closed">CLOSED</span>';
    return '';
  }

  /* ------------------------------------------------------------------ Chip */
  function Chip(o) {
    o = o || {};
    var k = o.kind || 'filter';
    if (k === 'filter') {
      return '<button type="button" class="' + cls('it-fchip', o.selected && 'is-on', o.focus && 'is-focus') + '" data-it-single aria-pressed="' + (o.selected ? 'true' : 'false') + '" aria-label="' + esc(o.label + ', ' + (o.count || 0) + ' items') + '">' +
        '<span>' + esc(o.label) + '</span>' + (o.count > 0 ? '<span class="it-fchip__n">' + o.count + '</span>' : '') + '</button>';
    }
    if (k === 'type') {
      return '<button type="button" class="' + cls('it-tchip', o.compact && 'it-tchip--compact', o.selected && 'is-on', o.focus && 'is-focus') + '"' + sty({ '--c': o.color }) + ' data-it-single aria-pressed="' + (o.selected ? 'true' : 'false') + '">' +
        '<span class="it-tchip__ic">' + icon(o.icon, { size: o.compact ? 16 : 18 }) + '</span><span class="it-tchip__t">' + esc(o.label) + '</span></button>';
    }
    if (k === 'template') {
      return '<button type="button" class="it-tmpl"' + sty({ '--c': o.color }) + ' aria-label="Template: ' + esc(o.label) + '"><span style="font-size:16px">' + o.emoji + '</span>' + esc(o.label) + '</button>';
    }
    if (k === 'theme') return '<span class="' + cls('it-ctheme', o.selected && 'is-on') + '">' + esc(o.label) + '</span>';
    return '';
  }

  /* ------------------------------------------------------------------ EmptyState */
  function EmptyState(o) {
    o = o || {};
    var k = o.kind || 'basic';
    if (k === 'basic') {
      var ic = icon(o.icon, { cls: 'it-empty__icon', size: o.compact ? 40 : 64 });
      if (o.disc) ic = '<span class="it-empty__disc" style="background:linear-gradient(90deg,' + o.disc.join(',') + ')">' + ic + '</span>';
      return '<div class="' + cls('it-empty', o.compact && 'it-empty--compact') + '" role="group" aria-label="' + esc(o.title + '. ' + o.message) + '">' + ic +
        '<h3 class="it-empty__title">' + esc(o.title) + '</h3><p class="it-empty__msg">' + esc(o.message) + '</p>' +
        (o.actionLabel ? '<div class="it-empty__act">' + Button({ variant: 'text', label: o.actionLabel, icon: o.actionIcon || 'add' }) + '</div>' : '') + '</div>';
    }
    if (k === 'demo') {          // OverviewEmptyState _XIRRDemoCard, shown at its final frame
      return GlassCard('<div class="it-demo"><span class="it-demo__disc">' + icon('insights', { size: 40 }) + '</span><h3 class="it-demo__title">' + esc(o.title) + '</h3><p class="it-demo__sub">' + esc(o.subtitle) + '</p>' +
        '<div class="it-demo__cmp" role="img" aria-label="' + esc(o.sr) + '"><div class="it-demo__col">' + icon('campaign', { size: 24, color: 'var(--text-muted)' }) + '<b>' + esc(o.advertised) + '</b><small>Advertised</small></div>' +
        icon('arrow_forward', { size: 24, color: 'var(--text-subtle)' }) +
        '<div class="it-demo__col">' + icon('trending_down', { size: 24, color: 'var(--it-warning-l)' }) + '<b style="color:var(--it-warning-l)">' + esc(o.real) + '</b><small>Your XIRR</small></div></div>' +
        '<p class="it-demo__cap">' + esc(o.caption) + '</p></div>');
    }
    if (k === 'quickstart') {
      var tile = function (ic2, label, sub, col) {
        return '<button type="button" class="it-qs"' + sty({ '--c': col }) + ' aria-label="' + esc(label + ', ' + sub) + '"><span class="it-qs__disc">' + icon(ic2, { size: 24 }) + '</span><b>' + esc(label) + '</b><small>' + esc(sub) + '</small></button>';
      };
      return GlassCard('<h3 class="it-h4">Get Started</h3><div class="it-tile2">' + tile('add', 'Add Manually', 'Step by step', 'var(--primary)') + tile('upload_file', 'Import CSV', 'Bulk upload', 'var(--it-accent-l)') + '</div>');
    }
    if (k === 'sample') {
      return '<div class="it-banner"><span class="it-banner__disc">' + icon('science', { size: 24 }) + '</span><div class="it-banner__txt"><b>Try Sample Data</b><small>Explore with realistic Indian investments</small></div>' + Button({ variant: 'text', label: 'Try It' }) + '</div>';
    }
    if (k === 'error') {         // OverviewLoadErrorState: no add, import or sample-data action
      return GlassCard('<div class="it-errst">' + icon('cloud_off', { size: 48, color: 'var(--it-danger-l)' }) +
        '<h3 class="it-errst__t" aria-live="polite">Couldn\'t load your portfolio</h3>' +
        '<p class="it-errst__m">Your data is safe. Check your connection and try again.</p>' +
        Button({ variant: 'filled', label: 'Retry', icon: 'refresh', iconSize: 18 }) + '</div>');
    }
    return '';
  }

  /* ------------------------------------------------------------------ TextField */
  function TextField(o) {
    o = o || {};
    var id = o.id || ('f' + Math.random().toString(36).slice(2, 8));
    var tag = o.multiline ? 'textarea' : 'input';
    var attrs = ' id="' + id + '" class="it-field__in"' + (o.hint ? ' placeholder="' + esc(o.hint) + '"' : '') + (o.readonly ? ' readonly' : '') + (o.disabled ? ' disabled' : '') +
      (o.error ? ' aria-invalid="true" aria-describedby="' + id + '-e"' : '') + (o.mode ? ' inputmode="' + o.mode + '"' : '') + (o.multiline ? ' rows="3"' : '');
    var field = tag === 'input' ? '<input type="text"' + attrs + ' value="' + esc(o.value || '') + '">' : '<textarea' + attrs + '>' + esc(o.value || '') + '</textarea>';
    var clear = o.value && !o.readonly && !o.disabled
      ? '<button type="button" class="it-field__clear" data-it-clear aria-label="Clear text">' + icon('cancel', { size: 20 }) + '</button>' : '';
    return '<div class="' + cls('it-field', o.readonly && 'is-readonly') + '">' +
      (o.label ? '<label class="it-field__label" for="' + id + '">' + esc(o.label) + '</label>' : '') +
      '<div class="' + cls('it-field__box', o.focus && 'is-focus', o.error && 'is-error') + '">' +
      (o.prefixIcon ? icon(o.prefixIcon, { cls: 'it-field__ic', size: 24 }) : '') + (o.prefixText ? '<span class="it-field__pre">' + esc(o.prefixText) + '</span>' : '') +
      field + clear + '</div>' +
      (o.error ? '<div class="it-field__err" id="' + id + '-e" role="alert">' + esc(o.error) + '</div>' : '') + '</div>';
  }

  /* ------------------------------------------------------------------ PrivacyMask */
  function PrivacyMask(o) {
    o = o || {};
    var k = o.kind || 'amount';
    if (k === 'toggle') {
      var on = !!o.on, bg = o.background !== false;
      if (!bg) {
        return '<button type="button" data-it-privacy aria-pressed="' + on + '" aria-label="' + (on ? 'Show amounts' : 'Hide amounts') + '" title="' + (on ? 'Show amounts' : 'Hide amounts') + '" style="display:inline-flex;padding:8px;border:0;background:transparent;color:' + (o.color || 'var(--text-muted)') + ';cursor:pointer">' + icon(on ? 'visibility_off' : 'visibility', { size: o.size || 20 }) + '</button>';
      }
      return '<button type="button" class="it-hero__eye" data-it-privacy aria-pressed="' + on + '" aria-label="' + (on ? 'Show amounts' : 'Hide amounts') + '" title="' + (on ? 'Show amounts' : 'Hide amounts') + '">' + icon(on ? 'visibility_off' : 'visibility', { size: o.size || 18 }) + '</button>';
    }
    if (k === 'blur') return '<span class="it-blur-mask" aria-hidden="false">' + o.html + '</span>';
    return amount(o.text, { big: o.big });
  }

  /* ------------------------------------------------------------------ AmountText */
  function AmountText(o) {
    o = o || {};
    var sym = o.symbol || '₹';
    var exact = inr(Math.abs(o.amount), { decimals: 2, symbol: sym });
    var full = (o.amount < 0 && !o.prefix ? '-' : '') + (o.prefix || '') + exact;
    var shown = (o.prefix || '') + compact(o.prefix ? Math.abs(o.amount) : o.amount, { symbol: sym });
    return '<span class="it-amt" role="text" tabindex="0" data-it-exact="' + esc(full) + '" aria-label="' + esc(srAmount(o.amount, sym)) + '" title="Press and hold for the exact amount"' + sty(o.style ? o.style : null) + '>' +
      '<span class="it-amt__v">' + esc(shown) + '</span><span class="it-amt__m" role="img" aria-label="Hidden amount">•••••</span></span>';
  }

  /* ------------------------------------------------------------------ Skeleton */
  function box(w, h, hero) {
    return '<span class="it-skel' + (hero ? ' it-skel--hero' : '') + '" style="width:' + (typeof w === 'number' ? w + 'px' : w) + ';height:' + h + 'px;border-radius:' + (h / 3) + 'px"></span>';
  }
  function Skeleton(o) {
    o = o || {};
    var k = o.kind || 'investment';
    if (k === 'hero') {
      return '<div class="it-shimmer" role="status" aria-label="Loading summary"><div class="it-hero it-stack" style="gap:12px">' + box(120, 14, true) + box(180, 36, true) + '<span style="display:block;margin-top:-4px">' + box(100, 14, true) + '</span></div></div>';
    }
    if (k === 'investment') {
      return '<div class="it-shimmer" role="status" aria-label="Loading investment">' + GlassCard('<div class="it-skelrow"><span class="it-skel" style="width:48px;height:48px;border-radius:12px"></span>' +
        '<div style="flex:1" class="it-stack"><div>' + box(140, 16) + '</div><div style="margin-top:8px">' + box(100, 12) + '</div></div>' +
        '<div style="display:flex;flex-direction:column;align-items:flex-end;gap:8px">' + box(80, 16) + box(50, 12) + '</div></div>', { flat: true }) + '</div>';
    }
    if (k === 'cashflow') {
      return '<div class="it-shimmer" role="status" aria-label="Loading content">' + GlassCard('<div class="it-skelrow" style="gap:14px"><span class="it-skel" style="width:40px;height:40px;border-radius:10px"></span>' +
        '<div style="flex:1"><div>' + box(80, 14) + '</div><div style="margin-top:6px">' + box(100, 12) + '</div></div>' + box(70, 18) + '</div>', { padding: '14px', flat: true }) + '</div>';
    }
    if (k === 'stats') {
      var one = GlassCard('<span class="it-skel" style="width:36px;height:36px;border-radius:10px"></span><div style="margin-top:10px">' + box(60, 20) + '</div><div style="margin-top:6px">' + box(50, 12) + '</div>', { padding: '12px', flat: true });
      return '<div class="it-shimmer it-two" style="grid-template-columns:repeat(3,1fr);gap:12px" role="status" aria-label="Loading content">' + one + one + one + '</div>';
    }
    if (k === 'section') {
      return '<div class="it-shimmer" role="status" aria-label="Loading content">' + GlassCard(box(140, 16) + '<div style="margin-top:16px">' + box('100%', (o.height || 150) - 60) + '</div>') + '</div>';
    }
    if (k === 'fullscreen') {
      return '<div class="it-loading" role="status" aria-label="' + esc(o.message || 'Loading') + '"><span class="it-loading__disc">' + icon('account_balance_wallet', { size: 48 }) + '</span><span class="it-loading__ring"></span>' +
        (o.message ? '<p class="it-loading__msg">' + esc(o.message) + '</p>' : '') + '</div>';
    }
    return '';
  }

  /* ------------------------------------------------------------------ HeroCard */
  function HeroCard(o) {
    o = o || {};
    if (o.loading) {
      return '<div class="it-hero it-stack" style="gap:12px" role="status" aria-label="Loading summary"><span class="it-skel it-hero__bar" style="width:100px;height:14px;background:rgba(255,255,255,.3);border-radius:4px"></span><span class="it-skel" style="width:200px;height:36px;background:rgba(255,255,255,.3);border-radius:8px"></span></div>';
    }
    var scope = o.scope === 'realized';
    var title = scope ? 'Realized Net Position' : 'Net cash flow so far';
    var badge = o.status
      ? '<span class="it-hero__badge it-hero__badge--status it-hide-private">' + esc(o.status) + '</span>'
      : '<span class="' + cls('it-hero__badge', o.positive === false ? 'it-hero__badge--down' : 'it-hero__badge--up', 'it-hide-private') + '">' + esc(o.returnText) + '</span>';
    var value = '<div class="it-hero__amount">' + amount(o.amount, { big: true }) + '</div>';
    var valueRow = o.status
      ? '<div class="it-hero__value">' + value + badge + '</div>'
      : '<div class="it-hero__value it-hero__value--row">' + value + badge + '</div>';
    var xirrs = (o.realisedXirr ? '<div class="it-hero__metric"><small>Realised XIRR</small><b>' + amount(o.realisedXirr) + '</b></div>' : '') +
      '<div class="it-hero__metric"><small>' + esc(o.xirrLabel || 'XIRR') + '</small><b>' + amount(o.xirr) + '</b></div>';
    return '<div class="it-hero" role="group" aria-label="' + esc(title) + '">' +
      '<div class="it-hero__title-row"><div class="it-hero__title">' + esc(title) + '</div>' + PrivacyMask({ kind: 'toggle', on: !!o.privacy, size: 18 }) +
      '<button type="button" class="it-hero__scope" data-it-scope="' + (scope ? 'realized' : 'all') + '" aria-label="' + (scope ? 'Switch to all investments' : 'Switch to realized investments only') + '">' + icon(scope ? 'check_circle' : 'all_inclusive', { size: 14 }) + '<span>' + (scope ? 'Realized' : 'All') + '</span></button></div>' +
      valueRow +
      '<div class="it-hero__stats"><div class="it-hero__flows">' +
      '<span class="it-hero__flow">' + icon('arrow_upward', { size: 14 }) + amount(o.out) + '<small>out</small></span>' +
      '<span class="it-hero__flow">' + icon('arrow_downward', { size: 14 }) + amount(o.inn) + '<small>in</small></span></div>' +
      '<div class="it-hero__metrics">' + xirrs + '</div></div>' +
      (o.note ? '<p class="it-hero__note">' + esc(o.note) + '</p>' : '') +
      (o.hint ? '<p class="it-hero__note">' + esc(o.hint) + '</p>' : '') +
      '<div class="it-hero__ccy">' + icon('info_outline', { size: 12 }) + '<span>All amounts shown in ' + esc(o.currencyLabel || '₹ (INR)') + '</span></div>' +
      (scope ? '<p class="it-hero__note it-hero__note--scope">Showing closed investments only</p>' : '') + '</div>';
  }

  /* ------------------------------------------------------------------ InvestmentCard */
  var TYPES = {
    'p2p-lending': ['P2P Lending', 'handshake'], 'fixed-deposit': ['Fixed Deposit', 'account_balance'], 'bonds': ['Bonds/Debentures', 'description'],
    'real-estate': ['Real Estate', 'home'], 'private-equity': ['Private Equity', 'business_center'], 'angel-investing': ['Angel Investing', 'rocket_launch'],
    'chit-funds': ['Chit Funds', 'group'], 'gold': ['Gold/Commodities', 'monetization_on'], 'crypto': ['Crypto', 'currency_bitcoin'],
    'mutual-funds': ['Mutual Funds', 'pie_chart'], 'stocks': ['Stocks', 'show_chart'], 'invoice-discounting': ['Invoice Discounting', 'receipt_long'],
    'financing': ['Financing', 'payments'], 'other': ['Other', 'attach_money']
  };
  function InvestmentCard(o) {
    o = o || {};
    var t = TYPES[o.type] || TYPES.other, col = o.closed ? 'var(--it-grey)' : 'var(--inv-' + (TYPES[o.type] ? o.type : 'other') + ')';
    var tagCol = 'var(--inv-' + (TYPES[o.type] ? o.type : 'other') + ')';
    var netCol = o.positive === false ? 'var(--it-danger-l)' : 'var(--graph-emerald)';
    // A card that awaits its value (`status`) shows what went in and what came back, with no net, sign or percent.
    var awaiting = !!o.status && !o.empty;
    var tags = Badge({ kind: 'type', label: o.typeName || t[0], color: tagCol }) + (o.closed ? Badge({ kind: 'closed' }) : '') + (o.maturity && !o.closed ? Badge(Object.assign({ kind: 'maturity' }, o.maturity)) : '');
    var right = o.empty ? '<span class="it-inv__chev">' + icon('chevron_right', { size: 24 }) + '</span>'
      : awaiting ? '<div class="it-inv__val"><div class="it-inv__ledger"><span class="it-inv__net it-inv__net--ink">' + amount(o.invested) + '</span><span class="it-inv__w">invested</span>' +
        '<span class="it-inv__got">' + amount(o.received) + '</span><span class="it-inv__w">received</span></div>' +
        '<span class="it-inv__badge it-inv__badge--status">' + esc(o.status) + '</span></div>'
      : '<div class="it-inv__val"><div class="it-inv__net" style="color:' + netCol + '">' + amount((o.positive === false ? '-' : '+') + o.net.replace(/^[-+]/, '')) + '</div>' +
        (o.badge ? '<span class="it-inv__badge it-hide-private" style="--c:' + (o.badge.positive === false ? 'var(--it-danger-l)' : 'var(--graph-emerald)') + '">' + esc(o.badge.text) + '</span>' : '') + '</div>';
    var strip = '<div class="it-inv__strip"><span>' + icon('update', { size: 12 }) + esc(o.last) + '</span><span>' + icon('receipt_long', { size: 12 }) + esc(o.entries) + '</span>' +
      (awaiting ? '' : '<span class="it-sp"></span>' + (o.invested ? '<span><b>Invested: </b>' + amount(o.invested) + '</span>' : '<a href="#" onclick="return false">View Details</a>')) + '</div>';
    var label = (o.closed ? 'Closed' : 'Open') + ' investment: ' + (o.name || '') + '. Type: ' + (o.typeName || t[0]);
    return '<div class="it-glass it-glass--flat it-glass--tap it-inv" role="button" tabindex="0" aria-label="' + esc(label) + '">' +
      '<div class="it-inv__main">' + (o.selectionMode ? '<input class="it-inv__check" type="checkbox" aria-label="Select"' + (o.selected ? ' checked' : '') + '>' : '') +
      '<span class="it-inv__tile"' + sty({ '--c': col }) + '>' + icon(t[1], { size: 24 }) + '</span>' +
      '<div class="it-inv__info"><p class="it-inv__name">' + esc(o.name) + '</p><div class="it-inv__tags">' + tags + '</div></div>' + right + '</div>' + strip + '</div>';
  }

  /* ------------------------------------------------------------------ BottomSheet / Dialog / Snackbar */
  function behind() {
    return '<div class="it-stage__bg it-stack" style="padding:16px;gap:12px" aria-hidden="true"><div class="it-hero" style="height:96px;padding:0"></div>' +
      GlassCard('<div class="it-h4" style="margin:0">Investments</div><div class="it-cap" style="margin:4px 0 0">12 open, 3 closed</div>') + GlassCard('<div class="it-h4" style="margin:0">Goals</div>') + '</div>';
  }
  function BottomSheet(o) {
    o = o || {};
    var opts = (o.options || []).map(function (x) {
      return '<button type="button" class="' + cls('it-opt', x.selected && 'is-on') + '" data-it-single aria-pressed="' + (x.selected ? 'true' : 'false') + '">' + icon(x.icon, { size: 24, family: x.base ? 'base' : undefined }) +
        '<span class="it-opt__t">' + esc(x.label) + (x.isDefault ? '<span class="it-opt__def">Default</span>' : '') + '</span>' + (x.selected ? icon('check', { size: 24, color: 'var(--it-primary-l)' }) : '') + '</button>';
    }).join('');
    return '<div class="it-stage" style="min-height:' + (o.height || 420) + 'px">' + behind() + '<div class="it-scrim"></div>' +
      '<div class="it-sheet" role="dialog" aria-label="' + esc(o.title) + '"><div class="it-sheet__handle"></div><div class="it-sheet__head">' + icon(o.icon || 'sort', { size: 24 }) +
      '<h3 class="it-sheet__title">' + esc(o.title) + '</h3>' + (o.reset ? Button({ variant: 'text', label: 'Reset' }) : '') + '</div><hr class="it-sheet__hr"><div data-it-group>' + opts + '</div></div></div>';
  }
  function Dialog(o) {
    o = o || {};
    var m3 = o.variant === 'form';
    var body = m3 ? (o.html || '') : '<p class="it-dialog__body">' + esc(o.message) + '</p>';
    var acts = m3
      ? Button({ variant: 'text', label: 'Use estimate' }) + Button({ variant: 'text', label: 'Cancel' }) + Button({ variant: 'filled', label: 'Save' })
      : '<button type="button" class="it-btn it-btn--text is-muted">' + esc(o.cancel || 'Cancel') + '</button><button type="button" class="it-btn it-btn--text ' + (o.destructive === false ? 'is-primary' : 'is-danger') + '">' + esc(o.confirm || 'Delete') + '</button>';
    return '<div class="it-stage" style="min-height:' + (o.height || 360) + 'px">' + behind() + '<div class="it-scrim"></div><div class="' + cls('it-dialog', m3 && 'it-dialog--m3') + '" role="alertdialog" aria-label="' + esc(o.title) + '">' +
      '<h3 class="it-dialog__title">' + esc(o.title) + '</h3>' + body + '<div class="it-dialog__act">' + acts + '</div></div></div>';
  }
  function Snackbar(o) {
    o = o || {};
    var k = o.kind || 'info';
    if (k === 'exact') {
      return '<div class="it-snack it-snack--exact" role="status"><div style="flex:1"><small>Exact Amount</small><b>' + esc(o.message) + '</b></div>' +
        '<button type="button" class="it-snack__btn" aria-label="Copy amount">' + icon('copy', { size: 20 }) + '</button></div>';
    }
    var ic = { success: 'check_circle', error: 'error', info: 'info' }[k];
    return '<div class="it-snack it-snack--' + k + '" role="status">' + icon(ic, { size: 20 }) + '<span>' + esc(o.message) + '</span></div>';
  }

  /* ------------------------------------------------------------------ Navigation */
  function Navigation(o) {
    o = o || {};
    var items = o.items || [
      { label: 'Overview', icon: 'pie_chart_outline', on: 'pie_chart' }, { label: 'Investments', icon: 'account_balance_wallet', on: 'account_balance_wallet', outlined: true },
      { label: 'Goals', icon: 'flag', on: 'flag', outlined: true }, { label: 'Reports', icon: 'assessment', on: 'assessment', outlined: true }, { label: 'Settings', icon: 'settings', on: 'settings', outlined: true }
    ];
    var active = o.active == null ? 0 : o.active;
    var nav = items.map(function (it, i) {
      var on = i === active;
      return '<button type="button" class="' + cls('it-nav', on && 'is-on') + '" data-it-single aria-pressed="' + on + '"' + (on ? ' aria-current="page"' : '') + '><span class="it-nav__pill">' +
        icon(on ? it.on : it.icon, { size: 24, family: on ? 'base' : (it.outlined ? 'outlined' : 'base') }) + '</span><span>' + esc(it.label) + '</span></button>';
    }).join('');
    return '<div class="it-phone"><div class="it-appbar"><h2 class="it-appbar__title">' + esc(o.title || 'Overview') + '</h2>' +
      (o.actions || []).map(function (a) { return '<button type="button" class="it-appbar__act" aria-label="' + esc(a.label) + '">' + icon(a.icon, { size: 24 }) + '</button>'; }).join('') + '</div>' +
      '<div class="it-phone__body">' + (o.body || '') + (o.fab === false ? '' : Button({ variant: 'fab', icon: 'add', label: 'Add Investment' })) + '</div>' +
      '<nav class="it-navbar" data-it-group aria-label="Primary">' + nav + '</nav></div>';
  }

  /* ------------------------------------------------------------------ export */
  window.InvTrack = {
    GlassCard: GlassCard, GradientCard: GradientCard, Button: Button, StatTile: StatTile, Badge: Badge, Chip: Chip, EmptyState: EmptyState,
    TextField: TextField, PrivacyMask: PrivacyMask, AmountText: AmountText, Skeleton: Skeleton, HeroCard: HeroCard, InvestmentCard: InvestmentCard,
    BottomSheet: BottomSheet, Dialog: Dialog, Snackbar: Snackbar, Navigation: Navigation,
    icon: icon, amount: amount, panes: panes, wire: wire, esc: esc,
    fmt: { inr: inr, compact: compact, smart: smart, percent: percent, multiplier: multiplier, srAmount: srAmount },
    types: TYPES
  };
})();
