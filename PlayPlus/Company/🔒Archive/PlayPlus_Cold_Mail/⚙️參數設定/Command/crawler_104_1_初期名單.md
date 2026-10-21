現在要先收集104的初期名單，請執行 `# 任務` 項目。

# 任務

1. 依照 `# 104 頁面資料` 規則從 [[PlayPlus_Cold_Mail/⌚️暫存/104_early_list.csv]] 收集資料，前往這些頁面收集目標清單。
2. 依照 `# 欄位` 規則透過 [[PlayPlus_Cold_Mail/⚙️參數設定/eternal-skyline-494002-j8-356884d3e786.json]] API 將結果覆寫於 [初期名單](https://docs.google.com/spreadsheets/d/14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE/edit?gid=711543812#gid=711543812) 頁面欄位。
3. 如果爬蟲任務途中需要暫存資料，請儲存於 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.csv]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.md]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.py]] 檔案內。

# 104 頁面資料

撈取頁面的 <a data-v-6217bf82="" target="_blank" rel="noopener" class="d-none d-md-inline company-name-link--pc jb-link jb-link-blue jb-link-blue--visited font-weight-bold" data-gtm-cmps="瀏覽公司" href="104URL" title="CompanyName">CompanyName</a> 容器的資料。

- CompanyName: 公司名稱。
- 104URL: 104頁面網址。

# 欄位

從第2列開始寫入，不可覆蓋第1列標題列。

- A欄: 公司名稱，帶入 `# 104 頁面資料` 的 {CompanyName} 。
- B欄: 序號，固定填寫「2026mmdd」。
- C欄: 官方網站，留空。
- D欄: 產業，留空。
- E欄: 員工人數，留空。
- F欄: 聯絡人信箱，留空。
- G欄: 聯絡人名稱，固定填寫「官方」。
- H欄: 來源，帶入 `# 104 頁面資料` 的 {104URL} 。
- I欄: 說明，留空。
- J欄: 空白欄位，留空。
- K欄: 日期，固定填寫「2026/01/01」。