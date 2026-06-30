import csv

csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對雄/名單副本.csv"
# Wait, typo in the path above: "冷郵件對雄" -> "冷郵件對象"
csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"

rows = []
with open(csv_path, 'r', encoding='utf-8-sig') as f:
    reader = csv.reader(f)
    for row in reader:
        rows.append(row)

# Excel rows 64 to 107 correspond to 0-based indices 63 to 106 in the rows list
# Column R is index 17 (day1_content)
# Column T is index 19 (day7_content)
# Column X is index 23 (day30_content)
updated_count = 0
for excel_row_idx in range(64, 108):
    list_idx = excel_row_idx - 1
    if list_idx < len(rows):
        row = rows[list_idx]
        # Update Column R (index 17)
        if len(row) > 17 and row[17]:
            row[17] = row[17].replace('\r\n', '\n').replace('\n', '<br>')
        # Update Column T (index 19)
        if len(row) > 19 and row[19]:
            row[19] = row[19].replace('\r\n', '\n').replace('\n', '<br>')
        # Update Column X (index 23)
        if len(row) > 23 and row[23]:
            row[23] = row[23].replace('\r\n', '\n').replace('\n', '<br>')
        updated_count += 1

with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(rows)

print(f"Successfully replaced newlines with <br> in {updated_count} rows (Excel rows 64-107)")
