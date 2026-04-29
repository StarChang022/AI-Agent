"""
gsheet_helper.py
================
Google Sheets API 共用輔助模組。
供 crawler_104_*.py 系列腳本使用。

Sheet 設定：
  Spreadsheet ID : 14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE
  工作表名稱     : 名單副本

欄位順序（共 8 欄，A~H）：
  A 公司品牌簡稱 | B 序號 | C 官方網站 | D 產業 | E 員工人數
  F email       | G 聯絡人名稱 | H 來源 | I 說明

需要安裝的套件：
    pip install google-auth google-auth-httplib2 google-api-python-client
"""

import os
from typing import List, Dict, Optional

from google.oauth2 import service_account
from googleapiclient.discovery import build

# ──────────────────────────────────────────────
# 全域設定
# ──────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Service Account 金鑰檔案路徑
SERVICE_ACCOUNT_FILE = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "crawler_api",
                 "eternal-skyline-494002-j8-356884d3e786.json")
)

# Google Sheets 設定
SPREADSHEET_ID = "14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE"
SHEET_NAME = "名單副本"

# 欄位定義（順序即為 A~I 欄）
FIELDNAMES = [
    "公司品牌簡稱", "序號", "官方網站", "產業", "員工人數",
    "email", "聯絡人名稱", "來源", "說明"
]

SCOPES = ["https://www.googleapis.com/auth/spreadsheets"]


# ──────────────────────────────────────────────
# 連線與認證
# ──────────────────────────────────────────────

def get_service():
    """建立並回傳 Google Sheets API service 物件。"""
    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES
    )
    service = build("sheets", "v4", credentials=creds)
    return service


def get_sheet(service):
    """回傳 spreadsheets().values() 的快捷參考。"""
    return service.spreadsheets().values()


# ──────────────────────────────────────────────
# 讀取
# ──────────────────────────────────────────────

def read_all_rows(service) -> tuple[List[Dict], List[str]]:
    """
    讀取整個工作表，回傳 (rows, fieldnames)。
    - rows      : list of dict，每列對應一個 dict（key = 欄位名稱）
    - fieldnames: 第一列的欄位名稱清單（以 Sheet 實際標題為準）
    """
    range_name = f"{SHEET_NAME}"
    result = get_sheet(service).get(
        spreadsheetId=SPREADSHEET_ID,
        range=range_name
    ).execute()

    values = result.get("values", [])
    if not values:
        return [], FIELDNAMES

    header = values[0]
    rows = []
    for raw_row in values[1:]:
        # 補齊不足的欄位（空白結尾的列可能較短）
        padded = raw_row + [""] * (len(header) - len(raw_row))
        rows.append(dict(zip(header, padded)))

    return rows, header


# ──────────────────────────────────────────────
# 寫入
# ──────────────────────────────────────────────

def write_all_rows(service, rows: List[Dict], fieldnames: List[str]) -> None:
    """
    將全部資料（含標題列）完整覆寫回 Google Sheet。
    """
    # 組成二維陣列（標題 + 資料）
    header_row = fieldnames
    data_rows = []
    for row in rows:
        data_rows.append([row.get(col, "") for col in fieldnames])

    all_values = [header_row] + data_rows

    # 先清除舊內容，再寫入新內容
    range_name = SHEET_NAME
    get_sheet(service).clear(
        spreadsheetId=SPREADSHEET_ID,
        range=range_name
    ).execute()

    get_sheet(service).update(
        spreadsheetId=SPREADSHEET_ID,
        range=f"{SHEET_NAME}!A1",
        valueInputOption="USER_ENTERED",
        body={"values": all_values}
    ).execute()

    print(f"[GSheet] ✅ 已覆寫 {len(data_rows)} 列資料至『{SHEET_NAME}』分頁")


def append_rows(service, new_rows: List[Dict], fieldnames: List[str]) -> int:
    """
    將新資料附加至 Google Sheet 末尾（不清除現有資料）。
    回傳實際附加的列數。
    """
    if not new_rows:
        return 0

    data_rows = []
    for row in new_rows:
        data_rows.append([row.get(col, "") for col in fieldnames])

    get_sheet(service).append(
        spreadsheetId=SPREADSHEET_ID,
        range=f"{SHEET_NAME}!A1",
        valueInputOption="USER_ENTERED",
        insertDataOption="INSERT_ROWS",
        body={"values": data_rows}
    ).execute()

    print(f"[GSheet] ✅ 已附加 {len(data_rows)} 列資料至『{SHEET_NAME}』分頁")
    return len(data_rows)


def ensure_header(service) -> List[str]:
    """
    確保第一列為標題列，若工作表為空則先寫入標題。
    回傳實際標題列。
    """
    result = get_sheet(service).get(
        spreadsheetId=SPREADSHEET_ID,
        range=f"{SHEET_NAME}!1:1"
    ).execute()
    values = result.get("values", [])

    if not values or not values[0]:
        # 工作表為空，寫入標題
        get_sheet(service).update(
            spreadsheetId=SPREADSHEET_ID,
            range=f"{SHEET_NAME}!A1",
            valueInputOption="USER_ENTERED",
            body={"values": [FIELDNAMES]}
        ).execute()
        print(f"[GSheet] 已初始化標題列")
        return FIELDNAMES

    return values[0]


def get_existing_sources(service) -> set:
    """
    讀取 Google Sheet 中所有已存在的「來源」欄 URL（去除 query string 後），
    回傳 set，用於去重判斷。
    """
    rows, fieldnames = read_all_rows(service)
    existing = set()
    src_col = "來源"
    if src_col not in fieldnames:
        return existing
    for row in rows:
        src = row.get(src_col, "").strip()
        if src:
            clean = src.split("?")[0].rstrip("/")
            existing.add(clean)
    return existing
