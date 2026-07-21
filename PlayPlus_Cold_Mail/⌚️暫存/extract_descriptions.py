import csv
import json
import os

csv_path = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv'
json_path = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/extracted_descriptions.json'

with open(csv_path, 'r', encoding='utf-8-sig') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

unique_companies = {}
for row in rows:
    name = row.get('公司名稱', '').strip()
    desc = row.get('說明', '').strip()
    if name and name not in unique_companies:
        unique_companies[name] = desc

os.makedirs(os.path.dirname(json_path), exist_ok=True)
with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(unique_companies, f, ensure_ascii=False, indent=2)

print(f"Extracted {len(unique_companies)} unique companies to {json_path}")
