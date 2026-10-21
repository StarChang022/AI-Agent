import csv
import re
import os

csv_file = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"

def process_desc(desc, company_name):
    # Remove the company name at the beginning if present
    company_name = company_name.replace("股份有限公司", "").replace("有限公司", "")
    desc = desc.replace(company_name + "股份有限公司", "")
    desc = desc.replace(company_name + "有限公司", "")
    desc = desc.replace(company_name, "")
    
    # Clean up prefixes
    desc = re.sub(r'^(成立|創立)於\d+年，', '', desc)
    desc = re.sub(r'^為', '貴司為', desc)
    desc = re.sub(r'^專', '貴司專', desc)
    desc = re.sub(r'^深耕', '貴司深耕', desc)
    desc = re.sub(r'^以', '貴司以', desc)
    desc = re.sub(r'^主打', '貴司主打', desc)
    desc = re.sub(r'^具備', '貴司具備', desc)
    desc = re.sub(r'^擁有', '貴司擁有', desc)
    
    # If it still doesn't start with a natural subject, prepend "貴司"
    if not desc.startswith("貴司"):
        desc = "貴司" + desc
        
    return desc

def generate_quickey(row):
    contact = row[6].strip()
    greeting = "您好" if contact == "官方" else f"{contact} 您好"
    desc = row[8].strip()
    company = row[0].strip()
    
    clean_desc = process_desc(desc, company)
    hook = f"注意到{clean_desc}，平常的營運一定非常忙碌。我們發現許多從事相關業務的企業，每個月底行政同仁光是處理各項採購與零碎發票，就會耗掉一整天的時間。"
    
    day1_title = "關於改善貴司報帳流程的一些觀察"
    day1_content = f"{greeting}，<br><br>{hook}<br><br>不知道你們目前是否也還在用人工一筆筆登打這些支出？<br><br>為了解決這個痛點，我們開發了「快記」數位系統。透過 OCR 光學字元辨識技術，只需上傳發票照片就能自動建立支出紀錄，讓財務管理變得輕鬆準確。<br><br>不確定這是否是貴司目前想解決的痛點？如果有興趣，歡迎點擊下方連結進行 3 分鐘的免費 Demo 測試：<br>https://demos.playplus.dev/quickey/<br><br>感謝您"
    
    day7_title = f"Re: {day1_title}"
    day7_content = f"{greeting}，<br><br>我是 PlayPlus 的阿星，上週曾寫信與您交流。<br><br>理解您平時業務繁忙，特此簡單追蹤。其實我們發現，導入 OCR 自動辨識後，多數企業能省下至少一半的報帳時間。這對於常需要處理大量採購發票的企業來說，能省下非常可觀的行政成本。<br><br>若您上週比較忙碌還沒時間體驗，這裡再次附上可以隨時免費測試的 Demo 連結，邀請您花 3 分鐘親自操作看看：<br>https://demos.playplus.dev/quickey/<br><br>若您體驗後覺得有幫助，歡迎在 Demo 頁面點擊「問卷調查」與我們交流。<br><br>感謝您"
    
    day30_title = "關於優化報帳流程的最後一封信"
    day30_content = f"{greeting}，<br><br>打擾了，這是最後一封追蹤信，未來我不會再發信打擾您的收件匣。<br><br>在結束追蹤前，還是想再次提醒，若貴公司未來希望擺脫人工登打發票的繁瑣流程，我們打造的「快記」OCR 報帳系統，會是您提升行政效率的絕佳幫手。<br><br>您依然可以保留這個 Demo 連結，隨時進行測試：<br>https://demos.playplus.dev/quickey/<br><br>若未來貴司有優化內部支出的需求，歡迎您隨時在 Demo 頁面點擊「問卷調查」與我們聯繫。<br><br>感謝您"
    
    return [day1_title, day1_content, day7_title, day7_content, "-", "-", day30_title, day30_content, "-", "-"]

def generate_smb(row):
    contact = row[6].strip()
    greeting = "您好" if contact == "官方" else f"{contact} 您好"
    desc = row[8].strip()
    company = row[0].strip()
    
    clean_desc = process_desc(desc, company)
    hook = f"剛才在研究貴司的業務，得知{clean_desc}，這讓我印象非常深刻。我最近跟幾位同業主管交流，他們常提到業務擴張太快，導致內部表單跟報表系統開始出現斷層，消耗了團隊很多精力。"
    
    day1_title = "關於貴司目前內部管理系統的一些想法"
    day1_content = f"{greeting}，<br><br>{hook}<br><br>不知道這也是貴司目前的挑戰嗎？<br>如果是的話，我們有一套內部系統解決方案，能把表單與報表無縫整合，幫助團隊把時間花在更有價值的地方。<br><br>如果您有興趣進一步了解，歡迎參考我們的服務說明：<br>https://playplus.com.tw/services/internal-systems<br><br>如果有興趣進一步探討，隨時歡迎回信交流。<br><br>感謝您"
    
    day7_title = f"Re: {day1_title}"
    day7_content = f"{greeting}，<br><br>我是 PlayPlus 的阿星，上週曾跟您分享我們的內部系統解決方案。<br><br>我知道您平時業務繁忙，特此簡單追蹤。我們發現，只要能把報表與表單的資料打通，多數企業的行政溝通成本就能降低至少一半。<br><br>若您還沒看過我們的服務說明，這裡再次附上連結：<br>https://playplus.com.tw/services/internal-systems<br><br>歡迎您隨時回信，探討這套系統如何應用在您的團隊中。<br><br>感謝您"
    
    day30_title = "關於優化內部管理系統的最後一封信"
    day30_content = f"{greeting}，<br><br>打擾了，這是最後一封追蹤信，未來我不會再發信打擾您的收件匣。<br><br>在結束追蹤前，還是想再次提醒，若貴公司未來希望擺脫資料零散、表單繁雜的困擾，我們所開發的內部系統解決方案，會是您提升團隊效率的絕佳幫手。<br><br>您依然可以保留這個服務說明的連結，隨時參考：<br>https://playplus.com.tw/services/internal-systems<br><br>未來如果有任何內部系統的升級需求，非常歡迎您隨時與我們聯繫。<br><br>感謝您"
    
    return [day1_title, day1_content, day7_title, day7_content, "-", "-", day30_title, day30_content, "-", "-"]


new_rows = []
with open(csv_file, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    new_rows.append(header)
    
    for row in reader:
        scenario = row[10].strip()
        if scenario == "Quickey_快記":
            emails = generate_quickey(row)
            row[11:21] = emails
        elif scenario == "中小企業_企業內部系統":
            emails = generate_smb(row)
            row[11:21] = emails
        
        new_rows.append(row)

with open(csv_file, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(new_rows)

print(f"Successfully processed {len(new_rows)-1} rows.")
