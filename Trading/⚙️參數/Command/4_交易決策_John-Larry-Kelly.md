我要你使用凱利公式發明者 John-Larry-Kelly 的方法，為我分析台股交易決策。請執行 `# 任務` 指示。

# 任務

依序執行以下任務。執行任務時請務必遵守 `# 額外規範` 的規定。

1. 熟讀 `# 知識及經驗` 文件。
2. 熟讀 `# 情報清單` 文件。
3. 執行 `# 台股大盤趨勢` 項目。
4. 執行 `# 分析持股` 項目。
5. 執行 `# 分析指定個股` 項目。
6. 遵守 `# 文件格式規範` 的格式指示並參照 `# 範例文件` 的格式將報告結果覆寫於 `# 產出成果` 檔案。
7. 執行 `# 複查` 項目。

<!-- ------------------ 參數 ------------------ -->

# 知識及經驗

- [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/John-Larry-Kelly]]

# 情報清單

- **加權指數交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/TAIEX_daily.csv]]
- **櫃買指數交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/TPEx_daily.csv]]
- **大盤今日情報** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅今日情報.md]]
- **個股每日交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_daily.csv 檔案。
- **個股月營收** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_monthly.csv 檔案。
- **個股季財報** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_quarterly.csv 檔案。

# 額外規範

- **寫作通用規範** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/通用規範.md]]

# 範例文件

[[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/範例_交易決策_John-Larry-Kelly.md]]

# 產出成果

[[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅交易決策_John-Larry-Kelly.md]]

<!-- ------------------ 任務 ------------------ -->

# 台股大盤趨勢

依據「股市算牌策略」與條件機率空間（大盤位階、均線結構與市場寬度），先分析大盤環境處於「記憶性結構區（順風正期望值）」或「無記憶性雜訊區／逆風區」，判定是否適合做多進場（Risk-On / Neutral / Risk-Off）。評估市場波動率變異數（$\sigma^2$），定調操作環境的主要策略、總資金水位策略與帳戶總在險資金上限（Max Portfolio Heat）。

# 分析持股

根據上述 `# 台股大盤趨勢` 的結果，依據 John-Larry-Kelly 統計優勢與凱利公式交易體系規則，分析 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/stocks.csv]] 裡的「持股」股票。每檔持股卡片或標題最上方先給出交易策略建議的結論，依照 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/交易決策標籤.md]] 明確定義結論。

- 明確列出「期望值與統計優勢檢核」：評估策略類型、條件勝率（$p$）、預設停損價與停損幅度（$a$）、波段目標價與獲利幅度（$b$）、盈虧比（$B = b/a$）及期望值（$E[R] = p \cdot B - q$）。
- 明確列出「分數凱利倉位與風險預算」：計算理論凱利風險（$r^* = p - q/B$）、實戰單筆風險預算（$r_{\text{actual}}$，受分數凱利折減與 $0.5\% \sim 2.0\%$ 硬上限約束）、目標持倉比例（$f_{\text{actual}} = \min(r_{\text{actual}}/a, 25\%)$）與應持有股數，並檢核目前部位是否已脫離成本區釋放「在險資金（Portfolio Heat）」。
- 明確告訴我接下來「如果遇到什麼狀況要加碼多少（寫清楚底倉保本後的順勢金字塔加碼條件及數量，嚴禁虧損向下攤平；如果不需要加碼就給予「無」）」。
- 明確告訴我接下來「如果遇到什麼狀況要減碼多少（寫清楚觸發停損、波動率 $\sigma^2$ 放大或回撤斷路器等狀況及數量，如果不需要減碼就給予「無」）」。
- 明確列出「凱利三層防線與防破產五大鐵律檢核」（包含具體停損防守價格、單一持股 $25\%$ 上限、同族群 Beta 共振風險及財報／流動性等外生非模型風險檢核）。

# 分析指定個股

與 `# 分析持股` 採用完全相同的方法，分析 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/短期交易指定名單.md]] 裡面的指定股票。

# 複查

請根據 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/John-Larry-Kelly/Kelly-Criterion.md]] 指導手冊再次對 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅交易決策_John-Larry-Kelly.md]] 進行複查，如果有需要修正的地方請直接修改文件。