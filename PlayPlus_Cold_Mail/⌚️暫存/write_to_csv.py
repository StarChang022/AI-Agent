import csv
import json
import shutil

# Read generated data
with open('/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json', 'r', encoding='utf-8') as f:
    generated_data = json.load(f)

# Create a lookup dictionary by company name
gen_map = {}
for row in generated_data:
    company = row.get("公司名稱", "")
    if company:
        gen_map[company] = row

csv_path = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv'
backup_path = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv.bak'

# Backup the file first
shutil.copy2(csv_path, backup_path)

# Read original csv
with open(csv_path, 'r', encoding='utf-8-sig') as f:
    reader = list(csv.DictReader(f))
    fieldnames = reader[0].keys() if reader else []

# Update reader with generated data
updated_count = 0
for row in reader:
    company = row.get("公司名稱", "")
    if company in gen_map:
        gen_row = gen_map[company]
        # Update email fields
        row['day1_title'] = gen_row.get('day1_title', '')
        row['day1_content'] = gen_row.get('day1_content', '')
        row['day7_title'] = gen_row.get('day7_title', '')
        row['day7_content'] = gen_row.get('day7_content', '')
        row['day14_title'] = gen_row.get('day14_title', '')
        row['day14_content'] = gen_row.get('day14_content', '')
        row['day30_title'] = gen_row.get('day30_title', '')
        row['day30_content'] = gen_row.get('day30_content', '')
        row['day60_title'] = gen_row.get('day60_title', '')
        row['day60_content'] = gen_row.get('day60_content', '')
        updated_count += 1

# Write back to csv with utf-8-sig
with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(reader)

print(f"Successfully updated {updated_count} rows in CSV.")
