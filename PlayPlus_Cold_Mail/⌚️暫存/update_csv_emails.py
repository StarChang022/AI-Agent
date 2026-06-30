import csv
import json

json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"
csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"

# Load the generated emails
with open(json_path, 'r', encoding='utf-8') as f:
    emails_list = json.load(f)

# Convert the list to a dictionary keyed by (company_name, email)
emails_dict = {}
for entry in emails_list:
    key = (entry["company_name"].strip(), entry["email"].strip())
    emails_dict[key] = entry

# Read the CSV and update the matching rows
rows = []
updated_count = 0
with open(csv_path, 'r', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    header = next(reader)
    rows.append(header)
    for row in reader:
        if len(row) > 10:
            company_name = row[0].strip()
            email = row[5].strip()
            scenario = row[10].strip()
            if scenario == "大企業_企業內部系統":
                key = (company_name, email)
                if key in emails_dict:
                    entry = emails_dict[key]
                    # Ensure the row has enough columns (up to index 25, so length at least 26)
                    while len(row) < 26:
                        row.append('')
                    row[16] = entry["day1_title"]
                    row[17] = entry["day1_content"]
                    row[18] = entry["day7_title"]
                    row[19] = entry["day7_content"]
                    row[20] = entry["day14_title"]
                    row[21] = entry["day14_content"]
                    row[22] = entry["day30_title"]
                    row[23] = entry["day30_content"]
                    row[24] = entry["day60_title"]
                    row[25] = entry["day60_content"]
                    updated_count += 1
                else:
                    print(f"Warning: Match not found in JSON for {company_name} <{email}>")
        rows.append(row)

# Write the updated rows back to the CSV
with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(rows)

print(f"Successfully updated {updated_count} rows in {csv_path}")
