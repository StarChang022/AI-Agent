import csv
import json
import os

csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"

def main():
    if not os.path.exists(csv_path):
        print(f"CSV file not found: {csv_path}")
        return

    records = []
    with open(csv_path, mode='r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        print("Header:", header)
        
        # We need to find the index of "公司名稱" and "說明"
        name_idx = -1
        desc_idx = -1
        for i, col in enumerate(header):
            if col == "公司名稱":
                name_idx = i
            elif col == "說明":
                desc_idx = i
        
        print(f"Name index: {name_idx}, Description index: {desc_idx}")
        if name_idx == -1 or desc_idx == -1:
            print("Could not find '公司名稱' or '說明' columns.")
            return

        for idx, row in enumerate(reader):
            # The CSV row index (0-based for data rows, 1-based if including header)
            if len(row) <= max(name_idx, desc_idx):
                # Row might be malformed or empty
                continue
            name = row[name_idx]
            desc = row[desc_idx]
            records.append({
                "row_idx": idx, # 0-based index of data row
                "name": name,
                "desc": desc,
                "summary": "" # to be filled
            })

    print(f"Total records found: {len(records)}")
    
    # Ensure directory exists
    os.makedirs(os.path.dirname(json_path), exist_ok=True)
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(records, f, ensure_ascii=False, indent=2)
    print(f"Saved records to {json_path}")

if __name__ == "__main__":
    main()
