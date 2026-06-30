import csv
import json
import os

# Define file paths
json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"
csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"

# Load the JSON descriptions
with open(json_path, 'r', encoding='utf-8') as f:
    descriptions = json.load(f)

# Read the CSV file
rows = []
with open(csv_path, 'r', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    header = next(reader)
    rows.append(header)
    for row in reader:
        if len(row) > 0:
            company_name = row[0].strip()
            # If the company is in our JSON, update the '說明' (index 8)
            if company_name in descriptions:
                # Ensure the row has enough columns
                while len(row) < 9:
                    row.append('')
                row[8] = descriptions[company_name]
            rows.append(row)

# Write the updated rows back to the CSV file
# Using utf-8-sig to preserve Excel compatibility (BOM) if it was there,
# or just utf-8. The original file was read with utf-8-sig.
with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(rows)

print(f"Successfully updated {len(rows) - 1} rows in {csv_path}")
