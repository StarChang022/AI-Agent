<!-- 官網網址、公司介紹 -->
現在要開始收集目標公司的資料，請執行 `# 任務` 項目。

# 任務

1. 先透過 [[PlayPlus_Cold_Mail/⚙️參數設定/eternal-skyline-494002-j8-356884d3e786.json]] API 將 [名單副本](https://docs.google.com/spreadsheets/d/14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE/edit?gid=1168472169#gid=1168472169) 資料抓到本地端 [[PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv]] 檔並覆寫。

2. 依照 `# 104 頁面資料` 規則，從 [[PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv]] 每間公司的G欄（來源）網址收集資料。

3. 依照 `# 欄位` 規則將結果覆寫於 [[PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv]] 檔案內。

4. 如果爬蟲任務途中需要暫存資料，請儲存於 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.csv]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.md]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.py]] 檔案內。

# 104 頁面資料

撈取頁面的 <a data-v-5cd1502f="" class="t3 jb-link jb-link-blue" href="CompanyURL" data-gtm-content="公司網址" target="_blank" rel="sponsored">CompanyURL</a> 容器的資料。

<p data-v-5cd1502f="" class="intro-profile mb-0 text-break">CompanyProfile1</p> 容器和
<p data-v-5cd1502f="" class="r3 mb-0 text-break">CompanyProfile2</p> 容器

- CompanyURL: 公司官網網址。
- CompanyProfile1: 公司簡介第一個段落。
- CompanyProfile2: 公司簡介第二個段落。

# 欄位

從第2列開始寫入，不可覆蓋第1列標題列。

- A欄: 公司名稱，維持現狀。
- B欄: 序號，維持現狀。
- C欄: 官方網站，帶入 `# 104 頁面資料` 的 {CompanyURL} 。
- D欄: 產業，維持現狀。
- E欄: 員工人數，維持現狀。
- F欄: 聯絡人信箱，維持現狀。
- G欄: 聯絡人名稱，維持現狀。
- H欄: 來源，維持現狀。
- I欄: 說明，帶入 `# 104 頁面資料` 的 {CompanyProfile1} 和 {CompanyProfile2} 。
- J欄: 空白欄位，留空。
- K欄: 日期，維持現狀。