(function(){
  // 後台原型：資料來自前端 mock（window.QDS_PROTO_DATA），另補一年份的示意一般支出讓圖表有內容。
  // 示意的「今天」固定為 2026/09/24。
  window.QDS = window.QDS || {}; QDS.TODAY = new Date(2026, 8, 24);
  function start(){
  var root = document.getElementById('dash-demo'); if (!root || !window.QDS_PROTO_DATA) return;
  var $ = function(s, el){ return (el || root).querySelector(s); }, $$ = function(s, el){ return [].slice.call((el || root).querySelectorAll(s)); };
  var DATA = window.QDS_PROTO_DATA, TODAY = new Date(2026, 8, 24);
  function pad(n){ return (n < 10 ? '0' : '') + n; }
  function P(s){ if (!s) return null; var d = new Date(s); return isNaN(d) ? null : d; }
  function dOnly(s){ if (!s) return null; var p = String(s).slice(0, 10).split('-'); return new Date(+p[0], p[1] - 1, +p[2]); }
  function ymd(d){ return d ? d.getFullYear() + '/' + pad(d.getMonth() + 1) + '/' + pad(d.getDate()) : '—'; }
  function ymdhm(d){ return d ? ymd(d) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes()) : '—'; }
  function iso(d){ return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function fmt(n){ return (n < 0 ? '−' : '') + 'NT$ ' + Math.round(Math.abs(n || 0)).toLocaleString('en-US'); }
  function num(v){ var n = parseFloat(String(v == null ? '' : v).replace(/[^0-9.\-]/g, '')); return isNaN(n) ? null : n; }
  function esc(s){ return String(s == null ? '' : s).replace(/[&<>"]/g, function(c){ return { '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;' }[c]; }); }
  function rnd(k){ var x = Math.sin(k * 12.9898) * 43758.5453; return x - Math.floor(x); }
  function now(){ return new Date(2026, 8, 24, 14, 30); }
  function match(q){ q = (q || '').trim().toLowerCase(); if (!q) return true; return [].slice.call(arguments, 1).join(' ').toLowerCase().indexOf(q) > -1; }
  var SEP = '<span class="sep" aria-hidden="true"></span>';
  function bind(k, v, html){ $$('[data-bind="' + k + '"]').forEach(function(el){ if (html) el.innerHTML = v; else el.textContent = v; }); }
  var ICON = function(d){ return '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + d + '</svg>'; };
  var I_EYE = ICON('<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>'), I_EDIT = ICON('<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>'),
      I_DEL = ICON('<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>'), I_MORE = ICON('<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>'),
      I_ARCH = ICON('<rect x="3" y="4" width="18" height="4" rx="1"/><path d="M5 8v11h14V8M10 12h4"/>'), I_LINK = ICON('<path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/>');
  var RSTATUS = { in_review:['簽核中','review'], approved:['已核銷','approved'], paid:['已發放','paid'], rejected:['駁回','rejected'], voided:['已作廢','voided'], draft:['草稿','draft'] };
  var PAYM = { bank_transfer:'匯款', cash:'現金' };
  function badge(key, text){ return key === 'voided' ? '<span class="status-badge" style="color:#fff;background:var(--status-voided)">' + text + '</span>' : '<span class="status-badge" style="color:var(--status-' + key + ');background:var(--status-' + key + '-bg)">' + text + '</span>'; }
  function rbadge(s){ var t = RSTATUS[s] || [s, 'draft']; return badge(t[1], t[0]); }
  function pbadge(s){ return s === 'paid' ? badge('paid', '已付款') : badge('review', '待付款'); }

  // ---------- 資料 ----------
  var cats = DATA.categories.slice().sort(function(a, b){ return a.sortOrder - b.sortOrder; }).map(function(c){ return { id:c.id, name:c.name, code:c.accountCode || '', archived:!!c.isArchived }; });
  var users = DATA.users.map(function(u){ return { id:u.id, name:u.name, email:u.email, role:u.role, createdAt:P(u.createdAt) }; });
  var ME = users.filter(function(u){ return u.role === 'admin'; })[0] || users[0];
  var invites = DATA.invitations.filter(function(i){ return !i.acceptedAt; }).map(function(i){ return { id:i.id, email:i.email, name:i.name, expiresAt:P(i.expiresAt), revoked:!!i.revokedAt, createdAt:P(i.createdAt) }; });
  function uname(id){ var u = users.filter(function(x){ return x.id === id; })[0]; return u ? u.name : '（已離職）'; }
  var reqs = DATA.reimbursements.filter(function(r){ return r.status !== 'draft'; }).map(function(r){
    var steps = (r.approvalProgress && r.approvalProgress.steps) || [];
    return { id:r.id, emp:r.employeeId, name:uname(r.employeeId), amount:r.amount, cat:r.categoryId, desc:r.description, incurredAt:dOnly(r.incurredAt), vendor:r.vendor, docType:r.documentType,
      invoiceNo:r.invoiceNo, taxId:r.taxId, status:r.status, comment:(steps[0] && steps[0].comment) || null, reviewedAt:P(steps[0] && steps[0].reviewedAt),
      paymentMethod:r.paymentMethod, expenseId:r.expenseId, createdAt:P(r.createdAt), updatedAt:P(r.updatedAt), receiptCount:r.receiptCount || 0 };
  });
  var exps = DATA.expenses.map(function(e){ return { id:e.id, source:e.source, ref:e.sourceRefId, docType:e.documentType, vendor:e.vendor, taxId:e.taxId, invoiceNo:e.invoiceNo, taxRate:e.taxRate,
      preTax:e.preTaxAmt, tax:e.taxAmt, amount:e.amount, cat:e.categoryId, date:dOnly(e.date), note:e.note, items:e.items || [], payout:e.payoutStatus, by:e.createdBy, files:e.attachmentCount || 0 }; });
  // 示意：補 2025/10 ～ 2026/09 的一般支出，讓趨勢圖與類別分佈有內容（金額與廠商為虛構）
  var SEED_V = { travel:['台灣大車隊','Uber','台北捷運'], business_travel:['台灣高鐵','長榮航空','福容大飯店'], meal:['鼎泰豐','八方雲集','Uber Eats'], office:['誠品文具','無印良品','全家便利商店'],
    postage:['中華郵政','中華電信'], utilities:['台灣電力公司','台北自來水事業處'], advertising:['Google Ads','Meta 廣告'], entertainment:['晶華酒店','欣葉餐廳'], training:['天下學習','Hahow'], rent:['信義房屋管理'], other:['清潔公司'] };
  var ids = Object.keys(SEED_V), seq = 1;
  for (var mo = 0; mo < 12; mo++){
    var y = 2025 + Math.floor((9 + mo) / 12), m = (9 + mo) % 12, n = 4 + Math.floor(rnd(mo + 3) * 4);
    for (var k = 0; k < n; k++){
      var key = mo * 10 + k, cid = ids[Math.floor(rnd(key * 3 + 1) * ids.length)], day = 1 + Math.floor(rnd(key * 7 + 2) * 27);
      var dt = new Date(y, m, day); if (dt > TODAY) continue;
      var amt = Math.round((300 + rnd(key * 5 + 4) * (cid === 'rent' ? 30000 : cid === 'advertising' ? 12000 : 5200)) / 10) * 10;
      var vv = SEED_V[cid][Math.floor(rnd(key + 9) * SEED_V[cid].length)], inv = rnd(key + 5) > 0.35;
      exps.push({ id:'demo-' + (seq++), source:'general', ref:null, docType:inv ? 'invoice' : 'receipt', vendor:vv, taxId:inv ? '2' + Math.floor(10000000 + rnd(key) * 8999999) : null,
        invoiceNo:inv ? 'QK-' + (10000000 + Math.floor(rnd(key + 2) * 89999999)) : null, taxRate:inv ? 'business_5' : 'exempt_0', preTax:inv ? Math.round(amt / 1.05) : amt, tax:inv ? amt - Math.round(amt / 1.05) : 0,
        amount:amt, cat:cid, date:dt, note:null, items:[], payout:dt < new Date(2026, 8, 1) || rnd(key + 11) > 0.4 ? 'paid' : 'pending', by:ME.id, files:1 });
    }
  }
  var budgets = DATA.budgets.map(function(b){ return { cat:b.categoryId, cycle:b.cycle, amount:b.amount, start:dOnly(b.periodStart) }; });
  var templates = DATA.budgetTemplates.map(function(t){ return { cat:t.categoryId, cycle:t.cycle, amount:t.amount }; });
  function cat(id){ return cats.filter(function(c){ return c.id === id; })[0]; }
  function catName(id){ var c = cat(id); return c ? c.name : id; }
  function activeCats(){ return cats.filter(function(c){ return !c.archived; }); }
  function req(id){ return reqs.filter(function(r){ return r.id === id; })[0]; }
  function exp(id){ return exps.filter(function(e){ return e.id === id; })[0]; }
  function expOfReq(r){ return r && r.expenseId ? exp(r.expenseId) : null; }
  function sumAmt(list){ return list.reduce(function(a, x){ return a + (x.amount || 0); }, 0); }
  function expIn(from, to, cid){ return exps.filter(function(e){ return e.date >= from && e.date <= to && (!cid || e.cat === cid); }); }
  var catIdx = {}; cats.forEach(function(c, i){ catIdx[c.id] = i; });
  // 類別顏色與前端 CATEGORY_COLOR_PALETTE 相同，依類別排序循環套用
  var CAT_PALETTE = ['#0ea5e9','#06b6d4','#ef4444','#a855f7','#8b5cf6','#6366f1','#ec4899','#f97316','#64748b','#22c55e','#14b8a6','#d946ef','#94a3b8','#3b5bdb','#f59e0b','#10b981'];
  function catColor(id){ return CAT_PALETTE[(catIdx[id] || 0) % CAT_PALETTE.length]; }

  var state = { view:'home', trendPreset:'month', trendRange:null, catPreset:'month', catRange:null, hover:null,
    expTab:'all', recTab:'all', revTab:'pending', payTab:'pending', catTab:'active',
    f:{ expenses:{ q:'', cat:'all', src:'all', range:null }, records:{ q:'', cat:'all', range:null, min:null, max:null }, review:{ q:'', cat:'all', range:null, min:null, max:null }, payout:{ q:'', cat:'all', range:null, min:null, max:null } },
    q:{ categories:'', users:'' },
    sort:{ exp:{ key:'date', dir:-1 }, records:{ key:'createdAt', dir:-1 }, review:{ key:'updatedAt', dir:-1 }, payout:{ key:'updatedAt', dir:-1 } },
    pg:{ exp:{ first:0, rows:10 }, rec:{ first:0, rows:10 }, rev:{ first:0, rows:10 }, pay:{ first:0, rows:10 } },
    sel:{ review:{}, payout:{} }, budCycle:'month', budStart:new Date(2026, 8, 1), budEdit:null, notifRead:{}, form:null, action:null, confirm:null };

  // ---------- 儀表板 ----------
  // 期間切成長條：本日/本週/本月按日（本週從週一算）；近三個月以上按月；自訂區間 31 天以內按日，超過按月（頭尾月份只算區間內的日子）
  function buckets(preset, custom){
    var endY = TODAY.getFullYear(), endM = TODAY.getMonth(), n = preset === '3m' ? 3 : preset === '1y' ? 12 : 6, s, e, out = [];
    if (preset === 'custom' && custom){ s = new Date(custom.start); e = new Date(custom.end); }
    else if (preset === 'today'){ s = new Date(TODAY); e = new Date(TODAY); }
    else if (preset === 'week'){ s = new Date(endY, endM, TODAY.getDate() - (TODAY.getDay() + 6) % 7); e = new Date(TODAY); }
    else if (preset === 'month'){ s = new Date(endY, endM, 1); e = new Date(TODAY); }
    else { s = new Date(endY, endM - n + 1, 1); e = new Date(TODAY); }
    if ((e - s) / 864e5 < 31 && preset !== '3m' && preset !== '6m' && preset !== '1y'){
      for (var d = new Date(s); d <= e; d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)) out.push({ from:new Date(d), to:new Date(d), day:true });
      return out;
    }
    for (var m = new Date(s.getFullYear(), s.getMonth(), 1); m <= e; m = new Date(m.getFullYear(), m.getMonth() + 1, 1)){
      var mEnd = new Date(m.getFullYear(), m.getMonth() + 1, 0);
      out.push({ from:m < s ? new Date(s) : new Date(m), to:mEnd > e ? new Date(e) : mEnd, month:new Date(m) });
    }
    return out;
  }
  function monthList(preset, custom){ return buckets(preset, custom); }
  function kLabel(n){ if (n >= 1000){ var k = n / 1000; return (k % 1 === 0 ? k : k.toFixed(1)) + 'k'; } return String(n); }
  function niceStep(max){ var raw = max / 4, p = Math.pow(10, Math.floor(Math.log10(raw || 1))), f = raw / p; return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * p; }
  function renderKpi(){
    var m0 = new Date(2026, 8, 1), mon = expIn(m0, TODAY), rev = reqs.filter(function(r){ return r.status === 'in_review'; }), out = reqs.filter(function(r){ return r.status === 'approved'; }), pending = exps.filter(function(e){ return e.payout === 'pending'; });
    var mb = activeCats().map(function(c){ var b = budgetOf(c.id, 'month', m0); return b ? { b:b.amount, u:sumAmt(expIn(m0, TODAY, c.id)) } : null; }).filter(Boolean);
    var tb = mb.reduce(function(a, x){ return a + x.b; }, 0), tu = mb.reduce(function(a, x){ return a + x.u; }, 0);
    bind('kpi-spend', fmt(sumAmt(mon))); bind('kpi-spend-count', mon.length + ' 筆');
    bind('kpi-review', fmt(sumAmt(rev))); bind('kpi-review-count', rev.length + ' 筆');
    bind('kpi-budget', tb ? Math.round(tu / tb * 100) + '%' : '—'); bind('kpi-budget-count', tb ? fmt(tb) : '尚未設定');
    bind('kpi-nextpay', fmt(sumAmt(pending))); bind('kpi-nextpay-count', pending.length + ' 筆');
    bind('review-count', rev.length || ''); bind('review-count-2', rev.length); bind('payout-count', out.length || '');
    $$('.sn-badge').forEach(function(b){ b.hidden = !b.textContent; });
  }
  function renderTrend(){
    var box = $('[data-el="trend-chart"]');
    if (!exps.length){ box.innerHTML = '<div class="dash-empty dash-empty-lg"><b>尚無支出資料</b><br>新增第一筆支出或核准代墊款後，趨勢圖會開始累積</div>'; bind('trend-total', fmt(0)); return; }
    var ms = buckets(state.trendPreset, state.trendRange), byDay = !!ms[0].day, showYear = ms[0].from.getFullYear() !== ms[ms.length - 1].from.getFullYear();
    var data = ms.map(function(x){ var l = expIn(x.from, x.to), f = x.from, part = !byDay && (x.from.getDate() !== 1 || x.to.getDate() !== new Date(x.to.getFullYear(), x.to.getMonth() + 1, 0).getDate());
      return { from:f, amt:sumAmt(l), n:l.length,
        label:byDay ? (f.getMonth() + 1) + '/' + f.getDate() : showYear ? (f.getFullYear() % 100) + '/' + (f.getMonth() + 1) : (f.getMonth() + 1) + '月',
        full:byDay ? ymd(f) : f.getFullYear() + ' 年 ' + (f.getMonth() + 1) + ' 月' + (part ? '（' + (f.getMonth() + 1) + '/' + f.getDate() + '–' + (x.to.getMonth() + 1) + '/' + x.to.getDate() + '）' : ''),
        cur:byDay ? f.getTime() === TODAY.getTime() : f.getFullYear() === TODAY.getFullYear() && f.getMonth() === TODAY.getMonth() }; });
    if (!data.some(function(d){ return d.amt; })){ box.innerHTML = '<div class="dash-empty dash-empty-lg chart-empty"><b>此區間內尚無支出資料</b><br>換個期間看看，或新增一筆支出</div>'; bind('trend-total', fmt(0)); return; }
    var max = Math.max.apply(null, data.map(function(d){ return d.amt; }).concat([1])), step = niceStep(max), top = Math.ceil(max / step) * step || step, ticks = [];
    for (var t = 0; t <= top + 0.001; t += step) ticks.push(t);
    var many = data.length > 12;
    box.innerHTML = '<div class="chart-y" aria-hidden="true">' + ticks.map(function(t){ return '<span style="bottom:' + (t / top * 100) + '%">' + kLabel(t) + '</span>'; }).join('') + '</div>' +
      '<div class="chart-plot"><div class="chart-grid" aria-hidden="true">' + ticks.map(function(t){ return '<i style="bottom:' + (t / top * 100) + '%"></i>'; }).join('') + '</div>' +
      '<div class="chart-bars' + (many ? ' is-dense' : '') + '">' + data.map(function(d){ return '<div class="chart-col"><span class="chart-bar' + (d.cur ? ' cur' : '') + '" tabindex="0" style="height:' + (d.amt / top * 100) + '%" data-tip="' + d.full + '|' + fmt(d.amt) + '|' + d.n + ' 筆" aria-label="' + d.full + ' ' + fmt(d.amt) + '，' + d.n + ' 筆"></span></div>'; }).join('') + '</div><div class="dash-tip" hidden></div></div>' +
      '<div class="chart-x" aria-hidden="true">' + data.map(function(d, i){ return '<span>' + (many && i % Math.ceil(data.length / 12) ? '' : d.label) + '</span>'; }).join('') + '</div>';
    bind('trend-total', fmt(data.reduce(function(a, d){ return a + d.amt; }, 0)));
  }
  function renderCat(){
    var ms = monthList(state.catPreset, state.catRange), from = ms[0].from, to = ms[ms.length - 1].to;
    var by = {}; expIn(from, to).forEach(function(e){ by[e.cat] = (by[e.cat] || 0) + e.amount; });
    var list = Object.keys(by).map(function(id){ return { id:id, amt:by[id] }; }).sort(function(a, b){ return b.amt - a.amt; }), total = sumAmt(list.map(function(x){ return { amount:x.amt }; }));
    $('[data-el="cat-body"]').hidden = !list.length; $('[data-el="cat-empty"]').hidden = !!list.length;
    if (!list.length) return;
    var cum = 0, segs = '';
    list.forEach(function(x){ var pct = x.amt / total * 100, len = Math.max(pct - 0.8, 0.1);
      segs += '<circle class="donut-seg" data-cid="' + x.id + '" cx="21" cy="21" r="15.915" fill="none" stroke="' + catColor(x.id) + '" stroke-width="5.5" stroke-dasharray="' + len + ' ' + (100 - len) + '" stroke-dashoffset="' + (25 - cum) + '" tabindex="0" aria-label="' + esc(catName(x.id)) + ' ' + fmt(x.amt) + '，占 ' + pct.toFixed(1) + '%"></circle>'; cum += pct; });
    $('[data-el="donut"]').innerHTML = '<circle cx="21" cy="21" r="15.915" fill="none" stroke="var(--surface-soft)" stroke-width="5.5"></circle>' + segs;
    bind('cat-total', fmt(total));
    $('[data-el="cat-legend"]').innerHTML = list.map(function(x){ return '<li tabindex="0" data-cid="' + x.id + '"><span class="legend-dot" style="background:' + catColor(x.id) + '"></span><span class="cat-name">' + esc(catName(x.id)) + '</span><span class="cat-pct">' + (x.amt / total * 100).toFixed(1) + '%</span><span class="cat-amt">' + fmt(x.amt) + '</span></li>'; }).join('');
    setHover(state.hover);
  }
  function setHover(id){ state.hover = id; $$('.donut-seg, [data-el="cat-legend"] li').forEach(function(el){ var k = el.dataset.cid; el.classList.toggle('on', k === id); el.classList.toggle('dim', !!id && k !== id); }); }
  function renderHomeLists(){
    var recent = reqs.slice().sort(function(a, b){ return b.createdAt - a.createdAt; }).slice(0, 5);
    $('[data-el="home-requests"]').innerHTML = recent.map(function(r){ return '<tr tabindex="0" data-open="' + r.id + '"><td>' + esc(r.name) + '<div class="cell-sub">' + esc(r.desc) + '</div></td><td>' + esc(catName(r.cat)) + '</td><td class="num">' + fmt(r.amount) + '</td><td>' + rbadge(r.status) + '</td></tr>'; }).join('') || '<tr><td colspan="4" class="dash-empty">目前沒有請款單</td></tr>';
    var pend = reqs.filter(function(r){ return r.status === 'in_review'; }).sort(function(a, b){ return b.createdAt - a.createdAt; }).slice(0, 5);
    $('[data-el="home-pending"]').innerHTML = pend.map(function(r){ return '<button type="button" class="ar-row" data-open="' + r.id + '"><div class="row-top"><span>' + esc(r.name) + SEP + esc(catName(r.cat)) + '</span><span class="ar-time">' + ymd(r.createdAt) + '</span></div><div class="ar-sub ar-sub-split"><span>' + esc(r.desc) + '</span><b>' + fmt(r.amount) + '</b></div></button>'; }).join('') || '<div class="dash-empty">目前沒有待簽核的請款</div>';
  }
  function renderNotifs(){
    var items = reqs.filter(function(r){ return r.status === 'in_review'; }).sort(function(a, b){ return b.createdAt - a.createdAt; }).slice(0, 4).map(function(r){ return { key:'r' + r.id, id:r.id, html:'<b>' + esc(r.name) + '</b> 送出請款「' + esc(r.desc) + '」<small>' + ymdhm(r.createdAt) + '</small>' }; });
    var m0 = new Date(2026, 8, 1);
    activeCats().forEach(function(c){ var b = budgetOf(c.id, 'month', m0); if (!b) return; var u = sumAmt(expIn(m0, TODAY, c.id)); if (u / b.amount >= 0.8) items.push({ key:'b' + c.id, budget:true, html:'「' + esc(c.name) + '」本月預算已使用 ' + Math.round(u / b.amount * 100) + '%<small>預算管理</small>' }); });
    $('[data-el="notif-list"]').innerHTML = items.map(function(x){ return '<button type="button" role="menuitem" class="notif-item' + (state.notifRead[x.key] ? '' : ' unread') + '" data-notif="' + x.key + '"' + (x.id ? ' data-open="' + x.id + '"' : ' data-action="goto" data-view="budgets"') + '>' + x.html + '</button>'; }).join('') || '<div class="dash-empty">沒有新通知</div>';
    $('[data-el="notif-dot"]').hidden = !items.some(function(x){ return !state.notifRead[x.key]; });
  }
  function renderHome(){ renderKpi(); renderTrend(); renderCat(); renderHomeLists(); renderNotifs(); }

  // ---------- 列表共用 ----------
  function tabs(el, list, cur, attr){ $(el).innerHTML = list.map(function(t){ var on = t[0] === cur; return '<button type="button" class="tab' + (on ? ' active' : '') + '" role="tab" aria-selected="' + on + '" ' + attr + '="' + t[0] + '">' + t[1] + '<span class="tab-count">' + t[2] + '</span></button>'; }).join(''); }
  function pageSlice(rows, key){ var p = state.pg[key]; if (p.first >= rows.length) p.first = 0; var pg = $('[data-el="' + key + '-pg"]'); if (pg && pg.qdsSetTotal){ pg.qdsSetTotal(rows.length); pg.hidden = rows.length <= p.rows; } return rows.slice(p.first, p.first + p.rows); }
  function resetPage(key){ state.pg[key].first = 0; var pg = $('[data-el="' + key + '-pg"]'); if (pg && pg.qdsSetPage) pg.qdsSetPage(1); }
  function sortRows(rows, s){ if (!s) return rows; return rows.slice().sort(function(a, b){ var x = a[s.key], y = b[s.key]; if (x == null) return 1; if (y == null) return -1; return (x > y ? 1 : x < y ? -1 : 0) * s.dir; }); }
  function sortInd(scope){ $$('[data-sort^="' + scope + ':"]').forEach(function(b){ var k = b.dataset.sort.split(':')[1], s = state.sort[scope === 'exp' ? 'exp' : scope], on = s && s.key === k; var th = b.closest('th'); if (th) th.setAttribute('aria-sort', on ? (s.dir > 0 ? 'ascending' : 'descending') : 'none'); b.querySelector('.sort-ind').textContent = on ? (s.dir > 0 ? '↑' : '↓') : '↕'; }); }
  function emptyRow(cols, filtered, emptyText, clearAttr){ return '<tr><td colspan="' + cols + '"><div class="dash-empty">' + (filtered ? '沒有符合條件的資料　<button type="button" class="btn btn-text btn-sm" ' + clearAttr + '>清除所有篩選</button>' : emptyText) + '</div></td></tr>'; }
  function rowMenu(id, items){ return '<div class="dash-pop row-menu" data-pop="m' + id + '"><button type="button" class="btn btn-secondary btn-icon-only btn-sm" data-toggle="m' + id + '" aria-haspopup="true" aria-expanded="false" aria-label="更多動作" title="更多動作">' + I_MORE + '</button><div class="dash-menu" role="menu">' + items + '</div></div>'; }
  function catOpts(all){ return (all ? [{ value:'all', label:'全部類別' }] : []).concat(activeCats().map(function(c){ return { value:c.id, label:c.name }; })); }
  function syncCatSelects(){
    ['exp-cat', 'records-cat', 'review-cat', 'payout-cat'].forEach(function(k){ var el = $('[data-el="' + k + '"]'); if (el && el.qdsSetOptions) el.qdsSetOptions(catOpts(true)); });
    ['f-cat', 'ap-cat'].forEach(function(k){ var el = $('[data-el="' + k + '"]'); if (el && el.qdsSetOptions) el.qdsSetOptions(catOpts(false), el.dataset.value || ''); });
  }

  // ---------- 支出管理 ----------
  function expRows(){
    var f = state.f.expenses, rg = f.range;
    var all = exps.filter(function(e){ return (f.src === 'all' || e.source === f.src) && (f.cat === 'all' || e.cat === f.cat) && (!rg || (e.date >= rg.start && e.date <= rg.end)) && match(f.q, e.vendor, e.note, e.invoiceNo); });
    return all;
  }
  function renderExpenses(){
    var f = state.f.expenses, base = expRows(), filtered = f.q.trim() || f.src !== 'all' || f.cat !== 'all' || f.range;
    var cnt = function(s){ return base.filter(function(e){ return e.payout === s; }).length; };
    tabs('[data-el="exp-tabs"]', [['all','全部',base.length],['pending','待付款',cnt('pending')],['paid','已付款',cnt('paid')]], state.expTab, 'data-exp-tab');
    var rows = sortRows(base.filter(function(e){ return state.expTab === 'all' || e.payout === state.expTab; }), state.sort.exp);
    $('[data-action="exp-clear"]').hidden = !filtered;
    bind('exp-sum', '共 ' + rows.length + ' 筆' + SEP + '合計 ' + fmt(sumAmt(rows)), true);
    $('[data-el="exp-rows"]').innerHTML = rows.length ? pageSlice(rows, 'exp').map(function(e){
      var menu = e.source === 'general' ? rowMenu(e.id, '<button type="button" role="menuitem" data-action="edit-exp" data-id="' + e.id + '">編輯</button>' + (e.payout === 'pending' ? '<button type="button" role="menuitem" data-action="exp-paid" data-id="' + e.id + '">標記為已付款</button>' : '') + '<button type="button" role="menuitem" class="danger" data-action="del-exp" data-id="' + e.id + '">刪除</button>') : '';
      return '<tr tabindex="0" data-exp="' + e.id + '"><td>' + ymd(e.date) + '</td><td>' + esc(catName(e.cat)) + '</td><td class="num">' + fmt(e.amount) + '</td><td>' + esc(e.vendor || '未填廠商') + (e.note ? '<div class="cell-sub">' + esc(e.note) + '</div>' : '') + '</td><td>' + (e.source === 'reimbursement' ? '<span class="tag-soft">代墊款</span>' : '<span class="tag-soft tag-neutral">一般支出</span>') + '</td><td>' + pbadge(e.payout) + '</td><td class="act"><span class="row-actions"><button type="button" class="btn btn-secondary btn-icon-only btn-sm" data-action="view-exp" data-id="' + e.id + '" aria-label="查看詳情" title="查看詳情">' + I_EYE + '</button>' + menu + '</span></td></tr>';
    }).join('') : (pageSlice([], 'exp'), emptyRow(7, filtered, '尚無支出紀錄　<button type="button" class="btn btn-primary btn-sm" data-action="new-expense">新增支出</button>', 'data-action="exp-clear"'));
    sortInd('exp');
  }
  function kv(label, value){ return '<div class="dash-kv"><span>' + label + '</span><b>' + value + '</b></div>'; }
  function openExpDetail(id, from){
    var e = exp(id); if (!e) return;
    $('[data-el="expdetail-title"]').innerHTML = '支出詳情' + SEP + esc(e.vendor || '未填廠商');
    var r = e.ref ? req(e.ref) : null, items = e.items.length ? '<div class="dash-sub-title">品項明細</div><table class="dash-table mini-table"><thead><tr><th>品項</th><th class="num">數量</th><th class="num">單價</th><th class="num">小計</th></tr></thead><tbody>' + e.items.map(function(it){ return '<tr><td>' + esc(it.name) + '</td><td class="num">' + it.quantity + '</td><td class="num">' + fmt(it.unitPrice) + '</td><td class="num">' + fmt(it.subtotal) + '</td></tr>'; }).join('') + '</tbody></table>' : '';
    $('[data-el="expdetail-body"]').innerHTML = kv('費用日期', ymd(e.date)) + kv('類別', esc(catName(e.cat)) + (cat(e.cat) && cat(e.cat).code ? '<span class="cell-sub">' + SEP + cat(e.cat).code + '</span>' : '')) + kv('來源', e.source === 'reimbursement' ? '代墊款' + (r ? '（' + esc(r.name) + '）' : '') : '一般支出') + kv('付款狀態', pbadge(e.payout)) +
      '<div class="dash-sub-title">憑證</div>' + kv('憑證類型', e.docType === 'invoice' ? '統一發票' : '收據/其他單據') + kv('發票號碼', esc(e.invoiceNo || '—')) + kv('賣方統編', esc(e.taxId || '—')) + kv('賣方名稱', esc(e.vendor || '—')) + kv('附件', (e.files || 0) + ' 個') +
      '<div class="dash-sub-title">金額</div>' + kv('稅率', e.taxRate === 'business_5' ? '營業稅 5%' : '免稅/收據 0%') + kv('未稅金額', e.preTax != null ? fmt(e.preTax) : '—') + kv('稅額', e.tax != null ? fmt(e.tax) : '—') + kv('總金額', fmt(e.amount)) + items +
      (e.note ? '<div class="dash-sub-title">備註</div><p class="dash-dialog-text">' + esc(e.note) + '</p>' : '') +
      '<div class="dash-sub-title">紀錄</div>' + kv('建立者', esc(uname(e.by)));
    $('[data-el="expdetail-foot"]').innerHTML = e.source === 'general' ? '<button type="button" class="btn btn-danger" data-action="del-exp" data-id="' + e.id + '">刪除</button><span class="button-bar-gap"></span>' + (e.payout === 'pending' ? '<button type="button" class="btn btn-secondary" data-action="exp-paid" data-id="' + e.id + '">標記為已付款</button>' : '') + '<button type="button" class="btn btn-primary" data-action="edit-exp" data-id="' + e.id + '">編輯</button>'
      : (r ? '<button type="button" class="btn btn-secondary" data-action="open-req" data-id="' + r.id + '">查看請款單</button>' : '') + '<button type="button" class="btn btn-primary" data-action="close">關閉</button>';
    lastFocus = from || document.activeElement; openOverlay('expdetail');
  }

  // ---------- 新增/編輯支出（整頁表單） ----------
  function openForm(id){
    var e = id ? exp(id) : null;
    state.form = { id:e ? e.id : null, files:e ? Array.apply(null, Array(e.files || 0)).map(function(_, i){ return '附件 ' + (i + 1) + '.jpg'; }) : [], items:e ? e.items.map(function(x){ return Object.assign({}, x); }) : [] };
    $('[data-el="form-title"]').textContent = e ? '編輯支出' : '新增支出'; $('[data-el="form-submit"]').textContent = e ? '儲存變更' : '新增支出';
    var docType = e ? e.docType : 'invoice';
    $$('input[name="f-doc"]').forEach(function(r){ r.checked = r.value === docType; });
    $('[data-el="f-date"]').qdsSetValue(e ? e.date : TODAY);
    syncCatSelects(); $('[data-el="f-cat"]').qdsSetValue(e ? e.cat : ''); if (!e){ var fc = $('[data-el="f-cat"]'); fc.dataset.value = ''; $('.qds-select-value', fc).textContent = '請選擇類別'; $('.qds-select-value', fc).classList.add('is-placeholder'); $$('[role="option"]', fc).forEach(function(o){ o.classList.remove('sel'); o.setAttribute('aria-selected', 'false'); }); }
    $('#f-vendor').value = e ? (e.vendor || '') : ''; $('#f-taxid').value = e ? (e.taxId || '') : '';
    var inv = e && e.invoiceNo ? e.invoiceNo.split('-') : ['', '']; $('#f-inv1').value = inv[0] || ''; $('#f-inv2').value = inv[1] || '';
    $('[data-el="f-payout"]').qdsSetValue(e ? e.payout : 'paid'); $('[data-el="f-taxrate"]').qdsSetValue(e ? e.taxRate : 'business_5');
    $('#f-pretax').value = e && e.preTax != null ? e.preTax : ''; $('#f-tax').value = e && e.tax != null ? e.tax : ''; $('#f-amount').value = e ? e.amount : '';
    $('#f-note').value = e ? (e.note || '') : '';
    $$('[data-err]', $('.dash-view[data-view="expense-form"]')).forEach(function(x){ x.hidden = true; }); $$('.is-invalid', $('.dash-view[data-view="expense-form"]')).forEach(function(x){ x.classList.remove('is-invalid'); });
    renderFormBits(); goto('expense-form');
  }
  function renderFormBits(){
    var f = state.form, invoice = ($('input[name="f-doc"]:checked') || {}).value === 'invoice';
    $('.f-inv-field').classList.toggle('is-optional', !invoice); $('.f-inv-field .req').hidden = !invoice;
    $('[data-el="form-files"]').innerHTML = f.files.map(function(n, i){ return '<li><span>' + esc(n) + '</span><button type="button" class="btn btn-text btn-sm" data-action="rm-file" data-i="' + i + '" aria-label="移除 ' + esc(n) + '">移除</button></li>'; }).join('');
    $('[data-action="ocr"]').disabled = !f.files.length;
    $('[data-el="f-items"]').innerHTML = f.items.map(function(it, i){ return '<tr><td><input class="cell-input" data-item="' + i + '" data-k="name" value="' + esc(it.name) + '" placeholder="例：A4 影印紙" aria-label="第 ' + (i + 1) + ' 筆品項名稱"></td><td class="num"><input class="cell-input num" data-item="' + i + '" data-k="quantity" value="' + it.quantity + '" inputmode="numeric" aria-label="第 ' + (i + 1) + ' 筆數量"></td><td class="num"><input class="cell-input num" data-item="' + i + '" data-k="unitPrice" value="' + it.unitPrice + '" inputmode="numeric" aria-label="第 ' + (i + 1) + ' 筆單價"></td><td class="num">' + fmt(it.subtotal) + '</td><td class="act"><button type="button" class="btn btn-text btn-sm" data-action="rm-item" data-i="' + i + '" aria-label="移除第 ' + (i + 1) + ' 筆品項">移除</button></td></tr>'; }).join('') || '<tr><td colspan="5" class="dash-empty">沒有品項明細（選填）</td></tr>';
    var isum = f.items.reduce(function(a, x){ return a + x.subtotal; }, 0), amt = num($('#f-amount').value);
    bind('items-sum', f.items.length ? '品項小計合計 ' + fmt(isum) + (amt != null && Math.round(amt) !== Math.round(isum) ? '<span class="warn-text">・與總金額相差 ' + fmt(amt - isum) + '</span>' : '') : '', true);
  }
  function taxCalc(from){
    var rate = $('[data-el="f-taxrate"]').qdsGetValue() === 'business_5' ? 0.05 : 0, a = num($('#f-amount').value), p = num($('#f-pretax').value);
    if (from === 'amount' && a != null){ var pt = Math.round(a / (1 + rate)); $('#f-pretax').value = pt; $('#f-tax').value = a - pt; }
    else if (from === 'pretax' && p != null){ var tx = Math.round(p * rate); $('#f-tax').value = tx; $('#f-amount').value = p + tx; }
    else if (from === 'rate' && a != null){ taxCalc('amount'); }
    else if (from === 'tax'){ var t2 = num($('#f-tax').value); if (p != null && t2 != null) $('#f-amount').value = p + t2; }
    renderFormBits();
  }
  function ferr(key, msg){ var el = $('[data-err="' + key + '"]'); el.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 8v5M12 16h.01"/></svg>' + msg; el.hidden = false; var fld = el.closest('.field'); var inp = fld && $('input, .qds-select, .qds-datepicker, .input-group', fld); if (inp) inp.classList.add('is-invalid'); return fld; }
  function saveForm(){
    var f = state.form, view = $('.dash-view[data-view="expense-form"]');
    $$('[data-err]', view).forEach(function(x){ x.hidden = true; }); $$('.is-invalid', view).forEach(function(x){ x.classList.remove('is-invalid'); });
    var invoice = ($('input[name="f-doc"]:checked') || {}).value === 'invoice', date = $('[data-el="f-date"]').qdsGetValue().start, cid = $('[data-el="f-cat"]').qdsGetValue(), amt = num($('#f-amount').value);
    var i1 = $('#f-inv1').value.trim().toUpperCase(), i2 = $('#f-inv2').value.trim(), taxId = $('#f-taxid').value.trim(), bad = [];
    if (!date) bad.push(ferr('f-date', '請選擇費用日期'));
    if (!cid) bad.push(ferr('f-cat', '請選擇類別'));
    if (taxId && !/^\d{8}$/.test(taxId)) bad.push(ferr('f-taxid', '賣方統編為 8 碼數字'));
    if (invoice && !(/^[A-Z]{2}$/.test(i1) && /^\d{8}$/.test(i2))) bad.push(ferr('f-inv', '發票號碼格式為 2 碼英文＋8 碼數字，例如 AB-12345678'));
    if (!invoice && (i1 || i2) && !(i1 && i2)) bad.push(ferr('f-inv', '請填完整的號碼，或兩格都留空'));
    if (!(amt > 0)) bad.push(ferr('f-amount', '請輸入大於 0 的總金額'));
    if (bad.length){ var first = bad[0] && $('input, button', bad[0]); if (first) first.focus(); toast('有 ' + bad.length + ' 個欄位需要修正'); return; }
    var rec = { docType:invoice ? 'invoice' : 'receipt', vendor:$('#f-vendor').value.trim() || null, taxId:taxId || null, invoiceNo:i1 && i2 ? i1 + '-' + i2 : null, taxRate:$('[data-el="f-taxrate"]').qdsGetValue(),
      preTax:num($('#f-pretax').value), tax:num($('#f-tax').value), amount:amt, cat:cid, date:new Date(date.getFullYear(), date.getMonth(), date.getDate()), note:$('#f-note').value.trim() || null,
      items:f.items.filter(function(x){ return x.name.trim(); }), payout:$('[data-el="f-payout"]').qdsGetValue(), files:f.files.length };
    if (f.id){ Object.assign(exp(f.id), rec); toast('已更新「' + (rec.vendor || catName(cid)) + '」'); }
    else { exps.push(Object.assign({ id:'new-' + Date.now(), source:'general', ref:null, by:ME.id }, rec)); toast('已新增支出 ' + fmt(amt) + '（' + catName(cid) + '）'); }
    state.form = null; state.expTab = 'all'; goto('expenses');
  }

  // ---------- 請款記錄/簽核/發放 ----------
  function reqFilter(v){ var f = state.f[v]; return reqs.filter(function(r){ return (f.cat === 'all' || r.cat === f.cat) && (!f.range || (r.incurredAt >= f.range.start && r.incurredAt <= f.range.end)) && (f.min == null || r.amount >= f.min) && (f.max == null || r.amount <= f.max) && match(f.q, r.name, r.desc, r.vendor, r.id, catName(r.cat)); }); }
  function isFiltered(v){ var f = state.f[v]; return !!(f.q.trim() || f.cat !== 'all' || f.range || f.min != null || f.max != null); }
  function whoCell(r){ return esc(r.name) + '<div class="cell-sub">' + esc(r.desc) + '</div>'; }
  function selInfo(v, rows){
    var sel = state.sel[v]; Object.keys(sel).forEach(function(id){ if (!rows.some(function(r){ return r.id === id; })) delete sel[id]; });
    var ids = Object.keys(sel).filter(function(k){ return sel[k]; }), amt = sumAmt(rows.filter(function(r){ return sel[r.id]; }));
    $('[data-toolbar="' + v + '"]').hidden = !!ids.length; $('[data-selbar="' + v + '"]').hidden = !ids.length;
    bind(v + '-selcount', '已選 ' + ids.length + ' 筆，合計 ' + fmt(amt));
    var all = $('[data-check-all="' + v + '"]'); if (all){ var onPage = $$('[data-sel="' + v + '"]').map(function(c){ return c.value; }); var n = onPage.filter(function(id){ return sel[id]; }).length; all.checked = !!onPage.length && n === onPage.length; all.indeterminate = n > 0 && n < onPage.length; }
  }
  function chk(v, id){ return '<td class="chk"><input type="checkbox" class="dash-check" data-sel="' + v + '" value="' + id + '"' + (state.sel[v][id] ? ' checked' : '') + ' aria-label="選取 ' + id + '"></td>'; }
  function renderRecords(){
    var base = reqFilter('records'), cnt = function(s){ return base.filter(function(r){ return r.status === s; }).length; };
    tabs('[data-el="rec-tabs"]', [['all','全部',base.length],['in_review','簽核中',cnt('in_review')],['rejected','駁回',cnt('rejected')],['approved','已核銷',cnt('approved')],['paid','已發放',cnt('paid')],['voided','已作廢',cnt('voided')]], state.recTab, 'data-rec-tab');
    var rows = sortRows(base.filter(function(r){ return state.recTab === 'all' || r.status === state.recTab; }), state.sort.records);
    $('[data-action="clear-filter"][data-list="records"]').hidden = !isFiltered('records');
    bind('records-sum', '共 ' + rows.length + ' 筆' + SEP + '合計 ' + fmt(sumAmt(rows)), true);
    $('[data-el="rec-rows"]').innerHTML = rows.length ? pageSlice(rows, 'rec').map(function(r){ return '<tr tabindex="0" data-open="' + r.id + '"><td>' + whoCell(r) + '</td><td>' + esc(catName(r.cat)) + '</td><td class="num">' + fmt(r.amount) + '</td><td>' + ymd(r.incurredAt) + '</td><td>' + rbadge(r.status) + '</td><td>' + (PAYM[r.paymentMethod] || '—') + '</td><td>' + ymdhm(r.createdAt) + '</td><td class="act"><button type="button" class="btn btn-secondary btn-icon-only btn-sm" data-open="' + r.id + '" aria-label="查看詳情" title="查看詳情">' + I_EYE + '</button></td></tr>'; }).join('')
      : (pageSlice([], 'rec'), emptyRow(8, isFiltered('records'), '這個分類目前沒有請款單', 'data-action="clear-filter" data-list="records"'));
    sortInd('records');
  }
  function renderReview(){
    var base = reqFilter('review'), pend = state.revTab === 'pending';
    var P = base.filter(function(r){ return r.status === 'in_review'; }), D = base.filter(function(r){ return r.status !== 'in_review' && r.reviewedAt; });
    tabs('[data-el="rev-tabs"]', [['pending','待簽核',P.length],['reviewed','已處理',D.length]], state.revTab, 'data-rev-tab');
    var rows = sortRows(pend ? P : D, state.sort.review);
    $('[data-el="rev-rows-head"]').innerHTML = (pend ? '<th class="chk"><input type="checkbox" class="dash-check" data-check-all="review" aria-label="全選本頁"></th>' : '') + '<th>申請人</th><th>類別</th><th class="num sortable"><button type="button" class="sort-btn" data-sort="review:amount">金額<span class="sort-ind"></span></button></th><th class="sortable"><button type="button" class="sort-btn" data-sort="review:incurredAt">費用日<span class="sort-ind"></span></button></th>' + (pend ? '<th>目前階段</th>' : '<th>狀態</th><th>支出狀態</th>') + '<th class="sortable"><button type="button" class="sort-btn" data-sort="review:updatedAt">更新時間<span class="sort-ind"></span></button></th><th class="act"><span class="sr-only">操作</span></th>';
    $('[data-action="clear-filter"][data-list="review"]').hidden = !isFiltered('review');
    bind('review-sum', (pend ? '待簽核 ' : '已處理 ') + rows.length + ' 筆' + SEP + '合計 ' + fmt(sumAmt(rows)), true);
    var cols = pend ? 8 : 8;
    $('[data-el="rev-rows"]').innerHTML = rows.length ? pageSlice(rows, 'rev').map(function(r){
      var e = expOfReq(r), expCell = r.status === 'rejected' || r.status === 'voided' ? '—' : e ? '<button type="button" class="btn btn-text btn-sm" data-action="view-exp" data-id="' + e.id + '">已建立支出</button>' : '<span class="muted">尚未建立</span>';
      var act = pend ? '<span class="row-actions"><button type="button" class="btn btn-secondary btn-sm" data-action="approve" data-id="' + r.id + '">通過</button><button type="button" class="btn btn-danger btn-sm" data-action="reject" data-id="' + r.id + '">駁回</button></span>'
        : (!e && (r.status === 'approved' || r.status === 'paid') ? '<button type="button" class="btn btn-secondary btn-sm" data-action="create-exp" data-id="' + r.id + '" aria-label="補建立對應支出">新增支出</button>' : '<button type="button" class="btn btn-secondary btn-icon-only btn-sm" data-open="' + r.id + '" aria-label="查看詳情" title="查看詳情">' + I_EYE + '</button>');
      return '<tr tabindex="0" data-open="' + r.id + '">' + (pend ? chk('review', r.id) : '') + '<td>' + whoCell(r) + '</td><td>' + esc(catName(r.cat)) + '</td><td class="num">' + fmt(r.amount) + '</td><td>' + ymd(r.incurredAt) + '</td>' + (pend ? '<td><span class="tag-soft tag-warn">管理員簽核</span></td>' : '<td>' + rbadge(r.status) + '</td><td>' + expCell + '</td>') + '<td>' + ymdhm(r.updatedAt) + '</td><td class="act">' + act + '</td></tr>';
    }).join('') : (pageSlice([], 'rev'), emptyRow(cols, isFiltered('review'), pend ? '目前沒有待簽核的請款單' : '還沒有處理過的請款單', 'data-action="clear-filter" data-list="review"'));
    if (pend) selInfo('review', rows); else { $('[data-toolbar="review"]').hidden = false; $('[data-selbar="review"]').hidden = true; }
    sortInd('review');
  }
  function renderPayout(){
    var base = reqFilter('payout'), pend = state.payTab === 'pending';
    var P = base.filter(function(r){ return r.status === 'approved'; }), D = base.filter(function(r){ return r.status === 'paid' || (r.status === 'voided'); });
    tabs('[data-el="pay-tabs"]', [['pending','待發放',P.length],['completed','已完成',D.length]], state.payTab, 'data-pay-tab');
    var rows = sortRows(pend ? P : D, state.sort.payout);
    var head = $('[data-el="pay-rows-head"]'), th = head.querySelector('th.chk'); if (th) th.hidden = !pend;
    $('[data-action="clear-filter"][data-list="payout"]').hidden = !isFiltered('payout');
    bind('payout-sum', (pend ? '待發放 ' : '已完成 ') + rows.length + ' 筆' + SEP + '合計 ' + fmt(sumAmt(rows)), true);
    $('[data-el="pay-rows"]').innerHTML = rows.length ? pageSlice(rows, 'pay').map(function(r){
      var act = pend ? '<span class="row-actions"><button type="button" class="btn btn-secondary btn-sm" data-action="pay" data-id="' + r.id + '">發放</button><button type="button" class="btn btn-danger btn-sm" data-action="void" data-id="' + r.id + '">作廢</button></span>'
        : r.status === 'paid' ? '<button type="button" class="btn btn-text btn-sm" data-action="revert-pay" data-id="' + r.id + '">取消發放</button>' : '<button type="button" class="btn btn-text btn-sm" data-action="revert-void" data-id="' + r.id + '">取消作廢</button>';
      return '<tr tabindex="0" data-open="' + r.id + '">' + (pend ? chk('payout', r.id) : '') + '<td>' + whoCell(r) + '</td><td>' + esc(catName(r.cat)) + '</td><td class="num">' + fmt(r.amount) + '</td><td>' + ymd(r.incurredAt) + '</td><td>' + rbadge(r.status) + '</td><td>' + (PAYM[r.paymentMethod] || '—') + '</td><td>' + ymdhm(r.updatedAt) + '</td><td class="act">' + act + '</td></tr>';
    }).join('') : (pageSlice([], 'pay'), emptyRow(8, isFiltered('payout'), pend ? '沒有待發放的款項' : '還沒有已完成的發放', 'data-action="clear-filter" data-list="payout"'));
    if (pend) selInfo('payout', rows); else { $('[data-toolbar="payout"]').hidden = false; $('[data-selbar="payout"]').hidden = true; }
    sortInd('payout');
  }

  // ---------- 彈出層 ----------
  var TI = { ok:'<path d="M5 12l5 5L20 7"/>', wait:'<circle cx="12" cy="12" r="8"/><path d="M12 8v4l3 2"/>', no:'<path d="M6 6l12 12M18 6L6 18"/>', none:'<circle cx="12" cy="12" r="3"/>' };
  function tlItem(cls, icon, title, status, meta, comment){
    return '<li class="tl-item ' + cls + '"' + (cls === 'current' ? ' aria-current="step"' : '') + '><span class="tl-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">' + TI[icon] + '</svg></span><div class="tl-content"><div class="tl-head"><span class="tl-title">' + title + '</span><span class="tl-status">' + status + '</span></div>' + (meta ? '<div class="tl-meta">' + meta + '</div>' : '') + (comment ? '<div class="tl-comment">' + esc(comment) + '</div>' : '') + '</div></li>';
  }
  var toastT; function toast(msg){ var t = $('[data-el="toast"]'); t.textContent = msg; t.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(function(){ t.classList.remove('show'); }, 2600); }
  function closePops(){ $$('.dash-pop.open').forEach(function(p){ p.classList.remove('open'); var b = $('[data-toggle]', p); if (b) b.setAttribute('aria-expanded', 'false'); }); if (QDS.closeAll) QDS.closeAll(); }
  var lastFocus = null;
  function openOverlay(name){ closePops(); if (!lastFocus) lastFocus = document.activeElement; $$('.dash-overlay.open').forEach(function(o){ o.classList.remove('open'); o.setAttribute('aria-hidden', 'true'); }); var o = $('[data-overlay="' + name + '"]'); o.classList.add('open'); o.setAttribute('aria-hidden', 'false'); var f = $('[data-autofocus]', o) || $('.db input:not([disabled]):not([type="checkbox"]):not([type="radio"]):not([hidden]), .db textarea, .df .btn-primary, .df .btn-danger, .close-btn', o); setTimeout(function(){ if (f && f.offsetParent) f.focus(); else { var c = $('.close-btn, .df .btn', o); if (c) c.focus(); } }, 0); }
  function closeOverlay(){ $$('.dash-overlay.open').forEach(function(o){ o.classList.remove('open'); o.setAttribute('aria-hidden', 'true'); }); if (lastFocus && document.contains(lastFocus) && lastFocus.offsetParent) lastFocus.focus(); lastFocus = null; }
  function clearErrs(scope){ $$('[data-err]', scope).forEach(function(x){ x.hidden = true; }); $$('.is-invalid', scope).forEach(function(x){ x.classList.remove('is-invalid'); }); }

  // ---------- 請款單明細 ----------
  function openDetail(id, from){
    var r = req(id); if (!r) return;
    var st = r.status, admin = esc(ME.name), e = expOfReq(r);
    $('[data-el="detail-title"]').innerHTML = '請款單' + SEP + esc(r.name);
    var tl = tlItem('approved', 'ok', '送出請款', '已送出', esc(r.name) + SEP + ymdhm(r.createdAt));
    if (st === 'in_review') tl += tlItem('current', 'wait', '管理員簽核', '等待中', '送出後 ' + Math.max(0, Math.round((now() - r.createdAt) / 864e5)) + ' 天') + tlItem('pending', 'none', '發放', '尚未開始');
    else if (st === 'rejected') tl += tlItem('rejected', 'no', '管理員簽核', '已駁回', admin + SEP + ymdhm(r.reviewedAt || r.updatedAt), r.comment);
    else {
      tl += tlItem('approved', 'ok', '管理員簽核', '已核准', admin + SEP + ymdhm(r.reviewedAt || r.updatedAt), r.comment);
      tl += st === 'paid' ? tlItem('approved', 'ok', '發放', '已發放', (PAYM[r.paymentMethod] || '') + SEP + ymdhm(r.updatedAt))
        : st === 'voided' ? tlItem('rejected', 'no', '發放', '已作廢', ymdhm(r.updatedAt), r.comment) : tlItem('current', 'wait', '發放', '等待發放');
    }
    $('[data-el="detail-body"]').innerHTML = '<div class="detail-status">' + rbadge(st) + '<span class="detail-amt">' + fmt(r.amount) + '</span></div>' +
      kv('申請人', esc(r.name)) + kv('說明', esc(r.desc)) + kv('類別', esc(catName(r.cat))) + kv('費用日期', ymd(r.incurredAt)) +
      '<div class="dash-sub-title">憑證</div>' + kv('賣方名稱', esc(r.vendor || '—')) + kv('憑證類型', r.docType === 'invoice' ? '統一發票' : r.docType === 'receipt' ? '收據/其他單據' : '—') + kv('發票號碼', esc(r.invoiceNo || '—')) + kv('賣方統編', esc(r.taxId || '—')) + kv('附件', r.receiptCount + ' 個') +
      (st === 'paid' ? kv('發放方式', PAYM[r.paymentMethod] || '—') : '') + kv('建立時間', ymdhm(r.createdAt)) +
      '<div class="dash-sub-title">簽核進度</div><ol class="timeline" aria-label="簽核進度">' + tl + '</ol>' +
      (st === 'in_review' || st === 'rejected' ? '' : '<div class="dash-sub-title">對應支出</div>' + (e ? '<button type="button" class="linked-exp" data-action="view-exp" data-id="' + e.id + '"><span>' + esc(e.vendor || catName(e.cat)) + '<span class="cell-sub">' + SEP + esc(catName(e.cat)) + SEP + ymd(e.date) + '</span></span><span>' + pbadge(e.payout) + '</span></button>' : '<p class="dash-dialog-text">尚未建立支出，這筆代墊款還不會出現在支出管理與報表。</p>'));
    var foot = '';
    if (st === 'in_review') foot = '<button type="button" class="btn btn-danger" data-action="reject" data-id="' + r.id + '">駁回</button><span class="button-bar-gap"></span><button type="button" class="btn btn-primary" data-action="approve" data-id="' + r.id + '">核准</button>';
    else if (st === 'approved') foot = '<button type="button" class="btn btn-danger" data-action="void" data-id="' + r.id + '">作廢</button><span class="button-bar-gap"></span>' + (e ? '' : '<button type="button" class="btn btn-secondary" data-action="create-exp" data-id="' + r.id + '">補建立對應支出</button>') + '<button type="button" class="btn btn-primary" data-action="pay" data-id="' + r.id + '">標記已發放</button>';
    else if (st === 'paid') foot = '<button type="button" class="btn btn-secondary" data-action="revert-pay" data-id="' + r.id + '">取消發放</button><span class="button-bar-gap"></span><button type="button" class="btn btn-primary" data-action="close">關閉</button>';
    else if (st === 'voided') foot = '<button type="button" class="btn btn-secondary" data-action="revert-void" data-id="' + r.id + '">取消作廢</button><span class="button-bar-gap"></span><button type="button" class="btn btn-primary" data-action="close">關閉</button>';
    else foot = '<span class="button-bar-gap"></span><button type="button" class="btn btn-primary" data-action="close">關閉</button>';
    $('[data-el="detail-foot"]').innerHTML = foot;
    lastFocus = from || document.activeElement; openOverlay('detail');
  }

  // ---------- 核准（可同時建立支出）/補建支出 ----------
  function reqsOf(ids, status){ return ids.map(req).filter(function(r){ return r && (!status || r.status === status); }); }
  function openApprove(ids, createOnly){
    var list = reqsOf(ids, createOnly ? null : 'in_review'); if (!list.length) return;
    var dlg = $('[data-overlay="approve"]'), one = list.length === 1, r = list[0];
    state.action = { type:'approve', ids:list.map(function(x){ return x.id; }), createOnly:!!createOnly };
    clearErrs(dlg);
    $('[data-el="approve-title"]').textContent = createOnly ? '補建立對應支出' : one ? '核准請款' : '批次核准 ' + list.length + ' 筆';
    $('[data-el="approve-summary"]').innerHTML = one ? '<b>' + esc(r.name) + SEP + esc(r.desc) + '</b><span>' + esc(catName(r.cat)) + '' + SEP + '費用日 ' + ymd(r.incurredAt) + '</span><strong>' + fmt(r.amount) + '</strong>'
      : '<b>已選 ' + list.length + ' 筆</b><span>' + list.map(function(x){ return esc(x.name); }).join('、') + '</span><strong>' + fmt(sumAmt(list)) + '</strong>';
    $('#ap-comment').value = ''; $('#ap-comment').closest('.field').hidden = !!createOnly;
    $('[data-el="ap-create-row"]').hidden = !one || !!createOnly; $('#ap-create').checked = true;
    $('[data-el="ap-expense"]').hidden = !one;
    if (one){ var ac = $('[data-el="ap-cat"]'); ac.qdsSetOptions(catOpts(false), r.cat); $('#ap-vendor').value = r.vendor || ''; $('[data-el="ap-payout"]').qdsSetValue('pending'); }
    $('[data-el="approve-confirm"]').textContent = createOnly ? '建立支出' : one ? '核准' : '核准 ' + list.length + ' 筆';
    openOverlay('approve');
  }
  function makeExpense(r, vendor, cid, payout){
    var inv = r.docType === 'invoice', pre = inv ? Math.round(r.amount / 1.05) : r.amount;
    var e = { id:'exp-' + r.id, source:'reimbursement', ref:r.id, docType:r.docType || 'receipt', vendor:vendor, taxId:r.taxId, invoiceNo:r.invoiceNo, taxRate:inv ? 'business_5' : 'exempt_0', preTax:pre, tax:r.amount - pre,
      amount:r.amount, cat:cid, date:r.incurredAt, note:r.desc, items:[], payout:r.status === 'paid' ? 'paid' : payout, by:ME.id, files:r.receiptCount };
    exps.push(e); r.expenseId = e.id; return e;
  }
  function confirmApprove(){
    var a = state.action, dlg = $('[data-overlay="approve"]'), list = reqsOf(a.ids); clearErrs(dlg);
    var one = list.length === 1, create = one && (a.createOnly || $('#ap-create').checked), vendor = $('#ap-vendor').value.trim(), cid = $('[data-el="ap-cat"]').qdsGetValue(), bad = null;
    if (create && !cid) bad = ferr('ap-cat', '請選擇會計科目');
    if (create && !vendor) bad = ferr('ap-vendor', '請填寫實付廠商');
    if (bad){ var f = $('input, button', bad); if (f) f.focus(); return; }
    var comment = $('#ap-comment').value.trim();
    list.forEach(function(r){
      if (!a.createOnly){ r.status = 'approved'; r.comment = comment || null; r.reviewedAt = now(); r.updatedAt = now(); delete state.sel.review[r.id]; }
      if (create) makeExpense(r, vendor, cid, $('[data-el="ap-payout"]').qdsGetValue());
    });
    lastFocus = null; closeOverlay(); render();
    toast(a.createOnly ? '已建立支出，已寫入支出管理' : '已核准 ' + (one ? '「' + list[0].desc + '」' : list.length + ' 筆') + (create ? '並建立支出' : '') + '，已移到「發放」');
  }
  // ---------- 駁回 ----------
  function openReject(ids){
    var list = reqsOf(ids, 'in_review'); if (!list.length) return;
    state.action = { type:'reject', ids:list.map(function(x){ return x.id; }) };
    clearErrs($('[data-overlay="reject"]')); $('#rj-reason').value = '';
    $('[data-el="reject-title"]').textContent = list.length > 1 ? '批次駁回 ' + list.length + ' 筆' : '駁回請款';
    $('[data-el="reject-text"]').textContent = list.length > 1 ? '將駁回 ' + list.length + ' 筆請款（合計 ' + fmt(sumAmt(list)) + '），同一個原因會通知每位申請人。' : '將駁回「' + list[0].name + '・' + list[0].desc + '」' + fmt(list[0].amount) + '，原因會通知申請人。';
    openOverlay('reject');
  }
  function confirmReject(){
    var reason = $('#rj-reason').value.trim();
    if (!reason){ ferr('rj-reason', '請填寫駁回原因'); $('#rj-reason').classList.add('is-invalid'); $('#rj-reason').focus(); return; }
    var list = reqsOf(state.action.ids, 'in_review');
    list.forEach(function(r){ r.status = 'rejected'; r.comment = reason; r.reviewedAt = now(); r.updatedAt = now(); delete state.sel.review[r.id]; });
    lastFocus = null; closeOverlay(); render();
    toast('已駁回 ' + (list.length > 1 ? list.length + ' 筆' : '「' + list[0].desc + '」') + '，已通知申請人');
  }
  // ---------- 發放/作廢/取消 ----------
  var PA = {
    pay:{ from:'approved', title:'標記已發放', btn:'確認發放', cls:'btn-primary', method:true, comment:false },
    'void':{ from:'approved', title:'作廢請款', btn:'確認作廢', cls:'btn-danger', method:false, comment:'作廢原因', req:true },
    'revert-pay':{ from:'paid', title:'取消發放', btn:'取消發放', cls:'btn-primary', method:false, comment:'說明（選填）' },
    'revert-void':{ from:'voided', title:'取消作廢', btn:'取消作廢', cls:'btn-primary', method:false, comment:'說明（選填）' }
  };
  function openPay(kind, ids){
    var cfg = PA[kind], list = reqsOf(ids, cfg.from); if (!list.length) return;
    state.action = { type:kind, ids:list.map(function(x){ return x.id; }) };
    var dlg = $('[data-overlay="payaction"]'); clearErrs(dlg);
    $('[data-el="payaction-title"]').textContent = cfg.title + (list.length > 1 ? ' ' + list.length + ' 筆' : '');
    var who = list.length > 1 ? list.length + ' 筆，合計 ' + fmt(sumAmt(list)) : '「' + list[0].name + '・' + list[0].desc + '」' + fmt(list[0].amount);
    $('[data-el="payaction-text"]').textContent = kind === 'pay' ? '確認已把 ' + who + ' 撥給申請人。' : kind === 'void' ? '作廢 ' + who + '，作廢後不會發放，申請人會收到通知。' : kind === 'revert-pay' ? '把 ' + who + ' 退回「待發放」。' : '把 ' + who + ' 恢復為「待發放」。';
    $('[data-el="payaction-method"]').hidden = !cfg.method; $$('input[name="pay-method"]').forEach(function(x){ x.checked = x.value === 'bank_transfer'; });
    var noExp = list.filter(function(r){ return !r.expenseId; }).length, w = $('[data-el="payaction-warn"]');
    w.hidden = !(kind === 'pay' && noExp) && !(kind === 'revert-pay' && list.some(function(r){ return r.expenseId; }));
    w.textContent = kind === 'pay' ? noExp + ' 筆還沒建立支出；發放後仍可在請款單明細補建。' : '對應支出的付款狀態會一併改回「待付款」。';
    $('[data-el="payaction-comment"]').hidden = !cfg.comment; $('[data-el="payaction-comment-label"]').textContent = cfg.comment || ''; $('#pa-comment').value = '';
    var b = $('[data-el="payaction-confirm"]'); b.textContent = cfg.btn; b.className = 'btn ' + cfg.cls;
    openOverlay('payaction');
  }
  function confirmPay(){
    var kind = state.action.type, cfg = PA[kind], c = $('#pa-comment').value.trim();
    if (cfg.req && !c){ ferr('pa-comment', '請填寫' + cfg.comment); $('#pa-comment').classList.add('is-invalid'); $('#pa-comment').focus(); return; }
    var list = reqsOf(state.action.ids, cfg.from), m = ($('input[name="pay-method"]:checked') || {}).value;
    list.forEach(function(r){
      var e = expOfReq(r); r.updatedAt = now(); delete state.sel.payout[r.id];
      if (kind === 'pay'){ r.status = 'paid'; r.paymentMethod = m; if (e) e.payout = 'paid'; }
      else if (kind === 'void'){ r.status = 'voided'; r.comment = c; }
      else if (kind === 'revert-pay'){ r.status = 'approved'; r.paymentMethod = null; if (e) e.payout = 'pending'; }
      else { r.status = 'approved'; }
    });
    lastFocus = null; closeOverlay(); render();
    toast({ pay:'已標記發放 ' + list.length + ' 筆（' + PAYM[m] + '）', 'void':'已作廢 ' + list.length + ' 筆', 'revert-pay':'已取消發放，退回待發放', 'revert-void':'已取消作廢，恢復為待發放' }[kind]);
  }

  // ---------- 確認對話框（刪除類操作） ----------
  function askConfirm(kind, id, title, body, okText){
    state.confirm = { kind:kind, id:id };
    $('[data-el="confirm-title"]').textContent = title; $('[data-el="confirm-body"]').innerHTML = '<p class="dash-dialog-text">' + body + '</p>'; $('[data-el="confirm-ok"]').textContent = okText || '刪除';
    openOverlay('confirm');
  }
  function doConfirm(){
    var c = state.confirm, msg = '';
    if (c.kind === 'del-exp'){ var e = exp(c.id); exps = exps.filter(function(x){ return x.id !== c.id; }); msg = '已刪除支出「' + (e.vendor || catName(e.cat)) + '」'; }
    else if (c.kind === 'del-cat'){ var ct = cat(c.id); cats = cats.filter(function(x){ return x.id !== c.id; }); budgets = budgets.filter(function(b){ return b.cat !== c.id; }); templates = templates.filter(function(b){ return b.cat !== c.id; }); syncCatSelects(); msg = '已刪除類別「' + ct.name + '」'; }
    else if (c.kind === 'del-user'){ var u = users.filter(function(x){ return x.id === c.id; })[0]; users = users.filter(function(x){ return x.id !== c.id; }); msg = '已刪除「' + u.name + '」，他送出的請款記錄會保留'; }
    else if (c.kind === 'revoke'){ var iv = invites.filter(function(x){ return x.id === c.id; })[0]; iv.revoked = true; msg = '已撤回給 ' + iv.email + ' 的邀請'; }
    lastFocus = null; closeOverlay(); if ($('.dash-overlay.open')) closeOverlay(); render(); toast(msg);
  }
  // ---------- 匯入 ----------
  var IMPORT_ROWS = [{ d:3, cat:'office', v:'誠品文具', amt:1280 }, { d:8, cat:'postage', v:'中華郵政', amt:420 }, { d:15, cat:'meal', v:'八方雲集', amt:2350 }];
  function openImport(){ $('[data-el="import-file"]').value = ''; $('[data-el="import-preview"]').hidden = true; $('[data-el="import-drop"]').hidden = false; $('[data-el="import-confirm"]').disabled = true; openOverlay('import'); }
  function importChosen(name){
    $('[data-el="import-drop"]').hidden = true;
    var p = $('[data-el="import-preview"]'); p.hidden = false;
    p.innerHTML = '<div class="file-chip"><span>' + esc(name) + '</span><button type="button" class="btn btn-text btn-sm" data-action="import-reset">重新選擇</button></div><p class="dash-dialog-text">讀到 ' + IMPORT_ROWS.length + ' 筆，全部通過檢查：</p>' +
      '<table class="dash-table mini-table"><thead><tr><th>日期</th><th>類別</th><th>廠商</th><th class="num">金額</th></tr></thead><tbody>' + IMPORT_ROWS.map(function(x){ return '<tr><td>2026/09/' + pad(x.d) + '</td><td>' + esc(catName(x.cat)) + '</td><td>' + esc(x.v) + '</td><td class="num">' + fmt(x.amt) + '</td></tr>'; }).join('') + '</tbody></table>';
    $('[data-el="import-confirm"]').disabled = false;
  }
  function doImport(){
    IMPORT_ROWS.forEach(function(x, i){ exps.push({ id:'imp-' + Date.now() + i, source:'general', ref:null, docType:'receipt', vendor:x.v, taxId:null, invoiceNo:null, taxRate:'exempt_0', preTax:x.amt, tax:0, amount:x.amt, cat:x.cat, date:new Date(2026, 8, x.d), note:'Excel 匯入', items:[], payout:'paid', by:ME.id, files:0 }); });
    lastFocus = null; closeOverlay(); state.expTab = 'all'; resetPage('exp'); render(); toast('已匯入 ' + IMPORT_ROWS.length + ' 筆支出');
  }

  // ---------- 類別管理 ----------
  function catUse(id){ return exps.filter(function(e){ return e.cat === id; }).length + reqs.filter(function(r){ return r.cat === id; }).length; }
  function renderCategories(){
    var act = cats.filter(function(c){ return !c.archived; }), arc = cats.filter(function(c){ return c.archived; });
    tabs('[data-el="cat-tabs"]', [['active','使用中',act.length],['archived','已停用',arc.length]], state.catTab, 'data-cat-tab');
    var q = state.q.categories, rows = (state.catTab === 'active' ? act : arc).filter(function(c){ return match(q, c.name, c.code ? subjLabel(c.code) : ""); }), m0 = new Date(2026, 8, 1);
    bind('categories-sum', rows.length + ' 個類別');
    $('[data-el="cat-rows"]').innerHTML = rows.length ? rows.map(function(c){
      var used = catUse(c.id), menu = '<button type="button" role="menuitem" data-action="' + (c.archived ? 'unarchive' : 'archive') + '" data-id="' + c.id + '">' + (c.archived ? '啟用' : '停用') + '</button><button type="button" role="menuitem" class="danger" data-action="del-cat" data-id="' + c.id + '"' + (used ? ' disabled title="已有 ' + used + ' 筆紀錄使用，只能停用"' : '') + '>刪除' + (used ? '<small>已有紀錄使用，只能停用</small>' : '') + '</button>';
      return '<tr><td>' + esc(c.name) + '</td><td>' + (c.code ? esc(subjLabel(c.code)) : '<span class="cell-sub">未設定</span>') + '</td><td class="num">' + fmt(sumAmt(expIn(m0, TODAY, c.id))) + '</td><td class="num">' + used + '</td><td class="act"><span class="row-actions"><button type="button" class="btn btn-text btn-icon-only btn-sm" data-action="edit-cat" data-id="' + c.id + '" aria-label="編輯 ' + esc(c.name) + '" title="編輯">' + I_EDIT + '</button>' + rowMenu(c.id, menu) + '</span></td></tr>';
    }).join('') : emptyRow(5, !!q.trim(), state.catTab === 'active' ? '還沒有使用中的類別' : '沒有停用的類別', 'data-action="clear-q" data-list="categories"');
  }
  // 會計科目名稱直接取自對話框裡的科目選單（選項即科目表）
  function subjLabel(code){ var o = $('[data-el="cat-subject"] [data-value="' + code + '"]'); return o ? o.textContent : code; }
  function catSubjectHelp(){
    var code = $('[data-el="cat-subject"]').qdsGetValue(), same = code ? cats.filter(function(c){ return c.code === code && c.id !== state.catEdit; }).map(function(c){ return c.name; }) : [];
    bind('cat-subject-help', same.length ? '同科目類別：' + same.join('、') : '可稍後補填。不同類別可共用同一科目，如交通費、差旅費皆為 6114 旅費。');
  }
  function openCat(id){
    var c = id ? cat(id) : null, dlg = $('[data-overlay="cat"]'), sj = $('[data-el="cat-subject"]'); clearErrs(dlg); state.catEdit = id || null;
    $('[data-el="cat-title"]').textContent = c ? '編輯類別' : '新增類別'; $('#cat-name').value = c ? c.name : '';
    if (c && c.code) sj.qdsSetValue(c.code); else { sj.dataset.value = ''; $$('[role="option"]', sj).forEach(function(o){ o.classList.remove('sel'); o.setAttribute('aria-selected', 'false'); }); var v = $('.qds-select-value', sj); v.textContent = '請選擇會計科目'; v.classList.add('is-placeholder'); }
    catSubjectHelp(); openOverlay('cat');
  }
  function saveCat(){
    var nm = $('#cat-name').value.trim(), code = $('[data-el="cat-subject"]').qdsGetValue(), id = state.catEdit;
    clearErrs($('[data-overlay="cat"]'));
    if (!nm){ ferr('cat-name', '請填寫類別名稱'); $('#cat-name').focus(); return; }
    if (cats.some(function(c){ return c.name === nm && c.id !== id; })){ ferr('cat-name', '已經有「' + nm + '」這個類別'); $('#cat-name').focus(); return; }
    if (id){ var c = cat(id); c.name = nm; c.code = code; toast('已更新「' + nm + '」'); }
    else { cats.push({ id:'cat-' + Date.now(), name:nm, code:code, archived:false }); catIdx[cats[cats.length - 1].id] = cats.length - 1; state.catTab = 'active'; toast('已新增類別「' + nm + '」'); }
    lastFocus = null; closeOverlay(); syncCatSelects(); render();
  }
  function setArchived(id, v){ var c = cat(id); c.archived = v; syncCatSelects(); closePops(); render(); toast(v ? '已停用「' + c.name + '」，既有紀錄保留原類別' : '已啟用「' + c.name + '」'); }

  // ---------- 預算管理 ----------
  function periodEnd(s, cycle){ return cycle === 'year' ? new Date(s.getFullYear(), 11, 31) : new Date(s.getFullYear(), s.getMonth() + 1, 0); }
  function samePeriod(a, b, cycle){ return a.getFullYear() === b.getFullYear() && (cycle === 'year' || a.getMonth() === b.getMonth()); }
  function budgetOf(cid, cycle, start){ return budgets.filter(function(b){ return b.cat === cid && b.cycle === cycle && samePeriod(b.start, start, cycle); })[0] || null; }
  function periodLabel(s, cycle){ return cycle === 'year' ? s.getFullYear() + ' 年' : s.getFullYear() + ' 年 ' + (s.getMonth() + 1) + ' 月'; }
  function renderBudgets(){
    var cy = state.budCycle, s = state.budStart, e = periodEnd(s, cy), cur = samePeriod(s, TODAY, cy);
    var dpM = $('[data-el="bud-month"]'), dpY = $('[data-el="bud-year"]');
    dpM.hidden = cy !== 'month'; dpY.hidden = cy !== 'year'; (cy === 'year' ? dpY : dpM).qdsSetValue(s); $('[data-el="bud-today"]').hidden = cur; $('[data-el="bud-today"]').textContent = cy === 'year' ? '回到今年' : '回到本月';
    var tb = 0, tu = 0, over = 0, warn = 0;
    $('[data-el="budget-rows"]').innerHTML = activeCats().map(function(c){
      var b = budgetOf(c.id, cy, s), u = sumAmt(expIn(s, e, c.id)), pct = b && b.amount ? u / b.amount * 100 : 0, ed = state.budEdit === c.id;
      if (b){ tb += b.amount; tu += u; if (pct > 100) over++; else if (pct >= 80) warn++; }
      // 點金額就地編輯：Enter 或離開輸入框儲存、Esc 取消（對應 PrimeVue InputNumber）
      var budCell = ed ? '<label class="search-sm amt-in budget-edit-input"><span>NT$</span><input data-el="bud-input" inputmode="numeric" value="' + (b ? b.amount : '') + '" aria-label="' + esc(c.name) + ' 預算金額"></label>'
        : '<button type="button" class="ie-trigger' + (b ? '' : ' empty') + '" data-action="bud-edit" data-id="' + c.id + '" aria-label="' + esc(c.name) + ' 預算：' + (b ? fmt(b.amount) : '未設定') + '，點擊修改">' + I_PEN + '<span>' + (b ? fmt(b.amount) : '未設定') + '</span></button>';
      var use = b ? '<div class="budget-cell"><div class="budget-bar' + (pct > 100 ? ' over' : pct >= 80 ? ' warn' : '') + '" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="' + Math.min(100, Math.round(pct)) + '" aria-label="' + esc(c.name) + ' 使用率"><span style="width:' + Math.min(100, pct) + '%"></span></div><span class="budget-pct">' + Math.round(pct) + '%</span></div>' : '<span class="cell-sub">—</span>';
      var left = b ? '<span' + (b.amount - u < 0 ? ' class="warn-text"' : '') + '>' + fmt(b.amount - u) + '</span>' : '—';
      return '<tr><td>' + esc(c.name) + '</td><td class="num">' + budCell + '</td><td class="num">' + fmt(u) + '</td><td class="budget-col">' + use + '</td><td class="num">' + left + '</td></tr>';
    }).join('');
    $('[data-el="budget-summary"]').innerHTML = '<div><span>總預算</span><b>' + fmt(tb) + '</b></div><div><span>已設預算類別的支出</span><b>' + fmt(tu) + '</b></div><div><span>整體使用率</span><b>' + (tb ? Math.round(tu / tb * 100) + '%' : '—') + '</b></div><div><span>超支/接近上限</span><b>' + over + ' / ' + warn + ' 個類別</b></div>';
    var inp = $('[data-el="bud-input"]'); if (inp){ inp.focus(); inp.select(); }
  }
  var I_PEN = '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 20h4L18.5 9.5a2.1 2.1 0 0 0-4-4L4 16v4z"/></svg>';
  function budShift(n){ var s = state.budStart; state.budStart = state.budCycle === 'year' ? new Date(s.getFullYear() + n, 0, 1) : new Date(s.getFullYear(), s.getMonth() + n, 1); state.budEdit = null; renderBudgets(); }
  function budSave(cid){
    var v = num($('[data-el="bud-input"]').value), cy = state.budCycle, b = budgetOf(cid, cy, state.budStart);
    if ((b ? b.amount : 0) === (v || 0)){ state.budEdit = null; renderBudgets(); return; }
    if (v != null && v < 0){ toast('預算不能是負數'); return; }
    if (!v){ budgets = budgets.filter(function(x){ return x !== b; }); toast('已清除「' + catName(cid) + '」的預算'); }
    else if (b){ b.amount = v; toast('已更新「' + catName(cid) + '」預算為 ' + fmt(v)); }
    else { budgets.push({ cat:cid, cycle:cy, amount:v, start:new Date(state.budStart) }); toast('已設定「' + catName(cid) + '」預算 ' + fmt(v)); }
    state.budEdit = null; render();
  }
  function openTemplates(){
    $('[data-el="template-list"]').innerHTML = '<div class="tpl-row tpl-head"><span>類別</span><span>月預算</span><span>年預算</span></div>' + activeCats().map(function(c){
      var m = templates.filter(function(t){ return t.cat === c.id && t.cycle === 'month'; })[0], y = templates.filter(function(t){ return t.cat === c.id && t.cycle === 'year'; })[0];
      // 月、年分開設定互不連動（例如員工旅遊只有年預算）
      var mv = m ? m.amount : '', yv = y ? y.amount : '';
      return '<div class="tpl-row"><span>' + esc(c.name) + '</span><label class="search-sm amt-in"><span>NT$</span><input inputmode="numeric" data-tpl="' + c.id + '" data-cycle="month" value="' + mv + '" placeholder="未設定" aria-label="' + esc(c.name) + ' 月預算"></label><label class="search-sm amt-in"><span>NT$</span><input inputmode="numeric" data-tpl="' + c.id + '" data-cycle="year" value="' + yv + '" placeholder="未設定" aria-label="' + esc(c.name) + ' 年預算"></label></div>';
    }).join('') + '<div class="tpl-row tpl-total"><span>合計</span><span data-bind="tpl-sum-month"></span><span data-bind="tpl-sum-year"></span></div>';
    tplSum();
    openOverlay('template');
  }
  // 基本預算合計列
  function tplSum(){
    var sm = 0, sy = 0; $$('[data-tpl]').forEach(function(i){ var v = num(i.value) || 0; if (i.dataset.cycle === 'month') sm += v; else sy += v; });
    bind('tpl-sum-month', fmt(sm)); bind('tpl-sum-year', fmt(sy));
  }
  function saveTemplates(){
    templates = []; $$('[data-tpl]').forEach(function(i){ var v = num(i.value); if (v) templates.push({ cat:i.dataset.tpl, cycle:i.dataset.cycle, amount:v }); });
    lastFocus = null; closeOverlay(); toast('已儲存基本預算（' + templates.length + ' 項）');
  }
  function applyTemplates(){
    var cy = state.budCycle, list = templates.filter(function(t){ return t.cycle === cy && cat(t.cat) && !cat(t.cat).archived; });
    if (!list.length){ toast('還沒有設定' + (cy === 'year' ? '年' : '月') + '的基本預算'); return; }
    list.forEach(function(t){ var b = budgetOf(t.cat, cy, state.budStart); if (b) b.amount = t.amount; else budgets.push({ cat:t.cat, cycle:cy, amount:t.amount, start:new Date(state.budStart) }); });
    render(); toast('已把基本預算套用到 ' + periodLabel(state.budStart, cy) + '（' + list.length + ' 個類別）');
  }

  // ---------- 人員管理 ----------
  var EMP_CAP = 10;
  function invActive(i){ return !i.revoked; }
  function invExpired(i){ return i.expiresAt < now(); }
  function renderUsers(){
    var q = state.q.users;
    var rows = users.filter(function(u){ return match(q, u.name, u.email); }).map(function(u){
      var self = u.id === ME.id;
      return '<tr><td>' + esc(u.name) + (self ? '<span class="cell-sub">（你）</span>' : '') + '</td><td>' + esc(u.email) + '</td><td><span class="tag-soft ' + (u.role === 'admin' ? 'tag-info' : 'tag-neutral') + '">' + (u.role === 'admin' ? '管理員' : '一般人員') + '</span></td><td>' + badge('paid', '已啟用') + '</td><td>' + ymd(u.createdAt) + '</td>' +
        '<td class="act"><span class="row-actions"><button type="button" class="btn btn-text btn-icon-only btn-sm" data-action="edit-user" data-id="' + u.id + '" aria-label="編輯 ' + esc(u.name) + '" title="編輯">' + I_EDIT + '</button>' +
        rowMenu(u.id, '<button type="button" role="menuitem" data-action="reset-pwd" data-id="' + u.id + '"' + (self ? ' disabled' : '') + '>重設密碼' + (self ? '<small>請到個人設定修改</small>' : '') + '</button>' + '<button type="button" role="menuitem" class="danger" data-action="del-user" data-id="' + u.id + '"' + (self ? ' disabled' : '') + '>刪除' + (self ? '<small>不能刪除自己</small>' : '') + '</button>') + '</span></td></tr>';
    }).concat(invites.filter(function(i){ return invActive(i) && match(q, i.name, i.email); }).map(function(i){
      var ex = invExpired(i);
      return '<tr class="row-muted"><td>' + esc(i.name) + '</td><td>' + esc(i.email) + '</td><td><span class="tag-soft tag-neutral">一般人員</span></td><td>' + (ex ? '<span class="tag-soft tag-danger">邀請已過期</span>' : '<span class="tag-soft tag-warn">邀請中</span><div class="cell-sub">' + ymdhm(i.expiresAt) + ' 到期</div>') + '</td><td>' + ymd(i.createdAt) + '</td>' +
        '<td class="act"><span class="row-actions">' + (ex ? '<button type="button" class="btn btn-secondary btn-sm" data-action="reinvite" data-id="' + i.id + '">重新邀請</button>' : '<button type="button" class="btn btn-text btn-icon-only btn-sm" data-action="copy-link" data-id="' + i.id + '" aria-label="複製 ' + esc(i.name) + ' 的邀請連結" title="複製連結">' + I_LINK + '</button>') +
        rowMenu(i.id, '<button type="button" role="menuitem" class="danger" data-action="revoke" data-id="' + i.id + '">撤回邀請</button>') + '</span></td></tr>';
    }));
    $('[data-el="user-rows"]').innerHTML = rows.join('') || emptyRow(6, !!q.trim(), '還沒有人員', 'data-action="clear-q" data-list="users"');
  }
  function openInvite(){ clearErrs($('[data-overlay="invite"]')); $('#inv-email').value = ''; $('#inv-name').value = ''; openOverlay('invite'); }
  function sendInvite(){
    var em = $('#inv-email').value.trim().toLowerCase(), nm = $('#inv-name').value.trim(), bad = null;
    clearErrs($('[data-overlay="invite"]'));
    var emp = users.filter(function(u){ return u.role === 'employee'; }).length + invites.filter(function(i){ return invActive(i) && !invExpired(i); }).length;
    if (!nm) bad = ferr('inv-name', '請填寫姓名');
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(em)) bad = ferr('inv-email', 'Email 格式不正確');
    else if (users.some(function(u){ return u.email.toLowerCase() === em; })) bad = ferr('inv-email', '這個 Email 已經是成員');
    else if (invites.some(function(i){ return invActive(i) && !invExpired(i) && i.email.toLowerCase() === em; })) bad = ferr('inv-email', '已經寄過邀請，尚未到期');
    else if (emp >= EMP_CAP) bad = ferr('inv-email', '一般人員已達 ' + EMP_CAP + ' 人上限（含邀請中）');
    if (bad){ $('input', bad).focus(); return; }
    invites.push({ id:'inv-' + Date.now(), email:em, name:nm, expiresAt:new Date(now().getTime() + 3 * 864e5), revoked:false, createdAt:now() });
    lastFocus = null; closeOverlay(); renderUsers(); toast('已寄出邀請給 ' + em + '，3 天內有效');
  }
  function openUserEdit(id){
    var u = users.filter(function(x){ return x.id === id; })[0]; state.userEdit = id; clearErrs($('[data-overlay="useredit"]'));
    $('#ue-name').value = u.name; $('#ue-email').value = u.email; $('[data-el="ue-role"]').qdsSetValue(u.role); openOverlay('useredit');
  }
  function saveUser(){
    var u = users.filter(function(x){ return x.id === state.userEdit; })[0], nm = $('#ue-name').value.trim(), role = $('[data-el="ue-role"]').qdsGetValue();
    clearErrs($('[data-overlay="useredit"]'));
    if (!nm){ ferr('ue-name', '請填寫姓名'); $('#ue-name').focus(); return; }
    if (u.role === 'admin' && role !== 'admin' && users.filter(function(x){ return x.role === 'admin'; }).length < 2){ ferr('ue-name', '至少要保留一位管理員'); return; }
    u.name = nm; u.role = role; reqs.forEach(function(r){ if (r.emp === u.id) r.name = nm; });
    if (u === ME) syncMe();
    lastFocus = null; closeOverlay(); render(); toast('已更新「' + nm + '」');
  }
  function syncMe(){ var av = $('[data-toggle="user"]'); av.textContent = ME.name.charAt(0); av.setAttribute('aria-label', '帳號選單：' + ME.name); bind('me-label', esc(ME.name) + SEP + (ME.role === 'admin' ? '管理員' : '一般人員'), true); }
  // ---------- 管理員重設他人密碼（不需舊密碼） ----------
  function openResetPwd(id){
    var u = users.filter(function(x){ return x.id === id; })[0]; state.resetPwd = id; clearErrs($('[data-overlay="resetpwd"]'));
    $('#rp-new').value = ''; $('#rp-new2').value = ''; bind('rp-who', '為 ' + u.name + '（' + u.email + '）設定新密碼，儲存後舊密碼立即失效。'); closePops(); openOverlay('resetpwd');
  }
  function genPwd(){
    var cs = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789', a = new Uint32Array(10), p = ''; crypto.getRandomValues(a);
    for (var i = 0; i < a.length; i++) p += cs[a[i] % cs.length];
    $('#rp-new').value = p; $('#rp-new2').value = p; clearErrs($('[data-overlay="resetpwd"]'));
  }
  function saveResetPwd(){
    var n = $('#rp-new').value, n2 = $('#rp-new2').value, bad = [], u = users.filter(function(x){ return x.id === state.resetPwd; })[0];
    clearErrs($('[data-overlay="resetpwd"]'));
    if (n2 !== n || !n2) bad.push(ferr('rp-new2', n2 ? '兩次輸入的密碼不同' : '請再次輸入新密碼'));
    if (n.length < 8) bad.push(ferr('rp-new', n ? '密碼長度至少 8 碼' : '請設定新密碼'));
    if (bad.length){ $('input', bad[bad.length - 1]).focus(); return; }
    lastFocus = null; closeOverlay(); toast('已重設「' + u.name + '」的密碼，請將新密碼告知對方');
  }

  // ---------- 個人設定/密碼 ----------
  function fillProfile(){ $('#pf-name').value = ME.name; $('#pf-email').value = ME.email; }
  function saveProfile(){ var nm = $('#pf-name').value.trim(); if (!nm){ $('#pf-name').classList.add('is-invalid'); $('#pf-name').focus(); toast('姓名不能空白'); return; } $('#pf-name').classList.remove('is-invalid'); ME.name = nm; syncMe(); toast('個人設定已儲存'); }
  function openPassword(){ clearErrs($('[data-overlay="password"]')); ['#pw-old', '#pw-new', '#pw-new2'].forEach(function(s){ $(s).value = ''; }); openOverlay('password'); }
  function savePassword(){
    var o = $('#pw-old').value, n = $('#pw-new').value, n2 = $('#pw-new2').value, bad = [];
    clearErrs($('[data-overlay="password"]'));
    if (n2 !== n || !n2) bad.push(ferr('pw-new2', n2 ? '兩次輸入的新密碼不一致' : '請再輸入一次新密碼'));
    if (n.length < 8 || !/[A-Za-z]/.test(n) || !/\d/.test(n)) bad.push(ferr('pw-new', '至少 8 碼，需包含英文與數字'));
    else if (n === o) bad.push(ferr('pw-new', '新密碼不能和目前密碼相同'));
    if (!o) bad.push(ferr('pw-old', '請輸入目前密碼'));
    if (bad.length){ $('input', bad[bad.length - 1]).focus(); return; }
    lastFocus = null; closeOverlay(); toast('密碼已更新');
  }

  // ---------- 導覽 ----------
  var VIEWS = { home:renderHome, expenses:renderExpenses, 'expense-form':function(){}, records:renderRecords, review:renderReview, payout:renderPayout, categories:renderCategories, budgets:renderBudgets, users:renderUsers, profile:fillProfile };
  var TITLES = { home:'儀表板', expenses:'支出管理', 'expense-form':'支出管理', records:'請款記錄', review:'簽核', payout:'發放', categories:'類別管理', budgets:'預算管理', users:'人員管理', profile:'個人設定' };
  function render(){ renderKpi(); renderNotifs(); VIEWS[state.view](); }
  function goto(v, fromHash){
    if (!VIEWS[v]) v = 'home';
    if (v === 'expense-form' && !state.form){ openForm(); return; }
    if (v !== 'budgets') state.budEdit = null;
    state.view = v; closePops();
    if (!fromHash && history.replaceState) history.replaceState(null, '', '#' + v);
    $$('.dash-view').forEach(function(el){ el.hidden = el.dataset.view !== v; });
    var nav = v === 'expense-form' ? 'expenses' : v;
    $$('.sn-item').forEach(function(a){ var on = a.dataset.view === nav; a.classList.toggle('active', on); if (on) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current'); });
    root.setAttribute('data-current', TITLES[v]);
    render();
    var r = root.getBoundingClientRect(); if (r.top < 0) root.scrollIntoView({ behavior:'smooth', block:'start' });
    var t = $('.dash-view[data-view="' + v + '"] .dash-page-title'); if (t){ t.tabIndex = -1; t.focus({ preventScroll:true }); }
  }
  function setNav(open){
    root.classList.toggle('nav-collapsed', !open);
    var b = $('[data-action="toggle-nav"]'); b.setAttribute('aria-expanded', open ? 'true' : 'false'); b.setAttribute('aria-label', open ? '收合側邊選單' : '展開側邊選單');
    $('#dash-nav').inert = !open;
  }
  function clearList(v){
    var f = state.f[v]; f.q = ''; f.cat = 'all'; f.range = null; if ('min' in f){ f.min = null; f.max = null; } if ('src' in f) f.src = 'all';
    var pre = v === 'expenses' ? 'exp' : v;
    var q = $('[data-q="' + v + '"]'); if (q) q.value = '';
    var c = $('[data-el="' + pre + '-cat"]'); if (c) c.qdsSetValue('all');
    var s = $('[data-el="exp-src"]'); if (v === 'expenses' && s) s.qdsSetValue('all');
    var rg = $('[data-el="' + pre + '-range"]'); if (rg) rg.qdsSetValue(null, null);
    $$('[data-amt^="' + v + '-"]').forEach(function(i){ i.value = ''; });
    resetPage({ expenses:'exp', records:'rec', review:'rev', payout:'pay' }[v]); VIEWS[state.view]();
  }
  // ---------- 全域搜尋：找請款單與支出 ----------
  var gs = $('[data-el="search"]'), gsPanel = $('.dash-gsearch-panel');
  function gsClose(){ gsPanel.hidden = true; gs.setAttribute('aria-expanded', 'false'); }
  function gsRender(){
    var q = gs.value.trim(); if (!q){ gsClose(); return; }
    var rs = reqs.filter(function(r){ return match(q, r.name, r.desc, r.vendor, catName(r.cat), r.invoiceNo); }).slice(0, 5);
    var es = exps.filter(function(x){ return match(q, x.vendor, x.note, catName(x.cat), x.invoiceNo); }).sort(function(a, b){ return b.date - a.date; }).slice(0, 5);
    var h = '';
    if (rs.length) h += '<div class="gs-group">請款單</div>' + rs.map(function(r){ return '<button type="button" role="option" class="gs-item" data-gs-req="' + r.id + '"><span class="gs-main">' + esc(r.name) + SEP + esc(r.desc) + '</span><span class="gs-sub">' + esc(catName(r.cat)) + SEP + fmt(r.amount) + '</span><span class="gs-right">' + rbadge(r.status) + '</span></button>'; }).join('');
    if (es.length) h += '<div class="gs-group">支出</div>' + es.map(function(x){ return '<button type="button" role="option" class="gs-item" data-gs-exp="' + x.id + '"><span class="gs-main">' + esc(x.vendor || catName(x.cat)) + '</span><span class="gs-sub">' + esc(catName(x.cat)) + SEP + ymd(x.date) + '</span><span class="gs-right">' + fmt(x.amount) + '</span></button>'; }).join('');
    gsPanel.innerHTML = h || '<div class="gs-empty">找不到「' + esc(q) + '」相關的請款單或支出</div>';
    gsPanel.hidden = false; gs.setAttribute('aria-expanded', 'true');
  }
  gs.addEventListener('input', gsRender);
  gs.addEventListener('focus', function(){ if (gs.value.trim()) gsRender(); });
  gs.addEventListener('keydown', function(e){ if (e.key === 'ArrowDown'){ var f = $('.gs-item', gsPanel); if (f && !gsPanel.hidden){ e.preventDefault(); f.focus(); } } else if (e.key === 'Escape'){ e.stopPropagation(); gsClose(); } });
  gsPanel.addEventListener('keydown', function(e){
    var items = $$('.gs-item', gsPanel), i = items.indexOf(document.activeElement);
    if (e.key === 'ArrowDown'){ e.preventDefault(); if (items[i + 1]) items[i + 1].focus(); }
    else if (e.key === 'ArrowUp'){ e.preventDefault(); if (i > 0) items[i - 1].focus(); else gs.focus(); }
    else if (e.key === 'Escape'){ e.stopPropagation(); gsClose(); gs.focus(); }
  });
  gsPanel.addEventListener('click', function(e){
    e.stopPropagation(); var b = e.target.closest('.gs-item'); if (!b) return; gsClose();
    if (b.dataset.gsReq) openDetail(b.dataset.gsReq, gs); else openExpDetail(b.dataset.gsExp, gs);
  });
  document.addEventListener('click', function(e){ if (!e.target.closest('.dash-gsearch')) gsClose(); if (!root.contains(e.target)) closePops(); });

  // ---------- 表單小工具 ----------
  function updItemsSum(){ var f = state.form, isum = f.items.reduce(function(a, x){ return a + (x.subtotal || 0); }, 0), amt = num($('#f-amount').value); bind('items-sum', f.items.length ? '品項小計合計 ' + fmt(isum) + (amt != null && Math.round(amt) !== Math.round(isum) ? '<span class="warn-text">・與總金額相差 ' + fmt(amt - isum) + '</span>' : '') : '', true); }
  function addFiles(list){ if (!state.form) return; [].slice.call(list).forEach(function(f){ state.form.files.push(f.name || f); }); renderFormBits(); toast('已加入 ' + list.length + ' 個附件'); }
  function runOcr(){
    var b = $('[data-action="ocr"]'), lab = $('[data-el="ocr-label"]'); b.disabled = true; lab.textContent = '辨識中…'; b.setAttribute('aria-busy', 'true');
    setTimeout(function(){
      $$('input[name="f-doc"]').forEach(function(r){ r.checked = r.value === 'invoice'; });
      $('[data-el="f-date"]').qdsSetValue(new Date(2026, 8, 20)); $('[data-el="f-cat"]').qdsSetValue('office'); $('[data-el="f-taxrate"]').qdsSetValue('business_5');
      $('#f-vendor').value = '全家便利商店'; $('#f-taxid').value = '22555003'; $('#f-inv1').value = 'QK'; $('#f-inv2').value = '48210376'; $('#f-amount').value = 1260;
      state.form.items = [{ name:'A4 影印紙', quantity:2, unitPrice:380, subtotal:760 }, { name:'原子筆（盒）', quantity:2, unitPrice:250, subtotal:500 }];
      taxCalc('amount'); clearErrs($('.dash-view[data-view="expense-form"]')); b.removeAttribute('aria-busy'); lab.textContent = '重新辨識';
      toast('已從發票辨識出 7 個欄位與 2 筆品項，請確認');
    }, 900);
  }

  // ---------- 事件：點擊 ----------
  var TABS = { expTab:['exp', 'exp'], recTab:['rec', 'rec'], revTab:['rev', 'rev'], payTab:['pay', 'pay'], catTab:['cat', null] };
  function keysOf(o){ return Object.keys(o).filter(function(k){ return o[k]; }); }
  root.addEventListener('click', function(e){
    var k = e.target.closest('.stat-card');
    if (k){ goto(k.dataset.target.slice(5)); return; }
    if (e.target.closest('.qds-select, .qds-datepicker, .qds-paginator, .dash-check, .toggle, input, textarea, label.upload-drop, .seg-radio, .choice-cards')) return;
    var t = e.target.closest('[data-toggle],[data-action],[data-open],[data-exp],[data-sort],[data-exp-tab],[data-rec-tab],[data-rev-tab],[data-pay-tab],[data-cat-tab],.sn-item,.dash-overlay');
    if (!t){ closePops(); return; }
    if (t.classList.contains('dash-overlay')){ if (e.target === t) closeOverlay(); return; }
    if (t.classList.contains('sn-item')){ e.preventDefault(); goto(t.dataset.view); return; }
    if (t.dataset.toggle){ var pop = t.closest('.dash-pop'), open = !pop.classList.contains('open'); closePops(); pop.classList.toggle('open', open); t.setAttribute('aria-expanded', open); if (open){ var fi = $('.dash-menu button:not([disabled])', pop); if (fi && e.detail === 0) fi.focus(); } return; }
    for (var tk in TABS){ var ak = 'data-' + tk.replace('Tab', '-tab'); if (t.hasAttribute(ak)){ state[tk] = t.getAttribute(ak); if (TABS[tk][1]) resetPage(TABS[tk][1]); if (tk === 'revTab') state.sel.review = {}; if (tk === 'payTab') state.sel.payout = {}; VIEWS[state.view](); var nb = $('[' + ak + '="' + state[tk] + '"]'); if (nb) nb.focus(); return; } }
    if (t.dataset.sort){ var sp = t.dataset.sort.split(':'), s = state.sort[sp[0]]; state.sort[sp[0]] = s && s.key === sp[1] ? { key:sp[1], dir:-s.dir } : { key:sp[1], dir:-1 }; VIEWS[state.view](); var sb = $('[data-sort="' + t.dataset.sort + '"]'); if (sb) sb.focus(); return; }
    if (t.dataset.notif) state.notifRead[t.dataset.notif] = true;
    if (t.dataset.open && !t.dataset.action){ closePops(); openDetail(t.dataset.open, t); if (t.dataset.notif) renderNotifs(); return; }
    if (t.dataset.exp && !t.dataset.action){ openExpDetail(t.dataset.exp, t); return; }
    var a = t.dataset.action, id = t.dataset.id; if (!a) return; e.preventDefault();
    if (t.disabled) return;
    if (t.closest('.dash-menu')) closePops();
    switch (a){
      case 'toggle-nav': setNav(root.classList.contains('nav-collapsed')); break;
      case 'goto': goto(t.dataset.view); if (t.dataset.notif) renderNotifs(); break;
      case 'toast': toast(t.dataset.msg); break;
      case 'tour': toast('新手導覽：依序介紹儀表板、支出管理、簽核與發放（示意）'); break;
      case 'read-all': $$('.notif-item').forEach(function(x){ state.notifRead[x.dataset.notif] = true; }); renderNotifs(); toast('通知已全部標為已讀'); break;
      case 'close': closeOverlay(); break;
      case 'new-expense': openForm(); break;
      case 'edit-exp': lastFocus = null; closeOverlay(); openForm(id); break;
      case 'save-expense': saveForm(); break;
      case 'exp-paid': var ep = exp(id); ep.payout = 'paid'; render(); toast('已把「' + (ep.vendor || catName(ep.cat)) + '」標記為已付款'); if ($('[data-overlay="expdetail"].open')) openExpDetail(id); break;
      case 'del-exp': var ed = exp(id); askConfirm('del-exp', id, '刪除支出', '確定要刪除「' + esc(ed.vendor || catName(ed.cat)) + '」' + fmt(ed.amount) + '？刪除後無法復原。'); break;
      case 'view-exp': openExpDetail(id, t); break;
      case 'open-req': openDetail(id); break;
      case 'exp-clear': clearList('expenses'); break;
      case 'clear-filter': clearList(t.dataset.list); break;
      case 'clear-q': state.q[t.dataset.list] = ''; $('[data-q="' + t.dataset.list + '"]').value = ''; VIEWS[state.view](); break;
      case 'clear-sel': state.sel[t.dataset.list] = {}; VIEWS[state.view](); break;
      case 'approve': openApprove([id]); break;
      case 'create-exp': openApprove([id], true); break;
      case 'reject': openReject([id]); break;
      case 'batch-approve': openApprove(keysOf(state.sel.review)); break;
      case 'batch-reject': openReject(keysOf(state.sel.review)); break;
      case 'batch-pay': openPay('pay', keysOf(state.sel.payout)); break;
      case 'batch-void': openPay('void', keysOf(state.sel.payout)); break;
      case 'pay': case 'void': case 'revert-pay': case 'revert-void': openPay(a, [id]); break;
      case 'confirm-approve': confirmApprove(); break;
      case 'confirm-reject': confirmReject(); break;
      case 'confirm-payaction': confirmPay(); break;
      case 'confirm-ok': doConfirm(); break;
      case 'open-import': openImport(); break;
      case 'import-reset': $('[data-el="import-file"]').value = ''; $('[data-el="import-preview"]').hidden = true; $('[data-el="import-drop"]').hidden = false; $('[data-el="import-confirm"]').disabled = true; $('[data-el="import-drop"]').focus(); break;
      case 'confirm-import': doImport(); break;
      case 'open-cat': openCat(); break;
      case 'edit-cat': openCat(id); break;
      case 'save-cat': saveCat(); break;
      case 'archive': setArchived(id, true); break;
      case 'unarchive': setArchived(id, false); break;
      case 'del-cat': askConfirm('del-cat', id, '刪除類別', '確定要刪除「' + esc(catName(id)) + '」？這個類別的預算設定也會一併移除。'); break;
      case 'open-template': openTemplates(); break;
      case 'save-template': saveTemplates(); break;
      case 'apply-template': applyTemplates(); break;
      case 'bud-prev': budShift(-1); break;
      case 'bud-next': budShift(1); break;
      case 'bud-today': state.budStart = state.budCycle === 'year' ? new Date(TODAY.getFullYear(), 0, 1) : new Date(TODAY.getFullYear(), TODAY.getMonth(), 1); state.budEdit = null; renderBudgets(); $('[data-el="bud-prev"]').focus(); break;
      case 'bud-edit': state.budEdit = id; renderBudgets(); break;
      case 'bud-cancel': state.budEdit = null; renderBudgets(); break;
      case 'bud-save': budSave(id); break;
      case 'open-invite': openInvite(); break;
      case 'send-invite': sendInvite(); break;
      case 'edit-user': openUserEdit(id); break;
      case 'save-user': saveUser(); break;
      case 'del-user': var du = users.filter(function(x){ return x.id === id; })[0]; askConfirm('del-user', id, '刪除人員', '確定要刪除「' + esc(du.name) + '」？對方將無法登入，已送出的請款紀錄會保留。'); break;
      case 'revoke': var rv = invites.filter(function(x){ return x.id === id; })[0]; askConfirm('revoke', id, '撤回邀請', '撤回後，寄給 ' + esc(rv.email) + ' 的邀請連結會立即失效。', '撤回'); break;
      case 'reinvite': var ri = invites.filter(function(x){ return x.id === id; })[0]; ri.expiresAt = new Date(now().getTime() + 3 * 864e5); ri.createdAt = now(); renderUsers(); toast('已重新寄出邀請給 ' + ri.email + '，3 天內有效'); break;
      case 'copy-link': try { navigator.clipboard.writeText('https://quickey.example/invite/' + id); } catch (err) {} toast('已複製邀請連結'); break;
      case 'save-profile': saveProfile(); break;
      case 'open-password': openPassword(); break;
      case 'save-password': savePassword(); break;
      case 'reset-pwd': openResetPwd(id); break;
      case 'gen-pwd': genPwd(); break;
      case 'save-resetpwd': saveResetPwd(); break;
      case 'ocr': runOcr(); break;
      case 'add-item': state.form.items.push({ name:'', quantity:1, unitPrice:0, subtotal:0 }); renderFormBits(); var ni = $$('[data-k="name"]'); if (ni.length) ni[ni.length - 1].focus(); break;
      case 'rm-item': state.form.items.splice(+t.dataset.i, 1); renderFormBits(); break;
      case 'rm-file': state.form.files.splice(+t.dataset.i, 1); renderFormBits(); break;
    }
  });

  // ---------- 事件：輸入與元件變更 ----------
  var PGK = { expenses:'exp', records:'rec', review:'rev', payout:'pay' };
  function clearFieldErr(el){ var fd = el.closest('.field'); if (!fd) return; var er = $('[data-err]', fd); if (er && !er.hidden){ er.hidden = true; $$('.is-invalid', fd).forEach(function(x){ x.classList.remove('is-invalid'); }); } }
  root.addEventListener('input', function(e){
    if (e.target.dataset && e.target.dataset.tpl){ tplSum(); return; }
    var t = e.target, v;
    if ((v = t.dataset.q)){ if (state.f[v]) state.f[v].q = t.value; else state.q[v] = t.value; if (PGK[v]) resetPage(PGK[v]); VIEWS[state.view](); return; }
    if ((v = t.dataset.amt)){ var p = v.split('-'); state.f[p[0]][p[1]] = num(t.value); resetPage(PGK[p[0]]); VIEWS[state.view](); return; }
    if (t.dataset.item != null){ var it = state.form.items[+t.dataset.item], kk = t.dataset.k; it[kk] = kk === 'name' ? t.value : (num(t.value) || 0); it.subtotal = Math.round(it.quantity * it.unitPrice); t.closest('tr').children[3].textContent = fmt(it.subtotal); updItemsSum(); return; }
    clearFieldErr(t);
    if (t.id === 'f-amount') taxCalc('amount'); else if (t.id === 'f-pretax') taxCalc('pretax'); else if (t.id === 'f-tax') taxCalc('tax');
    if (t.id === 'f-inv1') t.value = t.value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 2);
    if (t.id === 'f-inv2' || t.id === 'f-taxid') t.value = t.value.replace(/\D/g, '').slice(0, 8);
  });
  root.addEventListener('change', function(e){
    var t = e.target;
    if (t.dataset.sel){ if (t.checked) state.sel[t.dataset.sel][t.value] = true; else delete state.sel[t.dataset.sel][t.value]; VIEWS[state.view](); var c = $('[data-sel="' + t.dataset.sel + '"][value="' + t.value + '"]'); if (c) c.focus(); return; }
    if (t.dataset.checkAll){ var v = t.dataset.checkAll; $$('[data-sel="' + v + '"]').forEach(function(x){ if (t.checked) state.sel[v][x.value] = true; else delete state.sel[v][x.value]; }); VIEWS[state.view](); $('[data-check-all="' + v + '"]').focus(); return; }
    if (t.name === 'f-doc') renderFormBits();
    if (t.dataset.el === 'form-file' && t.files.length){ addFiles(t.files); t.value = ''; }
    if (t.dataset.el === 'import-file' && t.files.length) importChosen(t.files[0].name);
    if (t.id === 'ap-create') $('[data-el="ap-expense"]').hidden = !t.checked;
  });
  root.addEventListener('focusout', function(e){
    // 離開預算輸入框即儲存；Enter/Esc 已結束編輯（budEdit=null）時略過
    if (!(e.target.dataset && e.target.dataset.el === 'bud-input' && state.budEdit && e.target.isConnected)) return;
    var nxt = e.relatedTarget && e.relatedTarget.closest && e.relatedTarget.closest('[data-action="bud-edit"]');
    budSave(state.budEdit);
    if (nxt){ state.budEdit = nxt.dataset.id; renderBudgets(); }
  });
  root.addEventListener('qds-change', function(e){
    var el = e.target.dataset.el, d = e.detail || {}; if (!el) return;
    var rg = d.start ? { start:d.start, end:d.end } : null;
    if (el === 'trend-period' || el === 'cat-period'){ var kd = el.split('-')[0]; state[kd + 'Preset'] = d.value; state[kd + 'Range'] = d.value === 'custom' ? rg : null; if (kd === 'trend') renderTrend(); else renderCat(); return; }
    if (el === 'exp-cat'){ state.f.expenses.cat = d.value; resetPage('exp'); renderExpenses(); return; }
    if (el === 'exp-src'){ state.f.expenses.src = d.value; resetPage('exp'); renderExpenses(); return; }
    if (el === 'exp-range'){ state.f.expenses.range = rg; resetPage('exp'); renderExpenses(); return; }
    var m = /^(records|review|payout)-(cat|range)$/.exec(el);
    if (m){ state.f[m[1]][m[2]] = m[2] === 'cat' ? d.value : rg; resetPage(PGK[m[1]]); VIEWS[state.view](); return; }
    var pk = /^(exp|rec|rev|pay)-pg$/.exec(el);
    if (pk){ state.pg[pk[1]] = { first:d.first, rows:d.rows }; VIEWS[state.view](); return; }
    if (el === 'cat-subject'){ catSubjectHelp(); return; }
    if (el === 'bud-month' || el === 'bud-year'){ if (!d.date) return; state.budStart = el === 'bud-year' ? new Date(d.date.getFullYear(), 0, 1) : new Date(d.date.getFullYear(), d.date.getMonth(), 1); state.budEdit = null; renderBudgets(); return; }
    if (el === 'bud-cycle'){ state.budCycle = d.value; state.budStart = d.value === 'year' ? new Date(TODAY.getFullYear(), 0, 1) : new Date(TODAY.getFullYear(), TODAY.getMonth(), 1); state.budEdit = null; renderBudgets(); return; }
    if (el === 'f-taxrate'){ taxCalc('rate'); return; }
    clearFieldErr(e.target);
  });
  // ---------- 事件：鍵盤 ----------
  root.addEventListener('keydown', function(e){
    var t = e.target;
    if (t.dataset.el === 'bud-input'){ if (e.key === 'Enter'){ e.preventDefault(); budSave(state.budEdit); return; } if (e.key === 'Escape'){ e.preventDefault(); state.budEdit = null; renderBudgets(); return; } }
    if (e.key === 'Escape'){ if ($('.dash-overlay.open')) closeOverlay(); else { var p = $('.dash-pop.open'); if (p){ closePops(); $('[data-toggle]', p).focus(); } } return; }
    if ((e.key === 'Enter' || e.key === ' ') && t.matches('.stat-card, tr[data-open], tr[data-exp], .cat-legend li')){ e.preventDefault(); t.click(); return; }
    if (e.key === 'Enter' && t.matches('.dash-overlay .db input:not([type="checkbox"]):not([type="radio"])')){ var pb = $('.df .btn-primary, .df .btn-danger', t.closest('.dash-overlay')); if (pb && !pb.disabled){ e.preventDefault(); pb.click(); } return; }
    if (e.key === 'Tab'){ var o = $('.dash-overlay.open'); if (o){ var f = $$('button, input, textarea, [tabindex="0"]', o).filter(function(x){ return !x.disabled && x.offsetParent; }); if (!f.length) return; var first = f[0], last = f[f.length - 1]; if (e.shiftKey && document.activeElement === first){ e.preventDefault(); last.focus(); } else if (!e.shiftKey && document.activeElement === last){ e.preventDefault(); first.focus(); } } }
    if (t.closest('.dash-menu') && (e.key === 'ArrowDown' || e.key === 'ArrowUp')){ var its = $$('button:not([disabled])', t.closest('.dash-menu')), i = its.indexOf(t); e.preventDefault(); var nx = its[(i + (e.key === 'ArrowDown' ? 1 : -1) + its.length) % its.length]; if (nx) nx.focus(); }
  });
  // ---------- 圖表互動 ----------
  var chart = $('[data-el="trend-chart"]');
  function tip(e){ var b = e.target.closest('.chart-bar'), plot = $('.chart-plot', chart), tp = plot && $('.dash-tip', plot); if (!tp) return; if (!b){ tp.hidden = true; return; } var c = plot.getBoundingClientRect(), r = b.getBoundingClientRect(), x = b.dataset.tip.split('|'); tp.innerHTML = '<b>' + x[0] + '</b><span>' + x[1] + '</span><span>' + x[2] + '</span>'; tp.style.left = (r.left - c.left + r.width / 2) + 'px'; tp.style.top = (r.top - c.top) + 'px'; tp.hidden = false; }
  function hideTip(){ var tp = $('.dash-tip', chart); if (tp) tp.hidden = true; }
  chart.addEventListener('mouseover', tip); chart.addEventListener('focusin', tip); chart.addEventListener('mouseleave', hideTip); chart.addEventListener('focusout', hideTip);
  var catBox = $('#dp-category');
  catBox.addEventListener('mouseover', function(e){ var x = e.target.closest('[data-cid]'); setHover(x ? x.dataset.cid : null); });
  catBox.addEventListener('mouseleave', function(){ setHover(null); });
  catBox.addEventListener('focusin', function(e){ var x = e.target.closest('[data-cid]'); if (x) setHover(x.dataset.cid); });
  catBox.addEventListener('focusout', function(){ setHover(null); });
  // ---------- 拖放上傳 ----------
  $$('.upload-drop').forEach(function(d){
    d.addEventListener('dragover', function(e){ e.preventDefault(); d.classList.add('is-drag'); });
    d.addEventListener('dragleave', function(){ d.classList.remove('is-drag'); });
    d.addEventListener('drop', function(e){ e.preventDefault(); d.classList.remove('is-drag'); var fs = e.dataTransfer && e.dataTransfer.files; if (!fs || !fs.length) return; if (d.dataset.el === 'import-drop') importChosen(fs[0].name); else addFiles(fs); });
    d.addEventListener('keydown', function(e){ if (e.key === 'Enter' || e.key === ' '){ e.preventDefault(); $('input[type="file"]', d).click(); } });
    d.tabIndex = 0; d.setAttribute('role', 'button');
  });
  // ---------- 初始化 ----------
  syncCatSelects(); syncMe();
  if (root.getBoundingClientRect().width < 960){ root.classList.add('nav-instant'); setNav(false); requestAnimationFrame(function(){ requestAnimationFrame(function(){ root.classList.remove('nav-instant'); }); }); }
  var h0 = location.hash.slice(1);
  if (VIEWS[h0] && h0 !== 'home') goto(h0, true); else render();
  window.addEventListener('hashchange', function(){ var h = location.hash.slice(1); if (VIEWS[h] && h !== state.view) goto(h, true); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
