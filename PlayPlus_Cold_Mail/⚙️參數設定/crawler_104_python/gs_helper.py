"""
gs_helper.py
============
Google Sheets 共用輔助模組，供四支 104 爬蟲腳本 import 使用。

認證方式：Service Account JSON
Sheet ID：14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE
預設分頁：名單副本

需安裝：
    pip install gspread google-auth
"""

import os
from typing import List, Dict, Tuple

import gspread
from google.oauth2.service_account import Credentials

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Service Account JSON 路徑
CREDENTIALS_PATH = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "crawler_api", "eternal-skyline-494002-j8-356884d3e786.json")
)

# Google Sheets 存取範圍
SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

# Google Sheet ID
SPREADSHEET_ID = "14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE"

# 預設分頁名稱
DEFAULT_TAB = "名單副本"


# ──────────────────────────────────────────────
# 核心函式
# ──────────────────────────────────────────────

def get_worksheet(tab_name: str = DEFAULT_TAB) -> gspread.Worksheet:
    """
    建立 gspread client，回傳指定分頁的 Worksheet 物件。
    """
    if not os.path.exists(CREDENTIALS_PATH):
        raise FileNotFoundError(f"找不到 Service Account JSON：{CREDENTIALS_PATH}")

    creds = Credentials.from_service_account_file(CREDENTIALS_PATH, scopes=SCOPES)
    client = gspread.authorize(creds)
    spreadsheet = client.open_by_key(SPREADSHEET_ID)
    worksheet = spreadsheet.worksheet(tab_name)
    print(f"[GS] 已連線 Google Sheets → 分頁：{tab_name}")
    return worksheet


def load_sheet_as_rows(ws: gspread.Worksheet) -> Tuple[List[Dict], List[str]]:
    """
    讀取整個分頁，回傳：
      - rows: List[Dict]  每列轉成 {欄位: 值} 字典
      - fieldnames: List[str]  第一列的欄位名稱清單

    注意：空白列自動過濾（全欄皆空），保留標題列用作 fieldnames。
    """
    all_values = ws.get_all_values()
    if not all_values:
        return [], []

    fieldnames = all_values[0]
    rows = []
    for raw_row in all_values[1:]:
        # 補齊欄位數（以防某些欄尾部有空格而 gspread 截短了）
        padded = raw_row + [""] * (len(fieldnames) - len(raw_row))
        row_dict = {fieldnames[i]: padded[i] for i in range(len(fieldnames))}
        # 過濾全空列
        if any(v.strip() for v in row_dict.values()):
            rows.append(row_dict)

    print(f"[GS] 讀取完成：{len(rows)} 列資料（欄位數：{len(fieldnames)}）")
    return rows, fieldnames


def save_rows_to_sheet(
    ws: gspread.Worksheet,
    rows: List[Dict],
    fieldnames: List[str],
) -> None:
    """
    將整個 rows 覆寫回 Google Sheet（先清空再寫入）。
    第一列為 fieldnames（標題列），之後接 rows。
    """
    # 建立要寫入的二維陣列
    data = [fieldnames]
    for row in rows:
        data.append([row.get(f, "") for f in fieldnames])

    # 清空分頁後批次寫入
    ws.clear()
    ws.update(data, value_input_option="USER_ENTERED")
    print(f"[GS] 寫入完成：{len(rows)} 列資料 → Google Sheets『{ws.title}』")


def append_rows_to_sheet(
    ws: gspread.Worksheet,
    new_rows: List[Dict],
    fieldnames: List[str],
    key_col: str = "來源",
) -> int:
    """
    將 new_rows 附加寫入 Google Sheet（依 key_col 去重，不重複）。
    若分頁為空，自動先寫入標題列。
    回傳實際寫入的新列數。
    """
    existing_rows, existing_fields = load_sheet_as_rows(ws)

    # 取得已存在的 key 值集合
    existing_keys = set()
    for r in existing_rows:
        key_val = r.get(key_col, "").strip()
        if key_val:
            existing_keys.add(key_val.split("?")[0].rstrip("/"))

    # 若分頁為空（無標題列），先寫入標題列
    if not existing_fields:
        ws.append_row(fieldnames)

    # 過濾新列（去重）
    to_write = []
    for row in new_rows:
        key_val = row.get(key_col, "").strip()
        clean_key = key_val.split("?")[0].rstrip("/")
        if clean_key and clean_key not in existing_keys:
            to_write.append([row.get(f, "") for f in fieldnames])
            existing_keys.add(clean_key)

    if to_write:
        ws.append_rows(to_write, value_input_option="USER_ENTERED")

    print(f"[GS] 附加完成：新增 {len(to_write)} 列（略過 {len(new_rows) - len(to_write)} 筆重複）")
    return len(to_write)


# ──────────────────────────────────────────────
# 連線測試（python3 gs_helper.py 直接執行）
# ──────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("  Google Sheets 連線測試")
    print("=" * 60)
    try:
        ws = get_worksheet()
        rows, fields = load_sheet_as_rows(ws)
        print(f"\n✅ 連線成功！")
        print(f"   分頁名稱：{ws.title}")
        print(f"   欄位數  ：{len(fields)}")
        print(f"   資料列數：{len(rows)}")
        print(f"   欄位清單：{fields}")
        if rows:
            print(f"\n   第一筆資料：")
            for k, v in rows[0].items():
                if v:
                    print(f"     {k}: {v}")
    except Exception as e:
        print(f"\n❌ 連線失敗：{e}")
        print("\n請確認：")
        print("  1. Service Account JSON 路徑正確")
        print("  2. Service Account 已被加入 Google Sheet 為「編輯者」")
        print(f"     email: google-sheet-bot@eternal-skyline-494002-j8.iam.gserviceaccount.com")
