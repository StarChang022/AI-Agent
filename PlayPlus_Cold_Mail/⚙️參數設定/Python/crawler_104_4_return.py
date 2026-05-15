import os
import csv
import time
import gspread
from google.oauth2.service_account import Credentials

# ================= 參數設定 =================
# ⚙️參數設定/Python/ → 上三層是 PlayPlus_Cold_Mail 根目錄
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCAL_CSV = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
CREDENTIALS_FILE = os.path.join(BASE_DIR, '⚙️參數設定', 'eternal-skyline-494002-j8-356884d3e786.json')

SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'
WORKSHEET_NAME = '名單副本'   # gid=1168472169

BATCH_SIZE = 500             # 每次批次寫入的列數
# ==========================================


def main():
    print("=== 寫回 Google Sheets：名單副本 ===\n")

    # ── 讀取本地 CSV ──
    if not os.path.exists(LOCAL_CSV):
        print(f"[錯誤] 找不到本地 CSV：{LOCAL_CSV}")
        return

    with open(LOCAL_CSV, 'r', encoding='utf-8') as f:
        all_rows = list(csv.reader(f))

    if len(all_rows) < 2:
        print("[警告] CSV 內無資料列，結束。")
        return

    headers = all_rows[0]
    data_rows = all_rows[1:]
    print(f"[讀取] 標題欄位：{headers}")
    print(f"[讀取] 資料列數：{len(data_rows)} 筆\n")

    # ── 連接 Google Sheets ──
    print(f"[連接] Google Sheets → 工作表「{WORKSHEET_NAME}」")
    scope = ['https://www.googleapis.com/auth/spreadsheets',
             'https://www.googleapis.com/auth/drive']
    creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    sheet = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)

    # ── 清除舊資料（保留標題列）──
    print("[清除] 清除舊資料列 A2:Z ...")
    try:
        sheet.batch_clear(['A2:Z'])
    except Exception as e:
        print(f"  [警告] 清除失敗：{e}")

    # ── 批次寫入 ──
    print(f"[寫入] 開始批次寫入（每批 {BATCH_SIZE} 筆）...")
    for i in range(0, len(data_rows), BATCH_SIZE):
        chunk = data_rows[i:i + BATCH_SIZE]
        start_row = 2 + i
        end_row = start_row + len(chunk) - 1
        try:
            sheet.update(f'A{start_row}', chunk)
        except TypeError:
            sheet.update(range_name=f'A{start_row}', values=chunk)
        print(f"  → 已寫入第 {start_row} ~ {end_row} 列（{len(chunk)} 筆）")
        if i + BATCH_SIZE < len(data_rows):
            time.sleep(1)   # 避免觸發 Google API 速率限制

    print(f"\n[完成] 共 {len(data_rows)} 筆資料已成功寫回「{WORKSHEET_NAME}」！")


if __name__ == '__main__':
    main()
