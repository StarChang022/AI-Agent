我要你使用凱利公式發明者 John-Larry-Kelly 與量化先驅愛德華·索普（Edward Thorp）的方法，為我分析台股交易決策。請執行 `# 任務` 指示。

# 任務

依序執行以下任務。執行任務時請務必遵守 `# 額外規範` 的規定。

1. 熟讀 `# 知識及經驗` 文件（所有計分、勝率、定錨價、盈虧比與凱利倉位計算，必須 **100% 嚴格遵循**《Kelly-Criterion.md》內之封閉型數學公式，嚴禁憑直覺主觀臆測數值）。
2. 熟讀 `# 情報清單` 文件。
3. 執行 `# 台股大盤趨勢` 項目。
4. 執行 `# 分析持股` 項目。
5. 執行 `# 分析指定個股` 項目。
6. 參照 `# 範例文件` 的排版與章節結構（但數值計算一律以《Kelly-Criterion.md》最新數學公式為準），將報告結果覆寫於 `# 產出成果` 檔案。
7. 執行 `# 複查` 項目。

<!-- ------------------ 參數 ------------------ -->

# 知識及經驗

- [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/John-Larry-Kelly/Kelly-Criterion.md]]

# 情報清單

- **加權指數交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/TAIEX_daily.csv]]
- **櫃買指數交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/TPEx_daily.csv]]
- **大盤今日情報** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅今日情報.md]]
- **帳戶持股清單** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/stocks.csv]]
- **歷史交易明細** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/trading_detail.csv]]
- **短期交易指定名單** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/短期交易指定名單.md]]
- **個股每日交易資訊** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_daily.csv 檔案。
- **個股月營收** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_monthly.csv 檔案。
- **個股季財報** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks]] 資料夾裡面的「非TAIEX」和「非TPEx」的 StockID 對應的 {StockID}_quarterly.csv 檔案。

# 額外規範

- **寫作通用規範** : [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/通用規範.md]]
- **數學公式一致性強制規範** : 計算任何一檔股票的條件勝率（$p$）、停損幅度（$a$）、獲利幅度（$b$）、盈虧比（$B$）、期望值（$E[R]$）與建議配置資金／股數（$f_{\text{actual}}, N_{\text{shares}}$）時，**必須完全代入《Kelly-Criterion.md》第 2 章與第 3 章之唯一確定數學公式**，並在報告中顯性列出計數子分數（$S_{\text{mkt}}, S_{\text{stock}}, TC$），確保每次計算皆有完全相同的勝率與倉位依據。

# 範例文件

[[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/範例_交易決策_John-Larry-Kelly.md]]

# 產出成果

[[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅交易決策_John-Larry-Kelly.md]]

<!-- ------------------ 任務 ------------------ -->

# 台股大盤趨勢

依據《Kelly-Criterion.md》第 1 章「股市算牌策略」與第 2.1 節「大盤環境計數模型（$S_{\text{mkt}}$）」，先分析大盤環境處於「記憶性結構區（順風正期望值）」或「無記憶性雜訊區／逆風區」：

1. **明確計算大盤環境計數（$S_{\text{mkt}}$）**：逐項列出均線位階分 $m_1 \in \{-2, 0, +2\}$、均線斜率動能分 $m_2 \in \{-1, 0, +1, +2\}$、年線長牛保護分 $m_3 \in \{-1, +1\}$、市場寬度（櫃買共振）與法人資金流向分 $m_4 \in \{-1, 0, +1\}$，加總得出 $S_{\text{mkt}} = m_1 + m_2 + m_3 + m_4 \in [-5, +6]$。
2. **判定環境三態與風控參數**：依 $S_{\text{mkt}}$ 判定是否適合做多進場（🟢 Risk-On $S_{\text{mkt}} \ge +3$ ／ 🟡 Neutral $0 \le S_{\text{mkt}} \le +2$ ／ 🔴 Risk-Off $S_{\text{mkt}} < 0$），並明確給出環境調節乘數 $\kappa_{\text{regime}} \in \{1.00, 0.50, 0.00\}$ 與帳戶總在險資金上限 $H_{\max} \in \{6.0\%, 3.0\%, 0.0\%\}$。
3. **指數與籌碼結構評估**：結合連續時間凱利公式 $f^* \approx \frac{\mu - r_f}{\sigma^2}$ 評估市場波動率變異數（$\sigma^2$）與外資期現貨、投信、匯率結構，定調操作環境的主要策略與總資金水位策略。

# 分析持股

根據上述 `# 台股大盤趨勢` 的結果（$S_{\text{mkt}}, \kappa_{\text{regime}}, H_{\max}$），嚴格依據《Kelly-Criterion.md》第 2～5 章之數學公式，分析 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/stocks/stocks.csv]] 裡的「持股」股票。每檔持股卡片或標題最上方先給出交易策略建議的結論，依照 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/交易決策標籤.md]] 明確定義結論。

- **投資組合概況與風控檢討**：統計持股檔數、資產總計 $W_t$、股票總市值與佔比、可用現金 $C_{\text{cash}}$ 與佔比、帳戶基準 $1R$ 風險預算、當前總在險資金（Portfolio Heat, $H_{\text{open}} = \sum r_{\text{open},i}$）與剩餘可用風險額度 $r_{\text{avail}}$，並檢核是否有違反五大鐵律（如虧損向下攤平、單一持股 $> 20\% \sim 25\%$、同產業集中度 $> 40\%$）之處置計畫。
- **明確列出「期望值與統計優勢檢核」（嚴格代入第 2.2～2.4 節公式）**：
    1. **個股結構四維計分與真實計數 $TC$**：明確列出趨勢位階分 $S_{\text{trend}} \in [0,30]$、波動收縮與量價分 $S_{\text{vol}} \in [0,25]$、法人籌碼與融資分 $S_{\text{chip}} \in [0,25]$、基本面催化分 $S_{\text{fund}} \in [0,20]$，加總得出 $S_{\text{stock}} \in [0,100]$，並代入 $TC = \frac{S_{\text{stock}} - 50}{10} + 0.5 \times S_{\text{mkt}}$ 算出索普真實計數 $TC$。
    2. **嚴格優先判定樹型態歸類與條件勝率 $p$**：依第 2.3 節優先順序（Setup D $\rightarrow$ C $\rightarrow$ A $\rightarrow$ B $\rightarrow$ N）判定唯一策略型態與基準勝率 $p_0$，並代入 $p = \text{clip}(p_0 + 0.025 \times TC, \; p_{\min}, \; p_{\max})$ 算出精確條件勝率 $p$ 與敗率 $q = 1 - p$。
    3. **定錨價格、含稅費停損/獲利幅度與期望值**：計算 $\text{ATR}_{14,t}$，定錨進場／評估基準價 $P_{\text{entry}}$、經 ATR 夾擠校正後之停損價 $P_{\text{stop}}$（以及既有持股之未實現風險倍數 $R_t$ 與動態有效防守價 $P_{\text{stop, active}}$）、波段目標價 $P_{\text{target}}$；計入來回摩擦成本率 $c_{\text{fric}} = 0.585\%$，算出實質停損幅度 $a$、實質淨獲利幅度 $b$、淨盈虧比 $B = b/a$ 及單位風險期望值 $E[R] = p \cdot B - q$。
- **明確列出「分數凱利倉位與風險預算」（嚴格代入第 3.2 與 3.4 節公式）**：計算理論全凱利風險（$r^* = p - q/B$）、實戰單筆風險預算（$r_{\text{actual}} = \kappa_{\text{regime}} \times \kappa_{\text{dd}} \times \min(k_{\text{frac}} \cdot r^*, r_{\max})$）、目標持倉比例（$f_{\text{actual}}$）與應持有股數（$N_{\text{shares}}$，採盤中零股精確股數），並檢核目前部位是否已達 $R_t \ge +1.50R$ 脫離成本區、將停損上移至保本價 $P_{\text{stop, BE}}$ 而釋放「在險資金（Portfolio Heat）」。
- **明確告訴我接下來「如果遇到什麼狀況要加碼多少」**：依第 3.5 節動態金字塔加碼公式，寫清楚底倉保本（$R_t \ge +1.50R$）後的順勢 $0.5R$ 金字塔加碼觸發價位與精確加碼股數 $N_{\text{add}}$（嚴禁在 $R_t < 0$ 虧損狀態向下攤平；若不符加碼條件則給予「無」）。
- **明確告訴我接下來「如果遇到什麼狀況要減碼多少」**：依第 3.5 節 P0～P5 六道出場防線，寫清楚觸發初始／動態停損 $P_{\text{stop, active}}$、P2 時間停損、P3 目標 $+2.5R$ 減碼 $50\%$、P4 末升段乖離／爆量長黑 $\sigma^2$ 暴增減碼、或 P5 跌破 $\text{MA}_{10}/\text{MA}_{20}$ 移動停利之具體價位與減碼股數（若無立即減碼動作亦須標明盤中觸價停損防線與股數）。
- **明確列出「凱利三層防線與防破產五大鐵律檢核」**：包含第 4.2 節流動性門檻 $\text{Reject}_{\text{liq}}$、季財報現金流與應收帳款／存貨防雷檢核 $\text{Reject}_{\text{fraud}}$、單一持股上限 $f_{\max}$ 與同族群 $40\%$ 集中度檢核。

# 分析指定個股

與 `# 分析持股` 採用完全相同的數學公式與檢核標準，分析 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/短期交易指定名單.md]] 裡面的指定股票（先提供全方位量化檢核總表，再逐檔列出包含 $S_{\text{stock}}$、$TC$、$p$、$P_{\text{entry}}$、$P_{\text{stop}}$、$a$、$P_{\text{target}}$、$b$、$B$、$E[R]$、$r^*$、$r_{\text{actual}}$、$f_{\text{actual}}$ 與核定買進股數 $N_{\text{shares}}$ 之完整分析卡片，最後於文末提供「次日交易策略」掛單指令彙整與處置後風控指標）。

# 複查

請根據 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/📔資源/John-Larry-Kelly/Kelly-Criterion.md]] 指導手冊再次對 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⌚️暫存/✅交易決策_John-Larry-Kelly.md]] 進行嚴格數學驗算與格式複查：
1. 檢查大盤計數 $S_{\text{mkt}}$ 與每檔個股之四維分數 $S_{\text{stock}}$、真實計數 $TC$、條件勝率 $p$、停損幅度 $a$、獲利幅度 $b$、盈虧比 $B$、期望值 $E[R]$ 與凱利股數 $N_{\text{shares}}$ 是否均由公式精確算出，無任何主觀概算或前後矛盾。
2. 檢查每檔股票的交易決策標籤是否嚴格符合 [[Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數/交易決策標籤.md]] 的 9 種標準標籤定義。如果有需要修正的地方請直接修改文件。
