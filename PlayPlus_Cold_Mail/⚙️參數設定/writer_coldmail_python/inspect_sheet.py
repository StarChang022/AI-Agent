
import sys
import os
import json

# 將 ⚙️參數設定/crawler_104_python 加入 path
sys.path.append("/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⚙️參數設定/crawler_104_python")

import gsheet_helper as gs

def main():
    service = gs.get_service()
    rows, fieldnames = gs.read_all_rows(service)
    
    # 列印每一列的索引和關鍵欄位
    for i, row in enumerate(rows, start=2): # 假設 Google Sheets 第一列是 Header，所以資料從第 2 列開始
        print(f"Row {i}: {row.get('公司品牌簡稱', 'N/A')} | Email: {row.get('email', 'N/A')} | Day1 Title: {row.get('day1_title', 'EMPTY')}")

if __name__ == "__main__":
    main()
