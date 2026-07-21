import csv
import json
import os

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
TEMP_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104.json")

def get_greeting(contact_name):
    contact_name = contact_name.strip()
    if contact_name == "官方" or contact_name.lower().endswith("窗口") or contact_name == "":
        return "您好，"
    return f"{contact_name} 您好，"

def analyze_industry(desc):
    desc = desc.lower()
    manufacturing_keywords = ["製造", "工業", "機械", "機電", "零件", "科技", "硬體", "五金", "鋼鐵", "精密", "塑膠", "紡織"]
    if any(k in desc for k in manufacturing_keywords):
        return "manufacturing"
    return "other"

def get_quickey_day7_context(desc):
    desc = desc.lower()
    if "食品" in desc or "生技" in desc:
        return "特別是針對貴司經常處理的食材與原物料採購單據，能省下大量的登打時間"
    if analyze_industry(desc) == "manufacturing":
        return "特別是針對貴司經常處理的進銷存單據與零組件採購紀錄，能省下大量的登打時間"
    return "特別是針對貴司日常運營中繁瑣的請款與收據核銷流程，能省下大量的登打時間"

def generate_quickey(contact_name, desc):
    greeting = get_greeting(contact_name)
    d7_context = get_quickey_day7_context(desc)
    
    day1_title = "幾秒鐘完成月底的發票處理"
    day1_content = f"{greeting}<br><br>我的客戶們經常在月底或月初都面臨同樣一件頭痛的事，將收據或發票紀錄到電腦裡面很費工...<br>不知道你們目前是不是也還在用人工一筆筆登打這些支出？<br><br>因為看到這個痛點，我們最近開發了一個叫「QuicKey快記」的小工具。簡單來說，就是讓同仁直接拍發票，系統會自動幫忙建檔成支出紀錄。<br><br>如果你剛好有遇到類似的困擾，可以直接玩玩看我們做的測試版：<br>https://demos.playplus.dev/quickey/<br><br>祝順利。"
    
    day7_title = f"Re: {day1_title}"
    day7_content = f"{greeting}<br><br>我是 PlayPlus 的阿星，上週曾寫信與您交流。<br><br>理解您平時業務繁忙，特此簡單追蹤。其實我們發現，導入 OCR 自動辨識後，多數企業能省下至少一半的報帳時間。{d7_context}。<br><br>若您上週比較忙碌還沒時間體驗，這裡再次附上可以隨時免費測試的 Demo 連結，邀請您花 3 分鐘親自操作看看：<br>https://demos.playplus.dev/quickey/<br><br>若您體驗後覺得有幫助，歡迎在 Demo 頁面點擊「問卷調查」與我們交流。<br><br>祝順利。"
    
    day30_title = "關於優化報帳流程的最後一封信"
    day30_content = f"{greeting}<br><br>打擾了，這是最後一封追蹤信，未來我不會再發信打擾您的收件匣。<br><br>在結束追蹤前，還是想再次提醒，若貴公司未來希望擺脫人工登打發票的繁瑣流程，我們打造的「快記」OCR 報帳系統，會是您提升行政效率的絕佳幫手。<br><br>您依然可以保留這個 Demo 連結，隨時進行測試：<br>https://demos.playplus.dev/quickey/<br><br>若未來貴司有優化內部支出的需求，歡迎您隨時在 Demo 頁面點擊「問卷調查」與我們聯繫。<br><br>祝順利。"
    
    return day1_title, day1_content, day7_title, day7_content, day30_title, day30_content

def generate_big_enterprise(contact_name, desc):
    greeting = get_greeting(contact_name)
    industry = analyze_industry(desc)
    
    if industry == "manufacturing":
        d1_context = "供應商管理、跨部門人力調度"
        d7_context = "特別是針對貴司常見的產線數據串接與跨部門單據審核"
        d30_context = "提升跨部門與產線的資源綜效"
    else:
        d1_context = "一站式入口、工時登錄及簽核流程重構"
        d7_context = "特別是針對貴司常見的跨部門協作與單據簽核"
        d30_context = "提升跨部門協作的資源綜效與效率"
        
    day1_title = "神達集團的系統整合經驗分享"
    day1_content = f"{greeting}<br><br>我是 PlayPlus 的阿星。我們近期協助神達集團設計及整合了多個企業系統，包含{d1_context}等。<br><br>我理解像貴司這樣的規模，每個工作環節應該都已經有既定的系統在運作。但如果剛好你們近期有碰到痛點，需要討論「優化舊有系統」或「梳理新流程」，隨時歡迎找我們討論。<br><br>如果不介意，您可以參考我們協助神達整合系統的案例介紹：<br>https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system<br><br>祝順利。"
    
    day7_title = f"Re: {day1_title}"
    day7_content = f"{greeting}<br><br>我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤。<br><br>我們在協助大型集團數位轉型時，非常注重「前半段」的設計討論。{d7_context}，在實際開發前，我們會深度盤點並將營運流程標準化，打造直觀系統，降低員工學習成本。<br><br>附上我們的案例簡報供您參考：https://playplus.com.tw/internal-system-briefing.pdf<br><br>若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br><br>祝順利。"
    
    day30_title = "企業內部系統優化的最後一封信"
    day30_content = f"{greeting}<br><br>打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br><br>在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型{d30_context}，我們 PlayPlus 能提供專業服務，為您梳理營運流程。<br><br>我再次附上案例簡報：https://playplus.com.tw/internal-system-briefing.pdf<br>若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。<br><br>祝順利。"
    
    return day1_title, day1_content, day7_title, day7_content, day30_title, day30_content


def main():
    # Load JSON
    with open(TEMP_JSON_PATH, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    # Read CSV to get company specific info
    companies_info = {}
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        for row in reader:
            comp_name = row['公司名稱'].strip()
            if not comp_name: continue
            if comp_name not in companies_info:
                companies_info[comp_name] = {
                    'Scenarios': row['Scenarios'].strip(),
                    '聯絡人名稱': row['聯絡人名稱'].strip(),
                    '說明': row['說明'].strip()
                }

    updated_count = 0
    # Process structured cases
    for comp_name, info in companies_info.items():
        if comp_name not in data:
            continue
            
        scenario = info['Scenarios']
        contact_name = info['聯絡人名稱']
        desc = info['說明']
        
        if scenario == 'Quickey_快記':
            d1t, d1c, d7t, d7c, d30t, d30c = generate_quickey(contact_name, desc)
        elif scenario == '大企業_企業內部系統':
            d1t, d1c, d7t, d7c, d30t, d30c = generate_big_enterprise(contact_name, desc)
        else:
            continue
            
        data[comp_name]['day1_title'] = d1t
        data[comp_name]['day1_content'] = d1c
        data[comp_name]['day7_title'] = d7t
        data[comp_name]['day7_content'] = d7c
        data[comp_name]['day14_title'] = '-'
        data[comp_name]['day14_content'] = '-'
        data[comp_name]['day30_title'] = d30t
        data[comp_name]['day30_content'] = d30c
        data[comp_name]['day60_title'] = '-'
        data[comp_name]['day60_content'] = '-'
        
        updated_count += 1
        
    # Save back to JSON
    with open(TEMP_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        
    print(f"✅ Generated structured emails for {updated_count} companies.")

if __name__ == "__main__":
    main()
