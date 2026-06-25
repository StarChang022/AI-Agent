#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import csv
import json
import os

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
OUTPUT_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "extracted_descriptions.json")

def main():
    if not os.path.exists(CSV_PATH):
        print(f"❌ CSV file not found: {CSV_PATH}")
        return

    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV file is empty")
        return

    header = rows[0]
    try:
        name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
    except ValueError as e:
        print(f"❌ Missing headers: {e}")
        return

    unique_companies = {}
    for row in rows[1:]:
        if not row or len(row) <= max(name_idx, desc_idx):
            continue
        name = row[name_idx].strip()
        desc = row[desc_idx].strip()
        if name and desc:
            if name not in unique_companies:
                unique_companies[name] = desc

    with open(OUTPUT_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(unique_companies, f, ensure_ascii=False, indent=2)

    print(f"✅ Extracted {len(unique_companies)} unique companies to {OUTPUT_JSON_PATH}")

if __name__ == "__main__":
    main()
