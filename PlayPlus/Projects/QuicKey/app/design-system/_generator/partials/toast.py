# Toast 頁內容（由 build_pages.py 以 exec 載入，產生 TOAST_CONTENT）
_ICON_OK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l4 4 10-10"/></svg>'
_ICON_WARN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17h.01"/></svg>'
_ICON_ERR = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M9 9l6 6M15 9l-6 6"/></svg>'
_ICON_INFO = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg>'

def _toast_demo(tone, color, icon, title, detail):
    body = '<p class="qds-toast-detail">%s</p>' % detail if detail else ''
    return ('<div class="qds-toast" style="--toast-c:%s;">'
            '<span class="qds-toast-icon">%s</span>'
            '<div class="qds-toast-body"><p class="qds-toast-title">%s</p>%s</div>'
            '</div>') % (color, icon, title, body)

TOAST_CONTENT = """
      <style>
        .qds-toast-demo { display:grid; gap:12px; max-width:25rem; }
        .qds-toast { display:grid; grid-template-columns:auto 1fr; gap:8px; align-items:start; padding:16px; border:1px solid var(--toast-c); border-radius:12px; background:#fff; box-shadow:0 4px 8px rgba(42,49,64,.08); }
        .qds-toast-icon { width:18px; height:24px; display:flex; align-items:center; color:var(--toast-c); }
        .qds-toast-icon svg { width:18px; height:18px; }
        .qds-toast-title { margin:0; font-size:16px; font-weight:500; line-height:24px; color:var(--ink, #2a3140); }
        .qds-toast-detail { margin:4px 0 0; font-size:14px; line-height:1.5; color:var(--muted, #646d80); }
        .qds-toast-table td:first-child { white-space:nowrap; font-weight:600; }
      </style>
      <h3>Toast — <code>toast</code></h3>
      <div class="demo"><div class="qds-toast-demo">
        %s
        %s
        %s
        %s
      </div></div>
      <p class="note">示意以 PrimeVue Toast 的實際版型為準；顏色取自上方「語意色」。實作位置與寬度由 <code>App.vue</code> 與 <code>styles/index.css</code> 統一設定，頁面內不另外指定。</p>

      <h3>語意與停留時間 — <code>toast-tone</code></h3>
      <div class="demo" style="overflow-x:auto;">
        <table class="qds-toast-table" style="width:100%%; border-collapse:collapse; font-size:14px;">
          <thead><tr><th style="text-align:left; padding:8px;">語意</th><th style="text-align:left; padding:8px;">用途</th><th style="text-align:left; padding:8px;">停留時間</th></tr></thead>
          <tbody>
            <tr><td style="padding:8px;">success（綠）</td><td style="padding:8px;">操作完成，例如「已移至垃圾桶」</td><td style="padding:8px;">2.5 秒</td></tr>
            <tr><td style="padding:8px;">warn（琥珀）</td><td style="padding:8px;">操作被前置條件擋下，需使用者處理，例如「已標記付款，無法移至垃圾桶」</td><td style="padding:8px;">3 秒</td></tr>
            <tr><td style="padding:8px;">error（紅）</td><td style="padding:8px;">操作失敗（後端或網路），例如「刪除失敗」</td><td style="padding:8px;">3.5 秒</td></tr>
            <tr><td style="padding:8px;">info（藍）</td><td style="padding:8px;">一般提示，不影響資料</td><td style="padding:8px;">3 秒</td></tr>
          </tbody>
        </table>
      </div>

      <h3>版型與文案 — <code>toast-layout</code></h3>
      <div class="demo" style="overflow-x:auto;">
        <table class="qds-toast-table" style="width:100%%; border-collapse:collapse; font-size:14px;">
          <thead><tr><th style="text-align:left; padding:8px;">項目</th><th style="text-align:left; padding:8px;">規範</th></tr></thead>
          <tbody>
            <tr><td style="padding:8px;">位置</td><td style="padding:8px;">畫面右上角；寬度 25rem，窄螢幕不超出視窗邊界</td></tr>
            <tr><td style="padding:8px;">結構</td><td style="padding:8px;">標題必填，說明結果或原因；內文選填，只寫處理方式或補充。</td></tr>
            <tr><td style="padding:8px;">圖示</td><td style="padding:8px;">18px；圖示區塊高度等於標題行高（24px），與標題第一行垂直置中</td></tr>
            <tr><td style="padding:8px;">字級</td><td style="padding:8px;">標題 16px／行高 24px；內文 14px；手機版標題也不超過 14px</td></tr>
            <tr><td style="padding:8px;">文案</td><td style="padding:8px;">不顯示英文或錯誤代碼；無法辨識的錯誤使用「請稍後再試。」；標題不重複列表上下文（不寫「這筆」）</td></tr>
            <tr><td style="padding:8px;">不用 Toast 的情況</td><td style="padding:8px;">需要使用者決定或確認 → Dialog（例如刪除確認）；表單欄位錯誤 → 欄位下方的錯誤文字；需要持續顯示的狀態 → Alert</td></tr>
          </tbody>
        </table>
      </div>
      <p class="note">現況待統一：部分既有提示的停留時間仍為 2–4 秒，少數錯誤使用 <code>danger</code> 而非 <code>error</code>。之後調整程式碼時依上表修正。</p>
""" % (
    _toast_demo('success', '#10b981', _ICON_OK, '已移至垃圾桶', '可從垃圾桶還原'),
    _toast_demo('warn', '#f59e0b', _ICON_WARN, '已標記付款，無法移至垃圾桶', '若付款狀態登錄有誤，請取消付款標記，再刪除。'),
    _toast_demo('error', '#dc2626', _ICON_ERR, '刪除失敗', '請稍後再試。'),
    _toast_demo('info', '#0ea5e9', _ICON_INFO, '資料已更新', ''),
)
