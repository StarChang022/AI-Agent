import csv
import json

with open('/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    scenarios = {}
    for row in reader:
        comp = row['公司名稱'].strip()
        scen = row['Scenarios'].strip()
        if comp and scen:
            scenarios[comp] = scen

with open('/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

missing = {'Quickey_快記': [], '大企業_企業內部系統': [], '中小企業_企業內部系統': []}
for comp, scen in scenarios.items():
    if comp in data:
        day1 = data[comp].get('day1_content', '')
        if not day1:
            missing[scen].append(comp)
        else:
            if scen == 'Quickey_快記' and 'QuicKey快記' not in day1:
                missing[scen].append(comp)
            elif scen == '大企業_企業內部系統' and '神達' not in day1:
                missing[scen].append(comp)
            elif scen == '中小企業_企業內部系統' and 'QuicKey快記' in day1:
                missing[scen].append(comp)

for k, v in missing.items():
    print(f"{k}: {len(v)} missing or incorrect")
    if v:
        print(f"  Example: {v[0]}")
