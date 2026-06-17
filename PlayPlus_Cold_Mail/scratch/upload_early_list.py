import os
import csv
import gspread
from google.oauth2.service_account import Credentials

BASE_DIR = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail'
TEMP_FILE = os.path.join(BASE_DIR, '⌚️暫存', '104_early_list_temporary.csv')
CREDENTIALS_FILE = os.path.join(BASE_DIR, '⚙️參數設定', 'eternal-skyline-494002-j8-356884d3e786.json')
SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'
WORKSHEET_NAME = '名單副本'

def main():
    print("Reading early list CSV...")
    if not os.path.exists(TEMP_FILE):
        print(f"Error: {TEMP_FILE} not found!")
        return

    with open(TEMP_FILE, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)  # CompanyName, 104URL
        companies = list(reader)

    print(f"Loaded {len(companies)} companies from CSV.")

    # Format values for Google Sheets:
    # A: CompanyName
    # B: 序號 (20260616)
    # C: 官方網站
    # D: 產業
    # E: 員工人數
    # F: email
    # G: 聯絡人名稱 (官方)
    # H: 來源 (104URL)
    # I: 說明
    # J: (empty)
    # K: 日期 (2026/01/01)
    rows_to_write = []
    for c in companies:
        name = c[0]
        url = c[1]
        row = [name, '20260616', '', '', '', '', '官方', url, '', '', '2026/01/01']
        rows_to_write.append(row)

    print("Connecting to Google Sheets...")
    scope = ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
    creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    sheet = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)

    print("Clearing worksheet A2:Y...")
    try:
        sheet.batch_clear(['A2:Y'])
    except Exception as e:
        print(f"Warning: clear failed: {e}")

    # Check and add rows if needed
    current_rows = sheet.row_count
    needed_rows = len(rows_to_write) + 5
    if needed_rows > current_rows:
        rows_to_add = needed_rows - current_rows
        print(f"Adding {rows_to_add} rows to the sheet...")
        sheet.add_rows(rows_to_add)

    print(f"Writing {len(rows_to_write)} rows to sheet...")
    # Update in chunks
    BATCH = 500
    for i in range(0, len(rows_to_write), BATCH):
        chunk = rows_to_write[i:i + BATCH]
        start_row = 2 + i
        try:
            sheet.update(values=chunk, range_name=f'A{start_row}')
        except Exception as e:
            try:
                sheet.update(f'A{start_row}', chunk)
            except Exception:
                sheet.update(range_name=f'A{start_row}', values=chunk)
        print(f"  → Wrote rows {start_row} to {start_row + len(chunk) - 1}")

    print("Google Sheets updated successfully!")

if __name__ == '__main__':
    main()
