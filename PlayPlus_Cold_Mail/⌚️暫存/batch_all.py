import csv

input_file = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv'

rows = []
with open(input_file, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)
    rows.append(header)
    
    idx_name = header.index('公司名稱')
    idx_desc = header.index('說明')
    idx_ind = header.index('產業')
    
    col_idx = {col: header.index(col) for col in ['day1_title', 'day1_content', 'day7_title', 'day7_content', 'day14_title', 'day14_content', 'day30_title', 'day30_content', 'day60_title', 'day60_content']}
    
    for row in reader:
        # Check if already filled
        if row[col_idx['day1_title']] != "":
            rows.append(row)
            continue
            
        comp_name = row[idx_name]
        short_name = comp_name.replace('股份有限公司', '').replace('有限公司', '').replace('科技集團_瑞磁生物科技', '')
        desc = row[idx_desc]
        ind = row[idx_ind]
        
        # Decide Social Proof and Pain Point
        if "食品" in desc or "飲水" in desc or "洗沐" in desc or "調味" in desc:
            sp_name = "食安智幫手APP"
            sp_link = "https://playplus.com.tw/portfolio/tfif-app"
            sp_desc = "解決食安資訊與流程追蹤的難題，將繁瑣的品管表單數位化"
            pain = "嚴格的品管把關與成分紀錄"
        elif "生醫" in desc or "醫療" in desc or "生技" in desc or "防護" in desc or "診斷" in desc:
            sp_name = "腎臟醫學會 TSN 病理系統"
            sp_link = "https://playplus.com.tw/portfolio/tsn"
            sp_desc = "整合龐大的病理數據與表單，讓跨單位的協作與追蹤變得透明且高效"
            pain = "龐大的檢驗數據與醫療級表單彙整"
        elif "租" in desc or "建" in desc or "鋁門窗" in desc or "綠建築" in desc:
            sp_name = "大管家包租代管系統"
            sp_link = "https://playplus.com.tw/portfolio/chrb"
            sp_desc = "將龐雜的物件管理與進度追蹤全面數位化，降低人為錯誤"
            pain = "龐雜的專案管理與進度追蹤"
        else:
            sp_name = "神達電腦會議室預約系統"
            sp_link = "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system"
            sp_desc = "解決跨部門資源爭奪的問題，讓內部營運不再因為繁瑣的紙本流程卡關"
            pain = "跨部門的資源調度與複雜的訂單、派工追蹤"
            
        row[col_idx['day1_title']] = f"如何解決{short_name}在{pain}上的耗時問題？"
        row[col_idx['day1_content']] = f"您好，<br><br>我們剛瀏覽了貴司的網站，對{comp_name}的優質產品與專業度印象深刻。不過我們也觀察到，許多企業在快速擴張或面對{pain}時，常會遇到內部管理與流程跟不上的問題，例如：新人交接困難、報表多半靠人工彙整等。<br><br>我們是 PlayPlus，專注於協助中型企業打造「客製化企業內部系統」。我們不推銷動輒數百萬的大型套裝系統，而是從你們最痛的一條流程開始，打造好紀錄、好追蹤、好交接的專屬系統。<br><br>是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>感謝您"
        
        row[col_idx['day7_title']] = f"快速跟進：關於{short_name}的內部流程優化"
        row[col_idx['day7_content']] = f"您好，<br><br>這是一封簡短的跟進信。不知道您是否有機會看過關於優化{short_name}內部管理流程的想法？<br><br>若您本週有空，只需幾分鐘，我們可以簡單聊聊現有的系統是否真正符合你們的需求。<br><br>感謝您"
        
        row[col_idx['day14_title']] = f"看看我們如何協助客戶提升營運效率"
        row[col_idx['day14_content']] = f"您好，<br><br>我們深知{comp_name}在業內的專業性，但在處理{pain}時，好用的數位工具能事半功倍。我們曾協助開發了{sp_name}（{sp_link}），成功{sp_desc}。<br><br>對於貴司來說，一套客製化的進度追蹤或管理系統，同樣能大幅降低人力盤點與彙整的時間成本。<br><br>希望有機會與您分享這份成功經驗。<br><br>感謝您"
        
        row[col_idx['day30_title']] = f"擔心系統開發曠日費時或超出預算嗎？"
        row[col_idx['day30_content']] = f"您好，<br><br>我知道導入系統常讓人聯想到高昂的費用與漫長的開發期。為了降低企業的疑慮，我們提供「模組化開發」與「分階段優化方案」，您完全可以根據目前的預算，選擇最迫切需要解決的流程先進行數位化。<br><br>而且我們極度重視溝通效率，主管每週只需 15 分鐘確認進度，絕不影響日常產能。<br><br>下週方便通個簡短的電話，評估一下可能性嗎？<br><br>感謝您"
        
        row[col_idx['day60_title']] = f"感謝您的時間，未來有需要隨時聯絡"
        row[col_idx['day60_content']] = f"您好，<br><br>因為一直沒有收到您的回覆，我假設{short_name}目前的內部管理系統運作良好，這是近期我發給您的最後一封信。<br><br>未來若在擴展市場或升級管理工具時，需要一套好追蹤、好交接的客製化內部系統，請記得 PlayPlus 隨時能為{comp_name}提供協助。<br><br>祝貴公司業績持續長紅！<br><br>感謝您"
        
        rows.append(row)

with open(input_file, 'w', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(rows)

print("Batch all completed")
