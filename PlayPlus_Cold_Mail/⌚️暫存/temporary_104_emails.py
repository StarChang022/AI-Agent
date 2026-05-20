import pandas as pd

sequences = {
    "A": {
        "d1_title": "{company}的產線與管理流程，還在仰賴人工彙整嗎？",
        "d1_content": "您好，<br><br>我們注意到{company}在{industry}領域的亮眼表現。隨著企業規模擴大，許多企業常面臨「關鍵流程只存在資深員工腦中」或「依賴紙本/Excel導致資訊落差」的瓶頸。<br><br>我們是 PlayPlus，專注為中型企業打造專屬的內部營運系統。我們不推銷龐大的套裝軟體，而是從你們最耗時的流程著手，將人工彙整自動化，降低出錯率。<br><br>是否方便寄一份我們為相關產業做流程數位化的案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>感謝您",
        "d7_title": "關於{company}的流程優化",
        "d7_content": "您好，<br><br>想快速跟進一下之前的信件。如果您目前正因為報表彙整或流程交接感到困擾，我們或許能提供一些具體的數位化建議。<br><br>若您最近較忙，也完全沒問題。<br><br>感謝您",
        "d14_title": "神達電腦如何解決跨部門資源預約的混亂？",
        "d14_content": "您好，<br><br>在評估內部系統時，很多企業擔心耗時且成效不彰。我們曾協助神達電腦開發專屬系統（https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system），成功解決跨部門資源調度的混亂，讓流程完全透明化。<br><br>對於{company}的日常營運，或許也能帶來類似的效率提升。有興趣了解我們是如何做到的嗎？<br><br>感謝您",
        "d30_title": "預算與時間的彈性方案",
        "d30_content": "您好，<br><br>我知道導入新系統最讓人卻步的就是「怕太貴」或「怕花太多時間溝通」。<br><br>在 PlayPlus，我們採用「模組化開發」與「分階段優化」策略，不僅能符合您的預算彈性，主管每週更只需花 15 分鐘確認進度，大幅降低溝通成本。<br><br>如果您對這種低壓力的數位轉型方式感興趣，歡迎隨時回覆。<br><br>感謝您",
        "d60_title": "未來有機會再合作",
        "d60_content": "您好，<br><br>因為尚未收到您的回覆，我假設目前{company}暫時沒有內部系統升級的需求，因此這將是我近期最後一封信。<br><br>未來若您在團隊擴張或營運流程上遇到數位化的瓶頸，隨時歡迎透過我們的網站聯繫我們。<br><br>祝 業務蒸蒸日上！<br><br>感謝您"
    },
    "B": {
        "d1_title": "協助{company}突破紙本表單與資料斷層的瓶頸",
        "d1_content": "您好，<br><br>我一直在關注{company}在{industry}領域的發展。我們發現，許多注重品質與細節的企業，在快速成長時常會遇到一個痛點：重要的檢驗或管理表單仍依賴紙本，導致後續難以追蹤，甚至面臨交接斷層。<br><br>我們是 PlayPlus，專門協助企業將繁瑣的內部流程轉化為好紀錄、好追蹤的數位系統。我們曾協助企業開發專屬的食安智幫手APP（https://playplus.com.tw/portfolio/tfif-app），大幅降低人工作業的錯誤率。<br><br>想請問您是否有興趣看看我們如何用數位工具優化管理流程？<br><br>感謝您",
        "d7_title": "快速詢問：數位轉型計畫",
        "d7_content": "您好，<br><br>知道您業務繁忙，只是一封簡短的跟進信。若{company}目前有減少人工作業、提升管理效率的想法，我們很樂意提供初步的免費諮詢。<br><br>期待您的回音。<br><br>感謝您",
        "d14_title": "複雜資料如何有效管理？",
        "d14_content": "您好，<br><br>處理大量專業數據時，系統不合用常是最大的阻礙。我們曾為腎臟醫學會建置 TSN 病理系統（https://playplus.com.tw/portfolio/tsn），證明了我們有能力處理高度專業與複雜的流程客製化需求。<br><br>我相信對於{company}的管理流程，我們也能量身打造最合適的解決方案。是否安排個 10 分鐘簡單聊聊？<br><br>感謝您",
        "d30_title": "導入系統不用動輒數百萬",
        "d30_content": "您好，<br><br>許多企業遲遲未啟動數位轉型，是因為擔心套裝軟體太僵化，而客製化又深怕預算超標。<br><br>我們提供的是「從最痛的單一流程切入」，透過分階段導入來控制預算，並確保系統真正符合員工使用習慣。<br><br>如果您想了解這種低風險的導入方式，請讓我知道。<br><br>感謝您",
        "d60_title": "期待未來的交流",
        "d60_content": "您好，<br><br>這是我近期最後一次聯繫您。看來目前可能不是{company}進行系統優化的最佳時機。<br><br>我們將繼續專注於協助企業打造高效率的內部系統。未來若您需要專業的數位轉型建議，隨時歡迎回來找我們。<br><br>感謝您"
    },
    "C": {
        "d1_title": "{company}在擴編時面臨的管理挑戰",
        "d1_content": "您好，<br><br>留意到{company}在{industry}領域近期的穩健發展。當企業規模擴大，我們常看到一個現象：主管每個月要花大量時間手動彙整各部門報表，既耗時又拖慢決策速度。<br><br>我們是 PlayPlus，專注於解決這類營運痛點。我們能將您現有僵化的流程，轉化為直覺、客製化的內部系統，讓關鍵資料不再散落各處。<br><br>不知您是否遇到類似的管理瓶頸？我們能提供一些實際的解決方案供您參考。<br><br>感謝您",
        "d7_title": "關於提升團隊效率的想法",
        "d7_content": "您好，<br><br>只是一個溫和的提醒。如果您團隊目前正苦於現有系統無法客製化，或是報表彙整太過耗時，我們或許能幫上忙。<br><br>若目前時機不對也沒關係。<br><br>感謝您",
        "d14_title": "別讓複雜的管理流程拖累成長",
        "d14_content": "您好，<br><br>面對多樣化的管理需求，靈活的系統是關鍵。我們曾打造過大管家包租代管系統（https://playplus.com.tw/portfolio/chrb），將複雜的租賃與合約流程完全數位化，大幅減輕行政負擔。<br><br>這類客製化經驗，相信也能為{company}帶來顯著的效率提升。想看看我們是怎麼做的嗎？<br><br>感謝您",
        "d30_title": "系統升級的溝通成本其實很低",
        "d30_content": "您好，<br><br>過去很多客戶跟我們反映，最怕開發系統時需要無止盡的開會。<br><br>在 PlayPlus，我們的敏捷開發流程讓主管每週只需 15 分鐘確認進度。我們幫您把關技術細節，您只需專注於業務決策。<br><br>如果您正在尋找省心且高效的開發夥伴，歡迎回覆此信。<br><br>感謝您",
        "d60_title": "暫時不打擾了",
        "d60_content": "您好，<br><br>看來目前{company}的內部流程運作得相當順利，因此我將不再主動發信打擾。<br><br>身為您的數位轉型顧問，我們的大門永遠敞開。若未來有客製化系統的需求，隨時歡迎回來找我們。<br><br>祝 一切順心！<br><br>感謝您"
    }
}

company_mapping = {
    "育安照明企業股份有限公司": ("C", "舞台特效設備"),
    "富堡工業股份有限公司": ("B", "衛生醫療用品"),
    "舜煜實業股份有限公司": ("A", "金屬管件製造"),
    "妙印精機股份有限公司": ("C", "精密網版印刷設備"),
    "雅輪實業股份有限公司": ("A", "高階自行車零件"),
    "大灃科技股份有限公司": ("C", "無線遙控設備"),
    "裕榮食品股份有限公司": ("B", "食品製造"),
    "櫻桃爺爺_豐稷食品股份有限公司": ("B", "伴手禮食品"),
    "浩鉦國際有限公司": ("A", "機車零組件"),
    "東龍工業股份有限公司": ("A", "家電製造"),
    "樺萊高分子工業股份有限公司": ("B", "醫療耗材"),
    "賀聲樂器股份有限公司": ("C", "銅管樂器"),
    "大東羊食品工業股份有限公司": ("B", "食品配料"),
    "唐振工業股份有限公司": ("A", "手工具零件"),
    "信服嘉工業股份有限公司": ("A", "精密機械加工"),
    "禾紡纖維有限公司": ("C", "紡織貿易"),
    "哲良企業股份有限公司": ("A", "自動化機械設備"),
    "台灣久林實業股份有限公司": ("A", "運動用品材料"),
    "立兆工業股份有限公司": ("A", "專業鎖具"),
    "洛亞貿易股份有限公司": ("C", "重型機車零件"),
    "翊達產業股份有限公司": ("B", "醫療器材"),
    "秉鋒興業股份有限公司": ("A", "冷鍛成型設備"),
    "裕利晟工業股份有限公司": ("A", "再生纖維"),
    "慶穗工業股份有限公司": ("A", "精密模具"),
    "明昌輪業股份有限公司": ("A", "傳動鏈條"),
    "新記企業股份有限公司": ("A", "發泡包材"),
    "順利金屬工業股份有限公司": ("A", "金屬鑄造"),
    "佳聯機械股份有限公司": ("A", "金屬切削工具機"),
    "立名鋼模有限公司": ("A", "塑膠射出成型")
}

file_path = '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv'

df = pd.read_csv(file_path)

def generate_emails(row):
    company = str(row['公司名稱'])
    seq_key, industry = company_mapping.get(company, ("C", "相關產業"))
    seq = sequences[seq_key]
    
    row['day1_title'] = seq['d1_title'].format(company=company, industry=industry)
    row['day1_content'] = seq['d1_content'].format(company=company, industry=industry)
    
    row['day7_title'] = seq['d7_title'].format(company=company, industry=industry)
    row['day7_content'] = seq['d7_content'].format(company=company, industry=industry)
    
    row['day14_title'] = seq['d14_title'].format(company=company, industry=industry)
    row['day14_content'] = seq['d14_content'].format(company=company, industry=industry)
    
    row['day30_title'] = seq['d30_title'].format(company=company, industry=industry)
    row['day30_content'] = seq['d30_content'].format(company=company, industry=industry)
    
    row['day60_title'] = seq['d60_title'].format(company=company, industry=industry)
    row['day60_content'] = seq['d60_content'].format(company=company, industry=industry)
    
    return row

df = df.apply(generate_emails, axis=1)

df.to_csv(file_path, index=False)
print("Successfully generated and updated all emails in 名單副本.csv")
