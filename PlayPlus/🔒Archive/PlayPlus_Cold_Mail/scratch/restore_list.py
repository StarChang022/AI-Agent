import csv
import os

CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
SOURCE_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/104初期名單.csv"

def restore():
    # Read existing rows in 名單副本
    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames
        existing_rows = list(reader)
    
    existing_names = {row["公司品牌簡稱"] for row in existing_rows}
    
    # Read target companies from 104初期名單 (first 41 lines)
    target_companies = []
    with open(SOURCE_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        count = 0
        for row in reader:
            count += 1
            if count > 40: break
            name = row["公司名稱"]
            if name == "年終獎金": continue
            target_companies.append({
                "公司品牌簡稱": name,
                "來源": row["104頁面連結"]
            })
    
    # Add missing companies back
    added_count = 0
    for target in target_companies:
        if target["公司品牌簡稱"] not in existing_names:
            new_row = {col: "" for col in fieldnames}
            new_row.update(target)
            new_row["序號"] = "20260512" # Based on existing data
            existing_rows.append(new_row)
            added_count += 1
            print(f"Restored: {target['公司品牌簡稱']}")
            
    if added_count > 0:
        # Sort or just write back
        with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(existing_rows)
        print(f"Done. Restored {added_count} companies.")
    else:
        print("No companies missing.")

if __name__ == "__main__":
    restore()
