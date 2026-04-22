"""
gsheet_helper.py
================
Google Sheets API 共用輔助模組。
供 writer_coldmail_*.py 系列腳本使用。

Sheet 設定：
  Spreadsheet ID : 14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE
  工作表名稱     : 名單副本

欄位順序（A~I 為名單欄位，J 以後為冷郵件欄位）：
  A 公司品牌簡稱 | B 序號 | C 官方網站 | D 產業 | E 員工人數
  F email       | G 聯絡人名稱 | H 來源 | I 說明
  J day1_title  | K day1_content
  L day7_title  | M day7_content
  N day14_title | O day14_content
  P day30_title | Q day30_content
  R day60_title | S day60_content

需要安裝的套件：
    pip install google-auth google-auth-httplib2 google-api-python-client
"""

import os
from typing import List, Dict

from google.oauth2 import service_account
from googleapiclient.discovery import build

# ──────────────────────────────────────────────
# 全域設定
# ──────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

SERVICE_ACCOUNT_FILE = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "crawler_api",
                 "eternal-skyline-494002-j8-356884d3e786.json")
)

SPREADSHEET_ID = "14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE"
SHEET_NAME = "名單副本"
SHEET_URL = f"https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit?gid=1168472169#gid=1168472169"

SCOPES = ["https://www.googleapis.com/auth/spreadsheets"]


# ──────────────────────────────────────────────
# 連線
# ──────────────────────────────────────────────

def get_service():
    """建立並回傳 Google Sheets API service 物件。"""
    creds = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES
    )
    return build("sheets", "v4", credentials=creds)


def get_values(service):
    """回傳 spreadsheets().values() 快捷參考。"""
    return service.spreadsheets().values()


# ──────────────────────────────────────────────
# 讀取
# ──────────────────────────────────────────────

def read_all_rows(service) -> tuple[List[Dict], List[str]]:
    """
    讀取整個工作表，回傳 (rows, fieldnames)。
    rows 為 list of dict；fieldnames 為第一列標題清單。
    """
    result = get_values(service).get(
        spreadsheetId=SPREADSHEET_ID,
        range=SHEET_NAME
    ).execute()

    values = result.get("values", [])
    if not values:
        return [], []

    header = values[0]
    rows = []
    for raw_row in values[1:]:
        padded = raw_row + [""] * (len(header) - len(raw_row))
        rows.append(dict(zip(header, padded)))

    return rows, header


# ──────────────────────────────────────────────
# 寫入
# ──────────────────────────────────────────────

def write_all_rows(service, rows: List[Dict], fieldnames: List[str]) -> None:
    """將全部資料（含標題列）完整覆寫回 Google Sheet。"""
    header_row = fieldnames
    data_rows = [[row.get(col, "") for col in fieldnames] for row in rows]
    all_values = [header_row] + data_rows

    get_values(service).clear(
        spreadsheetId=SPREADSHEET_ID,
        range=SHEET_NAME
    ).execute()

    get_values(service).update(
        spreadsheetId=SPREADSHEET_ID,
        range=f"{SHEET_NAME}!A1",
        valueInputOption="USER_ENTERED",
        body={"values": all_values}
    ).execute()

    print(f"[GSheet] ✅ 已覆寫 {len(data_rows)} 列資料至『{SHEET_NAME}』分頁")


def ensure_coldmail_columns(fieldnames: List[str]) -> List[str]:
    """
    確保所有冷郵件欄位存在於 fieldnames 中。
    若不存在則自動補齊至清單末端。
    """
    coldmail_cols = [
        "day1_title", "day1_content",
        "day7_title", "day7_content",
        "day14_title", "day14_content",
        "day30_title", "day30_content",
        "day60_title", "day60_content",
    ]
    updated = list(fieldnames)
    for col in coldmail_cols:
        if col not in updated:
            updated.append(col)
            print(f"[GSheet] 自動新增欄位：{col}")
    return updated


def write_coldmail_to_sheet(service, day: int, mail_data: List[Dict]) -> None:
    """
    將指定天數的冷郵件（標題 + 內容）批量寫回 Google Sheets。

    mail_data 格式（list of dict）：
        [
            {
                "公司品牌簡稱": "公司A",
                "email": "test@example.com",
                "title": "郵件標題",
                "content": "郵件內容（含 <br> 換行）"
            },
            ...
        ]
    """
    title_col = f"day{day}_title"
    content_col = f"day{day}_content"

    rows, fieldnames = read_all_rows(service)
    if not rows:
        print("[錯誤] Google Sheets 工作表為空")
        return

    # 確保欄位存在
    fieldnames = ensure_coldmail_columns(fieldnames)

    # 建立 email → mail_data 的查找字典
    mail_lookup: Dict[str, Dict] = {}
    for item in mail_data:
        key = item.get("email", "").strip().lower()
        if key:
            mail_lookup[key] = item
        # 也以公司品牌簡稱作為備用鍵
        name_key = item.get("公司品牌簡稱", "").strip()
        if name_key:
            mail_lookup[f"__name__{name_key}"] = item

    updated_count = 0
    for row in rows:
        email_key = row.get("email", "").strip().lower()
        name_key = f"__name__{row.get('公司品牌簡稱', '').strip()}"

        matched = mail_lookup.get(email_key) or mail_lookup.get(name_key)
        if matched:
            row[title_col] = matched.get("title", "")
            row[content_col] = matched.get("content", "")
            updated_count += 1

    write_all_rows(service, rows, fieldnames)
    print(f"[GSheet] ✅ 已更新 {updated_count} 列的 {title_col} / {content_col}")
    print(f"[GSheet] 🔗 {SHEET_URL}")
