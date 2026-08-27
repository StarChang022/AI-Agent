import os
import csv

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')

with open(CSV_PATH, 'r', encoding='utf-8', newline='') as f:
    reader = csv.reader(f)
    rows = list(reader)

header = rows[0]
scen_idx = header.index("Scenarios")
name_idx = header.index("公司名稱")
day1_title_idx = header.index("day1_title")
day1_content_idx = header.index("day1_content")

total_large_corp = 0
large_corp_filled = 0
large_corp_empty = 0

for i, row in enumerate(rows[1:], start=2):
    if not row or len(row) <= max(scen_idx, day1_title_idx, day1_content_idx):
        continue
    scen = row[scen_idx].strip()
    if scen == "大企業_企業內部系統":
        total_large_corp += 1
        day1_t = row[day1_title_idx].strip()
        day1_c = row[day1_content_idx].strip()
        if day1_t or day1_c:
            large_corp_filled += 1
        else:
            large_corp_empty += 1
            print(f"Row {i}: {row[name_idx]} is empty")

print(f"Total rows with Scenario '大企業_企業內部系統': {total_large_corp}")
print(f"Filled: {large_corp_filled}")
print(f"Empty: {large_corp_empty}")
