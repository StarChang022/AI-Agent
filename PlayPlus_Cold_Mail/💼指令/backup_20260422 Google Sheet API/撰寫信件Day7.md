我需要你為我撰寫第 7 天的冷郵件。

此指令搭配 [[⚙️參數設定/writer_coldmail_python/writer_day7.py]] 使用，請完成 `# 任務` 中的任務。

# 任務

1. 熟讀 [[原則與攻略/冷郵件守則.md]] 的 `### Day 7：快速溫和提醒` 原則。
2. 從 Google Sheets 讀取 [[名單副本]] 分頁的所有公司資料（公司品牌簡稱、email、聯絡人名稱、說明等欄位）。
3. 依照 `# 撰寫規定` 為每一間公司撰寫 Day 7 郵件標題（`day7_title`）與內容（`day7_content`）。
4. 將撰寫好的資料填入 [[⚙️參數設定/writer_coldmail_python/writer_day7.py]] 腳本的 `MAIL_DATA` 清單中。
5. 執行腳本，將結果寫入 Google Sheets。

# 使用步驟

1. 前往 Google Sheets 查看 [[名單副本]] 分頁的公司名單：
   https://docs.google.com/spreadsheets/d/14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE/edit?gid=1168472169#gid=1168472169
2. 依照 `# 撰寫規定` 為每間公司個別撰寫 Day 7 標題與內容（簡短不超過 3 句話，不給壓力）。
3. 打開 [[⚙️參數設定/writer_coldmail_python/writer_day7.py]]，將撰寫好的資料填入 `MAIL_DATA` 清單：
   ```python
   MAIL_DATA = [
       {
           "公司品牌簡稱": "公司A",
           "email": "info@companya.com",
           "title": "Day 7 標題",
           "content": "您好，<br><br>內容...<br><br>感謝您"
       },
       # ... 其餘公司
   ]
   ```
4. 在終端機執行：
   ```bash
   cd ⚙️參數設定/writer_coldmail_python
   python3 writer_day7.py
   ```
5. 腳本會自動將 `day7_title` 與 `day7_content` 寫入 Google Sheets 對應列。

# 撰寫規定

- 必須採用 [[⚙️參數設定/寫作風格與框架設定.md]] 的寫作風格。
- 必須遵守 [[⚙️參數設定/冷郵件規定.md]] 的規定（含 `<br>` 換行格式）。
- **不要使用「建議」這種角度**，應該用「您可以試著...」或者「我發現xxx對您更好...」之類的語氣。
- Day 7 為溫和提醒，內容極簡，不超過 3 句話，絕不施壓。
- 若聯絡人名稱為「官方」或通用窗口，內容開頭僅寫「您好，」。
- 內容最後須附上 https://playplus.com.tw/ 官網連結。
- 結尾固定寫「感謝您」，不附寄件人姓名。
- 郵件內容換行一律使用 `<br>` HTML 格式。
- 如果該天已有內容，請直接覆寫。
## 範例

您好，<br>
<br>
我剛瀏覽了寶昕的網站，注意到你們在動物用藥與器材領域已經有很深厚的基礎，也有電商購物車。不過我也發現目前的購物流程與視覺配置還有不小的提升空間，這在現今講求專業信任度的寵物醫療市場中，對於轉換率的影響不容小覷。<br>
<br>
我們是 PlayPlus，專注於協助企業將現有的「陽春」網站轉化為具備高質感與高轉換率的數位平台。我們曾協助多家品牌在不改動後端邏輯的情況下，大幅提升前端的使用者體驗。<br>
<br>
是否方便寄一份我們過去在相關產業的 UI/UX 優化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br>
<br>
感謝您
