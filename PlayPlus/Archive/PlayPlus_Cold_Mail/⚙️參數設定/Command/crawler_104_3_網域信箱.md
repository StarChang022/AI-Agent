現在要開始查找每間公司網域的信箱地址，收集有效的 Email 名單，請執行 `# 任務` 項目。

# 任務

1. 從 [[PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv]] 讀取每間公司的C欄（官方網站）。

2. 解析C欄網域，將「@網域」作為信箱地址後綴。例如 https://apple.com/ 的 steve.jobs@apple.com 信箱地址。

3. 參照 `# 爬蟲攻略` 開始使用爬蟲查找符合信箱地址後綴的信箱地址，執行時務必遵守 `# 管理規則` 。

4. 如果爬蟲任務途中需要暫存資料，請儲存於 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.csv]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.md]] 或 [[PlayPlus_Cold_Mail/⌚️暫存/temporary_104.py]] 檔案內。

# 爬蟲攻略

1. Google: 透過 Google 搜尋的方式查找。
2. Google Dorks: 使用進階語法（如 Facebook 專頁站內搜尋、官網站內 Email 搜尋）查找。
3. 其他: 其他任何你能想到的辦法。

# 管理規則

1. C欄（官方網站）為空: 維持現狀，略過該列。
2. F欄（email）已有值: 維持現狀，略過該列。
3. 當找到1筆符合後綴的信箱地址: 直接填入F欄（email），其餘欄位維持現狀。
4. 當找到2筆以上符合後綴的信箱地址: 複製該列公司資料對應筆數，再分別對F欄（email）填入對應的信箱地址（每筆 Email 一列），其餘欄位維持現狀。
5. 當找不到符合後綴的信箱地址: 維持現狀，略過該列。