import csv
import json
import os

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
TEMP_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104.json")

def main():
    # 1. 載入 JSON 資料
    with open(TEMP_JSON_PATH, "r", encoding="utf-8") as f:
        json_data = json.load(f)
        
    # 2. 讀取 CSV 全部資料至記憶體
    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        rows = list(reader)
        
    if not rows:
        print("CSV 為空")
        return
        
    header = rows[0]
    # 找到欄位索引
    try:
        idx_name = header.index("公司名稱")
        idx_scenario = header.index("Scenarios")
        
        # Mapping for the email columns
        email_cols = {
            "day1_title": header.index("day1_title"),
            "day1_content": header.index("day1_content"),
            "day7_title": header.index("day7_title"),
            "day7_content": header.index("day7_content"),
            "day14_title": header.index("day14_title"),
            "day14_content": header.index("day14_content"),
            "day30_title": header.index("day30_title"),
            "day30_content": header.index("day30_content"),
            "day60_title": header.index("day60_title"),
            "day60_content": header.index("day60_content")
        }
    except ValueError as e:
        print(f"欄位索引錯誤: {e}")
        return

    # 3. 逐列更新記憶體中的資料
    updated_count = 0
    for i in range(1, len(rows)):
        row = rows[i]
        comp = row[idx_name].strip()
        scen = row[idx_scenario].strip()
        
        # 只處理符合的 Scenario
        if scen in ["中小企業_企業內部系統", "大企業_企業內部系統", "Quickey_快記"]:
            if comp in json_data:
                comp_data = json_data[comp]
                for key, col_idx in email_cols.items():
                    val = comp_data.get(key, "")
                    
                    # 確保 row 長度足夠
                    while len(row) <= col_idx:
                        row.append("")
                        
                    # 根據規則，沒有使用的天數要填入 "-"
                    if key in ["day14_title", "day14_content", "day60_title", "day60_content"]:
                        val = "-"
                        
                    row[col_idx] = val
                updated_count += 1

    # 4. 一次性寫回 CSV
    with open(CSV_PATH, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(rows)
        
    print(f"✅ 成功將 {updated_count} 列冷郵件資料寫回 名單副本.csv")

if __name__ == "__main__":
    main()
