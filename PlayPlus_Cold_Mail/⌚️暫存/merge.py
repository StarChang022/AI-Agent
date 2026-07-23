import csv
import json

with open("temporary_104.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# Create a dictionary mapping row index (1-indexed based on CSV rows) to generated data
# The JSON "row" matches the 0-indexed reader index + 1, so row = 2 means row index 1 in reader.
# Wait, let's map by row number directly.
row_data = {item["row"]: item for item in data}

input_csv = "../冷郵件對象/名單副本.csv"
output_csv = "../冷郵件對象/名單副本_updated.csv"

with open(input_csv, "r", encoding="utf-8") as f:
    reader = list(csv.reader(f))

for i, row in enumerate(reader):
    if i == 0:
        continue # header
    
    # 0-indexed i corresponds to 1-indexed row number i+1
    row_num = i + 1
    
    if row_num in row_data:
        d = row_data[row_num]
        
        # Ensure row has enough columns
        while len(row) < 21:
            row.append("-")
            
        row[11] = d.get("day1_title", "-")
        row[12] = d.get("day1_content", "-")
        row[13] = d.get("day7_title", "-")
        row[14] = d.get("day7_content", "-")
        
        row[15] = "-" # day14 title
        row[16] = "-" # day14 content
        
        row[17] = d.get("day30_title", "-")
        row[18] = d.get("day30_content", "-")
        
        row[19] = "-" # day60 title
        row[20] = "-" # day60 content

        for j in range(11, 21):
            if not row[j]:
                row[j] = "-"

with open(output_csv, "w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f)
    writer.writerows(reader)
