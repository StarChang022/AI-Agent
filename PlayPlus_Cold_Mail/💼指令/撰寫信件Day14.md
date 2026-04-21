現在要開始為 Google Sheets 名單產生 Day 14 的冷郵件。

此指令搭配 [[⚙️參數設定/writer_coldmail_python/writer_coldmail_day14.py]] 使用，請完成 `# 任務` 中的任務。

# 任務

1. 你先熟讀 [[原則與攻略/冷郵件守則.md]] 的 `### Day 14：價值證明` 原則。
2. 從 Google Sheets 的 [『名單副本』分頁](https://docs.google.com/spreadsheets/d/14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE/edit?gid=1168472169#gid=1168472169) 讀取所有寄送對象資料。
3. 透過 Python 腳本產生符合規定的信件，並將 Day 14 標題覆寫於 Google Sheets 的「day14_title」欄位。
4. 透過 Python 腳本產生符合規定的信件，並將 Day 14 內容覆寫於 Google Sheets 的「day14_content」欄位。
5. 撰寫時，必須採用 [[⚙️參數設定/寫作風格與框架設定.md]] 的寫作風格。
6. 撰寫時，必須遵守 [[⚙️參數設定/冷郵件規定.md]] 的規定。

# 使用步驟

1. 在終端機執行：
   ```bash
   python3 ⚙️參數設定/writer_coldmail_python/writer_coldmail_day14.py
   ```
2. 腳本會自動連線 Google Sheets 與 Vertex AI，依據指示中的規則為名單中的每一間公司量身打造 Day 14 信件。
3. 腳本執行完畢後，資料會自動覆寫回 Google Sheets 的「day14_title」與「day14_content」欄位，**無需額外手動操作**。