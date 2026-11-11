我要你使用波段交易大師 Mark-Minervini 的方法，為我分析台股交易決策。請執行 `# 任務` 指示。

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

- [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/Mark-Minervini]]

# 情報清單

- **加權指數交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/TAIEX_daily.csv]]
- **櫃買指數交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/TPEx_daily.csv]]
- **大盤今日情報** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅今日情報.md]]
- **個股每日交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_daily.csv 檔案。
- **個股月營收** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_monthly.csv 檔案。
- **個股季財報** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_quarterly.csv 檔案。

# 額外規範

- **寫作通用規範** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/通用規範.md]]
- **輸出文件時的排版** : 第1個 <h2> 為「# 大盤環境」、第2個 <h2> 為「# 持股交易策略」、第3個 <h2> 為「# 指定個股交易策略」。

# 範例文件

[[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/範例_交易決策_Mark-Minervini.md]]

# 產出成果

[[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅交易決策_Mark-Minervini.md]]

<!-- ------------------ 任務 ------------------ -->

# 台股大盤趨勢

先分析大盤環境是否適合做多進場（判定 Risk-On / Neutral / Risk-Off）。判斷目前大盤趨勢，定調操作環境的主要策略與資金水位策略。

# 分析持股

根據上述 `# 台股大盤趨勢` 的結果，依據 Mark Minervini 波段交易指導手冊規則，分析 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/stocks.csv]] 裡的「持股」股票。每檔持股卡片或標題最上方先給出交易策略建議的結論，依照 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/交易決策標籤.md]] 明確定義結論。

- 明確告訴我接下來「如果遇到什麼狀況要加碼多少（寫清楚狀況及數量，如果不需要加碼就給予「無」）」。
- 明確告訴我接下來「如果遇到什麼狀況要減碼多少（寫清楚狀況及數量，如果不需要減碼就給予「無」）」。
- 明確列出 Minervini 規則檢核與防線（如 P1 初始停損、P3 時間停損、P5 均線防線等）及具體防守價格設定。

# 分析指定個股

與 `# 分析持股` 採用完全相同的方法，分析 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/短期交易指定名單.md]] 裡面的指定股票。

# 複查

請根據 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/Mark-Minervini/Swing-Trading.md]] 指導手冊再次對 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅交易決策_Mark-Minervini.md]] 進行複查，如果有需要修正的地方請直接修改文件。