import csv
import json
import os

csv_path = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv'
json_path = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json'

def get_greeting(contact_name):
    if not contact_name or '官方' in contact_name:
        return '您好'
    else:
        return f'{contact_name} 您好'

def is_manufacturing(industry, desc):
    keywords = ['製造', '科技', '硬體', '機械', '五金', '電子']
    text = (industry + desc).lower()
    return any(k in text for k in keywords)

rows = []
with open(csv_path, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames
    for row in reader:
        rows.append(row)

# Process rows
for row in rows:
    scenario = row.get('Scenarios')
    company = row.get('公司名稱', '')
    contact = row.get('聯絡人名稱', '')
    industry = row.get('產業', '')
    desc = row.get('說明', '')
    
    if scenario == 'Quickey_快記':
        greeting = get_greeting(contact)
        day1_title = '幾秒鐘完成月底的發票處理'
        day1_content = f'{greeting}，<br><br>我的客戶們經常在月底或月初都面臨同樣一件頭痛的事，將收據或發票紀錄到電腦裡面很費工...<br>不知道你們目前是不是也還在用人工一筆筆登打這些支出？<br><br>因為看到這個痛點，我們最近開發了一個叫「QuicKey快記」的小工具。簡單來說，就是讓同仁直接拍發票，系統會自動幫忙建檔成支出紀錄。<br><br>如果你剛好有遇到類似的困擾，可以直接玩玩看我們做的測試版：<br>https://demos.playplus.dev/quickey/<br><br>祝順利。<br><br>感謝您'
        
        day7_title = f'Re: {day1_title}'
        day7_rule3 = '這對於像貴司這樣快速成長的團隊來說，能大幅釋放行政量能，讓同仁專注於更有價值的事務上。'
        day7_content = f'{greeting}，<br><br>我是 PlayPlus 的阿星，上週曾寫信與您交流。<br><br>理解您平時業務繁忙，特此簡單追蹤。其實我們發現，導入 OCR 自動辨識後，多數企業能省下至少一半的報帳時間。{day7_rule3}<br><br>若您上週比較忙碌還沒時間體驗，這裡再次附上可以隨時免費測試的 Demo 連結，邀請您花 3 分鐘親自操作看看：<br>https://demos.playplus.dev/quickey/<br><br>若您體驗後覺得有幫助，歡迎在 Demo 頁面點擊「問卷調查」與我們交流。<br><br>祝順利。<br><br>感謝您'
        
        day30_title = '關於優化報帳流程的最後一封信'
        day30_content = f'{greeting}，<br><br>打擾了，這是最後一封追蹤信，未來我不會再發信打擾您的收件匣。<br><br>在結束追蹤前，還是想再次提醒，若貴公司未來希望擺脫人工登打發票的繁瑣流程，我們打造的「快記」OCR 報帳系統，會是您提升行政效率的絕佳幫手。<br><br>您依然可以保留這個 Demo 連結，隨時進行測試：<br>https://demos.playplus.dev/quickey/<br><br>若未來貴司有優化內部支出的需求，歡迎您隨時在 Demo 頁面點擊「問卷調查」與我們聯繫。<br><br>祝順利。<br><br>感謝您'
        
        row['day1_title'] = day1_title
        row['day1_content'] = day1_content
        row['day7_title'] = day7_title
        row['day7_content'] = day7_content
        row['day14_title'] = '-'
        row['day14_content'] = '-'
        row['day30_title'] = day30_title
        row['day30_content'] = day30_content
        row['day60_title'] = '-'
        row['day60_content'] = '-'

    elif scenario == '大企業_企業內部系統':
        greeting = get_greeting(contact)
        is_manu = is_manufacturing(industry, desc)
        
        rule3 = '供應商管理、跨部門人力調度' if is_manu else '一站式入口、工時登錄及簽核流程重構'
        rule4_day7 = '特別是針對貴司常見的產線協作與物料單據審核' if is_manu else '特別是針對貴司常見的跨據點協作與單據審核'
        rule4_day30 = '優化供應鏈與生產管理' if is_manu else '提升跨部門的資源綜效'
        
        day1_title = '神達集團的系統整合經驗分享'
        day1_content = f'{greeting}，<br><br>我是 PlayPlus 的阿星。我們近期協助神達集團設計及整合了多個企業系統，包含{rule3}等。<br><br>我理解像貴司這樣的規模，每個工作環節應該都已經有既定的系統在運作。但如果剛好你們近期有碰到痛點，需要討論「優化舊有系統」或「梳理新流程」，隨時歡迎找我們討論。<br><br>如果不介意，您可以參考我們協助神達整合系統的案例介紹：<br>https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system<br><br>祝順利。<br><br>感謝您'
        
        day7_title = f'Re: {day1_title}'
        day7_content = f'{greeting}，<br><br>我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤。<br><br>我們在協助大型集團數位轉型時，非常注重「前半段」的設計討論。{rule4_day7}，在實際開發前，我們會深度盤點並將營運流程標準化，打造直觀系統，降低員工學習成本。<br><br>附上我們的案例簡報供您參考：https://playplus.com.tw/internal-system-briefing.pdf<br><br>若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br><br>祝順利。<br><br>感謝您'
        
        day30_title = '企業內部系統優化的最後一封信'
        day30_content = f'{greeting}，<br><br>打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br><br>在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型{rule4_day30}，我們 PlayPlus 能提供專業服務，為您梳理營運流程。<br><br>我再次附上案例簡報：https://playplus.com.tw/internal-system-briefing.pdf<br>若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。<br><br>祝順利。<br><br>感謝您'
        
        row['day1_title'] = day1_title
        row['day1_content'] = day1_content
        row['day7_title'] = day7_title
        row['day7_content'] = day7_content
        row['day14_title'] = '-'
        row['day14_content'] = '-'
        row['day30_title'] = day30_title
        row['day30_content'] = day30_content
        row['day60_title'] = '-'
        row['day60_content'] = '-'

# Write to JSON temp file first as instructed
os.makedirs(os.path.dirname(json_path), exist_ok=True)
with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(rows, f, ensure_ascii=False, indent=2)

# Write back to CSV
with open(csv_path, 'w', encoding='utf-8', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print("Successfully regenerated emails and saved to CSV.")
