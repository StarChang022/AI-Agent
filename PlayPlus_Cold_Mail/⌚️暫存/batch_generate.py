import json

def get_industry_short(industry_full):
    if "製造" in industry_full or "工業" in industry_full:
        return "製造業"
    elif "生化科技" in industry_full or "生技醫療" in industry_full or "醫療" in industry_full:
        return "生技醫療業"
    elif "電腦" in industry_full or "軟體" in industry_full or "科技" in industry_full or "半導體" in industry_full or "電子" in industry_full:
        return "科技業"
    elif "餐飲" in industry_full or "食品" in industry_full:
        return "餐飲食品業"
    elif "零售" in industry_full or "批發" in industry_full or "貿易" in industry_full or "電商" in industry_full:
        return "零售批發業"
    elif "金融" in industry_full or "保險" in industry_full:
        return "金融業"
    elif "營造" in industry_full or "建築" in industry_full or "工程" in industry_full or "不動產" in industry_full:
        return "營建不動產業"
    elif "運輸" in industry_full or "物流" in industry_full:
        return "物流運輸業"
    elif "服務" in industry_full or "教育" in industry_full or "旅遊" in industry_full:
        return "服務業"
    return industry_full.replace("業", "") + "領域" if not industry_full.endswith("業") else industry_full

def get_tech_focus(desc, industry):
    tech_keywords = ['製造', '科技', '硬體', '電子', '半導體', '工業', '光電', '零組件', '自動化', '機械']
    is_tech = any(k in industry or k in desc for k in tech_keywords)
    if is_tech:
        return "供應商管理與跨部門人力調度", "產線協作與物料單據審核", "優化供應鏈與生產管理"
    else:
        return "一站式入口、工時登錄及簽核流程重構", "跨據點協作與單據審核", "梳理複雜的行政與服務流程"

def generate_big_enterprise(row):
    industry = row.get("產業", "企業")
    ind_short = get_industry_short(industry)
    desc = row.get("說明", "")
    contact = row.get("聯絡人名稱", "官方")
    company_name = row.get("公司名稱", "").replace("股份有限公司", "").replace("有限公司", "")
    
    greeting = "您好，" if contact == "官方" else f"{contact} 您好，"
    
    focus_1, focus_2, focus_3 = get_tech_focus(desc, industry)
    
    day1_title = f"關於{company_name}營運系統重構的一些觀察"
    day7_title = f"Re: {day1_title}"
    day30_title = "企業內部系統優化的最後一封信"
    
    day1_content = f"{greeting}<br><br>我們主要協助 {ind_short} 領域的企業，優化內部營運流程。根據我們的經驗，企業在擴張或調整組織時，內部流程跟報表多半仍高度依賴人工處理，容易產生資訊斷層。不知道貴司目前是否有內部系統數位化、或流程升級的評估計劃？<br><br>我們 PlayPlus 近期剛協助神達集團整合了{focus_1}，將繁瑣的流程大幅降低人工比例。<br><br>如果不確定這是否是你們目前關注的方向，請問是否介意我寄一份 2 分鐘的案例說明給您參考？<br><br>祝順利。<br><br>感謝您"
    
    day7_content = f"{greeting}<br><br>我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤。<br><br>我們在協助大型集團數位轉型時，非常注重「前半段」的設計討論。特別是針對貴司常見的{focus_2}，在實際開發前，我們會深度盤點並將營運流程標準化，打造直觀系統，降低員工學習成本。<br><br>附上我們的案例簡報供您參考：https://playplus.com.tw/internal-system-briefing.pdf<br><br>若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br><br>祝順利。<br><br>感謝您"
    
    day30_content = f"{greeting}<br><br>打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br><br>在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型{focus_3}，我們 PlayPlus 能提供專業服務，為您梳理營運流程。<br><br>我再次附上案例簡報：https://playplus.com.tw/internal-system-briefing.pdf<br>若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。<br><br>祝順利。<br><br>感謝您"
    
    return day1_title, day1_content, day7_title, day7_content, day30_title, day30_content

def generate_quickey(row):
    contact = row.get("聯絡人名稱", "官方")
    
    greeting = "您好，" if contact == "官方" else f"{contact} 您好，"
    
    day1_title = "幾秒鐘完成月底的發票處理"
    day7_title = f"Re: {day1_title}"
    day30_title = "關於優化報帳流程的最後一封信"
    
    day1_content = f"{greeting}<br><br>我的客戶們經常在月底或月初都面臨同樣一件頭痛的事，將收據或發票紀錄到電腦裡面很費工...<br>不知道你們目前是不是也還在用人工一筆筆登打這些支出？<br><br>因為看到這個痛點，我們最近開發了一個叫「QuicKey快記」的小工具。簡單來說，就是讓同仁直接拍發票，系統會自動幫忙建檔成支出紀錄。<br><br>如果你剛好有遇到類似的困擾，可以直接玩玩看我們做的測試版：<br>https://demos.playplus.dev/quickey/<br><br>祝順利。<br><br>感謝您"
    
    day7_content = f"{greeting}<br><br>我是 PlayPlus 的阿星，上週曾寫信與您交流。<br><br>理解您平時業務繁忙，特此簡單追蹤。其實我們發現，導入 OCR 自動辨識後，多數企業能省下至少一半的報帳時間。這對於像貴司這樣快速成長的團隊來說，能大幅釋放行政量能，讓同仁專注於更有價值的事務上。<br><br>若您上週比較忙碌還沒時間體驗，這裡再次附上可以隨時免費測試的 Demo 連結，邀請您花 3 分鐘親自操作看看：<br>https://demos.playplus.dev/quickey/<br><br>若您體驗後覺得有幫助，歡迎在 Demo 頁面點擊「問卷調查」與我們交流。<br><br>祝順利。<br><br>感謝您"
    
    day30_content = f"{greeting}<br><br>打擾了，這是最後一封追蹤信，未來我不會再發信打擾您的收件匣。<br><br>在結束追蹤前，還是想再次提醒，若貴公司未來希望擺脫人工登打發票的繁瑣流程，我們打造的「快記」OCR 報帳系統，會是您提升行政效率的絕佳幫手。<br><br>您依然可以保留這個 Demo 連結，隨時進行測試：<br>https://demos.playplus.dev/quickey/<br><br>若未來貴司有優化內部支出的需求，歡迎您隨時在 Demo 頁面點擊「問卷調查」與我們聯繫。<br><br>祝順利。<br><br>感謝您"
    
    return day1_title, day1_content, day7_title, day7_content, day30_title, day30_content

def main():
    with open('/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/generation_queue.json', 'r', encoding='utf-8') as f:
        queue = json.load(f)
    
    results = []
    
    for row in queue:
        scenario = row.get("Scenarios", "")
        if scenario == "大企業_企業內部系統":
            d1t, d1c, d7t, d7c, d30t, d30c = generate_big_enterprise(row)
        elif scenario == "Quickey_快記":
            d1t, d1c, d7t, d7c, d30t, d30c = generate_quickey(row)
        else:
            continue
            
        row["day1_title"] = d1t
        row["day1_content"] = d1c
        row["day7_title"] = d7t
        row["day7_content"] = d7c
        row["day14_title"] = "-"
        row["day14_content"] = "-"
        row["day30_title"] = d30t
        row["day30_content"] = d30c
        row["day60_title"] = "-"
        row["day60_content"] = "-"
        
        results.append(row)
        
    with open('/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json', 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
        
    print(f"Generated {len(results)} emails successfully.")

if __name__ == "__main__":
    main()
