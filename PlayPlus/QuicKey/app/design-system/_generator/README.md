# 文件站產生器

`build_pages.py` 是產生 `design-system/` 底下所有 `design*.html`/`design-tokens.css`/`design-search-index.js` 的唯一來源。之後要改任何頁面內容、拆頁、調整元件，都應該改這支腳本再重新 build，不要手動改 `design-system/` 裡的 html/css/js（手改的東西下次 rebuild 會被蓋掉）。

## 依賴

- `_source_design.html`：整份文件最早、尚未拆頁前的單頁版本，腳本用正規表示式從裡面挖出各區塊原始內容，**不能刪**。
- 路徑預設為相對位置：讀本資料夾的 `_source_design.html`、直接輸出到上一層 `design-system/`。需要改路徑時用環境變數覆寫：`QDS_SRC`（來源檔）、`QDS_OUT`（輸出資料夾）。

## 怎麼跑

```bash
cd design-system/_generator
python3 build_pages.py                      # 直接覆寫 design-system/ 底下的產物
QDS_OUT=/tmp/qds_build python3 build_pages.py   # 先輸出到暫存資料夾檢查，再手動複製
```


## partials/（直接改這些檔案，不用動 build_pages.py）

- `partials/components.js`、`components.css`：文件站共用的 Select/DatePicker 互動元件（外觀對齊 PrimeVue `<Select>`/`<DatePicker>`），輸出成 `design-components.js`，每頁都會載入。頁面裡用 `data-qds-select`/`data-qds-datepicker` 標記即可，值改變時會發出 `qds-change` 事件。Python 端可用 `qds_select()`/`qds_datepicker()` 產生標記。
- `partials/prototype.py`：後台原型的 HTML（exec 載入，產生 `PROTOTYPE_HTML`）。`partials/dashboard.js`、`dashboard.css`：後台原型的互動與樣式。`partials/prototype-notes.html`：原型可操作項目說明。
- `partials/layout-shell.html`、`layout-home.html`、`layout_list.py`：版型規則頁（頁面骨架/首頁（儀表板）/列表頁（CRUD））。
- 後台原型的資料在 build 時讀前端 mock `frontend/src/mocks/*.json`（可用環境變數 `QDS_MOCKS` 改路徑），去掉密碼、token、檔案網址後嵌成 `window.QDS_PROTO_DATA`。前端 mock 或欄位改了，重新 build 即可同步。

## 為什麼要存這份

2026-09 曾發生過：產生器只存在雲端 session 的暫存空間，session 結束後就消失，導致下一次要改東西時完全沒有原始碼可以改，只能直接手改部署出去的靜態 HTML，久了容易讓「靜態檔案」跟「產生邏輯」對不齊。把 `build_pages.py`（跟它依賴的 `_source_design.html`）存進 repo，之後不管哪個 session 接手維護，都能先讀這份腳本理解現況、照原本的方式改，而不是憑印象重建。
