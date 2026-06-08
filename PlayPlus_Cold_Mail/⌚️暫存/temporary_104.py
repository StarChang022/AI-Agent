import pandas as pd
import shutil
import os
import json

# Define file paths
csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
backup_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本_backup.csv"
json_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"

# 1. Back up the original file
if not os.path.exists(backup_path):
    shutil.copy2(csv_path, backup_path)
    print(f"Successfully backed up {csv_path} to {backup_path}")
else:
    print(f"Backup already exists at {backup_path}")

# 2. Load the mapped descriptions from JSON
with open(json_path, 'r', encoding='utf-8') as f:
    mapping = json.load(f)

# 3. Read original CSV file
df = pd.read_csv(csv_path, encoding='utf-8')

# 4. Map the company description
print("Updating descriptions...")
unmapped_companies = []
# Clean keys in mapping dict
mapping = {str(k).strip(): v for k, v in mapping.items()}

for index, row in df.iterrows():
    co_name = str(row['公司名稱']).strip()
    if co_name in mapping:
        df.at[index, '說明'] = mapping[co_name]
    else:
        unmapped_companies.append(row['公司名稱'])

if unmapped_companies:
    print(f"Warning: Found unmapped companies in CSV: {set(unmapped_companies)}")
else:
    print("All companies successfully mapped!")

# 5. Save the updated dataframe back to CSV
df.to_csv(csv_path, index=False, encoding='utf-8')
print(f"Successfully saved updated CSV to {csv_path}")

# 6. Verify first few rows
print("\nVerification (First 5 rows):")
df_ver = pd.read_csv(csv_path, encoding='utf-8')
for idx, row in df_ver.head(5).iterrows():
    print(f"Company: {row['公司名稱']}")
    print(f"Updated Description: {row['說明']}")
    print("-" * 50)
