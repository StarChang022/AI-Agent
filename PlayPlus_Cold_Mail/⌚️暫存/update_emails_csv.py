import os
import csv
import json

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL_CSV = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
TEMP_DIR = os.path.join(BASE_DIR, '⌚️暫存')

def load_all_emails():
    import sys
    sys.path.append(TEMP_DIR)
    import temporary_emails
    
    # Base dictionary from batch 1
    all_emails = {}
    all_emails.update(temporary_emails.EMAILS_DATA)
    
    # Load batch 2 to 5 from json
    for i in range(2, 6):
        json_path = os.path.join(TEMP_DIR, f'temporary_emails_batch{i}.json')
        if os.path.exists(json_path):
            with open(json_path, 'r', encoding='utf-8') as f:
                batch_data = json.load(f)
                all_emails.update(batch_data)
                
    return all_emails

def update_csv():
    all_emails = load_all_emails()
    print(f"Loaded {len(all_emails)} unique company email sequences.")
    
    if not os.path.exists(LOCAL_CSV):
        print(f"Error: {LOCAL_CSV} not found!")
        return

    with open(LOCAL_CSV, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("Error: CSV is empty!")
        return

    header = rows[0]
    updated_rows = [header]
    
    updated_count = 0
    not_found = set()

    for row in rows[1:]:
        # Ensure row has at least 25 columns (A to Y, index 0 to 24)
        while len(row) < 25:
            row.append('')

        company_name = row[0].strip()
        
        if company_name in all_emails:
            data = all_emails[company_name]
            # Indexes:
            # 15: day1_title, 16: day1_content
            # 17: day7_title, 18: day7_content
            # 19: day14_title, 20: day14_content
            # 21: day30_title, 22: day30_content
            # 23: day60_title, 24: day60_content
            
            row[15] = data.get('day1_title', '')
            row[16] = data.get('day1_content', '')
            
            row[17] = data.get('day7_title', '')
            row[18] = data.get('day7_content', '')
            
            row[19] = data.get('day14_title', '')
            row[20] = data.get('day14_content', '')
            
            row[21] = data.get('day30_title', '')
            row[22] = data.get('day30_content', '')
            
            row[23] = data.get('day60_title', '')
            row[24] = data.get('day60_content', '')
            
            updated_count += 1
        else:
            not_found.add(company_name)

        updated_rows.append(row)

    with open(LOCAL_CSV, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(updated_rows)

    print(f"Successfully updated {updated_count} rows in CSV.")
    if not_found:
        print(f"Companies not found in email generation data: {not_found}")

if __name__ == '__main__':
    update_csv()
