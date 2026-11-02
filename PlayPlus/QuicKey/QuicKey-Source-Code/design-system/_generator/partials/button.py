# Button 頁內容（由 build_pages.py 以 exec 載入，產生 BUTTON_CONTENT）
PLUS = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>'
SEARCH = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>'
DL = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>'
CARET = '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>'
SPIN = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M12 3a9 9 0 019 9"/></svg>'

VARIANTS = [
    ("btn-primary", "送出請款", "Primary", "每個畫面最主要的一個動作：送出、儲存、新增。一個區塊最多一個。"),
    ("btn-secondary", "取消", "Secondary", "次要動作：取消、返回、匯出。常與 Primary 並排。"),
    ("btn-danger", "駁回", "Danger", "破壞性動作：駁回、作廢、刪除。外框樣式，執行前需確認。"),
    ("btn-text", "取消選取", "Text", "低強調動作：清除、查看全部、取消選取。"),
    ("btn-success", "核准", "Success", "明確的正向確認：核准。只在審核情境使用。"),
    ("btn-outlined btn-success", "核准", "Success 外框", "同一列已有 Primary 時的次要正向動作。"),
    ("btn-info", "標記為已讀", "Info", "資訊類動作：標記已讀、查看說明。"),
    ("btn-outlined btn-info", "標記為已讀", "Info 外框", "Info 的低強調版本。"),
]
rows = []
for cls, label, name, use in VARIANTS:
    code = "." + cls.replace(" ", ".")
    rows.append(
        '<div class="bm-row">'
        '<div class="bm-name"><b>%s</b><code>%s</code><span>%s</span></div>'
        '<div class="bm-cell"><button class="btn %s">%s</button></div>'
        '<div class="bm-cell"><button class="btn %s is-hover" tabindex="-1">%s</button></div>'
        '<div class="bm-cell"><button class="btn %s is-focus" tabindex="-1">%s</button></div>'
        '<div class="bm-cell"><button class="btn %s" disabled>%s</button></div>'
        '</div>' % (name, code, use, cls, label, cls, label, cls, label, cls, label))

def cell(label, inner):
    return '<div class="spec-cell"><span class="spec-label">%s</span><div class="spec-demo">%s</div></div>' % (label, inner)

BUTTON_CONTENT = """
      <h3>種類與狀態 — <code>btn-primary / secondary / danger / text / success / info</code></h3>
      <div class="demo demo-flush">
        <div class="btn-matrix" role="table" aria-label="按鈕種類與狀態">
          <div class="bm-row bm-head" role="row"><div>種類與用途</div><div>預設</div><div>Hover</div><div>Focus（鍵盤）</div><div>Disabled</div></div>
          %s
        </div>
      </div>
      <p class="note">所有按鈕同一高度（44px）、圓角 <code>full</code>、14px 600，外框統一 1.5px（實心按鈕用同色外框補齊，並排時不會高低不一）。危險動作用外框樣式而不是實心紅底，維持整體克制感。Disabled 一律改成 <code>surface-soft</code> 底＋<code>muted-soft</code> 字，不用降低透明度（跟 Input 的 disabled 規則一致，也避免跟 Loading 混淆）。鍵盤聚焦時外加 2px 主色外框，滑鼠點擊不出現。</p>

      <h3>尺寸 — <code>btn / btn-sm</code></h3>
      <div class="demo">
        <div class="spec-grid">
          %s
          %s
          %s
          %s
        </div>
      </div>
      <p class="note">預設與 <code>btn-sm</code> 都維持 44px 高；<code>btn-sm</code> 只收斂左右 padding，用在表格工具列、批次操作列這類密度高的地方。卡片標題列若需要和 18px 標題同列對齊，使用 36px 的 compact Select / period-picker，不用把文字按鈕縮到 36px。</p>

      <h3>圖示按鈕 — <code>btn-icon-only</code></h3>
      <div class="demo">
        <div class="spec-grid">
          %s
          %s
          %s
          %s
        </div>
      </div>
      <p class="note">圖示在文字左側、間距 6px，顏色跟隨文字（<code>currentColor</code>）。只有圖示的按鈕是 44×44 正方形；表格列動作需維持正圓。次要按鈕（有文字或只有圖示）外框一律用 <code>primary-300</code>（hover 加深到 <code>primary-400</code>），字與圖示維持主色；比實心主要按鈕輕，層級更分明。一定要加 <code>aria-label</code>，並配合 tooltip 說明用途。</p>

      <h3>組合 — <code>btn-group / btn-split / is-loading</code></h3>
      <div class="demo">
        <div class="spec-grid">
          %s
          %s
          %s
        </div>
      </div>
      <p class="note">按鈕群組用在互斥的切換（日/週/月），選中項用較深的 <code>primary-600</code>；分裂按鈕用在「一個主要動作＋其他相關動作」（儲存/另存草稿）。Loading 時按鈕停用、文字改成進行中的說法（處理中…），寬度不變。</p>

      <h3>排列 — <code>button-bar</code></h3>
      <div class="demo">
        <div class="spec-grid spec-grid-wide">
          %s
          %s
        </div>
      </div>
      <p class="note">並排按鈕間距 8px、靠右對齊，主要動作放最右邊（Dialog、Drawer、表單底部都一樣）。有危險動作時放最左邊，跟其他按鈕拉開距離，避免誤按。</p>
""" % (
    "\n          ".join(rows),
    cell("預設 44px", '<button class="btn btn-primary">送出請款</button>'),
    cell("預設 44px・Secondary", '<button class="btn btn-secondary">取消</button>'),
    cell("小尺寸 44px <code>btn-sm</code>", '<button class="btn btn-primary btn-sm">新增</button>'),
    cell("小尺寸 44px・Secondary", '<button class="btn btn-secondary btn-sm">清除篩選</button>'),
    cell("圖示＋文字", '<button class="btn btn-primary">%s新增類別</button>' % PLUS),
    cell("圖示＋文字・Secondary", '<button class="btn btn-secondary">%s匯出</button>' % DL),
    cell("只有圖示 44×44", '<button class="btn btn-secondary btn-icon-only" aria-label="搜尋">%s</button>' % SEARCH),
    cell("只有圖示 44×44・btn-sm", '<button class="btn btn-secondary btn-icon-only btn-sm" aria-label="搜尋">%s</button>' % SEARCH),
    cell("按鈕群組 <code>btn-group</code>", '<div class="btn-group" role="group" aria-label="期間"><button class="btn btn-primary">日</button><button class="btn btn-primary is-selected" aria-pressed="true">週</button><button class="btn btn-primary">月</button></div>'),
    cell("分裂按鈕 <code>btn-split</code>", '<div class="btn-split"><button class="btn btn-primary">儲存</button><button class="btn-caret" aria-label="更多儲存選項">%s</button></div>' % CARET),
    cell("Loading <code>is-loading</code>", '<button class="btn btn-primary is-loading" disabled>%s處理中…</button>' % SPIN),
    cell("一般（Dialog/表單底部）", '<div class="button-bar-demo"><div class="button-bar"><button class="btn btn-secondary">取消</button><button class="btn btn-primary">儲存</button></div></div>'),
    cell("含危險動作", '<div class="button-bar-demo"><div class="button-bar"><button class="btn btn-danger">作廢</button><span class="button-bar-gap"></span><button class="btn btn-secondary">取消</button><button class="btn btn-primary">儲存</button></div></div>'),
)
