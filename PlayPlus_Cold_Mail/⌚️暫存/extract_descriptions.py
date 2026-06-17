#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import csv
import json

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
OUTPUT_JSON_PATH = os.path.join(BASE_DIR, '⌚️暫存', 'extracted_descriptions.json')

def main():
    if not os.path.exists(CSV_PATH):
        print(f"Error: {CSV_PATH} not found.")
        return

    with open(CSV_PATH, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("Error: CSV file is empty.")
        return

    header = rows[0]
    try:
        name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
    except ValueError as e:
        print(f"Error: Missing required column: {e}")
        return

    unique_companies = {}
    for row in rows[1:]:
        if len(row) <= max(name_idx, desc_idx):
            continue
        name = row[name_idx].strip()
        desc = row[desc_idx].strip()
        if name and desc:
            unique_companies[name] = desc

    with open(OUTPUT_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(unique_companies, f, ensure_ascii=False, indent=2)

    print(f"Successfully extracted {len(unique_companies)} unique company descriptions to {OUTPUT_JSON_PATH}")

if __name__ == "__main__":
    main()
