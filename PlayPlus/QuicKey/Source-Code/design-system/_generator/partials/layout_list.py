# 列表頁（CRUD）規則頁內容；由 build_pages.py exec 載入，可使用 qds_select / qds_datepicker
SRCH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>'
EDIT = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13.5 6.5l4 4"/></svg>'
TRASH = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/></svg>'
FILTER = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M4 5h16l-6 8v6l-4-2v-4z"/></svg>'
EMPTY = '<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" aria-hidden="true"><rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 5V3h6v2"/></svg>'
def search(ph):
    return '<label class="search-sm">%s<input type="search" placeholder="%s" aria-label="%s"></label>' % (SRCH, ph, ph)
def row(id_, name, cat, amt, st, stt):
    return ('<tr><td class="chk"><input type="checkbox" class="dash-check" aria-label="選取 #%s"></td><td class="mono">#%s</td><td>%s</td><td>%s</td><td class="num">%s</td>'
            '<td><span class="status-badge" style="color:var(--status-%s);background:var(--status-%s-bg)">%s</span></td>'
            '<td class="act"><span class="row-actions"><button type="button" class="btn btn-secondary btn-icon-only btn-sm" aria-label="編輯 #%s" title="編輯">%s</button><button type="button" class="btn btn-danger btn-icon-only btn-sm" aria-label="刪除 #%s" title="刪除">%s</button></span></td></tr>') % (
        id_, id_, name, cat, amt, st, st, stt, id_, EDIT, id_, TRASH)

TOOLBAR = '<div class="dash-filter">%s%s%s<button type="button" class="btn btn-text btn-sm">清除篩選</button></div><div class="dash-table-summary">共 86 筆<span class="sep" aria-hidden="true"></span>合計 NT$ 248,300</div>' % (
    search("搜尋說明、登錄人"), qds_select([("all", "全部類別"), ("交通費", "交通費"), ("餐費", "餐費")], "all", size="sm"),
    qds_datepicker("range", size="sm", placeholder="日期區間"))

LAYOUT_LIST_CONTENT = """
      <a class="proto-link" href="design-prototype.html#expenses">在後台原型中查看<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg></a>
      <p class="note" style="margin-top:0;">適用於支出管理、請款記錄、簽核、發放、類別管理、人員管理等「一張表管一種資料」的頁面。實作以 PrimeVue <code>&lt;DataTable&gt;</code> 為基礎（勾選 <code>selection</code>、排序 <code>sortable</code>、分頁 <code>paginator</code>），這頁定義它在 Quickey 裡的排法與規則。</p>

      <h3>結構 — <code>list-page</code></h3>
      <div class="dash-wire" aria-hidden="true">
        <div class="w-col">
          <div class="w-page">
            <div class="w-split"><div class="wb"><code>page-head</code><small>標題＋說明</small></div><div class="wb"><small>次要動作</small><code>主要動作</code></div></div>
            <div class="w-page w-panel">
              <div class="wb"><code>toolbar</code><small>搜尋＋篩選＋清除</small></div>
              <div class="wb w-tall"><code>data-table</code><small>勾選｜單號｜內容欄位｜金額｜狀態｜操作</small></div>
              <div class="wb"><code>table-summary</code><small>筆數/合計</small></div>
              <div class="wb"><code>paginator</code><small>超過一頁才顯示</small></div>
            </div>
          </div>
        </div>
      </div>

      <h3>工具列 — <code>list-toolbar</code></h3>
      <div class="demo">%s</div>
      <ul class="rules">
        <li>放在表格所在的 panel 裡、表格正上方。由左到右：搜尋（240px）→ 篩選（Select/DatePicker 小尺寸）→「清除篩選」文字按鈕（有套用篩選時才出現）。結果資訊（共幾筆/合計）不放在工具列，統一放在表格底部的 <code>table-summary</code>。</li>
        <li>搜尋只找這張表的資料，輸入即篩選；找整個系統用頂欄的全域搜尋。</li>
        <li>工具列所有元件高 44px，跟小尺寸 Select、<code>btn-sm</code> 等高。</li>
      </ul>

      <h3>批次操作 — <code>selection-bar</code></h3>
      <div class="demo">
        <div class="selection-bar" role="region" aria-label="批次操作"><span class="sel-count">已選 3 筆</span><button type="button" class="btn btn-text btn-sm sel-clear">取消選取</button><span class="sel-actions"><button type="button" class="btn btn-danger btn-sm">刪除</button><button type="button" class="btn btn-primary btn-sm">核准</button></span></div>
      </div>
      <ul class="rules">
        <li>勾選至少一列時，批次操作列獨立顯示在表格正上方，不取代搜尋/篩選工具列：左邊「已選 N 筆」＋「取消選取」，批次動作一律靠右，主要動作放最右邊、危險動作在它左邊（跟 Dialog 底部按鈕的順序一致）。取消全部勾選後隱藏批次操作列。</li>
        <li>外觀：<code>primary-50</code> 淡綠底、全圓角，高 56px、四周留 6px，讓 44px 的按鈕完整包在列裡（按鈕維持標準尺寸，不另做小按鈕）；「已選 N 筆」與「取消選取」都用 16px。</li>
        <li>不要在頁首或工具列放一顆常駐的、停用中的「刪除」按鈕，沒選資料時就不顯示批次動作。</li>
        <li>表頭勾選框可以全選目前這一頁；部分選取時顯示半選狀態。只有「有批次動作」的表格才出現勾選欄。</li>
      </ul>

      <h3>表格欄位與每列操作 — <code>data-table</code></h3>
      <div class="demo demo-flush">
        <table class="dash-table list-demo-table">
          <thead><tr><th class="chk"><input type="checkbox" class="dash-check" aria-label="全選"></th><th>單號</th><th>申請人</th><th>類別</th><th class="num">金額</th><th>狀態</th><th class="act"><span class="sr-only">操作</span></th></tr></thead>
          <tbody>%s%s%s</tbody>
        </table>
      </div>
      <ul class="rules">
        <li>欄位順序：勾選 → 識別（單號，主色粗體）→ 內容欄位 → 金額（靠右、<code>tabular-nums</code>）→ 狀態（Status Badge）→ 操作。文字靠左、數字靠右。</li>
        <li>每列操作放在最右欄、靠右對齊，用 44px 正圓圖示按鈕，最多 2 個（常見：編輯、刪除）；刪除用 Danger 外框。只有圖示的按鈕一定要有 <code>aria-label</code> 和提示文字。超過 2 個動作改成「⋯」選單。</li>
        <li>整列可點時（開明細），點操作按鈕不會觸發整列點擊；列 hover 用 <code>surface-soft</code> 底。</li>
        <li>唯一且明確的動作可以用文字按鈕取代圖示，例如簽核頁每列的「通過」「駁回」、發放頁的「發放」「作廢」。</li>
        <li>新增/編輯：欄位少（約 4 欄以內）用 Dialog，例如類別、邀請人員；欄位多、含上傳或明細時用整頁表單，例如支出。新增與編輯共用同一頁，頂部放「返回列表」。</li>
      </ul>

      <h3>刪除確認 — <code>confirm-dialog</code></h3>
      <div class="demo">
        <div class="dialog-preview" role="dialog" aria-label="刪除確認範例" style="width:400px;">
          <div class="dh">刪除這筆支出？</div>
          <div class="db">「影印紙、碳粉」NT$ 3,150（2026/09/20）<br>刪除後無法復原，也會從支出趨勢與預算中扣除。</div>
          <div class="df"><button type="button" class="btn btn-secondary">取消</button><button type="button" class="btn btn-danger">刪除</button></div>
        </div>
      </div>
      <ul class="rules">
        <li>刪除、作廢等無法復原的動作一律先跳確認視窗：標題直接問「刪除這筆支出？」，內文寫出是哪一筆、會有什麼影響。</li>
        <li>確認按鈕寫出動作本身（刪除），不寫「確定」；焦點預設停在「取消」，Esc 等於取消。</li>
        <li>已發放的代墊款、已簽核的請款單不能刪除，操作欄不顯示刪除按鈕。</li>
      </ul>

      <h3>空狀態 — <code>empty / no-results / loading</code></h3>
      <div class="demo">
        <div class="spec-grid">
          <div class="spec-cell"><span class="spec-label">還沒有資料</span><div class="empty-mini">%s<b>還沒有支出紀錄</b><span>新增第一筆，或從 Excel 匯入</span><button type="button" class="btn btn-primary btn-sm">新增支出</button></div></div>
          <div class="spec-cell"><span class="spec-label">搜尋/篩選沒有結果</span><div class="empty-mini"><b>沒有符合條件的支出</b><span>試試其他關鍵字，或</span><button type="button" class="btn btn-text btn-sm">清除篩選</button></div></div>
          <div class="spec-cell"><span class="spec-label">載入中</span><div class="skeleton-rows" aria-busy="true" aria-label="載入中"><span></span><span></span><span></span><span></span></div></div>
        </div>
      </div>
      <ul class="rules">
        <li>「還沒有資料」跟「搜尋不到」要分開：前者引導新增，後者引導清除篩選。</li>
        <li>載入中用骨架列（跟表格列同高），不要用整頁轉圈圈；超過 0.3 秒才顯示，避免閃一下。</li>
      </ul>

      <h3>分頁 — <code>paginator</code></h3>
      <ul class="rules">
        <li>放在表格正下方，超過一頁才顯示；預設每頁 10 筆，可選 10/20/50。規格見 <a href="design-paginator.html">Paginator</a>。</li>
        <li>換頁、改篩選或搜尋後回到第 1 頁；已勾選的資料在換頁時保留，並在批次操作列顯示總勾選數。</li>
      </ul>

      <h3>手機版 — <code>list-card</code></h3>
      <div class="demo">
        <div class="m-list">
          <div class="m-toolbar">%s<button type="button" class="btn btn-secondary btn-icon-only btn-sm" aria-label="篩選">%s</button></div>
          <div class="m-card"><div class="m-top"><span class="mono">#05895</span><span class="status-badge" style="color:var(--status-review);background:var(--status-review-bg)">簽核中</span></div><div class="m-mid"><span>王小明<span class="sep" aria-hidden="true"></span>交通費</span><b>NT$ 320</b></div></div>
          <div class="m-card"><div class="m-top"><span class="mono">#05811</span><span class="status-badge" style="color:var(--status-approved);background:var(--status-approved-bg)">已核銷</span></div><div class="m-mid"><span>林美惠<span class="sep" aria-hidden="true"></span>交通費</span><b>NT$ 2,140</b></div></div>
          <div class="m-card"><div class="m-top"><span class="mono">#05790</span><span class="status-badge" style="color:var(--status-paid);background:var(--status-paid-bg)">已發放</span></div><div class="m-mid"><span>張家豪<span class="sep" aria-hidden="true"></span>辦公用品</span><b>NT$ 850</b></div></div>
        </div>
      </div>
      <ul class="rules">
        <li>寬度 &lt; 640px 時表格改成卡片清單：上排單號＋狀態、下排說明＋金額；點卡片開明細，每列操作移到明細裡。</li>
        <li>工具列只留搜尋和「篩選」圖示按鈕，篩選條件放進從下方滑出的 Drawer；分頁改用精簡版。</li>
      </ul>
""" % (TOOLBAR,
       row("05895", "王小明", "交通費", "NT$ 320", "review", "簽核中"),
       row("05852", "林美惠", "餐費", "NT$ 1,280", "review", "簽核中"),
       row("05772", "王小明", "交通費", "NT$ 460", "rejected", "駁回"),
       EMPTY, search("搜尋"), FILTER)
