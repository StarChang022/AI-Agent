import csv
import json

companies = []
with open('/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        comp = row['公司名稱'].strip()
        scen = row['Scenarios'].strip()
        desc = row['說明'].strip()
        contact = row['聯絡人名稱'].strip()
        if scen == '中小企業_企業內部系統':
            companies.append({'name': comp, 'desc': desc, 'contact': contact})

# unique list
seen = set()
unique_companies = []
for c in companies:
    if c['name'] not in seen:
        seen.add(c['name'])
        unique_companies.append(c)

for i, c in enumerate(unique_companies[:15]): # Batch 1: first 15
    print(f"--- Company {i+1} ---")
    print(f"Name: {c['name']}")
    print(f"Contact: {c['contact']}")
    print(f"Desc: {c['desc']}")
    
