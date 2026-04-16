import csv
import re
import os

# 檔案路徑
CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
TEMP_CSV = CSV_PATH + ".tmp"

def clean_company_name(name):
    # 優先處理帶有底線 "_" 的品牌名
    if "_" in name:
        name = name.split("_")[0].strip()
    
    # 定義要移除的描述性詞彙與法律實體
    to_remove = [
        "股份有限公司", "有限公司", "合夥有限公司", "有限公司台北辦事處",
        "科技有限公司", "實業有限公司", "國際有限公司", "企業有限公司",
        "國際事業股份有限公司", "生化科技有限公司", "醫藥科技有限公司",
        "生醫科技有限公司", "科技股份有限公司", "管理顧問有限公司",
        "顧問有限公司", "事業有限公司", "開發有限公司", "行銷有限公司",
        "商業有限公司", "工程有限公司", "投資有限公司", "分公司", "工作室",
        "選貨商店", "好事交易所", "官方旗艦店", "電商平台"
    ]
    
    clean_name = name
    for item in sorted(to_remove, key=len, reverse=True):
        if clean_name.endswith(item):
            clean_name = clean_name[:-len(item)]
        # 也要處理中間出現的情況，如果後面還有 "_" 或空格（但我們已經拆過一次了）
        clean_name = clean_name.replace(item, "")

    # 處理 "GODA夠搭" -> "GODA" 或 "i good Point 好事" -> "i good Point"
    # 如果同時有英文與中文，且中文部分被認為是描述性的
    # 這裡我們觀察：如果開頭是英文，且後面跟著中文，通常英文是品牌
    eng_match = re.search(r'^([a-zA-Z0-9 &\'\.]+)', clean_name)
    if eng_match:
        eng_part = eng_match.group(1).strip()
        # 如果英文部分夠長 (例如 > 2 字)，且剩下的部分是描述性的中文，則只取英文
        # 這裡我們採取保守策略：如果英文後面接著中文，且英文不是只有一兩個字母
        if len(eng_part) >= 3 and eng_part != clean_name:
            # 如果剩下的中文包含了我們知道的描述詞，則只取英文
            return eng_part

    return clean_name.strip()

def process_csv():
    if not os.path.exists(CSV_PATH):
        print(f"File not found: {CSV_PATH}")
        return

    with open(CSV_PATH, 'r', encoding='utf-8-sig') as infile, \
         open(TEMP_CSV, 'w', encoding='utf-8-sig', newline='') as outfile:
        
        reader = csv.DictReader(infile)
        fieldnames = reader.fieldnames
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()
        
        for row in reader:
            original = row['公司品牌簡稱']
            cleaned = clean_company_name(original)
            row['公司品牌簡稱'] = cleaned
            writer.writerow(row)
            print(f"Original: {original} -> Cleaned: {cleaned}")

    # 替換原檔案
    os.replace(TEMP_CSV, CSV_PATH)
    print("CSV updated successfully.")

if __name__ == "__main__":
    process_csv()
