## Context

`refactor-rename-expense-to-reimbursement` 已於同日 archive，`useReimbursementStore` / `Reimbursement` 已全面到位，`Expense` identifier namespace 已清空。動機請見 `proposal.md - Why`。

現況：`views/admin/ExpensesView.vue` 是 empty state stub、`admin-expense-new` route 尚未存在、`frontend/src/api/` 目錄空。此 change 進行「從無到有的新模組建置」。

雙 model 決策見 `docs/資料模型.md` §一：`Expense.source`（enum）+ `sourceRefId`（→ Reimbursement.id）用於將來雙向連動。但 Phase 4 才做 store 層連動；本 change 只在 view 層讀 reimbursements store 做映射。

**本文件已於 2026-09-07 大幅更新**：反映類別擴充為 13 簡化會計科目、拿掉付款動作、以及表單設計重構（去 tab、單一表單、稅率選擇器、品項、自訂 tags、發票/收據 radio）。

## Goals / Non-Goals

**Goals:**

- 一份 `Expense` model 覆蓋一般支出 + 已核准代墊款 union 呈現的需要
- 新增支出頁單一表單完成 OCR / 手動兩種路徑；Excel 匯入拆成獨立 Dialog（批次流程與單筆不同性質，各自 UX 更清爽）
- 支出列表雙 source 合流讀取但視覺上一眼看得出來源
- 產出可交 Stage B 的 TS API 契約，Stage C 串接時 component 不用動

**Non-Goals:**

- 不做 store 層 Reimbursement ↔ Expense 雙向連動（Phase 4）
- 不做真的 OCR / xlsx parse / 檔案上傳（Stage B 才處理）
- 不做重複發票偵測（Phase 7）
- 不做事後標記/取消付款動作（Decision 8）
- 不做真的稅率特殊情境（外幣、進口關稅等）



## Decisions

**Decision 1：代墊款核准時真正建立 Expense record（原 view-mapping 廢棄）**

- **選擇**：`Reimbursement` 加 `expenseId: string | null`。Admin 於 `ReviewView` 通過代墊款時開 `ApproveWithExpenseDialog`：
  - Dialog 內有 checkbox「同時建立支出？」（**預設勾選**）
  - 若勾選 → 展開會計科目 / 付款狀態 / 自訂類別 tags 3 欄，admin 補齊後確認 → store 執行 `approveCurrentStep`（Reimbursement.status → approved）+ `useExpenseStore.addFromReimbursement(...)` 建立 Expense（source='reimbursement'）+ 雙向連動 `Reimbursement.expenseId = 新 Expense.id`
  - 若未勾選 → 只執行 approve；`Reimbursement.expenseId` 保持 null
- `ExpensesView.vue` **直讀 expenses store**，不再 view-mapping 代墊款
- 已處理清單看每筆的支出狀態：`expenseId=null` 顯示「未成立支出 + 新增支出按鈕」；不為 null 顯示「已成立支出」
- **理由**：使用者提出的原則「代墊款要通過簽核才成為支出」在 view-mapping 下無法成立（半假的 Expense 資料缺 documentType/taxRate/tags/items 等 Expense-only 欄位）。把 Phase 4 的雙向連動提前到 Phase 1 收尾階段合流；Reimbursement 資料模型的 `expenseId` 早已規劃好、承接毫無阻力
- **代價**：Phase 1 scope 明顯變大（ReviewView / ExpensesView / PayoutView / mocks 都要動）；ApproveWithExpenseDialog 元件新開；PayoutView 需在 mark-paid 時透過 `expenseId` 反向連動更新 Expense
- **替代方案**：保留 view-mapping（原設計）→ 拒絕，會讓 Categories/Budgets Phase 2/3 踩到同樣資料半空問題

**Decision 2：主表單憑證只接受圖片；單筆流程統一走「開始辨識」**

- **選擇**：新增支出頁的憑證上傳區僅接受 jpg/png 兩種圖片格式；PDF 移到列表「匯入」入口（見 Decision 3）。上傳圖片後憑證下方顯示「開始辨識」按鈕；點擊觸發 stub OCR → 填欄位 → toast「辨識完成」
- **理由**：單筆流程與批次流程的心智模型不同：單筆是「一張照片一筆支出」，批次是「一份文件多筆支出」。PDF 通常是掃描整份或多頁憑證，語意上屬於「批次匯入」的範疇。把兩者分開，主表單心智模型單純；批次匯入 Dialog 也有明確定位
- **代價**：使用者若拿到單張發票的 PDF，需要透過「匯入」入口而非主表單，動線多一層；使用者教育成本
- **替代方案**：主表單也接受 PDF → 拒絕，會讓「單筆 vs 批次」兩種模式糊掉；且 PDF 多頁的處理邏輯應集中在一個地方

**Decision 3：批次匯入 Dialog 統一收 PDF + Excel，也走「開始辨識」流程**

- **選擇**：支出列表 header 右上角「匯入」次要按鈕，開 `BatchImportDialog`；Dialog 接受 PDF 或 xlsx；上傳後顯示檔案卡片與 Message severity="info"「示範用途，實際解析由後端整合」+「開始辨識」按鈕；點擊「開始辨識」→ 1.5s stub loading → 直接呼叫 `expenses.stageImportedPages(drafts)` + 關閉 Dialog + 導向 `/admin/expenses/new`（N pages loaded）；**Dialog 內不顯示預覽 DataTable**（2026-09-08 決策：預覽動線改由表單頁分頁 UI 承擔，減少一次點擊）；表單頁 `fromImport = true` 時憑證上傳區塊隱藏，使用者只做欄位核對後按「建立」一次建立全部
- **理由**：PDF 與 Excel 都是「一份檔案 → 多筆支出」的批次匯入語意，UX 應該一致；統一的「開始辨識」動作跟主表單心智模型也一致（無論檔案類型，都要經過辨識這一步）；載入到分頁表單讓使用者有機會 review／編輯每一筆，比「全部匯入直接建立」安全
- **代價**：多維護一個元件（`BatchImportDialog.vue`）；stub 資料要準備 PDF 與 Excel 兩套（可先共用同一組）；批次匯入的動線多一步「載入表單編輯」
- **替代方案 1**：Excel 匯入直接建立（原「全部匯入」）→ 拒絕，缺乏 review 機會，錯誤發現太晚
- **替代方案 2**：PDF 走主表單、Excel 走 Dialog → 拒絕，兩種批次入口違反一致性原則

**Decision 4：類別下拉採 13 個簡化會計科目**

- **選擇**：`GENERAL_EXPENSE_CATEGORY_OPTIONS` 內含 13 個簡化會計科目（交通費/差旅費/伙食費/文具用品/郵電費/水電瓦斯費/廣告費/交際費/修繕費/教育訓練費/保險費/租金支出/其他費用），並附 `CATEGORY_ACCOUNT_CODES` 對照代碼（供 Select 選項右側顯示）；`ExpenseCategory` union 擴充涵蓋這 13 項 + 保留舊 material/tool/service
- **理由**：`docs/產品規格文件.md` §7 定位「保留簡化的會計科目對應」；13 項為台灣中小企業常見的營業費用 subject。附代碼便於行政人員未來對照傳票
- **代價**：`ExpenseCategory` union 變長；Phase 2 categories store 上線時 hardcoded 仍必移除
- **替代方案**：只維持 3 個過渡類別 → 拒絕，跟規格文件方向不符

**Decision 5：新 STORAGE_KEY 用 v2 後綴**

- **選擇**：`useExpenseStore` 的 `STORAGE_KEY` 用 `'quickey.expenses.v2'`
- **理由**：前一個 change 已把舊 key `'quickey.expenses'` 廢棄；避免 dev 環境切換分支拿到不同 schema 的 JSON
- **代價**：命名多一個字元；正式後端連 API 時 localStorage 不再是資料源

**Decision 6：view 內合流資料的排序**

- **選擇**：依 `date`（費用發生日）DESC 排序；相同日期時 `Expense` 優先於 `Reimbursement`
- **理由**：使用者最常問「這個月花了什麼」；日期 DESC 是最直覺順序

**Decision 7：API 契約檔的 endpoint 命名**

- **選擇**：`PATCH /expenses/:id/pay`（動詞化子資源）而非 `PATCH /expenses/:id { payoutStatus: 'paid' }`；`revert-pay` 同理
- **理由**：`/pay` 有明確語意（不僅改 status，還要記 payoutDate、method、可能觸發通知）；後端 RESTful 設計比較好對照
- **註**：MVP UI 不呼叫 pay/revert-pay 兩個 endpoint（見 Decision 8），但契約仍保留給 Stage B 後端依據

**Decision 8：MVP 不做事後付款動作，也不記錄付款方式**

- **選擇**：付款狀態於「新增支出」表單建立當下決定（`pending` / `paid`）；`paid` 時記 `payoutDate` 為當下日期。**Expense 不含** `payoutMethod` **欄位**（付款方式在一般支出情境不重要 — MVP 只在乎「錢花到哪裡」，不在乎「用哪個管道付」）。支出列表**不含**「標記已付款」/「取消付款」按鈕、也**不顯示付款方式欄**
- **理由**：Quickey MVP 定位是「錢花到哪裡」而非「付款流程管理」；使用者行政人員通常已知付款狀態才登錄，事後改狀態的頻率不高。省掉事後標記付款可以讓列表 UX 更簡單；付款方式對一般支出（例如廠商發票、訂閱費）的分析價值有限，且會讓表單多一個 conditional 欄位、列表多一欄
- **代價**：使用者若真的登錄後才付款，需要進「編輯」流程改狀態（此 change 也不做 edit route；Phase 2 才補）；`payoutStatus` / `payoutDate` 欄位仍留在資料模型（供 Reimbursement 對照與後端 API 契約使用）
- **保留**：`PaymentMethod` type 與 `PAYMENT_METHOD_OPTIONS` 常數 — 因為 Reimbursement 的 `paymentMethod` 仍在使用（PayoutView 發放時要選）
- **替代方案 1**：保留列表付款動作 → 拒絕，會與 Reimbursement PayoutView 動作範圍混淆
- **替代方案 2**：Expense 保留 `payoutMethod` 給後端未來擴充 → 拒絕，MVP 資料模型應該精簡；後端未來要加時再擴充 Expense 型別，不會是難改變的地方

**Decision 9：表單去 tab、統一單一表單**

- **選擇**：原設計 4 tab（拍照 OCR / 文件上傳 / Excel 匯入 / 手動建立）改為單一表單，主表單處理圖片憑證 OCR + 手動輸入；PDF / Excel 統一走列表 header 的「匯入」Dialog
- **理由**：見 Decision 2 & 3；tab 分流反而增加認知負擔
- **代價**：單頁元件更多；需注意手機版分區清晰

**Decision 10：稅率並排 3 欄設計**

- **選擇**：金額區塊改為 3 欄並排：未稅金額 `InputNumber` / 稅率 `Select`（`'business_5'` 營業稅 5% / `'exempt_0'` 免稅或收據 0%）/ 含稅金額 `InputNumber`。稅率下方顯示「營業稅額為 X 元」的即時計算文字。未稅 ↔ 含稅 雙向連動：編輯任一邊自動反推另一邊；切換稅率時未稅保留、含稅重算
- **理由**：參考截圖設計；台灣發票區分「銷售額（未稅）」與「總計（含稅）」，此設計使用者可從任一欄位起頭填寫；符合「二聯式發票請將總計填含稅」的實務
- **代價**：需維護雙向連動邏輯（避免無限循環：用 `updating` flag 或明確的 event source 判斷）
- **stub 資料**：OCR 帶入 `taxRate='business_5'`、`preTaxAmt=1200`、`amount=1260`（稅額 60）

**Decision 11：品項欄位手動 + OCR 兩用**

- **選擇**：品項區塊為列表（每列：品項名稱、數量、單價、小計）；使用者可「新增品項」或「刪除某列」；`subtotal` 由 `quantity × unitPrice` 自動計算；OCR 觸發時 stub 自動填入 2–3 筆假品項
- **理由**：`docs/資料模型.md` §2.3 已定義 `ExpenseItem`，此 change 也在 domain type 加入；發票通常多品項，OCR 也常見多筆識別結果
- **代價**：手機版空間有限，品項列可能需水平滾動
- **stub 資料**：OCR 觸發時填 `[{name:'A4 影印紙',quantity:3,unitPrice:200,subtotal:600},{name:'原子筆',quantity:10,unitPrice:60,subtotal:600}]`

**Decision 12：自訂類別多選 chip autocomplete**

- **選擇**：自訂類別（`tags: string[]`）為 chip 多選 autocomplete；suggestions 來自 `useExpenseStore` 的 `allTags` computed（歷史 tags 匯總去重）；使用者可鍵入新 tag（Enter 加入）；一筆支出可 0 至多個 tags
- **理由**：使用者需要在會計科目之外另有「專案 / 項目」維度標記；tag 是最靈活的模型；autocomplete 兼顧新增與重用
- **代價**：Tag 命名可能發散（Mitigation：Phase 2 可考慮「管理 tags」頁做整理；MVP 讓使用者自由累積）
- **資料存儲**：`Expense.tags: string[]`；空陣列表示未標

**Decision 13：發票／收據 radio + 發票號碼格式驗證**

- **選擇**：表單加 `documentType` radio（`'invoice'` 發票 / `'receipt'` 收據），預設「發票」。發票號碼欄位驗證條件依 `documentType`：
  - `'invoice'`：**必填**、格式 2 英文碼 + 8 數字碼（可含或不含連字號，e.g. `AB-12345678` 或 `AB12345678`）
  - `'receipt'`：**選填**、不驗證格式
- **理由**：台灣統一發票號碼固定格式；收據沒有標準號碼；分開處理避免使用者填收據時被卡格式
- **代價**：多一個 radio；表單邏輯多一個分支
- **regex**：`/^[A-Za-z]{2}-?\d{8}$/`

**Decision 14：OCR 手動觸發「開始辨識」按鈕，填入欄位可編輯**

- **選擇**：使用者上傳憑證後**不自動觸發 OCR**；憑證下方出現「開始辨識」按鈕，點擊才啟動 stub 流程（1.5s loading → 填欄位 → toast「辨識完成」）。填入的所有欄位（含日期、廠商、金額、品項）**皆保持可編輯**
- **理由**：自動觸發 OCR 會讓使用者一上傳就看到欄位被覆蓋，若剛好使用者已手填一些欄位會被沖掉；改成明確按鈕觸發，使用者對「什麼時候辨識」有主導權。填入欄位保持可編輯是符合「OCR 是輔助不是主宰」的精神
- **代價**：多一個「開始辨識」按鈕的 UI 元素；使用者需要明確操作才會看到辨識結果
- **stub 觸發條件**：只要當前有至少一個 attachment 就可觸發；重複點擊會覆蓋現有欄位（MVP 選直接覆蓋以簡化）

**Decision 15：新增支出頁欄位順序**

- **選擇**：欄位由上到下順序為：
  1. 憑證上傳
  2. 開始辨識 button（conditional）
  3. 發票／收據 radio
  4. 交易日期 / 統一編號 / 廠商 / 發票號碼（grid）
  5. **稅率並排 3 欄**（未稅 / 稅率 / 含稅）
  6. **品項列表**
  7. **費用類別 + 付款狀態並排**
  8. **自訂類別 tags**
  9. 備註
- **理由**：先讓使用者填「單據上有的資訊」（發票類型、發票欄位、金額、品項）— 這些是 OCR 主要能填的欄位；再讓使用者填「組織自己的分類資訊」（會計科目、付款狀態、自訂 tags）— 這些是使用者判斷；最後才是備註（自由文本）。分類欄位放在後面也符合「先看資料、再決定歸類」的思考順序
- **代價**：跟前版設計不同，需 QA 特別對照確認
- **替代方案**：分類欄位放前面 → 拒絕，OCR 填入的欄位分散在上下兩區塊會讓 review 流動線斷裂

**Decision 16：分頁表單支援多筆支出**

- **選擇**：`ExpenseFormView.vue` 內部維護 `pages: FormPageData[]` 陣列與 `currentPageIndex: number`；每頁 = 一項支出。當 `pages.length > 1` 時，於「建立」按鈕上方顯示 `ExpenseFormPagination` 元件：
  - 左：文字「第 X 筆 / 共 Y 筆」
  - 中：prev button `<` + N 個 dot（active 為 primary 圓角矩形、其他為灰圓點）+ next button `>`
  - 整體 pill 容器（rounded-full + 白底 + border）
- 觸發多頁的場景：
  1. **「匯入」Dialog 載入 N 筆（PDF/Excel）** → 導向新增支出頁 with N pages（Decision 5）
  2. 主表單「手動新增／上傳圖片」路徑一律單頁：每張表單只能上傳 1 張憑證，OCR 產生單頁 stub；多張收據場景改走批次匯入 Dialog
- 「建立」動作：逐頁驗證；有錯 → 跳至該頁 focus 錯誤欄位；通過 → 一次建立所有頁面的 Expense
- 切頁邏輯：切頁前將當前頁的表單狀態同步回 `pages[currentPageIndex]`；切至新頁時載入 `pages[newIndex]` 到表單狀態
- **理由**：批次匯入 UX 需要讓使用者逐筆檢視；分頁比 accordion / list 更聚焦（一次看一筆的完整表單）；分頁元件也適合手機版
- **代價**：分頁 state 管理複雜（unsaved edit + 多頁驗證）；QA 要測「切頁時未儲存的變更」
- **替代方案 1**：每筆獨立 route 導覽 → 拒絕，切頁動畫斷裂、URL 難管
- **替代方案 2**：所有筆展開為 accordion / 長清單 → 拒絕，手機版體驗差
- **不支援**：使用者手動新增 / 刪除頁面（MVP 不做；頁面數只由 OCR / 匯入決定）



## Risks / Trade-offs

- **Risk：view 層映射導致代墊款來源列的操作範圍不清** → Mitigation：代墊款列只顯示「到發放頁」按鈕；一般支出列則完全不含付款動作（Decision 8）；視覺上就分辨清楚
- **Risk：Phase 2 忘記移除** `GENERAL_EXPENSE_CATEGORY_OPTIONS` → Mitigation：常數上方註解明確標示 Phase 2 移除、在 spec Requirement「簡化會計科目下拉」內以 scenario 綁死
- **Risk：批次匯入 Dialog 讓 QA 誤以為系統會真的解 PDF / xlsx** → Mitigation：Dialog 上方寫「示範用途、實際解析由後端整合」
- **Risk：稅率雙向連動邏輯錯誤（無限循環或計算不對）** → Mitigation：用單一 source of truth（例如「使用者最後編輯的欄位」）驅動計算；含稅四捨五入到整數；QA 時要對 5% / 0% 都測正反向
- **Risk：Tags 命名發散導致篩選無用** → Mitigation：MVP 先讓使用者累積；Phase 2 可加「管理 tags」頁；autocomplete 已優先推薦歷史 tags 減少重複輸入
- **Risk：發票號碼格式驗證擋掉合法輸入** → Mitigation：regex 允許有無連字號兩種格式；選收據時完全不驗證
- **Risk：品項列表在手機版空間不夠** → Mitigation：手機版品項列表水平滾動；或改為每列展開卡片式
- **Risk：分頁表單切頁時未儲存的變更遺失** → Mitigation：切頁 handler 先 sync 當前表單狀態回 `pages[currentPageIndex]` 再切至新頁；page-level state 存於陣列避免因為 form ref 重建而遺失
- **Risk：多頁「建立」時任一頁失敗處理不清** → Mitigation：MVP 用「先全部驗證通過才建立」策略；不允許部分成功；有錯 → 跳至該頁；建立階段若後端失敗（未來 API 串接），全部 rollback



## Migration Plan

Prototype 階段無 production migration；dev 階段：

1. 新 `useExpenseStore` 首次啟動時從 seed 載入
2. 若使用者 dev localStorage 有舊 `quickey.expenses`（rename 前的舊 key），無害保留 — 沒 code 會讀它
3. 建議 QA 前執行 `localStorage.clear()` 或用無痕視窗



## Open Questions

- 批次匯入 Dialog 的假資料筆數與內容？→ 建議：PDF stub 3 筆、Excel stub 3 筆，均用相同 3 筆資料：`travel: 350`（交通費）、`meal: 220`（伙食費）、`office: 890`（文具用品），涵蓋 3 個常用科目、金額量級不同
- 未稅 ↔ 含稅 計算四捨五入策略？→ 建議：含稅 = round(未稅 × (1 + rate))；未稅 = round(含稅 / (1 + rate))；避免因浮點誤差顯示 999.9999
- OCR 觸發後若使用者已填部分欄位，是否要 confirm？→ 建議 MVP 直接覆蓋不 confirm，簡化流程；後續依使用者回饋調整
- Tags 是否支援中英混合？→ 是；無限制字元集；MVP 不做 trim / 大小寫合併
- 主表單上傳多張圖片時的 OCR 行為？→ 已定案（2026-09-08）：主表單不支援多張圖片；`<input type="file">` 移除 `multiple`、`attachments` 上限為 1、`startRecognize` 固定單頁；「多張收據」場景由「匯入」Dialog（PDF/Excel）承接（Decision 5 + 16）
- 分頁狀態下的離開頁確認？→ 建議：任一頁 dirty 就觸發離開確認（沿用單頁時的 onBeforeRouteLeave 邏輯）



## Additional Decisions (2026-09-07 追加)

**Decision 17：核准代墊款 Dialog 的預設策略**

- **選擇**：`ApproveWithExpenseDialog` 內 checkbox「同時建立支出？」**預設勾選**；若使用者取消勾選則 dialog 只需顯示簽核意見輸入（下方 3 欄支出補齊欄位收起）
- **理由**：大多數情境 admin 通過代墊款就是要立即列入公司支出；「暫緩建立」是少數情境。預設勾選節省點擊
- **代價**：若 admin 忘記檢查 checkbox，可能誤建 Expense（Mitigation：dialog 標題明確、下方欄位一展開就看得到）
- **暫緩建立情境**：例如 admin 尚未決定會計科目、想先跟財務討論；或該筆代墊款尚有其他資料等 clarification

**Decision 18：前台員工提交請款頁類別下拉改用 13 個簡化會計科目**

- **選擇**：`front/ExpenseFormView.vue` 的類別 Select 綁 `GENERAL_EXPENSE_CATEGORY_OPTIONS`；**只顯示中文名稱、不顯示會計代碼**（員工不需要看代碼）
- **理由**：員工提交時就正確分類，admin 審核時 dialog 內的會計科目欄位可直接沿用 `Reimbursement.category`；避免員工亂選導致 admin 每次都得重新分類
- **代價**：舊代墊款 mock 的 material/tool/service 類別會與新選項不一致（Mitigation：舊 seed 直接更新為新科目；`ExpenseCategory` union 保留 material/tool/service 給既有 mock 型別相容，但選單不列）
- **員工友善**：Select 選項排序按使用頻率放（交通費 / 差旅費 / 伙食費 / 文具用品 靠前，其他往後）

**Decision 19：ReviewView「已處理」清單支出狀態欄**

- **選擇**：已處理清單加「支出狀態」欄，依 `Reimbursement.expenseId` 顯示：
  - `expenseId != null`：chip「已成立支出」+ 額外顯示對應 Expense 的付款狀態（若 paid → 「已付款」次要 chip）
  - `expenseId == null` 且 `status='approved'`：chip「未成立支出」（琥珀色）+「新增支出」outlined 按鈕；點擊開同一 dialog（`isApproveOnly=true` mode，只需補建立支出，不再顯示簽核意見）
  - `status='rejected'`：不顯示支出狀態欄（駁回不會建立支出）
  - `status='voided'`：顯示「已作廢」chip；作廢前若已成立 Expense 該 Expense 也 soft-void（未來擴充；MVP 不做）
- **理由**：讓 admin 明確看到每筆核准的處理狀態，「未成立支出」是可 actionable 的狀態
- **代價**：ReviewView 表格新增一欄

