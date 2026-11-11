我要你使用台股短期投機名師 Zhu-Jiahong 的方法，為我分析台股交易決策。請執行 `# 任務` 指示。

# 任務

依序執行以下任務。執行任務時請務必遵守 `# 額外規範` 的規定。

1. 熟讀 `# 知識及經驗` 文件。
2. 熟讀 `# 情報清單` 文件。
3. 執行 `# 台股大盤趨勢` 項目。
4. 執行 `# 分析持股` 項目。
5. 執行 `# 分析指定個股` 項目。
6. 參照 `# 範例文件` 的格式將報告結果覆寫於 `# 產出成果` 檔案。
7. 執行 `# 複查` 項目。

<!-- ------------------ 參數 ------------------ -->

# 知識及經驗

- **Warren-Buffett 投資理論** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/Warren-Buffett]]
- **Zhu-Jiahong 交易理論** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/Zhu-Jiahong]]

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

[[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/範例_交易決策_Zhu-Jiahong.md]]

# 產出成果

[[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅交易決策_Zhu-Jiahong.md]]

<!-- ------------------ 任務 ------------------ -->

# 台股大盤趨勢

判斷目前大盤趨勢，定調操作環境的主要策略與資金水位策略。

1. **整體講評** : 簡短敘述。以及條列式「加權指數 TWSE」、「櫃買指數 TPEx」、「整體操作方向」、「總資金水位規劃」。
2. **指數與價量結構** : 講解 **加權指數 TWSE** 和 **櫃買指數 TPEx** 的指數結構與價量結構。
3. **趨勢與均線型態** : 說明均線排列（例如 5MA > 10MA > 20MA > 60MA）與型態，並依照 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/Zhu-Jiahong]] 提到的「趨勢六字訣」分析。以及條列式「5MA」、「10MA」、「20MA」、「60MA」指數。
4. **法人籌碼** : 說明三大法人動向、新台幣匯率變化。以及條列式「外資」、「投信」、「自營商」的買賣超成交量。

# 分析持股

分析 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/stocks.csv]] 裡的「持股」股票。

1. 最上面先統計「投資組合（總共N檔個股）」、「資產總計（總金額）」、「股票市值（股票總市值和資產百分比）」、「現金總計（現金總計和資產百分比）」。
2. 採用 Zhu-Jiahong 方法分析每檔持股，每檔持股卡片或標題最上方先給出交易策略建議的結論，依照 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/交易決策標籤.md]] 明確定義結論。
3. 採用 Zhu-Jiahong 方法分析「K線與價量」，並明確列出「壓力」與「支撐」。
4. 採用 Zhu-Jiahong 方法分析「均線系統」，先描述均線排列狀況，再明確列出「5MA、10MA、20MA、60MA」的點位。
5. 採用 Zhu-Jiahong 方法分析「法人籌碼」，明確列出「外資、投信、自營商」是「買超／賣超」多少張數。
6. 採用 Warren Buffett 方法分析「月營收動能」。
7. 採用 Warren Buffett 方法分析「季報與財報體質」。

# 分析指定個股

與 `# 分析持股` 採用完全相同的方法，分析 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/短期交易指定名單.md]] 裡面的指定股票。

# 複查

請根據 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/Zhu-Jiahong]] 指導手冊再次對 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅交易決策_Zhu-Jiahong.md]] 進行複查，如果有需要修正的地方請直接修改文件。