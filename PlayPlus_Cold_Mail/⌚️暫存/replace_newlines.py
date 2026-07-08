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
# Column M is index 12 (day1_content)
# Column O is index 14 (day7_content)
# Column S is index 18 (day30_content)
updated_count = 0
for excel_row_idx in range(64, 108):
    list_idx = excel_row_idx - 1
    if list_idx < len(rows):
        row = rows[list_idx]
        # Update Column M (index 12)
        if len(row) > 12 and row[12]:
            row[12] = row[12].replace('\r\n', '\n').replace('\n', '<br>')
        # Update Column O (index 14)
        if len(row) > 14 and row[14]:
            row[14] = row[14].replace('\r\n', '\n').replace('\n', '<br>')
        # Update Column S (index 18)
        if len(row) > 18 and row[18]:
            row[18] = row[18].replace('\r\n', '\n').replace('\n', '<br>')
        updated_count += 1

with open(csv_path, 'w', encoding='utf-8-sig', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(rows)

print(f"Successfully replaced newlines with <br> in {updated_count} rows (Excel rows 64-107)")
