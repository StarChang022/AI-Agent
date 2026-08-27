# -*- coding: utf-8 -*-
import os
import csv
import json
import gspread
from google.oauth2.service_account import Credentials

BASE_DIR = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail'
LOCAL_CSV = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
EMAILS_JSON = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_emails.json')
CREDENTIALS_FILE = os.path.join(BASE_DIR, '⚙️參數設定', 'eternal-skyline-494002-j8-356884d3e786.json')

SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'
WORKSHEET_NAME = '名單副本'

def update_emails():
    print("[1/3] Reading temporary emails JSON...")
    if not os.path.exists(EMAILS_JSON):
        print(f"Error: {EMAILS_JSON} not found!")
        return
        
    with open(EMAILS_JSON, 'r', encoding='utf-8') as f:
        emails_map = json.load(f)
    print(f"Loaded cold emails for {len(emails_map)} companies.")

    # 1. Update Local CSV
    print("[2/3] Updating local CSV file...")
    if not os.path.exists(LOCAL_CSV):
        print(f"Error: Local CSV file {LOCAL_CSV} not found!")
        return
        
    with open(LOCAL_CSV, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        rows = list(reader)
        
    print(f"Original CSV row count: {len(rows)}")
    
    # Update Column P to Y (index 15 to 24)
    # P:15, Q:16, R:17, S:18, T:19, U:20, V:21, W:22, X:23, Y:24
    for r_idx in range(2, len(rows) + 1):
        str_r_idx = str(r_idx)
        if str_r_idx in emails_map:
            # Ensure row has at least 25 columns
            while len(rows[r_idx - 1]) < 25:
                rows[r_idx - 1].append('')
                
            comp_emails = emails_map[str_r_idx]
            rows[r_idx - 1][15] = comp_emails['day1_title']
            rows[r_idx - 1][16] = comp_emails['day1_content']
            rows[r_idx - 1][17] = comp_emails['day7_title']
            rows[r_idx - 1][18] = comp_emails['day7_content']
            rows[r_idx - 1][19] = comp_emails['day14_title']
            rows[r_idx - 1][20] = comp_emails['day14_content']
            rows[r_idx - 1][21] = comp_emails['day30_title']
            rows[r_idx - 1][22] = comp_emails['day30_content']
            rows[r_idx - 1][23] = comp_emails['day60_title']
            rows[r_idx - 1][24] = comp_emails['day60_content']
            
    with open(LOCAL_CSV, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print("Local CSV updated successfully!")

    # 2. Sync to Google Sheets
    print("[3/3] Syncing cold emails to Google Sheets...")
    try:
        scope = ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
        creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
        client = gspread.authorize(creds)
        sheet = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)
        
        sheet_rows = sheet.get_all_values()
        num_sheet_rows = len(sheet_rows)
        print(f"Google Sheets row count: {num_sheet_rows}")
        
        # We will build a 2D array of updates for range P2:Y{num_sheet_rows}
        update_values = []
        for r_idx in range(2, num_sheet_rows + 1):
            str_r_idx = str(r_idx)
            if str_r_idx in emails_map:
                comp_emails = emails_map[str_r_idx]
                update_values.append([
                    comp_emails['day1_title'],
                    comp_emails['day1_content'],
                    comp_emails['day7_title'],
                    comp_emails['day7_content'],
                    comp_emails['day14_title'],
                    comp_emails['day14_content'],
                    comp_emails['day30_title'],
                    comp_emails['day30_content'],
                    comp_emails['day60_title'],
                    comp_emails['day60_content']
                ])
            else:
                # Pad with empty fields if row doesn't have generated email
                update_values.append(['', '', '', '', '', '', '', '', '', ''])
                
        range_name = f'P2:Y{num_sheet_rows}'
        print(f"Updating Sheets range: {range_name} (total {len(update_values)} rows)...")
        
        sheet.update(range_name=range_name, values=update_values)
        print("Google Sheets Columns P to Y updated successfully!")
        
    except Exception as e:
        print(f"Error syncing with Google Sheets: {e}")

if __name__ == '__main__':
    update_emails()
