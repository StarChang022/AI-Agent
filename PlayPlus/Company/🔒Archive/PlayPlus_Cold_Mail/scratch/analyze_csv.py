import os
import csv

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')

with open(CSV_PATH, 'r', encoding='utf-8', newline='') as f:
    reader = csv.reader(f)
    rows = list(reader)

print(f"Number of rows parsed by csv.reader: {len(rows)}")
if len(rows) > 0:
    header = rows[0]
    print(f"Header: {header}")
    try:
        name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
        print(f"Indices: 公司名稱={name_idx}, 說明={desc_idx}")
        
        unique_companies = set()
        with_desc = 0
        empty_desc = 0
        
        for i, row in enumerate(rows[1:], start=2):
            if not row or len(row) <= max(name_idx, desc_idx):
                continue
            comp_name = row[name_idx].strip()
            unique_companies.add(comp_name)
            desc = row[desc_idx].strip()
            if desc:
                with_desc += 1
            else:
                empty_desc += 1
        print(f"Unique companies: {len(unique_companies)}")
        print(f"Rows with desc: {with_desc}")
        print(f"Rows with empty desc: {empty_desc}")
    except ValueError as e:
        print(f"Error: {e}")
