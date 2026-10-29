// Quickey Design System — 文件站共用互動元件（Select/DatePicker）
// 由 build_pages.py 輸出為 design-components.js。這裡只是「文件示意」用的輕量實作，
// 外觀與互動對齊 PrimeVue 的 <Select> / <DatePicker>；正式專案一律直接使用 PrimeVue 元件。
(function(){
  var QDS = window.QDS = window.QDS || {};
  var CHEV_L = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M15 18l-6-6 6-6"/></svg>';
  var CHEV_R = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M9 18l6-6-6-6"/></svg>';
  var DOW = ['日','一','二','三','四','五','六'];
  function pad(n){ return (n < 10 ? '0' : '') + n; }
  function iso(d){ return d.getFullYear() + '-' + pad(d.getMonth()+1) + '-' + pad(d.getDate()); }
  function parse(s){ if(!s) return null; var p = s.split('-'); return new Date(+p[0], +p[1]-1, +p[2]); }
  function fmt(d){ return d ? d.getFullYear() + '/' + pad(d.getMonth()+1) + '/' + pad(d.getDate()) : ''; }
  function addDays(d, n){ var x = new Date(d); x.setDate(x.getDate() + n); return x; }
  function same(a, b){ return !!a && !!b && a.getTime() === b.getTime(); }
  QDS.today = function(){ return QDS.TODAY ? new Date(QDS.TODAY) : (function(){ var t = new Date(); return new Date(t.getFullYear(), t.getMonth(), t.getDate()); })(); };
  QDS.fmtDate = fmt; QDS.parseDate = parse; QDS.isoDate = iso;

  function closeAll(except){
    [].forEach.call(document.querySelectorAll('.qds-open'), function(el){
      if (el === except) return;
      el.classList.remove('qds-open');
      var t = el.querySelector('[aria-expanded]'); if (t) t.setAttribute('aria-expanded', 'false');
    });
  }
  QDS.closeAll = closeAll;
  document.addEventListener('mousedown', function(e){ if (!e.target.closest('.qds-select, .qds-datepicker, .qds-period')) closeAll(); });
  function emit(el, detail){ el.dispatchEvent(new CustomEvent('qds-change', { bubbles: true, detail: detail })); }

  // ---------------- Select ----------------
  function initSelect(el){
    if (el._qds) return; el._qds = true;
    var trig = el.querySelector('.qds-select-trigger'), panel = el.querySelector('.qds-select-panel'), val = el.querySelector('.qds-select-value');
    var opts = [].slice.call(panel.querySelectorAll('[role="option"]'));
    opts.forEach(function(o){ o.tabIndex = -1; });
    // data-filter：選項多時在面板頂端加關鍵字搜尋（對應 PrimeVue Select 的 filter）
    var filt = el.hasAttribute('data-filter'), fin = null, fempty = null;
    function addFilter(){
      if (!filt) return;
      var li = document.createElement('li'); li.className = 'qds-select-filter'; li.setAttribute('role', 'presentation');
      li.innerHTML = '<input type="text" autocomplete="off" aria-label="搜尋選項" placeholder="' + (el.dataset.filter || '輸入關鍵字搜尋') + '">';
      panel.insertBefore(li, panel.firstChild); fin = li.querySelector('input');
      fempty = document.createElement('li'); fempty.className = 'qds-select-empty'; fempty.setAttribute('role', 'presentation'); fempty.textContent = '找不到符合的選項'; fempty.hidden = true; panel.appendChild(fempty);
      fin.addEventListener('input', applyFilter);
    }
    function applyFilter(){
      var q = fin.value.trim().toLowerCase(), n = 0;
      opts.forEach(function(o){ var hit = !q || o.textContent.toLowerCase().indexOf(q) > -1; o.hidden = !hit; if (hit) n++; });
      fempty.hidden = n > 0;
    }
    function vis(){ return opts.filter(function(o){ return !o.hidden; }); }
    addFilter();
    function setOpen(o){
      if (o) closeAll(el);
      el.classList.toggle('qds-open', o); trig.setAttribute('aria-expanded', o ? 'true' : 'false');
      if (o && fin){ fin.value = ''; applyFilter(); setTimeout(function(){ fin.focus(); }, 0); return; }
      if (o){ var cur = panel.querySelector('.sel') || opts[0]; setTimeout(function(){ cur.focus(); }, 0); }
    }
    function choose(o, fire){
      opts.forEach(function(x){ var on = x === o; x.classList.toggle('sel', on); x.setAttribute('aria-selected', on ? 'true' : 'false'); });
      val.textContent = o.textContent.trim(); val.classList.remove('is-placeholder');
      el.dataset.value = o.dataset.value;
      el.classList.remove('is-invalid');
      if (fire) emit(el, { value: o.dataset.value, label: o.textContent.trim() });
    }
    trig.addEventListener('click', function(){ if (!trig.disabled) setOpen(!el.classList.contains('qds-open')); });
    trig.addEventListener('keydown', function(e){
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp'){ e.preventDefault(); setOpen(true); }
    });
    panel.addEventListener('click', function(e){
      e.stopPropagation();
      var o = e.target.closest('[role="option"]'); if (!o) return;
      choose(o, true); setOpen(false); trig.focus();
    });
    panel.addEventListener('keydown', function(e){
      var v = vis(), i = v.indexOf(document.activeElement), inInput = fin && document.activeElement === fin;
      if (inInput && (e.key === 'ArrowDown' || e.key === 'Enter')){ e.preventDefault(); e.stopPropagation(); if (!v.length) return; if (e.key === 'Enter'){ choose(v[0], true); setOpen(false); trig.focus(); } else v[0].focus(); return; }
      if (inInput && e.key === ' ') return;
      if (e.key === 'ArrowDown'){ e.preventDefault(); if (v.length) v[Math.min(i+1, v.length-1)].focus(); }
      else if (e.key === 'ArrowUp'){ e.preventDefault(); if (i <= 0 && fin) fin.focus(); else if (v.length) v[Math.max(i-1, 0)].focus(); }
      else if (e.key === 'Home' && !inInput){ e.preventDefault(); if (v.length) v[0].focus(); }
      else if (e.key === 'End' && !inInput){ e.preventDefault(); if (v.length) v[v.length-1].focus(); }
      else if (e.key === 'Enter' || e.key === ' '){ e.preventDefault(); if (i > -1){ choose(v[i], true); setOpen(false); trig.focus(); } }
      else if (e.key === 'Escape'){ e.preventDefault(); e.stopPropagation(); setOpen(false); trig.focus(); }
      else if (e.key === 'Tab'){ setOpen(false); }
    });
    el.qdsSetValue = function(v){ var o = opts.filter(function(x){ return x.dataset.value === v; })[0]; if (o) choose(o, false); };
    // 動態更新選項（例如類別被停用後），保留目前值；目前值不在新選項裡就改選第一個
    el.qdsSetOptions = function(list, keep){
      var cur = keep != null ? keep : el.dataset.value;
      panel.innerHTML = list.map(function(o){ var v = typeof o === 'string' ? o : o.value, l = typeof o === 'string' ? o : o.label; return '<li role="option" data-value="' + v + '" aria-selected="false" tabindex="-1">' + l + '</li>'; }).join('');
      opts = [].slice.call(panel.querySelectorAll('[role="option"]'));
      addFilter();
      var hit = opts.filter(function(x){ return x.dataset.value === cur; })[0] || opts[0];
      if (hit) choose(hit, false);
    };
    el.qdsGetValue = function(){ return el.dataset.value || ''; };
    var init = panel.querySelector('.sel'); if (init) choose(init, false);
  }

  // ---------------- DatePicker（single / range） ----------------
  function initDatePicker(el){
    if (el._qds) return; el._qds = true;
    // data-view="month"：選月份；data-view="year"：選年份；data-format="zh" 顯示「2026 年 9 月」
    var range = el.dataset.mode === 'range', yearView = el.dataset.view === 'year', monthView = el.dataset.view === 'month' || yearView, zh = el.dataset.format === 'zh';
    function fmtV(d){
      if (!d) return '';
      if (yearView) return d.getFullYear() + (zh ? ' 年' : '');
      if (monthView) return zh ? d.getFullYear() + ' 年 ' + (d.getMonth() + 1) + ' 月' : d.getFullYear() + '/' + pad(d.getMonth() + 1);
      return fmt(d);
    }
    var trig = el.querySelector('.qds-dp-trigger'), val = el.querySelector('.qds-select-value');
    var panel = document.createElement('div');
    panel.className = 'qds-dp-panel'; panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-label', range ? '選擇日期區間' : '選擇日期');
    el.appendChild(panel);
    var st = { start: parse(el.dataset.start || el.dataset.value), end: parse(el.dataset.end), hover: null, focus: null };
    st.view = new Date((st.start || QDS.today()).getFullYear(), (st.start || QDS.today()).getMonth(), 1);
    var placeholder = val.textContent;
    function label(){
      if (range){
        if (st.start && st.end) return fmtV(st.start) + ' – ' + fmtV(st.end);
        return '';
      }
      return fmtV(st.start);
    }
    function sync(){ var t = label(); val.textContent = t || placeholder; val.classList.toggle('is-placeholder', !t); }
    function renderMonths(){
      var y = st.view.getFullYear(), today = QDS.today(), lo = st.start, hi = st.end || (range && st.start && st.hover ? st.hover : null);
      if (lo && hi && hi < lo){ var t0 = lo; lo = hi; hi = t0; }
      var focus = st.focus || st.start || today; if (focus.getFullYear() !== y) focus = new Date(y, 0, 1);
      var h = '<div class="qds-dp-head"><button type="button" class="qds-dp-nav" data-nav="-12" aria-label="上一年">' + CHEV_L + '</button><span class="qds-dp-title" aria-live="polite">' + y + ' 年</span><button type="button" class="qds-dp-nav" data-nav="12" aria-label="下一年">' + CHEV_R + '</button></div><div class="qds-dp-grid qds-dp-months" role="grid">';
      for (var m = 0; m < 12; m++){
        var d = new Date(y, m, 1), c = ['qds-dp-day', 'qds-dp-month'];
        if (y === today.getFullYear() && m === today.getMonth()) c.push('today');
        var isS = same(d, lo), isE = same(d, hi);
        if (isS || isE || (!range && same(d, st.start))) c.push('sel');
        if (range && lo && hi && d > lo && d < hi) c.push(st.end ? 'in-range' : 'preview');
        if (range && lo && hi && !same(lo, hi)){ if (isS) c.push('range-start'); if (isE) c.push('range-end'); }
        h += '<button type="button" class="' + c.join(' ') + '" data-date="' + iso(d) + '" tabindex="' + (same(d, new Date(focus.getFullYear(), focus.getMonth(), 1)) ? 0 : -1) + '" aria-label="' + y + '年' + (m + 1) + '月"' + (c.indexOf('sel') > -1 ? ' aria-selected="true"' : '') + '>' + (m + 1) + ' 月</button>';
      }
      h += '</div><div class="qds-dp-foot"><button type="button" class="qds-dp-link" data-act="clear">清除</button>' + (range && st.start && !st.end ? '<span class="qds-dp-hint">請選擇結束月份</span>' : '') + '<button type="button" class="qds-dp-link" data-act="today">本月</button></div>';
      panel.innerHTML = h;
    }
    function renderYears(){
      var y0 = Math.floor(st.view.getFullYear() / 10) * 10, today = QDS.today();
      var focus = st.focus || st.start || today; if (Math.floor(focus.getFullYear() / 10) * 10 !== y0) focus = new Date(y0, 0, 1);
      var h = '<div class="qds-dp-head"><button type="button" class="qds-dp-nav" data-nav="-120" aria-label="前十年">' + CHEV_L + '</button><span class="qds-dp-title" aria-live="polite">' + y0 + ' – ' + (y0 + 9) + '</span><button type="button" class="qds-dp-nav" data-nav="120" aria-label="後十年">' + CHEV_R + '</button></div><div class="qds-dp-grid qds-dp-months" role="grid">';
      for (var y = y0; y < y0 + 10; y++){
        var d = new Date(y, 0, 1), c = ['qds-dp-day', 'qds-dp-month'];
        if (y === today.getFullYear()) c.push('today');
        if (st.start && st.start.getFullYear() === y) c.push('sel');
        h += '<button type="button" class="' + c.join(' ') + '" data-date="' + iso(d) + '" tabindex="' + (y === focus.getFullYear() ? 0 : -1) + '" aria-label="' + y + '年"' + (c.indexOf('sel') > -1 ? ' aria-selected="true"' : '') + '>' + y + '</button>';
      }
      h += '</div><div class="qds-dp-foot"><span></span><button type="button" class="qds-dp-link" data-act="today">今年</button></div>';
      panel.innerHTML = h;
    }
    function render(){
      if (yearView) return renderYears();
      if (monthView) return renderMonths();
      var y = st.view.getFullYear(), m = st.view.getMonth(), today = QDS.today();
      var first = new Date(y, m, 1), gridStart = addDays(first, -first.getDay());
      var focus = st.focus || st.start || today;
      if (focus.getMonth() !== m || focus.getFullYear() !== y) focus = first;
      var lo = st.start, hi = st.end || (range && st.start && st.hover ? st.hover : null);
      if (lo && hi && hi < lo){ var t = lo; lo = hi; hi = t; }
      var h = '<div class="qds-dp-head"><button type="button" class="qds-dp-nav" data-nav="-1" aria-label="上個月">' + CHEV_L + '</button>' +
        '<span class="qds-dp-title" aria-live="polite">' + y + ' 年 ' + (m+1) + ' 月</span>' +
        '<button type="button" class="qds-dp-nav" data-nav="1" aria-label="下個月">' + CHEV_R + '</button></div><div class="qds-dp-grid" role="grid">';
      DOW.forEach(function(d){ h += '<span class="qds-dp-dow" aria-hidden="true">' + d + '</span>'; });
      for (var i = 0; i < 42; i++){
        var d = addDays(gridStart, i), c = ['qds-dp-day'];
        if (d.getMonth() !== m) c.push('other');
        if (same(d, today)) c.push('today');
        var isStart = same(d, lo), isEnd = same(d, hi);
        if (isStart || isEnd || (!range && same(d, st.start))) c.push('sel');
        if (range && lo && hi && d > lo && d < hi) c.push(st.end ? 'in-range' : 'preview');
        if (range && lo && hi && !same(lo, hi)){ if (isStart) c.push('range-start'); if (isEnd) c.push('range-end'); }
        h += '<button type="button" class="' + c.join(' ') + '" data-date="' + iso(d) + '" tabindex="' + (same(d, focus) ? 0 : -1) + '" aria-label="' + d.getFullYear() + '年' + (d.getMonth()+1) + '月' + d.getDate() + '日' + '"' + (c.indexOf('sel') > -1 ? ' aria-selected="true"' : '') + '>' + d.getDate() + '</button>';
      }
      h += '</div><div class="qds-dp-foot"><button type="button" class="qds-dp-link" data-act="clear">清除</button>' +
        (range && st.start && !st.end ? '<span class="qds-dp-hint">請選擇結束日期</span>' : '') +
        '<button type="button" class="qds-dp-link" data-act="today">今天</button></div>';
      panel.innerHTML = h;
    }
    function focusDay(d){ st.focus = d; if (d.getMonth() !== st.view.getMonth() || d.getFullYear() !== st.view.getFullYear()) st.view = new Date(d.getFullYear(), d.getMonth(), 1); render(); var b = panel.querySelector('[data-date="' + iso(d) + '"]'); if (b) b.focus(); }
    function setOpen(o){
      if (o){ closeAll(el); var b0 = st.start || QDS.today(); st.view = yearView ? new Date(Math.floor(b0.getFullYear() / 10) * 10, 0, 1) : monthView ? new Date(b0.getFullYear(), 0, 1) : new Date(b0.getFullYear(), b0.getMonth(), 1); st.focus = null; render(); }
      el.classList.toggle('qds-open', o); trig.setAttribute('aria-expanded', o ? 'true' : 'false');
      if (o) setTimeout(function(){ var b = panel.querySelector('.qds-dp-day[tabindex="0"]'); if (b) b.focus(); }, 0);
    }
    function pick(d){
      if (!range){ st.start = d; sync(); setOpen(false); trig.focus(); emit(el, { value: iso(d), date: d }); return; }
      if (!st.start || st.end){ st.start = d; st.end = null; st.focus = d; render(); var b = panel.querySelector('[data-date="' + iso(d) + '"]'); if (b) b.focus(); return; }
      if (d < st.start){ st.end = st.start; st.start = d; } else st.end = d;
      sync(); setOpen(false); trig.focus(); var eEnd = monthView ? new Date(st.end.getFullYear(), st.end.getMonth() + 1, 0) : st.end; emit(el, { start: st.start, end: eEnd, value: iso(st.start) + '/' + iso(eEnd) });
    }
    trig.setAttribute('aria-haspopup', 'dialog'); trig.setAttribute('aria-expanded', 'false');
    trig.addEventListener('click', function(){ if (!trig.disabled) setOpen(!el.classList.contains('qds-open')); });
    panel.addEventListener('click', function(e){
      // 面板內會重新繪製，點擊目標可能已被移出 DOM；不讓事件冒泡到外層的「點外面關閉」判斷
      e.stopPropagation();
      var nav = e.target.closest('[data-nav]');
      if (nav){ st.view = new Date(st.view.getFullYear(), st.view.getMonth() + (+nav.dataset.nav), 1); st.focus = null; render(); return; }
      var act = e.target.closest('[data-act]');
      if (act){
        if (act.dataset.act === 'today' && monthView){ var tm = yearView ? new Date(QDS.today().getFullYear(), 0, 1) : new Date(QDS.today().getFullYear(), QDS.today().getMonth(), 1); if (range){ st.start = st.end = null; pick(tm); } pick(tm); return; }
        if (act.dataset.act === 'today'){ if (range){ st.start = st.end = null; pick(QDS.today()); } pick(QDS.today()); }
        else { st.start = st.end = null; sync(); render(); emit(el, { value: '' }); }
        return;
      }
      var day = e.target.closest('[data-date]'); if (day) pick(parse(day.dataset.date));
    });
    panel.addEventListener('mouseover', function(e){
      if (!range || !st.start || st.end) return;
      var day = e.target.closest('[data-date]'); if (!day) return;
      var d = parse(day.dataset.date); if (same(d, st.hover)) return;
      st.hover = d; st.focus = d; render();
    });
    panel.addEventListener('keydown', function(e){
      var cur = e.target.closest('[data-date]');
      if (e.key === 'Escape'){ e.preventDefault(); e.stopPropagation(); setOpen(false); trig.focus(); return; }
      if (!cur) return;
      var d = parse(cur.dataset.date), map = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 };
      if (yearView){ var yy = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -3, ArrowDown: 3 }[e.key]; if (yy !== undefined){ e.preventDefault(); var ny = new Date(d.getFullYear() + yy, 0, 1); st.focus = ny; st.view = ny; render(); var yb = panel.querySelector('[data-date="' + iso(ny) + '"]'); if (yb) yb.focus(); return; } }
      if (monthView && !yearView){ var mm = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -3, ArrowDown: 3 }[e.key]; if (mm !== undefined){ e.preventDefault(); var nd = new Date(d.getFullYear(), d.getMonth() + mm, 1); st.focus = nd; st.view = new Date(nd.getFullYear(), 0, 1); if (range && st.start && !st.end) st.hover = nd; render(); var fb = panel.querySelector('[data-date="' + iso(nd) + '"]'); if (fb) fb.focus(); return; } }
      if (map[e.key] !== undefined){ e.preventDefault(); st.hover = range && st.start && !st.end ? addDays(d, map[e.key]) : st.hover; focusDay(addDays(d, map[e.key])); }
      else if (e.key === 'PageUp' || e.key === 'PageDown'){ e.preventDefault(); var n = new Date(d); n.setMonth(n.getMonth() + (e.key === 'PageUp' ? -1 : 1)); focusDay(n); }
      else if (e.key === 'Enter' || e.key === ' '){ e.preventDefault(); pick(d); }
    });
    el.qdsOpen = function(){ setOpen(true); };
    el.qdsSetValue = function(a, b){ st.start = a ? (typeof a === 'string' ? parse(a) : a) : null; st.end = b ? (typeof b === 'string' ? parse(b) : b) : null; sync(); };
    el.qdsGetValue = function(){ return { start: st.start, end: st.end }; };
    sync();
  }

  // ---------------- Paginator（對應 PrimeVue <Paginator>） ----------------
  var ICO = {
    first: '<path d="M18 17l-5-5 5-5M11 17l-5-5 5-5"/>', prev: '<path d="M14 17l-5-5 5-5"/>',
    next: '<path d="M10 17l5-5-5-5"/>', last: '<path d="M6 17l5-5-5-5M13 17l5-5-5-5"/>'
  };
  function pgIcon(k){ return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICO[k] + '</svg>'; }
  function initPaginator(el){
    if (el._qds) return; el._qds = true;
    var st = { total: +el.dataset.total || 0, rows: +el.dataset.rows || 10, page: +el.dataset.page || 1 };
    var opts = (el.dataset.rowsOptions || '').split(',').filter(Boolean).map(Number);
    var compact = el.classList.contains('qds-paginator-compact'), showReport = el.dataset.report !== 'false', links = +el.dataset.links || 5;
    function pages(){ return Math.max(1, Math.ceil(st.total / st.rows)); }
    function range(){
      var n = pages(), half = Math.floor(links / 2), a = Math.max(1, st.page - half), b = Math.min(n, a + links - 1);
      a = Math.max(1, b - links + 1);
      var out = [];
      if (a > 1){ out.push(1); if (a > 2) out.push('…'); }
      for (var i = a; i <= b; i++) out.push(i);
      if (b < n){ if (b < n - 1) out.push('…'); out.push(n); }
      return out;
    }
    function btn(k, target, label, disabled){ return '<button type="button" class="qds-pg-btn qds-pg-nav" data-page="' + target + '" aria-label="' + label + '"' + (disabled ? ' disabled' : '') + '>' + pgIcon(k) + '</button>'; }
    function render(focusPage){
      var n = pages(); st.page = Math.min(Math.max(1, st.page), n);
      var from = st.total ? (st.page - 1) * st.rows + 1 : 0, to = Math.min(st.total, st.page * st.rows);
      var h = '';
      if (showReport && !compact) h += '<span class="qds-pg-report">第 ' + from + '–' + to + ' 筆，共 ' + st.total + ' 筆</span>';
      h += '<div class="qds-pg-links">' + btn('first', 1, '第一頁', st.page === 1) + btn('prev', st.page - 1, '上一頁', st.page === 1);
      if (compact) h += '<span class="qds-pg-compact" aria-live="polite">' + st.page + ' / ' + n + '</span>';
      else range().forEach(function(p){
        h += p === '…' ? '<span class="qds-pg-gap" aria-hidden="true">…</span>' : '<button type="button" class="qds-pg-btn' + (p === st.page ? ' active" aria-current="page' : '') + '" data-page="' + p + '" aria-label="第 ' + p + ' 頁">' + p + '</button>';
      });
      h += btn('next', st.page + 1, '下一頁', st.page === n) + btn('last', n, '最後一頁', st.page === n) + '</div>';
      if (opts.length && !compact){
        h += '<div class="qds-select qds-select-sm qds-pg-rows" data-qds-select><button type="button" class="qds-select-trigger" aria-haspopup="listbox" aria-expanded="false" aria-label="每頁筆數"><span class="qds-select-value">' + st.rows + ' 筆/頁</span><svg class="qds-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg></button><ul class="qds-select-panel" role="listbox">' +
          opts.map(function(o){ return '<li role="option" data-value="' + o + '"' + (o === st.rows ? ' class="sel" aria-selected="true"' : ' aria-selected="false"') + '>' + o + ' 筆/頁</li>'; }).join('') + '</ul></div>';
      }
      el.innerHTML = h;
      var sel = el.querySelector('[data-qds-select]'); if (sel) initSelect(sel);
      if (focusPage != null){ var f = el.querySelector('[data-page="' + focusPage + '"]:not([disabled])') || el.querySelector('.qds-pg-btn.active'); if (f) f.focus(); }
    }
    function go(p){ var n = pages(); p = Math.min(Math.max(1, p), n); if (p === st.page) return; st.page = p; render(p); emit(el, { page: st.page, rows: st.rows, first: (st.page - 1) * st.rows }); }
    el.addEventListener('click', function(e){ var b = e.target.closest('[data-page]'); if (b && !b.disabled) go(+b.dataset.page); });
    el.addEventListener('qds-change', function(e){
      if (e.target === el) return; e.stopPropagation();
      var first = (st.page - 1) * st.rows; st.rows = +e.detail.value; st.page = Math.floor(first / st.rows) + 1; render();
      el.querySelector('.qds-pg-rows .qds-select-trigger').focus();
      emit(el, { page: st.page, rows: st.rows, first: (st.page - 1) * st.rows });
    });
    el.setAttribute('role', 'navigation'); if (!el.getAttribute('aria-label')) el.setAttribute('aria-label', '分頁');
    el.qdsSetTotal = function(t){ st.total = t; render(); };
    el.qdsSetPage = function(p){ st.page = p; render(); };
    render();
  }


  // ---------------- Period（期間選擇：預設期間 Select＋自訂日期區間 DatePicker 合成一個控制項） ----------------
  // 觸發鈕顯示期間名稱；實際起訖日固定顯示在選單底部的「目前區間」資訊列。
  function initPeriod(el){
    if (el._qds) return; el._qds = true;
    var trig = el.querySelector('.qds-select-trigger'), panel = el.querySelector('.qds-select-panel'), val = el.querySelector('.qds-select-value');
    var dp = el.querySelector('[data-qds-datepicker]'); initDatePicker(dp);
    var opts = [].slice.call(panel.querySelectorAll('[role="option"]')), current = panel.querySelector('.qds-period-current b'), reset = panel.querySelector('[data-period-reset]');
    opts.forEach(function(o){ o.tabIndex = -1; });
    var st = { value: el.dataset.value || opts[0].dataset.value, start: parse(el.dataset.start), end: parse(el.dataset.end) };
    function presetRange(v){
      var today = QDS.today(), now = new Date(today), start = new Date(today), end = new Date(today);
      if (v === 'week') start.setDate(now.getDate() - ((now.getDay() + 6) % 7));
      else if (v === 'month') start = new Date(now.getFullYear(), now.getMonth(), 1);
      else if (v === '3m') start = new Date(now.getFullYear(), now.getMonth() - 2, 1);
      else if (v === '6m') start = new Date(now.getFullYear(), now.getMonth() - 5, 1);
      else if (v === '1y') start = new Date(now.getFullYear() - 1, now.getMonth(), now.getDate() + 1);
      return { start:start, end:end };
    }
    function rangeText(a, b){ if (!a || !b) return ''; return fmt(a) + ' – ' + (a.getFullYear() === b.getFullYear() ? pad(b.getMonth() + 1) + '/' + pad(b.getDate()) : fmt(b)); }
    function sync(){
      var custom = st.value === 'custom' && st.start && st.end;
      opts.forEach(function(o){ var on = o.dataset.value === st.value; o.classList.toggle('sel', on); o.setAttribute('aria-selected', on ? 'true' : 'false'); });
      var o = opts.filter(function(x){ return x.dataset.value === st.value; })[0];
      val.textContent = o ? o.dataset.label || o.textContent.trim() : '';
      el.classList.toggle('is-custom', !!custom);
      trig.setAttribute('aria-label', (el.dataset.label ? el.dataset.label + '：' : '') + val.textContent);
      var r = custom ? { start:st.start, end:st.end } : presetRange(st.value);
      if (current) current.textContent = rangeText(r.start, r.end);
      if (reset) reset.hidden = st.value === 'month' && !custom;
    }
    function setOpen(o){
      if (o) closeAll(el);
      el.classList.toggle('qds-open', o); trig.setAttribute('aria-expanded', o ? 'true' : 'false');
      if (o){ var cur = panel.querySelector('.sel') || opts[0]; setTimeout(function(){ cur.focus(); }, 0); }
    }
    function choose(o){
      setOpen(false);
      if (o.dataset.value === 'custom'){ dp.qdsSetValue(st.start, st.end); dp.qdsOpen(); return; }
      st.value = o.dataset.value; sync(); trig.focus();
      emit(el, { value: st.value, label: val.textContent });
    }
    trig.addEventListener('click', function(){ if (!trig.disabled) setOpen(!el.classList.contains('qds-open')); });
    trig.addEventListener('keydown', function(e){ if (e.key === 'ArrowDown' || e.key === 'ArrowUp'){ e.preventDefault(); setOpen(true); } });
    panel.addEventListener('click', function(e){ e.stopPropagation(); var o = e.target.closest('[role="option"]'); if (o) choose(o); });
    if (reset) reset.addEventListener('click', function(e){ e.stopPropagation(); st.value = 'month'; st.start = null; st.end = null; sync(); setOpen(false); trig.focus(); emit(el, { value: st.value, label: val.textContent }); });
    panel.addEventListener('keydown', function(e){
      var i = opts.indexOf(document.activeElement);
      if (e.key === 'ArrowDown'){ e.preventDefault(); opts[Math.min(i + 1, opts.length - 1)].focus(); }
      else if (e.key === 'ArrowUp'){ e.preventDefault(); opts[Math.max(i - 1, 0)].focus(); }
      else if (e.key === 'Enter' || e.key === ' '){ e.preventDefault(); if (i > -1) choose(opts[i]); }
      else if (e.key === 'Escape'){ e.preventDefault(); e.stopPropagation(); setOpen(false); trig.focus(); }
      else if (e.key === 'Tab'){ setOpen(false); }
    });
    // 月曆選完區間：改成自訂，焦點回到觸發鈕
    dp.addEventListener('qds-change', function(e){
      e.stopPropagation(); var d = e.detail || {};
      if (!d.start) return;
      st.value = 'custom'; st.start = d.start; st.end = d.end; sync(); trig.focus();
      emit(el, { value: 'custom', start: d.start, end: d.end, label: val.textContent });
    });
    // 月曆按 Esc 關閉時，焦點回到觸發鈕（月曆自己的觸發鈕是隱藏的）
    el.addEventListener('keydown', function(e){ if (e.key === 'Escape' && dp.contains(e.target)) setTimeout(function(){ trig.focus(); }, 0); }, true);
    el.qdsOpen = function(){ setOpen(true); };
    el.qdsSetValue = function(v, a, b){ st.value = v; if (a !== undefined){ st.start = a ? (typeof a === 'string' ? parse(a) : a) : null; st.end = b ? (typeof b === 'string' ? parse(b) : b) : null; } sync(); };
    el.qdsGetValue = function(){ return { value: st.value, start: st.start, end: st.end }; };
    sync();
  }

  // ---------------- SelectButton（分段切換） ----------------
  function initSegmented(el){
    if (el._qds) return; el._qds = true;
    var btns = [].slice.call(el.querySelectorAll('button'));
    // 滑動底色：共用一塊淡綠底，切換時滑到選中那顆（對應前端 SlideSelectButton / 膠囊式 TabBar）
    var ind = document.createElement('span'); ind.className = 'qds-seg-indicator'; ind.setAttribute('aria-hidden', 'true'); el.insertBefore(ind, el.firstChild);
    function place(anim){
      var b = el.querySelector('button.on'); if (!b || !b.offsetWidth){ ind.style.opacity = '0'; return; }
      if (!anim) ind.style.transition = 'none';
      ind.style.opacity = '1'; ind.style.width = b.offsetWidth + 'px'; ind.style.height = b.offsetHeight + 'px'; ind.style.transform = 'translate(' + b.offsetLeft + 'px,' + b.offsetTop + 'px)';
      if (!anim){ void ind.offsetWidth; ind.style.transition = ''; }
    }
    function pick(b, fire){
      btns.forEach(function(x){ var on = x === b; x.classList.toggle('on', on); x.setAttribute('aria-pressed', on ? 'true' : 'false'); });
      place(true);
      if (fire) emit(el, { value: b.dataset.value || b.textContent.trim() });
    }
    place(false);
    if (window.ResizeObserver) new ResizeObserver(function(){ place(false); }).observe(el);
    btns.forEach(function(b, i){
      b.addEventListener('click', function(){ pick(b, true); });
      b.addEventListener('keydown', function(e){
        var d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0; if (!d) return;
        e.preventDefault(); var n = btns[(i + d + btns.length) % btns.length]; n.focus(); pick(n, true);
      });
    });
  }

  QDS.init = function(root){
    root = root || document;
    [].forEach.call(root.querySelectorAll('[data-qds-select]'), initSelect);
    [].forEach.call(root.querySelectorAll('[data-qds-datepicker]'), initDatePicker);
    [].forEach.call(root.querySelectorAll('[data-qds-paginator]'), initPaginator);
    [].forEach.call(root.querySelectorAll('[data-qds-period]'), initPeriod);
    [].forEach.call(root.querySelectorAll('[data-qds-segmented]'), initSegmented);
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function(){ QDS.init(); });
  else QDS.init();
})();
