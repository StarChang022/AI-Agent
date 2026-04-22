import gspread
from google.oauth2.service_account import Credentials

# 設定金鑰檔案路徑
SERVICE_ACCOUNT_FILE = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⚙️參數設定/crawler_api/eternal-skyline-494002-j8-356884d3e786.json'

# 設定範圍
SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive'
]

# 試算表 ID
SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'

def main():
    try:
        # 認證
        creds = Credentials.from_service_account_file(SERVICE_ACCOUNT_FILE, scopes=SCOPES)
        client = gspread.authorize(creds)

        # 打開試算表
        sheet = client.open_by_key(SPREADSHEET_ID)
        
        # 取得 '名單副本' 分頁
        try:
            worksheet = sheet.worksheet('名單副本')
        except gspread.exceptions.WorksheetNotFound:
            print("找不到 '名單副本' 分頁，改用第一個分頁。")
            worksheet = sheet.get_worksheet(0)

        # 新增一列，並在 A 欄寫入 「TEST」
        worksheet.append_row(['TEST'])
        
        print(f"成功在分頁 '{worksheet.title}' 新增了一列 'TEST'！")

    except Exception as e:
        print(f"發生錯誤: {e}")

if __name__ == '__main__':
    main()
