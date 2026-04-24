
import sys
import os
import json

# 將 ⚙️參數設定/crawler_104_python 加入 path
sys.path.append("/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⚙️參數設定/crawler_104_python")

import gsheet_helper as gs

def main():
    service = gs.get_service()
    rows, fieldnames = gs.read_all_rows(service)
    
    # 過濾出有 email 的公司（或者全部，依據需求）
    # 撰寫信件通常需要 email
    print(json.dumps(rows, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
