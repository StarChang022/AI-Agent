# Paginator 頁內容（由 build_pages.py 以 exec 載入，產生 PAGINATOR_CONTENT）
PAGINATOR_CONTENT = """
      <h3>Paginator — <code>paginator</code></h3>
      <div class="demo">
        <table class="pg-demo-table" id="pg-demo-table">
          <thead><tr><th>單號</th><th>申請人</th><th>類別</th><th style="text-align:right;">金額</th></tr></thead>
          <tbody></tbody>
        </table>
        <div class="qds-paginator" data-qds-paginator id="pg-demo" data-total="86" data-rows="10" data-rows-options="10,20,50" aria-label="請款記錄分頁"></div>
      </div>
      <script>
      document.addEventListener('DOMContentLoaded', function(){
        var names = ['王小明','林美惠','張家豪','陳志明','李佳穎'], cats = ['交通費','餐費','辦公用品','軟體訂閱','其他'];
        var tb = document.querySelector('#pg-demo-table tbody'), pg = document.getElementById('pg-demo');
        function show(first, rows){
          var h = '';
          for (var i = first; i < Math.min(first + rows, 86); i++){
            var id = 5900 - i, amt = 180 + ((i * 7919) % 5200);
            h += '<tr><td>#0' + id + '</td><td>' + names[i % 5] + '</td><td>' + cats[(i * 3) % 5] + '</td><td style="text-align:right; font-variant-numeric:tabular-nums;">NT$ ' + amt.toLocaleString('en-US') + '</td></tr>';
          }
          tb.innerHTML = h;
        }
        pg.addEventListener('qds-change', function(e){ if (e.target === pg) show(e.detail.first, e.detail.rows); });
        show(0, 10);
      });
      </script>
      <p class="note">對應 PrimeVue <code>&lt;Paginator&gt;</code>（或 DataTable 的 <code>paginator</code> 屬性），版面用 <code>template="CurrentPageReport FirstPageLink PrevPageLink PageLinks NextPageLink LastPageLink RowsPerPageDropdown"</code>。放在表格正下方：左側「第 1–10 筆，共 86 筆」，中間頁碼，右側每頁筆數（10/20/50）。只有一頁時不顯示。</p>
      <p class="note">頁碼按鈕 32px 圓形，目前頁用 <code>primary-solid</code> 實心、白字（跟 Tab、Select 的選中態同一套語言）；hover 用 <code>surface-soft</code>；在第一頁/最後一頁時，前後箭頭停用成 <code>muted-soft</code>。頁碼最多顯示 5 個，其餘用「…」省略，第一頁與最後一頁永遠顯示。切換每頁筆數時，停在包含目前第一筆資料的那一頁。每頁筆數下拉使用一般下拉樣式（圓角 16px、1.5px 邊框），高 40px，和 32px 頁碼排在一起比較平衡。無障礙：外層是 <code>nav</code>（<code>aria-label="分頁"</code>），目前頁加 <code>aria-current="page"</code>，只有箭頭的按鈕都有 <code>aria-label</code>。</p>

      <h3>變化 — <code>paginator 變化</code></h3>
      <div class="demo">
        <div class="spec-grid spec-grid-stack">
          <div class="spec-cell"><span class="spec-label">頁數少（不需省略）</span><div class="qds-paginator" data-qds-paginator data-total="42" data-rows="10" data-report="false" aria-label="分頁示範：頁數少"></div></div>
          <div class="spec-cell"><span class="spec-label">頁數多（前後省略）</span><div class="qds-paginator" data-qds-paginator data-total="480" data-rows="20" data-page="12" data-report="false" aria-label="分頁示範：頁數多"></div></div>
          <div class="spec-cell"><span class="spec-label">精簡版 <code>qds-paginator-compact</code>（手機、窄卡片）</span><div class="qds-paginator qds-paginator-compact" data-qds-paginator data-total="240" data-rows="10" data-page="3" aria-label="分頁示範：精簡版"></div></div>
        </div>
      </div>
      <p class="note">手機版（寬度 &lt; 640px）或卡片內的清單改用精簡版：只保留前後箭頭與「3 / 24」，不顯示筆數與每頁筆數選單。</p>
"""
