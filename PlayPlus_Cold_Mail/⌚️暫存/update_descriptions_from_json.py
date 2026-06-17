#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
將 temporary_104.json 中的一句話簡介（new_description）更新至 名單副本.csv 的「說明」欄位（I欄/index 8）。
"""

import csv
import json
import os
import shutil

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
BACKUP_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本_backup_intro.csv')
JSON_PATH = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')

def main():
    print("=== 開始更新公司說明（I欄） ===")

    # 1. 檢查並備份原始 CSV
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份 CSV 至：{BACKUP_PATH}")

    # 2. 讀取 JSON 中的簡介對照
    if not os.path.exists(JSON_PATH):
        print(f"❌ 找不到 JSON 檔案：{JSON_PATH}")
        return
    
    with open(JSON_PATH, 'r', encoding='utf-8') as f:
        json_data = json.load(f)
    
    # 建立公司名稱與 summary 的對照表
    company_to_summary = {}
    for name, item in json_data.items():
        summary = item.get('new_description')
        if name and summary:
            company_to_summary[name.strip()] = summary.strip()
            
    print(f"✅ 已載入 {len(company_to_summary)} 筆獨特公司的簡介對照。")

    # 3. 讀取 CSV 全部資料至記憶體
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV 檔案內容為空")
        return

    header = rows[0]
    
    # 定位「公司名稱」與「說明」的欄位 index
    try:
        name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
    except ValueError as e:
        print(f"❌ CSV 標頭缺少必要欄位：{e}")
        return

    print(f"  → 「公司名稱」欄位 Index: {name_idx}, 「說明」欄位 Index: {desc_idx}")

    updated_count = 0
    skipped_count = 0

    # 4. 在記憶體中逐行更新「說明」欄位
    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(name_idx, desc_idx):
            continue

        comp_name = row[name_idx].strip()
        
        if comp_name in company_to_summary:
            row[desc_idx] = company_to_summary[comp_name]
            updated_count += 1
        else:
            skipped_count += 1
            print(f"  ⚠️ 警告: 未在對照表中找到公司 [{comp_name}]")

    # 5. 一次性寫回 CSV
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    print(f"✅ 更新完成！最後已一次性寫入 CSV。共更新: {updated_count} 筆, 跳過/未找到: {skipped_count} 筆。")

if __name__ == '__main__':
    main()
