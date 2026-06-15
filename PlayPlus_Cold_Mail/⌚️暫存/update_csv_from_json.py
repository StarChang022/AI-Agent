# -*- coding: utf-8 -*-
import csv
import json
import os

CSV_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv'
TEMP_JSON_PATH = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json'

def main():
    if not os.path.exists(TEMP_JSON_PATH):
        print(f"❌ 找不到暫存 JSON 檔案：{TEMP_JSON_PATH}")
        return

    # 1. 讀取暫存 JSON 檔，建立公司名稱對應全新說明的 Mapping
    with open(TEMP_JSON_PATH, 'r', encoding='utf-8') as f:
        temp_data = json.load(f)
    
    intro_mapping = {item['company_name']: item['new_description'] for item in temp_data}
    print(f"✅ 已載入 {len(intro_mapping)} 個公司的說明對應。")

    # 2. 一次性讀取 CSV 檔案至記憶體
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return

    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV 檔案內容為空！")
        return

    header = [h.strip() for h in rows[0]]
    try:
        name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
    except ValueError as e:
        print(f"❌ 缺少必要的欄位：{e}")
        return

    print(f"ℹ️ 「公司名稱」欄位 Index: {name_idx}, 「說明」欄位 Index: {desc_idx}")

    # 3. 在記憶體中逐行更新「說明」欄位
    updated_count = 0
    skipped_count = 0

    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(name_idx, desc_idx):
            continue
        
        comp_name = row[name_idx].strip()
        if comp_name in intro_mapping:
            row[desc_idx] = intro_mapping[comp_name]
            updated_count += 1
        else:
            skipped_count += 1
            print(f"⚠️ 跳過未匹配的公司: {comp_name}")

    # 4. 最後執行一次覆寫，寫回 CSV 檔案
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    print(f"✅ CSV 覆寫成功。更新筆數: {updated_count}, 未更新筆數: {skipped_count}")

if __name__ == '__main__':
    main()
