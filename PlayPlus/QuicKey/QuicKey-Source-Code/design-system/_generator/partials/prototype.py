# 後台原型的畫面結構（由 build_pages.py exec 載入，可用 qds_select / qds_datepicker），產生 PROTOTYPE_HTML。
# 互動與資料在 dashboard.js；資料來源是前端 mock（build 時注入 window.QDS_PROTO_DATA）。
def I(d, sw="1.8", size=16):
    return '<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%s</svg>' % (size, size, sw, d)
IC = {
    "home": '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    "expenses": '<path d="M7 3h8l4 4v14H7z"/><path d="M15 3v4h4"/>',
    "records": '<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3.5 6h.01M3.5 12h.01M3.5 18h.01"/>',
    "review": '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M8 12l3 3 5-6"/>',
    "payout": '<path d="M22 2L11 13"/><path d="M22 2l-7 20-4-9-9-4z"/>',
    "categories": '<path d="M20.6 12.6L12 21.2 2.8 12V3.4h8.6z"/><circle cx="7.6" cy="8.2" r="1.2"/>',
    "budgets": '<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
    "users": '<circle cx="9" cy="8" r="3"/><path d="M3 20c1-3.5 3.5-5 6-5s5 1.5 6 5"/><path d="M16 5.5a3 3 0 010 5.5M18 15c1.6.6 2.6 2.1 3 5"/>',
    "search": '<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>',
    "bell": '<path d="M6 8a6 6 0 0112 0c0 5 2 6 2 6H4s2-1 2-6"/><path d="M10 21a2 2 0 004 0"/>',
    "menu": '<path d="M3 6h18M3 12h18M3 18h18"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "upload": '<path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 16v3a2 2 0 002 2h12a2 2 0 002-2v-3"/>',
    "back": '<path d="M15 18l-6-6 6-6"/>',
    "wallet": '<rect x="3" y="6" width="18" height="14" rx="2"/><path d="M3 10h18M16 15h2"/>',
    "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    "chart": '<path d="M3 3v18h18"/><path d="M7 15l4-6 4 3 4-8"/>',
    "check": '<path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="9"/>',
    "scan": '<path d="M4 8V5a1 1 0 011-1h3M16 4h3a1 1 0 011 1v3M20 16v3a1 1 0 01-1 1h-3M8 20H5a1 1 0 01-1-1v-3M7 12h10"/>',
}

# 會計科目：商業會計項目表 6111–6134（與前端 constants/accountSubjects.ts 同步）
ACCOUNT_SUBJECTS = [("6111", "薪資支出"), ("6112", "租金支出"), ("6113", "文具用品"), ("6114", "旅費"), ("6115", "運費"), ("6116", "郵電費"), ("6117", "修繕費"), ("6118", "廣告費"),
                    ("6119", "水電瓦斯費"), ("6120", "保險費"), ("6121", "交際費"), ("6122", "捐贈"), ("6123", "稅捐"), ("6124", "呆帳損失"), ("6125", "折舊"), ("6126", "各項耗竭及攤提"),
                    ("6127", "外銷損失"), ("6128", "伙食費"), ("6129", "職工福利"), ("6130", "研究發展費用"), ("6131", "佣金支出"), ("6132", "訓練費"), ("6133", "勞務費"), ("6134", "其他營業費用")]

def bud_dp(view, value, label, hidden=False):
    """預算期間：PrimeVue DatePicker view=month|year，直接選月份/年份。"""
    return qds_datepicker("single", value=value, placeholder=label, extra_cls="period-dp").replace(
        'data-mode="single"', 'data-mode="single" data-view="%s" data-format="zh" data-el="bud-%s"%s' % (view, view, " hidden" if hidden else "")
    ).replace('class="qds-select-trigger qds-dp-trigger"', 'class="qds-select-trigger qds-dp-trigger" aria-label="%s"' % label)

def navlink(v, label, extra="", active=False):
    return '          <a class="sn-item%s" href="#%s" data-view="%s">%s%s%s</a>\n' % (' active" aria-current="page' if active else '', v, v, I(IC[v], size=18), label, extra)
NAV = ('        <nav class="side-nav-demo" id="dash-nav" aria-label="主選單">\n          <div class="sn-inner">\n          <div class="sn-brand"><span class="sn-logo">Q</span>Quickey</div>\n'
    '          <div class="sn-group">主選單</div>\n' + navlink("home", "儀表板", active=True) + navlink("expenses", "支出管理") +
    '          <div class="sn-group">請款</div>\n' + navlink("records", "請款記錄") + navlink("review", "簽核", '<span class="sn-badge" data-bind="review-count"></span>') +
    '          <div class="sn-group">系統</div>\n' + navlink("categories", "類別管理") + navlink("budgets", "預算管理") + navlink("users", "人員管理") +
    '          </div>\n        </nav>\n')
TOPBAR = ('          <div class="topbar-demo">\n'
    '            <button type="button" class="nav-toggle" aria-label="收合側邊選單" aria-expanded="true" aria-controls="dash-nav" data-action="toggle-nav">' + I(IC["menu"], size=18) + '</button>\n'
    '            <div class="tb-search dash-gsearch">' + I(IC["search"]) + '<input type="search" placeholder="搜尋請款、支出、廠商" aria-label="全域搜尋" data-el="search" autocomplete="off" role="combobox" aria-expanded="false" aria-controls="dash-gsearch-list"><div class="dash-gsearch-panel" id="dash-gsearch-list" role="listbox" hidden></div></div>\n'
    '            <div class="tb-actions">\n'
    '              <div class="dash-pop" data-pop="notif"><button type="button" class="btn btn-secondary btn-icon-only" aria-label="通知" aria-haspopup="true" aria-expanded="false" data-toggle="notif">' + I(IC["bell"]) + '<span class="dash-dot" data-el="notif-dot"></span></button>\n'
    '                <div class="dash-menu dash-menu-wide" role="menu"><div class="dash-menu-head"><span>通知</span><button type="button" class="dash-link-btn" data-action="read-all">全部標為已讀</button></div><div data-el="notif-list"></div></div></div>\n'
    '              <div class="dash-pop" data-pop="user"><button type="button" class="avatar" aria-label="帳號選單" aria-haspopup="true" aria-expanded="false" data-toggle="user" data-bind="avatar">系</button>\n'
    '                <div class="dash-menu" role="menu"><div class="dash-menu-head"><span data-bind="me-label">系統管理員<span class="sep" aria-hidden="true"></span>管理員</span></div>'
    '<button type="button" role="menuitem" data-action="goto" data-view="profile">個人設定</button>'
    '<button type="button" role="menuitem" data-action="tour">新手導覽</button>'
    '<button type="button" role="menuitem" data-action="open-password">修改密碼</button>'
    '<button type="button" role="menuitem" data-action="toast" data-msg="已切換到員工前台（示意）">切換到員工前台</button>'
    '<button type="button" role="menuitem" data-action="toast" data-msg="已登出（示意）">登出</button></div></div>\n'
    '            </div>\n          </div>\n')
def head(title, actions=""):
    """頁首：標題＋右側動作，不放副標題（與前端一致）。"""
    return ('              <div class="dash-page-head"><div><div class="dash-page-title">%s</div></div><div class="dash-page-actions">%s</div></div>\n' % (title, actions))
def view(v, inner, hidden=True):
    return '            <div class="dash-view" data-view="%s"%s>\n%s            </div>\n' % (v, ' hidden' if hidden else '', inner)
def search(v, ph):
    return '<label class="search-sm">' + I(IC["search"]) + '<input type="search" data-q="%s" placeholder="%s" aria-label="%s"></label>' % (v, ph, ph)
def tabs(el):
    return '                <div class="tabbar" role="tablist" data-el="%s"></div>\n' % el
def amount_range(v):
    return ('<div class="amt-range" role="group" aria-label="金額區間"><label class="search-sm amt-in"><span>NT$</span><input inputmode="numeric" data-amt="%s-min" placeholder="金額下限" aria-label="金額下限"></label>'
            '<span class="amt-sep">–</span><label class="search-sm amt-in"><span>NT$</span><input inputmode="numeric" data-amt="%s-max" placeholder="金額上限" aria-label="金額上限"></label></div>') % (v, v)
def selbar(v, actions):
    return ('                <div class="selection-bar" data-selbar="%s" role="region" aria-label="批次操作" hidden><span class="sel-count" data-bind="%s-selcount"></span>'
            '<button type="button" class="btn btn-text btn-sm sel-clear" data-action="clear-sel" data-list="%s">取消選取</button><span class="sel-actions">%s</span></div>\n') % (v, v, v, actions)
def pg(key, label):
    return '                <div class="qds-paginator dash-pg" data-qds-paginator data-el="%s-pg" data-total="0" data-rows="10" data-rows-options="10,20,50" aria-label="%s"></div>\n' % (key, label)
def table(el, heads, chk=None):
    th = ('<th class="chk"><input type="checkbox" class="dash-check" data-check-all="%s" aria-label="全選本頁"></th>' % chk) if chk else ''
    for h in heads:
        cls, txt = (h if isinstance(h, tuple) else ("", h))
        th += '<th%s>%s</th>' % (' class="%s"' % cls if cls else '', txt)
    return '                <div class="dash-table-wrap"><table class="dash-table"><thead><tr data-el="%s-head">%s</tr></thead><tbody data-el="%s"></tbody></table></div>\n' % (el, th, el)

def mrange(el, label):
    return qds_datepicker("range", size="sm", placeholder="自訂月份區間", extra_cls="qds-align-right").replace('data-mode="range"', 'data-mode="range" data-view="month" data-el="%s"' % el).replace('<button type="button" class="qds-select-trigger qds-dp-trigger"', '<button type="button" class="qds-select-trigger qds-dp-trigger" aria-label="%s"' % label)
PRESETS = [("today", "本日"), ("week", "本週"), ("month", "本月"), ("3m", "近三個月"), ("6m", "近六個月"), ("1y", "近一年")]
def period(el, val, label):
    return qds_period(PRESETS, val, label=label, el=el)
def preset_sel(el, val, label):
    return qds_select(PRESETS + [("custom", "自訂月份區間")], val, size="sm", extra_cls="qds-align-right").replace("data-qds-select", 'data-qds-select data-el="%s"' % el).replace('aria-haspopup="listbox"', 'aria-haspopup="listbox" aria-label="%s"' % label)
def stat(key, cls, icon, label, desc, target):
    return ('              <div class="stat-card %s" role="button" tabindex="0" data-target="%s" aria-label="%s，前往查看">\n'
            '                <div class="stat-top"><span class="stat-icon" aria-hidden="true">%s</span></div>\n'
            '                <div class="stat-label">%s</div><div class="stat-value" data-bind="kpi-%s">—</div>\n'
            '                <div class="stat-desc"><span>%s</span><span data-bind="kpi-%s-count"></span></div>\n'
            '                <div class="stat-wave" aria-hidden="true"></div>\n              </div>\n') % (cls, target, label, I(IC[icon], "2"), label, key, desc, key)
HOME = view("home", head("儀表板", '<button type="button" class="btn btn-primary" data-action="new-expense">' + I(IC["plus"]) + '新增支出</button>') +
    '              <div class="kpi-grid">\n' +
    stat("spend", "stat-primary", "wallet", "本月支出", "依費用發生日期", "view:expenses") +
    stat("review", "stat-warning", "check", "待簽核", "等待管理員簽核", "view:review") +
    stat("budget", "stat-info", "chart", "預算使用率", "本月月預算", "view:budgets") +
    stat("nextpay", "stat-danger", "clock", "下次預計付款", "待付款支出合計", "view:expenses") +
    '              </div>\n'
    '              <div class="dash-row">\n'
    '                <div class="dash-panel" role="region" aria-label="支出趨勢" id="dp-trend">\n'
    '                  <div class="dash-panel-head dash-panel-head-2"><div><span class="dash-panel-title">支出趨勢</span></div><div class="dash-panel-tools"><div class="dash-chart-total">區間合計<b data-bind="trend-total">—</b></div>' + period("trend-period", "month", "支出趨勢期間") + '</div></div>\n'
    '                  <div class="dash-chart" data-el="trend-chart"></div>\n'
    '                </div>\n'
    '                <div class="dash-panel" role="region" aria-label="費用類別分佈" id="dp-category">\n'
    '                  <div class="dash-panel-head dash-panel-head-2"><div><span class="dash-panel-title">費用類別分佈</span></div><div class="dash-panel-tools">' + period("cat-period", "month", "類別分佈期間") + '</div></div>\n'
    '                  <div data-el="cat-body"><div class="donut-wrap"><svg class="donut" viewBox="0 0 42 42" data-el="donut" role="img" aria-label="費用類別分佈圓環圖"></svg><div class="donut-center"><span>合計</span><b data-bind="cat-total">—</b></div></div><ul class="cat-legend" data-el="cat-legend"></ul></div>\n'
    '                  <div class="dash-empty dash-empty-lg" data-el="cat-empty" hidden>此區間內尚無支出資料</div>\n'
    '                </div>\n              </div>\n'
    '              <div class="dash-row">\n'
    '                <div class="dash-panel" role="region" aria-label="最近請款" id="dp-requests">\n'
    '                  <div class="dash-panel-head"><span class="dash-panel-title">最近請款</span><a class="dash-panel-link" href="#records" data-action="goto" data-view="records">查看全部</a></div>\n'
    + table("home-requests", ["申請人", "類別", ("num", "金額"), "狀態"]).replace("                <div", "                  <div") +
    '                </div>\n'
    '                <div class="dash-panel" role="region" aria-label="待簽核" id="dp-pending">\n'
    '                  <div class="dash-panel-head"><span class="dash-panel-title">待簽核<span class="tab-count" data-bind="review-count-2"></span></span><a class="dash-panel-link" href="#review" data-action="goto" data-view="review">查看全部</a></div>\n'
    '                  <div class="action-list" data-el="home-pending"></div>\n'
    '                </div>\n              </div>\n', hidden=False)

def sel_el(opts, val, el, label, size="sm", extra=""):
    return qds_select(opts, val, size=size, extra_cls=extra).replace("data-qds-select", 'data-qds-select data-el="%s"' % el, 1).replace('aria-haspopup="listbox"', 'aria-haspopup="listbox" aria-label="%s"' % label, 1)
def drange(el, ph="日期區間"):
    return qds_datepicker("range", size="sm", placeholder=ph).replace('data-mode="range"', 'data-mode="range" data-el="%s"' % el).replace('class="qds-select-trigger qds-dp-trigger"', 'class="qds-select-trigger qds-dp-trigger" aria-label="%s"' % ph)
EXPENSES = view("expenses", head("支出管理",
        '<button type="button" class="btn btn-secondary" data-action="open-import">' + I(IC["upload"]) + '匯入</button><button type="button" class="btn btn-primary" data-action="new-expense">' + I(IC["plus"]) + '新增支出</button>') +
    '              <div class="dash-panel" role="region" aria-label="支出列表">\n' + tabs("exp-tabs") +
    '                <div class="dash-filter">' + search("expenses", "搜尋廠商/備註/發票號") + sel_el([("all", "全部來源"), ("general", "一般支出"), ("reimbursement", "代墊款")], "all", "exp-src", "來源") +
    sel_el([("all", "全部類別")], "all", "exp-cat", "類別") + drange("exp-range", "費用日區間") +
    '<button type="button" class="btn btn-text btn-sm" data-action="exp-clear" hidden>清除篩選</button></div>\n' +
    table("exp-rows", [("sortable", '<button type="button" class="sort-btn" data-sort="exp:date">日期<span class="sort-ind"></span></button>'), "類別", ("num sortable", '<button type="button" class="sort-btn" data-sort="exp:amount">金額<span class="sort-ind"></span></button>'), "廠商/對象", "來源", "付款狀態", ("act", '<span class="sr-only">操作</span>')]) +
    pg("exp", "支出分頁") + '<div class="dash-table-summary" data-bind="exp-sum"></div>\n              </div>\n')

def fld(label, inner, fid=None, req=False, help_="", err=None, cls=""):
    lab = '<label%s>%s%s</label>' % (' for="%s"' % fid if fid else '', label, ' <span class="req">*</span>' if req else '')
    e = '<span class="error-msg" data-err="%s" hidden></span>' % err if err else ''
    h = '<span class="help-msg">%s</span>' % help_ if help_ else ''
    return '<div class="field %s">%s%s%s%s</div>' % (cls, lab, inner, h, e)
FORM = view("expense-form",
    '              <div class="dash-page-head"><div><button type="button" class="btn btn-text btn-sm dash-back" data-action="goto" data-view="expenses">' + I(IC["back"]) + '返回列表</button><div class="dash-page-title" data-el="form-title">新增支出</div></div><div class="dash-page-actions"></div></div>\n'
    '              <div class="form-layout">\n'
    '                <div class="dash-panel form-side" role="region" aria-label="憑證">\n'
    '                  <div class="dash-form-section">憑證</div>\n'
    '                  <label class="upload-drop form-drop"><input type="file" data-el="form-file" accept="image/*,.pdf" multiple hidden>' + I(IC["upload"], size=28) + '<b>拖放檔案，或點擊上傳</b><span>發票、收據照片或 PDF，單檔 10MB 以內</span></label>\n'
    '                  <ul class="file-list" data-el="form-files"></ul>\n'
    '                  <button type="button" class="btn btn-secondary btn-sm form-ocr" data-action="ocr" disabled>' + I(IC["scan"]) + '<span data-el="ocr-label">開始辨識</span></button>\n'
    '                  <p class="help-msg">辨識會自動帶入賣方、日期、發票號碼與金額，請再確認一次。</p>\n'
    '                </div>\n'
    '                <div class="form-main">\n'
    '                  <div class="dash-panel" role="region" aria-label="基本資料">\n'
    '                    <div class="dash-form-section">基本資料</div>\n'
    '                    <div class="form-grid">\n'
    '                      ' + fld("憑證類型", '<div class="choice-cards" role="radiogroup" aria-label="憑證類型"><label><input type="radio" name="f-doc" value="invoice" checked><span>統一發票</span></label><label><input type="radio" name="f-doc" value="receipt"><span>收據/其他單據</span></label></div>', cls="span-2") + '\n'
    '                      ' + fld("費用日期", qds_datepicker("single", value="2026-09-24", placeholder="請選擇日期").replace("data-qds-datepicker", 'data-qds-datepicker data-el="f-date"'), req=True, err="f-date") + '\n'
    '                      ' + fld("類別", qds_select([], None, placeholder="請選擇類別").replace("data-qds-select", 'data-qds-select data-el="f-cat"'), req=True, err="f-cat", help_='找不到類別？可到<a href="#categories" data-action="goto" data-view="categories">類別管理</a>新增') + '\n'
    '                      ' + fld("賣方名稱", '<input id="f-vendor" placeholder="例：福華文具行">', "f-vendor") + '\n'
    '                      ' + fld("賣方統編", '<input id="f-taxid" inputmode="numeric" maxlength="8" placeholder="8 碼數字">', "f-taxid", err="f-taxid") + '\n'
    '                      ' + fld("發票號碼", '<div class="inv-no"><input id="f-inv1" maxlength="2" placeholder="AB" aria-label="發票號碼前段（英文 2 碼）"><span>–</span><input id="f-inv2" inputmode="numeric" maxlength="8" placeholder="12345678" aria-label="發票號碼後段（數字 8 碼）"></div>', req=True, err="f-inv", cls="f-inv-field") + '\n'
    '                      ' + fld("付款狀態", qds_select([("pending", "待付款"), ("paid", "已付款")], "paid").replace("data-qds-select", 'data-qds-select data-el="f-payout"'), req=True) + '\n'
    '                    </div>\n                  </div>\n'
    '                  <div class="dash-panel" role="region" aria-label="金額">\n'
    '                    <div class="dash-form-section">金額</div>\n'
    '                    <div class="form-grid form-grid-3">\n'
    '                      ' + fld("稅率", qds_select([("business_5", "營業稅 5%"), ("exempt_0", "免稅/收據 0%")], "business_5").replace("data-qds-select", 'data-qds-select data-el="f-taxrate"')) + '\n'
    '                      ' + fld("未稅金額", '<div class="input-group" style="width:100%;"><span class="addon">NT$</span><input id="f-pretax" inputmode="numeric" placeholder="0" style="text-align:right;"></div>', "f-pretax") + '\n'
    '                      ' + fld("稅額", '<div class="input-group" style="width:100%;"><span class="addon">NT$</span><input id="f-tax" inputmode="numeric" placeholder="0" style="text-align:right;"></div>', "f-tax", help_="依稅率自動計算，可手動修改") + '\n'
    '                      ' + fld("總金額（含稅）", '<div class="input-group" style="width:100%;"><span class="addon">NT$</span><input id="f-amount" inputmode="numeric" placeholder="0" style="text-align:right;"></div>', "f-amount", req=True, err="f-amount", cls="span-3") + '\n'
    '                    </div>\n'
    '                    <div class="items-head"><span class="dash-form-section">品項明細</span><button type="button" class="btn btn-secondary btn-sm" data-action="add-item">' + I(IC["plus"]) + '新增品項</button></div>\n'
    '                    <table class="dash-table items-table"><thead><tr><th>品項</th><th class="num">數量</th><th class="num">單價</th><th class="num">小計</th><th class="act"><span class="sr-only">操作</span></th></tr></thead><tbody data-el="f-items"></tbody></table>\n'
    '                    <div class="items-foot" data-bind="items-sum"></div>\n'
    '                  </div>\n'
    '                  <div class="dash-panel" role="region" aria-label="其他">\n'
    '                    <div class="dash-form-section">其他</div>\n'
    '                    ' + fld("備註", '<textarea id="f-note" placeholder="選填"></textarea>', "f-note") + '\n'
    '                  </div>\n'
    '                  <div class="button-bar form-foot"><button type="button" class="btn btn-secondary" data-action="goto" data-view="expenses">取消</button><button type="button" class="btn btn-primary" data-action="save-expense" data-el="form-submit">新增支出</button></div>\n'
    '                </div>\n              </div>\n')

def reqfilters(v):
    return ('                <div class="dash-filter" data-toolbar="%s">' % v + search(v, "搜尋申請人、說明、廠商") + sel_el([("all", "全部類別")], "all", v + "-cat", "類別") + drange(v + "-range", "費用日區間") + amount_range(v) +
            '<button type="button" class="btn btn-text btn-sm" data-action="clear-filter" data-list="%s" hidden>清除篩選</button></div>\n' % v)
SORTH = lambda key, label, cls="": (("sortable " + cls).strip(), '<button type="button" class="sort-btn" data-sort="%s">%s<span class="sort-ind"></span></button>' % (key, label))
RECORDS = view("records", head("請款記錄", '<button type="button" class="btn btn-secondary" data-action="toast" data-msg="已匯出請款記錄 CSV（示意）">匯出</button>') +
    '              <div class="dash-panel" role="region" aria-label="請款記錄">\n' + tabs("rec-tabs") + reqfilters("records") +
    table("rec-rows", ["申請人", "類別", SORTH("records:amount", "金額", "num"), SORTH("records:incurredAt", "費用日"), "狀態", "發放方式", SORTH("records:createdAt", "建立時間"), ("act", '<span class="sr-only">操作</span>')]) +
    pg("rec", "請款記錄分頁") + '<div class="dash-table-summary" data-bind="records-sum"></div>\n              </div>\n')
REVIEW = view("review", head("簽核") +
    '              <div class="dash-panel" role="region" aria-label="簽核列表">\n' + tabs("rev-tabs") + reqfilters("review") +
    selbar("review", '<button type="button" class="btn btn-danger btn-sm" data-action="batch-reject">批次駁回</button><button type="button" class="btn btn-primary btn-sm" data-action="batch-approve">批次核准</button>') +
    table("rev-rows", ["申請人", "類別", SORTH("review:amount", "金額", "num"), SORTH("review:incurredAt", "費用日"), "目前階段", SORTH("review:updatedAt", "更新時間"), ("act", '<span class="sr-only">操作</span>')], chk="review") +
    pg("rev", "簽核分頁") + '<div class="dash-table-summary" data-bind="review-sum"></div>\n              </div>\n')
PAYOUT = view("payout", head("發放") +
    '              <div class="dash-panel" role="region" aria-label="發放列表">\n' + tabs("pay-tabs") + reqfilters("payout") +
    selbar("payout", '<button type="button" class="btn btn-danger btn-sm" data-action="batch-void">批次作廢</button><button type="button" class="btn btn-primary btn-sm" data-action="batch-pay">批次標記已發放</button>') +
    table("pay-rows", ["申請人", "類別", SORTH("payout:amount", "金額", "num"), SORTH("payout:incurredAt", "費用日"), "狀態", "發放方式", SORTH("payout:updatedAt", "更新時間"), ("act", '<span class="sr-only">操作</span>')], chk="payout") +
    pg("pay", "發放分頁") + '<div class="dash-table-summary" data-bind="payout-sum"></div>\n              </div>\n')
CATEGORIES = view("categories", head("類別管理", '<button type="button" class="btn btn-primary" data-action="open-cat">' + I(IC["plus"]) + '新增類別</button>') +
    '              <div class="dash-panel" role="region" aria-label="類別列表">\n' + tabs("cat-tabs") +
    '                <div class="dash-filter">' + search("categories", "搜尋類別或會計科目") + '</div>\n' +
    table("cat-rows", ["類別名稱", "會計科目", ("num", "本月支出"), ("num", "使用筆數"), ("act", '<span class="sr-only">操作</span>')]) + '<div class="dash-table-summary" data-bind="categories-sum"></div>\n              </div>\n')
BUDGETS = view("budgets", head("預算管理", '<button type="button" class="btn btn-primary" data-action="apply-template">' + I('<path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5"/>') + '套用基本預算</button>'
    '<div class="dash-pop row-menu" data-pop="bud-more"><button type="button" class="btn btn-secondary btn-icon-only" data-toggle="bud-more" aria-haspopup="true" aria-expanded="false" aria-label="更多動作" title="更多動作"><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg></button>'
    '<div class="dash-menu" role="menu"><button type="button" role="menuitem" data-action="open-template">基本預算設定</button></div></div>') +
    '              <div class="dash-panel budget-tools" role="region" aria-label="預算列表工具">\n'
    '                <div class="dash-filter">' +
    '<div class="period-nav"><button type="button" class="btn btn-secondary btn-icon-only btn-sm" data-action="bud-prev" data-el="bud-prev" aria-label="上一期">' + I('<path d="M15 18l-6-6 6-6"/>') + '</button>' + bud_dp("month", "2026-09-01", "選擇月份") + bud_dp("year", "2026-01-01", "選擇年份", hidden=True) + '<button type="button" class="btn btn-secondary btn-icon-only btn-sm" data-action="bud-next" data-el="bud-next" aria-label="下一期">' + I('<path d="M9 18l6-6-6-6"/>') + '</button></div>' +
    '<button type="button" class="btn btn-text btn-sm" data-action="bud-today" data-el="bud-today" hidden>回到本月</button><span class="dash-filter-action">' + '<div class="qds-segmented" role="group" aria-label="預算週期" data-qds-segmented data-el="bud-cycle"><button type="button" class="on" aria-pressed="true" data-value="month">月預算</button><button type="button" aria-pressed="false" data-value="year">年預算</button></div>' + '</span></div>\n'
    '              </div>\n'
    '              <div class="budget-summary" data-el="budget-summary" role="region" aria-label="預算摘要"></div>\n'
    '              <div class="dash-panel" role="region" aria-label="類別預算">\n' +
    table("budget-rows", ["類別", ("num", "預算"), ("num", "實際支出"), ("budget-col", "使用率"), ("num", "餘額")]) + '              </div>\n')
USERS = view("users", head("人員管理", '<button type="button" class="btn btn-primary" data-action="open-invite">' + I(IC["plus"]) + '邀請人員</button>') +
    '              <div class="dash-panel" role="region" aria-label="人員列表">\n'
    '                <div class="dash-filter">' + search("users", "搜尋姓名、Email") + '</div>\n' +
    table("user-rows", ["姓名", "Email", "身分", "狀態", "加入/邀請時間", ("act", '<span class="sr-only">操作</span>')]) + '              </div>\n')
PROFILE = view("profile", head("個人設定") +
    '              <div class="dash-panel dash-form-panel" role="region" aria-label="個人設定">\n'
    '                <div class="dash-form-section">帳號資料</div>\n'
    '                ' + fld("姓名", '<input id="pf-name">', "pf-name", req=True) + '\n'
    '                ' + fld("Email", '<input id="pf-email" disabled>', "pf-email", help_="Email 是登入帳號，無法修改") + '\n'
    '                <div class="dash-form-section">通知</div>\n'
    '                <div class="toggle-row"><label class="toggle"><input type="checkbox" checked><span class="slider"></span></label>有新的請款待簽核時寄 Email 給我</div>\n'
    '                <div class="toggle-row"><label class="toggle"><input type="checkbox" checked><span class="slider"></span></label>類別預算使用超過 80% 時提醒我</div>\n'
    '                <div class="toggle-row"><label class="toggle"><input type="checkbox"><span class="slider"></span></label>每週一寄送上週支出摘要</div>\n'
    '                <div class="dash-form-section">安全性</div>\n'
    '                <div class="dash-form-line"><span>密碼</span><button type="button" class="btn btn-secondary btn-sm" data-action="open-password">修改密碼</button></div>\n'
    '                <div class="dash-form-line"><span>新手導覽</span><button type="button" class="btn btn-secondary btn-sm" data-action="tour">重新開始導覽</button></div>\n'
    '                <div class="button-bar dash-form-foot"><button type="button" class="btn btn-secondary" data-action="goto" data-view="home">取消</button><button type="button" class="btn btn-primary" data-action="save-profile">儲存</button></div>\n'
    '              </div>\n')

def dialog(name, title, body, foot, width=440, role="dialog"):
    return ('        <div class="dash-overlay dash-overlay-center" data-overlay="%s" aria-hidden="true">\n          <div class="dialog-preview" role="%s" aria-modal="true" aria-labelledby="dlg-%s-title" style="width:min(%dpx, 100%%);">\n'
            '            <div class="dh" id="dlg-%s-title" data-el="%s-title">%s</div>\n            <div class="db">%s</div>\n            <div class="df">%s</div>\n          </div>\n        </div>\n') % (name, role, name, width, name, name, title, body, foot)
def drawer(name):
    return ('        <div class="dash-overlay dash-overlay-right" data-overlay="%s" aria-hidden="true">\n          <div class="drawer-preview" role="dialog" aria-modal="true" aria-labelledby="drw-%s-title">\n'
            '            <div class="dh"><span id="drw-%s-title" data-el="%s-title"></span><button type="button" class="close-btn" aria-label="關閉" data-action="close">✕</button></div>\n'
            '            <div class="db" data-el="%s-body"></div>\n            <div class="df" data-el="%s-foot"></div>\n          </div>\n        </div>\n') % (name, name, name, name, name, name)
CANCEL = '<button type="button" class="btn btn-secondary" data-action="close">取消</button>'
PAY_METHODS = '<div class="choice-cards" role="radiogroup" aria-label="發放方式"><label><input type="radio" name="pay-method" value="bank_transfer" checked><span>匯款</span></label><label><input type="radio" name="pay-method" value="cash"><span>現金</span></label></div>'
OVERLAYS = (
    drawer("detail") + drawer("expdetail") +
    dialog("approve", "核准請款",
        '<div class="dlg-summary" data-el="approve-summary"></div>' +
        fld("意見（選填）", '<textarea id="ap-comment" rows="2" placeholder="例如：金額與發票相符"></textarea>', "ap-comment") +
        '<label class="checkbox-row" data-el="ap-create-row"><input type="checkbox" id="ap-create" checked>同時建立支出（寫入支出管理）</label>' +
        '<div class="ap-expense" data-el="ap-expense">' +
        fld("實付廠商", '<input id="ap-vendor" placeholder="例如：台北大車隊、統一超商">', "ap-vendor", req=True, err="ap-vendor") +
        fld("會計科目（類別）", qds_select([], None, placeholder="請選擇").replace("data-qds-select", 'data-qds-select data-el="ap-cat"'), req=True, err="ap-cat") +
        fld("付款狀態", qds_select([("pending", "待付款"), ("paid", "已付款")], "pending").replace("data-qds-select", 'data-qds-select data-el="ap-payout"')) +
        '</div>',
        CANCEL + '<button type="button" class="btn btn-primary" data-action="confirm-approve" data-el="approve-confirm">核准</button>', 480) +
    dialog("reject", "駁回請款",
        '<p class="dash-dialog-text" data-el="reject-text"></p>' + fld("駁回原因", '<textarea id="rj-reason" rows="3" placeholder="請說明為什麼駁回，方便申請人補件"></textarea>', "rj-reason", req=True, err="rj-reason"),
        CANCEL + '<button type="button" class="btn btn-danger" data-action="confirm-reject">確認駁回</button>') +
    dialog("payaction", "標記已發放",
        '<p class="dash-dialog-text" data-el="payaction-text"></p><div data-el="payaction-method">' + fld("發放方式", PAY_METHODS) + '</div>'
        '<div class="alert-warn" data-el="payaction-warn" hidden></div>' +
        '<div data-el="payaction-comment">' + fld('<span data-el="payaction-comment-label">說明</span>', '<textarea id="pa-comment" rows="2" placeholder="例如：申請人反悔、重複請款"></textarea>', "pa-comment", err="pa-comment") + '</div>',
        CANCEL + '<button type="button" class="btn btn-primary" data-action="confirm-payaction" data-el="payaction-confirm">確認發放</button>', 480) +
    dialog("confirm", "確認", '<div data-el="confirm-body"></div>',
        '<button type="button" class="btn btn-secondary" data-action="close" data-autofocus>取消</button><button type="button" class="btn btn-danger" data-action="confirm-ok" data-el="confirm-ok">刪除</button>', role="alertdialog") +
    dialog("import", "匯入支出",
        '<p class="dash-dialog-text">用 Excel 一次匯入多筆一般支出。先下載範本、照欄位填好再上傳。</p><button type="button" class="btn btn-text btn-sm" data-action="toast" data-msg="已下載匯入範本（示意）">下載 Excel 範本</button>'
        '<label class="upload-drop form-drop" data-el="import-drop"><input type="file" accept=".xlsx,.xls,.csv" data-el="import-file" hidden>' + I(IC["upload"], size=28) + '<b>拖放 Excel 檔，或點擊上傳</b><span>支援 .xlsx、.xls、.csv</span></label>'
        '<div data-el="import-preview" hidden></div>',
        CANCEL + '<button type="button" class="btn btn-primary" data-action="confirm-import" data-el="import-confirm" disabled>匯入</button>', 520) +
    dialog("cat", "新增類別",
        fld("類別名稱", '<input id="cat-name" placeholder="例如：計程車資、Q3 行銷活動">', "cat-name", req=True, err="cat-name") +
        fld("會計科目（選填）", qds_select([(c, c + " " + n) for c, n in ACCOUNT_SUBJECTS], None, placeholder="請選擇會計科目").replace("data-qds-select", 'data-qds-select data-el="cat-subject" data-filter="輸入代碼或名稱搜尋"', 1), None, help_='<span data-bind="cat-subject-help"></span>'),
        CANCEL + '<button type="button" class="btn btn-primary" data-action="save-cat">儲存</button>') +
    dialog("template", "基本預算設定",
        '<p class="dash-dialog-text">月預算和年預算分開設定：每月固定的開銷填月預算，一年一次或不定期的（例如員工旅遊）只填年預算。按「套用基本預算」會依目前檢視帶入月預算或年預算；個別月份仍可在列表上單獨調整。</p><div class="tpl-list" data-el="template-list"></div>',
        CANCEL + '<button type="button" class="btn btn-primary" data-action="save-template">儲存</button>', 560) +
    dialog("invite", "邀請人員",
        '<p class="dash-dialog-text">對方會收到邀請信，3 天內點連結設定密碼即可登入前台提交請款。</p>' +
        fld("Email", '<input id="inv-email" type="email" placeholder="new@example.com">', "inv-email", req=True, err="inv-email") +
        fld("姓名", '<input id="inv-name" placeholder="姓名">', "inv-name", req=True, err="inv-name"),
        CANCEL + '<button type="button" class="btn btn-primary" data-action="send-invite">發送邀請</button>') +
    dialog("useredit", "編輯人員",
        fld("姓名", '<input id="ue-name">', "ue-name", req=True, err="ue-name") + fld("Email", '<input id="ue-email" disabled>', "ue-email") +
        fld("身分", qds_select([("employee", "一般人員"), ("admin", "管理員")], "employee").replace("data-qds-select", 'data-qds-select data-el="ue-role"'), help_="管理員可以進後台；一般人員只能在前台請款"),
        CANCEL + '<button type="button" class="btn btn-primary" data-action="save-user">儲存</button>') +
    dialog("resetpwd", "重設密碼",
        '<p class="dash-dialog-text" data-bind="rp-who"></p>' +
        '<div class="field"><div style="display:flex; align-items:center; justify-content:space-between;"><label for="rp-new">新密碼 <span class="req">*</span></label><button type="button" class="btn btn-text btn-sm" data-action="gen-pwd">產生隨機密碼</button></div><input id="rp-new" type="text" autocomplete="new-password" spellcheck="false"><span class="help-msg">至少 8 碼</span><span class="error-msg" data-err="rp-new" hidden></span></div>' +
        fld("確認新密碼", '<input id="rp-new2" type="text" autocomplete="new-password" spellcheck="false">', "rp-new2", req=True, err="rp-new2") +
        '<p class="dash-dialog-text">儲存後請將新密碼告知對方，對方登入後可在帳號設定自行修改。</p>',
        CANCEL + '<button type="button" class="btn btn-primary" data-action="save-resetpwd">重設密碼</button>') +
    dialog("password", "修改密碼",
        fld("目前密碼", '<input id="pw-old" type="password" autocomplete="current-password">', "pw-old", req=True, err="pw-old") +
        fld("新密碼", '<input id="pw-new" type="password" autocomplete="new-password">', "pw-new", req=True, err="pw-new", help_="至少 8 碼，需包含英文與數字") +
        fld("確認新密碼", '<input id="pw-new2" type="password" autocomplete="new-password">', "pw-new2", req=True, err="pw-new2"),
        CANCEL + '<button type="button" class="btn btn-primary" data-action="save-password">更新密碼</button>') +
    '        <div class="dash-toast" role="status" aria-live="polite" data-el="toast"></div>\n')

PROTOTYPE_HTML = ('      <div class="dash-shell dash-template" id="dash-demo">\n' + NAV + '        <div class="dash-body">\n' + TOPBAR +
    '          <div class="dash-page">\n' + HOME + EXPENSES + FORM + RECORDS + REVIEW + PAYOUT + CATEGORIES + BUDGETS + USERS + PROFILE +
    '          </div>\n        </div>\n' + OVERLAYS + '      </div>\n')
