import pandas as pd
import json

csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104_raw.json"

df = pd.read_csv(csv_path, encoding='utf-8')
mapping = {}
for idx, row in df.iterrows():
    name = str(row['公司名稱']).strip()
    desc = str(row['說明']).strip() if pd.notna(row['說明']) else ""
    mapping[name] = desc

with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(mapping, f, ensure_ascii=False, indent=2)

print(f"Extracted {len(mapping)} unique companies to {json_path}")
