# OCR 辨識規格

> 範圍：新增支出、代墊款、收入三個表單共用的憑證 OCR 辨識。
> Vendor：Google Document AI（Enterprise Document OCR 取全文，後端用規則抽欄位）；見技術選型 §6 與本文件 §3。
> 存檔策略：OCR 回傳不觸發後端存檔；原始檔由 Expense / Income / Reimbursement 的 attachments 流程另行處理。
> **策略**：多張憑證**每張獨立送 Document AI 辨識**，後端比對後回「可自動合併的欄位」+「衝突清單」給前端跳彈窗讓使用者挑。

## 1. 端點

```
POST /api/ocr/recognize
Content-Type: multipart/form-data
Authorization: Bearer <jwt>
```

### Request fields

| 欄位 | 型別 | 必填 | 說明 |
|---|---|---|---|
| `files[]` | File | ✓ | 1–5 張；支援 image/jpeg, image/png, image/webp, image/heic, application/pdf；單檔 ≤ 5 MB（與憑證附件上限一致，共用後端 `ReceiptAttachmentValidation::MAX_COUNT` / `MAX_FILE_BYTES`） |
| `role` | string | ✓ | `expense` / `reimbursement` / `income`；決定「我方 vs 對方」欄位對應 |

多檔語意：「同一張憑證的多個鏡位 / 分段拍 / 多頁 PDF」。後端**對每個檔案獨立呼叫** Document AI，再把結果 normalize 後比對衝突，回單一 response。要辨識多張**不同**憑證請走批次匯入另案，不走這支 endpoint。

計費單位：**每張圖 / 每頁 PDF = 1 次配額**。多檔混 PDF 的場景會按 Document AI 回傳的實際頁數累計（例如 3 檔含一份 5 頁 PDF = 7 次）。扣次數**只在 Document AI 成功回傳時**發生；格式錯誤、檔案過大被擋下不扣次。

## 2. Response

### Success (200)

```json
{
  "merged": {
    "documentType": "invoice",
    "incurredAt": "2026-10-15",
    "ourTaxId": null,
    "ourName": null,
    "counterpartyTaxId": "87654321",
    "counterpartyName": null,
    "invoicePrefix": "AB",
    "invoiceDigits": "98765432",
    "taxRate": "business_5",
    "preTaxAmt": 1200,
    "taxAmt": 60,
    "amount": 1260,
    "items": [
      { "name": "A4 影印紙", "quantity": 3, "unitPrice": 200, "subtotal": 600 }
    ]
  },
  "conflicts": {
    "fields": [
      {
        "field": "counterpartyName",
        "candidates": [
          { "value": "福華文具行", "sourceIndex": 0, "confidence": 0.91 },
          { "value": "福華文具", "sourceIndex": 1, "confidence": 0.74 }
        ]
      }
    ],
    "items": [
      {
        "candidates": [
          { "item": { "name": "鉛筆", "quantity": 3, "unitPrice": 20, "subtotal": 60 }, "sourceIndex": 0 },
          { "item": { "name": "鉛筆", "quantity": 5, "unitPrice": 20, "subtotal": 100 }, "sourceIndex": 1 }
        ]
      }
    ]
  },
  "confidence": {
    "overall": 0.87,
    "lowFields": ["counterpartyName"]
  },
  "warnings": ["counterpartyName 有多個候選值，請人工確認"],
  "quota": {
    "used": 1,
    "monthlyRemaining": 97,
    "purchasedRemaining": 50
  }
}
```

`merged` = 已能自動合併或只有單一來源的結果，可直接 bind 到表單。**列在 `conflicts.fields` 的欄位，`merged` 裡一律為 `null`**（等使用者在彈窗挑選；彈窗沒選就保持空白）。
`conflicts.fields` = 多張都辨識出但值不同的頂層欄位；每個 field 的 candidates 給前端跳彈窗讓使用者 radio 選。
`conflicts.items` = 被判定為「可能同一品項」但數量/小計有差的 line_item 群；使用者需挑一個保留。
`quota.used` = 本次扣除的次數（通常 = 傳入檔案的 Document AI 實際頁數）。

### Role → 欄位對應

| role | 「我方」= `ourXxx` | 「對方」= `counterpartyXxx` | 前端綁定 |
|---|---|---|---|
| `expense` | 本公司（買方） | 賣方 | `counterpartyName`→vendor、`counterpartyTaxId`→taxId |
| `reimbursement` | 本公司（買方） | 賣方 | 同上 |
| `income` | 本公司（賣方） | 買方（客戶） | `counterpartyName`→customer、`counterpartyTaxId`→買方統編 |

無法辨識的欄位回 `null`。整張文件完全無法辨識則回 422（見下節），不會回 200 + 全 null。

### Error codes

| HTTP | 代碼 | 情境 |
|---|---|---|
| 400 | `invalid_role` | role 不在白名單 |
| 400 | `invalid_file_type` | 檔案類型不在支援清單（依檔案內容判斷，不採信副檔名）；或沒附任何檔案 |
| 400 | `too_many_files` | 超過 5 檔 |
| 413 | `file_too_large` | 單檔 > 5 MB |
| 422 | `ocr_no_result` | Document AI 全部檔案都回空；請改手動輸入（Google 已成功回傳，**照樣扣次**） |
| 429 | `quota_exhausted` | 本月月費額度 + 加購次數皆用完 |
| 503 | `ocr_unavailable` | GCP 連線失敗 / credentials 缺 / processor 不存在 |

「全部檔案都回空」＝每個檔案都沒抽出任何**表單上看得到的欄位**（日期、對方名稱、對方統編、發票號碼、未稅 / 稅額 / 含稅金額、品項；例如空白或看不清的照片）。只抽到推導欄位（`documentType`、`taxRate`）或表單沒有對應欄位的我方名稱 / 統編，也算回空（2026-10-28 決定：避免顯示「辨識完成」卻什麼都沒帶入，還依覆蓋規則清掉使用者手填的欄位）；抽欄位出錯或逾時的檔案也算回空（見 §3.1 效能與防呆）。

錯誤 payload：`{ "code": "...", "message": "...", "quota": { ... } }`（`quota` 在 429 與 422 時附上；422 有扣次，前端用它更新剩餘次數）。

## 3. Document AI 設定

> **2026-10-27 決策**：由 Invoice Parser 改為 Enterprise Document OCR + 後端規則。原因：Invoice Parser 官方支援語言不含中文，台灣憑證幾乎抽不到欄位；Enterprise OCR 讀字品質相同、較快，費用約為 1/66（每月前 1,000 頁免費）。實測與比較見 `docs/reviews/後端開發-2026-10-27.md`。

| 項目 | 值 |
|---|---|
| Processor type | Enterprise Document OCR（`OCR_PROCESSOR`），只取全文 |
| Region | `us`（本機與測試站共用同一個 processor）。區域不影響辨識語言，只影響資料存放位置與延遲 |
| Processor version | pretrained 預設版 |
| API | 同步 `processDocument`（一次送一份文件） |

後端讀下列環境變數：

| ENV | 用途 |
|---|---|
| `GCP_PROJECT_ID` | GCP 專案 ID |
| `GCP_LOCATION` | processor 的 region |
| `GCP_OCR_PROCESSOR_ID` | Enterprise Document OCR processor id（取代原本的 `GCP_INVOICE_PROCESSOR_ID`） |
| `GOOGLE_APPLICATION_CREDENTIALS` | service account JSON 檔絕對路徑 |

**開發模式**：任一變數缺值時 `/api/ocr/recognize` 回 503 `ocr_unavailable`；不自動 fallback 到假資料（避免正式環境誤跑 stub）。

### 3.1 欄位抽取規則（從全文）

後端對每個檔案的全文套規則，產出 §4 用的內部物件。規則不得依賴文字排列順序（同一張圖，不同 processor 讀出的順序可能不同）。抓不到就回 `null`，**不猜**；同一欄位在同一張憑證上抓到兩個以上**不同**的值（例如同時印了開立日和到期日）也回 `null`。

| 欄位 | 抓法（台灣憑證格式） | 信心度 |
|---|---|---|
| `invoicePrefix` / `invoiceDigits` | 2 碼英文字軌 + 8 碼數字（中間可有 `-` 或一個空白），例如 `FV-63156693`。**全文必須出現「發票」二字（「免用統一發票」不算；全文有「免用統一發票」時一律不抓號碼）**，且號碼前面不能緊接「單號」「編號」「序號」「流水號」「訂單」「帳號」「卡號」等字樣（避免把 `ST12345678` 銷帳編號、`OD20261015` 訂單號當發票號碼）。有多個候選時，優先採用帶 `-` 或字軌與數字相連的寫法；只有找不到這種寫法時，才採用中間是空白的寫法 | 高 |
| `documentType` | 抓到發票號碼 → `invoice`；沒抓到號碼、但全文有「免用統一發票」，或有「收據」且沒有「發票」→ `receipt`；兩者皆無 → `null`（**沒讀到號碼不等於收據**）。推導欄位，不計信心度 | — |
| `incurredAt` | 西元 `YYYY-MM-DD` / `YYYY/MM/DD` / `YYYY MM DD`（空白分隔，超商繳款證明常見）/ `YYYY年M月D日`、民國 `YYY年M月D日` / `YYY/MM/DD`（民國年 + 1911）。換算後年份須在 **2000 年到今年 + 1 年**之間，否則不採用；民國斜線格式前後不能緊接 `/`、英文字母或數字（避免把規格尺寸 `100/12/31` 當日期）。電子發票上的期別（例如「115年09-10月」）不是日期，不採用。已知限制：沒有其他日期時，像「管 100/12/31」這類尺寸仍可能被當成日期（2026-10-27 決定接受；有其他日期時兩個值不同會留空） | 高 |
| 賣方 / 買方統編 | 標籤旁的 8 碼數字，且**必須通過統編檢查碼**（各位數乘 1,2,1,2,1,2,4,1 後把乘積的十位與個位相加，總和能被 5 整除；第 7 碼為 7 時總和或總和 + 1 能被 5 整除即可），不通過的 8 碼數字（流水號、電話、單號）一律不採用。歸屬：**同一行**在號碼前出現「買方」「買受人」→ 買方；「賣方」「統編」→ 賣方；「統一編號」在店章裡（附近有「專用章」）→ 賣方、緊接在「買受人」後或在免用統一發票收據表頭格子裡 → 買方。以上為**高**。「統一編號」不符合前述任何位置而預設當賣方、以及「No:」標籤 → **低**。再依 role（§2 對應表）放進 `ourTaxId` / `counterpartyTaxId` | 高 / 低 |
| `amount` | 「總計」「合計」「實收金額」「應收」「應收金額」後的金額（含「合計新臺幣 … 元整」，只認阿拉伯數字；大寫國字不轉換，抓不到回 `null`）。「銷售額合計」「營業稅額」「數量合計」「件數合計」「共 N 項 / 件」這類行不算含稅金額（但「總計(含營業稅)」仍算）。全文有「找零」時，「實收金額」是客人付的現金，不採用。標籤同一行開頭就是金額時一律採用、不再往下找：金額後面沒有字或接著另一個金額標籤 → **高**，後面還有其他文字 → **低**。標籤後沒有數字、要往下幾行找時，該數字必須帶「$」或接「元」才採用，而且中途遇到「找零」「現金」「付款」「信用卡」「刷卡」等付款相關字樣就停止往下找；往下找到的金額：緊接在標籤下一行（中間沒有其他文字行）→ **高**；隔了兩行以上 → **低** | 高 / 低 |
| `preTaxAmt` / `taxAmt` | 有印「銷售額」「稅額」「營業稅」「營業稅額」才抓（兩者寫在同一行也要抓得到）；沒印回 `null`（交給 §4 稅率推導） | 高 |
| 賣方 / 買方名稱 | 公司全名（含「股份有限公司」「有限公司」「商行」等）或憑證抬頭店名。去掉前面的標籤（「營業人」「賣方」「買受人」，含後接的「名稱」「姓名」）與後面的統編字樣。「買受人」標籤後面是空的時，才取緊接的下一行當買方名稱，且該行不能含數字、不能以「日期」「品名」「數量」「單價」「金額」「地址」「統一編號」等表頭字開頭；被當成買方名稱的那一行不得當成賣方名稱；含電話、6 碼以上連續數字的行不當名稱。手寫收據多在印章裡，常抓不準。已知限制：「買受人」空白、下一行剛好印著賣方店名（例如「福華商行」）時，會被當成買方名稱（2026-10-28 決定接受，已標低信心度） | **低** |
| `items` | 只抓固定格式的明細行（品名 + 單價 × 數量 = 小計，且能對上金額）；格式不固定或對不上就回 `[]`，讓使用者自己填 | **低** |

- 信心度用固定值：**高 = 0.9、低 = 0.5**（不是 Google 回傳的值）。同一欄位依抓到它的規則決定高低（例如同一份 `amount`，同行抓到為高、往下找到為低）。
- **效能與防呆**：所有規則必須在線性時間內跑完（不得寫出會回溯爆量的正規表達式，迴圈也不能隨單行長度變成平方時間）；另設全域正規表達式逾時 1 秒。抽欄位過程中任何錯誤（含逾時）都當作「該檔沒有結果」，該檔頁數**照樣計入扣次**（Google 已計費），並記錄錯誤（不記全文與統編）。
- QR code：Enterprise OCR 不回條碼內容，由後端自己解碼，見 §3.2。

### 3.2 電子發票 QR Code（2026-10-28 決策）

電子發票證明聯上的 QR Code 存的是正確資料，解得出來就不用猜。但照片模糊或感熱紙彎曲時常解不出來（10/27 實測 4 張只有 1 張讀到），所以 **QR 是加分項，OCR 照跑**。

**在後端解碼**（不在前端）：
- 衝突比對、扣次數、角色對應都在後端，QR 結果直接併進同一份結果，三個表單的前端都不用改。
- 現有流程是先上傳照片、再按辨識，不是用相機即時掃描，所以前端解碼的優勢（即時對焦）用不到。

**流程**（每個檔案各自處理；PDF 每一頁都要解，使用者可能把多張電子發票掃成一份 PDF）：
1. 後端先解這張圖（或 PDF 每一頁）裡所有 QR Code，再照常呼叫 Google 抽全文、套 §3.1 規則。PDF 要先把每頁轉成圖片才能解碼，解析度要足夠讓 QR 解得出來。
2. 找到電子發票左邊的 QR（格式見下）且檢查通過 → 這張圖的下列欄位**以 QR 為準**，蓋掉 §3.1 抽出的值，信心度一律**高**。其他欄位（例如賣方名稱，QR 裡沒有）照 §3.1。
3. 解不出來、不是電子發票格式（例如網址）、檢查沒通過 → 當作沒有 QR，結果完全照 §3.1。不另外提示使用者。
4. 解碼失敗或出錯不影響辨識，也不改變回 200 / 422 的判斷；解碼必須設逾時，逾時當作沒有 QR。

**扣次數不變**：每個檔案照樣呼叫 Google、照樣扣次數（QR 裡沒有賣方名稱，而且多數照片解不出 QR）。之後如果實測解碼率高，再評估「QR 解得出來就不呼叫 Google、不扣次數」。

**左邊 QR 的內容**（依財政部〈電子發票證明聯一維及二維條碼規格說明〉，實作以官方規格為準）：

| 位置 | 內容 | 對應欄位 |
|---|---|---|
| 第 1–10 碼 | 發票字軌 2 碼 + 號碼 8 碼 | `invoicePrefix` / `invoiceDigits` |
| 第 11–17 碼 | 民國年月日（7 碼） | `incurredAt`（民國年 + 1911） |
| 第 18–21 碼 | 隨機碼 | 不用 |
| 第 22–29 碼 | 銷售額（未稅，16 進位）；`00000000` = 店家沒把稅額分開 | `preTaxAmt`；`00000000` 時 `preTaxAmt` / `taxAmt` 都不填 |
| 第 30–37 碼 | 總計（含稅，16 進位） | `amount`；`taxAmt` = 總計 − 銷售額 |
| 第 38–45 碼 | 買方統編（`00000000` = 沒有買方） | 依 role 放進 `ourTaxId` / `counterpartyTaxId`；`00000000` 當作沒有 |
| 第 46–53 碼 | 賣方統編 | 依 role 放進 `counterpartyTaxId` / `ourTaxId` |
| 第 54–77 碼 | 加密驗證資訊 | 不用（要財政部金鑰才能驗） |
| 之後以 `:` 分隔 | 營業人自用區（10 碼）、左右兩個 QR 合計記載的品項筆數、發票總品項筆數、中文編碼（0 = Big5、1 = UTF-8、2 = Base64、3 = 境外電商 UTF-8）、接著每 3 段一筆「品名:數量:單價」，最後可能有補充說明 | `items` |

- **QR 裡沒有賣方名稱**：官方規格沒有這個欄位。有些店家會把店名寫進品名（例如「粥師傅 延吉店的訂購商品」），那是品項，不當賣方名稱。

- **右邊 QR** 以 `**` 開頭，接續左邊放不下的品項。
- **檢查**：發票號碼要符合 2 碼英文 + 8 碼數字；日期換算後要在 §3.1 的年份範圍內；賣方統編要通過檢查碼；總計 > 0 且 ≥ 銷售額。任一項不通過就整個 QR 不採用。
- **銷售額 = 總計**（算出來稅額是 0）：有些收銀機會把含稅總額填進銷售額，分不出是免稅還是填錯，所以跟 `00000000` 一樣，`preTaxAmt` / `taxAmt` 都不填，`taxRate` 也不推導（照 §4 第 2 條，「算出來的 0」不算免稅）。（2026-10-28 決定）前端照 §6 帶入規則：稅率預設 `business_5`，再用含稅總額自動算出未稅與稅額（例如總計 90 → 未稅 86、稅額 4），由使用者核對修改（2026-10-28 Peggy 確認維持）。
- **品項**：「左右 QR 合計記載的品項筆數」等於「發票總品項筆數」，而且實際解出的品項數也對得上時，才用 QR 的品項（小計 = 數量 × 單價，信心度高）取代 §3.1 的品項；筆數對不上（例如右邊 QR 沒解出來）就不用 QR 的品項，照 §3.1。
- `documentType` = `invoice`；`taxRate` 照 §4 稅率推導。
- **同一個檔案裡有多張不同號碼的電子發票**（2026-10-28 Peggy 決定）：
  - 新增單一支出 / 收入 / 代墊款（本 endpoint）：衝突彈窗**整張挑一張**，不逐欄挑，避免挑出第 1 張的金額配第 2 張的號碼。
    - 本次送的檔案中，只要有任一個檔案解出 2 張以上不同號碼的發票，回應就多一個 `conflicts.invoices`，列出本次**所有**解出的發票（跨檔案、號碼相同只列一次）：
      ```json
      "conflicts": {
        "fields": [ ... ],
        "items": [ ... ],
        "invoices": [
          { "sourceIndex": 0, "invoiceIndex": 1, "fields": { "invoicePrefix": "EU", "invoiceDigits": "04855261", "incurredAt": "2026-10-18", "preTaxAmt": 143, "taxAmt": 7, "amount": 150, "ourTaxId": null, "counterpartyTaxId": "70768666", "documentType": "invoice", "taxRate": "business_5" }, "items": [ { "name": "統一藥品", "quantity": 1, "unitPrice": 150, "subtotal": 150 } ] },
          { "sourceIndex": 0, "invoiceIndex": 2, "fields": { ... }, "items": [ ... ] }
        ]
      }
      ```
    - `invoiceIndex`：該發票在自己檔案裡的順序，從 1 開始；先看 PDF 頁序，同一頁由上到下、由左到右。`fields` 放 QR 有的欄位，加上按頁抽到的名稱（見下）；品項不齊全時 `items` 為 `[]`。
    - 有 `conflicts.invoices` 時，QR 有的欄位（發票號碼、日期、金額、稅額、統編、`documentType`、`taxRate`）、名稱（`ourName`、`counterpartyName`）和品項**不進** `merged` / `conflicts.fields` / `conflicts.items`，`merged` 裡這些欄位為 `null`、`merged.items` 為 `[]`。
    - **名稱按頁對應**（2026-10-28 Peggy 決定）：QR 裡沒有名稱，名稱改從該發票**所在那一頁**的文字照 §3.1 抽，放進該發票的 `fields`（信心度低）。同一頁有 2 張以上發票時分不出哪個名稱屬於哪張，該頁發票的名稱都不填，讓使用者自己輸入；寧可空白，不帶錯的店名。圖片檔視為一頁。
    - 前端：衝突彈窗先問一題「要用哪一張發票？」，每個選項標「憑證 N 的第 K 張發票」並列出號碼、日期、金額。選一張就整組帶入它的 `fields` 和 `items`（代墊款不帶品項）；沒選就關掉，這些欄位維持空白。
    - 沒有任何檔案出現多張發票時，不回 `conflicts.invoices`，一切照 §4，現有前端不受影響。
  - 同一張發票的左右 QR、或同一張發票在 PDF 裡重複出現（號碼相同）只算一張。
  - 批次匯入 PDF：要能一張發票新增一筆，見 §8（另案）。
- **前端圖片壓縮**：前端上傳時會把圖片壓成長邊 1600px、約 1MB 的 JPG。QA 要確認壓縮後的電子發票照片還解得出 QR；解不出來的比例高的話，再調整壓縮設定。

## 4. 多檔辨識與衝突解析

### 流程

1. 使用者送 N 個檔案（1 ≤ N ≤ 5）
2. 後端對每個檔案獨立呼叫 Document AI；PDF 多頁一次 call 回多頁結果
3. 把每份原始回應 normalize 成內部物件 `[{ sourceIndex, fields, items, confidence }]`
4. 逐欄位比對 → 分流到 `merged` 或 `conflicts`
5. 扣配額（實際頁數）
6. 回應前端

### 頂層欄位比對規則（完全比對；不做模糊）

對每個頂層欄位（`documentType`、`incurredAt`、`ourTaxId`、`ourName`、`counterpartyTaxId`、`counterpartyName`、`invoicePrefix`、`invoiceDigits`、`taxRate`、`preTaxAmt`、`taxAmt`、`amount`）：

| 情境 | 結果 |
|---|---|
| 只有 1 張辨識出來 | 進 `merged` |
| 多張都辨識出且值完全相同 | 進 `merged` |
| 多張都辨識出但值不同 | 進 `conflicts.fields`，列所有候選值 |
| 全部都 null | `merged` 該欄位為 null |

字串比較前先做正規化：去頭尾空白、全半形英數字統一；**不**做 Levenshtein 之類的相似度比對。這會多問使用者幾次（例如「福華文具行」vs「福華文具」會被當 conflict），寧可問、不要默默吃掉。

**發票號碼合成一題**（2026-10-27）：回應仍分成 `invoicePrefix` / `invoiceDigits` 兩個欄位，但前端衝突彈窗只要其中任一個有衝突，就合成一題「發票號碼」，每個候選顯示該張憑證的完整號碼（例如 `FV-63156693`；沒衝突的那半邊用 `merged` 的值補上）。選一張就同時帶入字軌和數字，避免挑出 `FV` + `04855261` 這種不存在的號碼。

### 品項（line_items）比對規則

Dedup key：`正規化後的 name + unitPrice`（quantity 不列入 key；因為同一品項分批買可能數量不同）。

分組規則：

1. 把所有張的 items 攤平、按 key 分組
2. 單一來源 group：直接進 `merged.items`
3. 多來源 group，且所有候選的 quantity + subtotal 都相同：進 `merged.items`（取第一個）
4. 多來源 group，但 quantity 或 subtotal 不同：進 `conflicts.items`，列所有候選 item 讓使用者挑一個保留

### 稅率推導

Document AI 不直接回傳 Quickey 的 `TaxRate` enum。對每張單獨推導後再比對：

1. 若發票有「稅額」欄且 `taxAmt / preTaxAmt ≈ 0.05`（允許 ±0.5% 誤差）→ `business_5`；沒有稅額但有 `preTaxAmt` 與 `amount`，且 `(amount − preTaxAmt) / preTaxAmt ≈ 0.05` → 也是 `business_5`
2. 若憑證上印的 `taxAmt === 0` 或 `documentType === 'receipt'` → `exempt_0`（`documentType` 為 `null` 時不適用，見 §3.1；用含稅 − 未稅推算出的 0 不算）
3. 其他 → `null`，前端預設帶 `business_5`

每張推導的結果再進 §4 頂層欄位比對。

## 5. OCR 配額

### 計次

- **1 張圖 = 1 次**；1 頁 PDF = 1 次；一份 N 頁 PDF = N 次
- 只在 Document AI 成功回傳的檔案才扣；格式錯 / 檔案過大 / 配額擋下 / Document AI 失敗（503）**不扣**
- 單次 `/recognize` 回應的 `quota.used` = 本次累計扣除
- 呼叫 Document AI 前只檢查「剩餘次數 ≥ 檔案數」（多頁 PDF 的頁數要辨識完才知道）；辨識完若實際頁數超過剩餘次數，照常回 200、**扣到 0 為止，不扣成負數**（Google 已計費，丟掉結果更浪費）

### 月費額度 vs 加購

每公司兩池次數分開管：

| 池 | 行為 |
|---|---|
| 月費額度 | 月初依公司方案重置；當月用剩歸零。**基本方案每月 50 次**（2026-10-28 由 20 次調為 50 次，之後可能調整） |
| 加購包 | 單獨購買一次給一包；**不過期、永久累積** |

扣除順序：**先扣月費額度，用完才扣加購**。使用者永遠優先消耗當月免費額度，避免「加購沒用到就被月費蓋掉」。

### 超額行為

本月月費 + 加購皆為 0 時：
- `/api/ocr/recognize` 回 **429 `quota_exhausted`**，附上 `quota` 物件
- 前端 toast：「本月 OCR 辨識次數已用完」+ 行動按鈕「前往加購」→ 導到 `/admin/settings/ocr-quota`（頁面另案建；**加購頁上線前不顯示此按鈕**，只顯示文字，避免導到不存在的頁面）
- 不做即時彈窗加購（MVP 尚無金流）

### 誰可以加購

- 管理員：看得到剩餘次數、能進加購頁、能加購
- 員工（代墊款場景）：看得到剩餘次數（表單側邊顯示），**不能**加購；超額時 toast 改成「本月額度已用完，請聯絡管理員加購」

### 資料模型（Company 直接加欄位）

```ruby
# db/migrate/XXXX_add_ocr_quota_to_companies.rb
add_column :companies, :ocr_monthly_quota,       :integer, null: false, default: 20  # 基本方案每月次數
add_column :companies, :ocr_monthly_used,        :integer, null: false, default: 0
add_column :companies, :ocr_purchased_remaining, :integer, null: false, default: 0
add_column :companies, :ocr_quota_reset_at,      :datetime, null: false  # 下次 monthly_used 歸零時間（通常是每月 1 日 00:00 UTC+8）
```

扣次邏輯（簡化）：

```
if used + add > ocr_monthly_quota - ocr_monthly_used + ocr_purchased_remaining
  raise QuotaExhausted
end

from_monthly = min(add, ocr_monthly_quota - ocr_monthly_used)
from_purchased = add - from_monthly
ocr_monthly_used += from_monthly
ocr_purchased_remaining -= from_purchased
```

調整基本方案次數：新增一支 migration，改 `ocr_monthly_quota` 的 default，並把仍是舊基本值的公司一併更新成新值（已個別調整過次數的公司不動）。前端與 API 一律讀 `monthlyQuota`，不寫死次數。

重置：每次呼叫 `/recognize` 前檢查 `ocr_quota_reset_at`；若已過期 → `ocr_monthly_used = 0; ocr_quota_reset_at = next_month_start`。不開 cron job，lazy 重置省工。

缺點：沒有歷史用量紀錄；若未來要做「這家公司 9 月用了幾次」或對帳 → 加 `OcrUsageLog` table 時再補。MVP 不做。

### 查詢 endpoint

```
GET /api/ocr/quota
→ 200 {
  "monthlyQuota": 20,
  "monthlyUsed": 5,
  "monthlyRemaining": 15,
  "purchasedRemaining": 0,
  "resetAt": "2026-11-01T00:00:00+08:00"
}
```

前端在新增支出 / 代墊款 / 收入表單進入時 call 一次顯示剩餘次數；辨識後用 response 的 `quota` 更新。

## 6. 信心度與警示

- 欄位信心度依 §3.1 的固定值（高 0.9 / 低 0.5）
- `confidence.overall` = 每個辨識成功的檔案先算「直接辨識出的欄位」信心度平均，再對各檔取平均；推導欄位（`documentType`、`taxRate`）不計入；0–1 浮點數
- `confidence.lowFields` = `merged` 裡**有值**且由低信心度規則抓到的欄位 key（`items` 為 `[]` 時不列）；沒有就回 `[]`。可能出現：`counterpartyName`、`ourName`、`items`（一律低），以及 `amount`、`counterpartyTaxId`、`ourTaxId`（依 §3.1 抓法可能為低）。多張憑證抽到相同值時，任一張是低就列入
- **前端不依信心度提示**（2026-10-28 Peggy 決定）：辨識成功一律顯示固定提示「辨識完成｜欄位已自動帶入，請核對後儲存／送出」，不逐欄提示推測欄位，也不因 `overall` 偏低另外警告；有衝突時改顯示衝突提示並跳彈窗。`overall` 與 `lowFields` 後端照常回傳，僅供除錯與之後調整規則參考
- 有欄位進 `conflicts` 時，前端一律跳 Modal 讓使用者挑；不自動選信心度最高的那個（寧可多問一次）
- 不自動丟棄低信心欄位；一律帶入 `merged`，由使用者決定是否改
- `warnings` 內含欄位 key，僅供除錯 / log，**前端不直接顯示給使用者**（衝突已由彈窗處理）

### 前端帶入規則

- **重新辨識＝整份取代**：使用者確認「覆蓋並辨識」後，OCR 會給的欄位一律以新結果取代，新結果為 `null` 的欄位清空，但憑證類型與稅率是必選欄位，不清空：`documentType` 為 `null` 時預設「發票」、`taxRate` 為 `null` 時預設 `business_5`（2026-10-27 決定；使用者手上是收據時，會因發票號碼必填而發現並改選）；OCR 不會給的欄位（類別、付款狀態、帳戶等）保持不動
- **已存檔的憑證不能辨識**：編輯既有紀錄（含員工草稿、駁回重送）時，只有新加入的憑證可勾選辨識；要重辨請先移除原憑證再重傳
- **代墊款沒有品項**：`role=reimbursement` 時前端忽略 `merged.items` 與 `conflicts.items`，衝突彈窗只問頂層欄位
- **不預填說明 / 備註欄**：辨識結果不寫入任何說明文字（避免隨請款送出），改以畫面提示「辨識完成，請核對後送出」

## 7. 稽核與 Rate limit

- 本 endpoint **不寫 AuditLog**（辨識結果最後是不是存成支出 / 收入，由該資源本身的建立事件記錄）
- 配額本身就是 rate limit；不另加「每分鐘 N 次」限制

## 8. 不做（out of scope）

- OCR 結果快取（相同檔案重跑結果可能不同；且使用者可能微調後再辨識）
- 批次辨識多筆**不同**憑證（走 BatchImportDialog 的 PDF/Excel 匯入另案）。已定方向（2026-10-28）：匯入一份含多張電子發票的 PDF 時，每張發票新增一筆；沒有 QR 的頁面怎麼切、扣次數怎麼算，開案時再定
- 字元層級座標回傳（Document AI 有但前端 UI 不用）
- 電子發票 XML 直接匯入
- 用相機即時掃描 QR Code、一維條碼（2026-10-28 決定只解上傳的圖片與 PDF 裡的 QR，見 §3.2）
- QR 解得出來就不呼叫 Google、不扣次數（上線後依解碼率再評估）
- 用財政部電子發票 API 查明細、用統編查公司名稱
- Custom Extractor / Gemini 等生成式抽取（Custom Extractor 每 1,000 頁 $30 另加部署時數費，且生成式抽取官方只正式支援英文。上線後拿規則辨識失敗的樣本再評估）
- OcrUsageLog 歷史用量明細（MVP 不做；超額對帳 / 客訴時再補）
- 加購包金流（本次只實作「加完次數進 Company 欄位」的 admin 工具；對外付款走獨立專案）
