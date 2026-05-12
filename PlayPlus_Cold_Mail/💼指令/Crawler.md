我現在需要為初期名單安排爬蟲作業，依序收集公司網址、公司說明與網域信箱。

> **【資料來源】所有階段的讀取與寫入全程透過 Google Sheets API 直接對接『名單副本』分頁，不使用本機 CSV 檔案。**
> Spreadsheet: https://docs.google.com/spreadsheets/d/14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE/edit?gid=1168472169#gid=1168472169

請作為 Workflows 自動化流程依序執行以下三個階段。每個階段請精確閱讀對應的指令文件，並執行該文件內要求的終端機指令（如啟動 Python 腳本）。確保前一個階段的腳本成功執行完畢後，再自動接續下一個階段。

**階段 1：收集公司網址**

* 執行指令參考：@[💼指令/Crawler/2.104crawler公司網址.md]
* 任務目標：執行對應腳本，自動讀取 Google Sheets `名單副本` 分頁，尋找公司網址並寫回 Google Sheets。
* 驗收標準：終端機腳本執行完畢且無錯誤，即進入下一階段。

**階段 2：撰寫公司說明**

* 執行指令參考：@[💼指令/Crawler/3.104crawler撰寫公司說明.md]
* 任務目標：執行對應腳本，針對 Google Sheets 內的資料生成或爬取公司說明，並更新至 Google Sheets。
* 驗收標準：終端機腳本執行完畢且無錯誤，即進入下一階段。

**階段 3：查找網域信箱**

* 執行指令參考：@[💼指令/Crawler/4.104crawler查找網域信箱.md]
* 任務目標：執行對應腳本，進一步爬取網域信箱並更新至 Google Sheets。
* 驗收標準：終端機腳本執行完畢且無錯誤，即完成整個工作流。