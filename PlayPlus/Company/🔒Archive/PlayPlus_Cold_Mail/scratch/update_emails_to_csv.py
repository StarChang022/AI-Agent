import pandas as pd
import json

csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
df = pd.read_csv(csv_path, encoding='utf-8')

industry_mapping = {
    "惠洋工業股份有限公司": "金屬帷幕牆加工與塗裝",
    "川奇機械股份有限公司": "製鞋機械與輸送設備",
    "常琪鋁業股份有限公司": "高品質鋁合金錠製造",
    "群瑞股份有限公司": "機構件整體供應鏈解決方案",
    "福基創新材料股份有限公司": "高分子內外裝材料",
    "尚福企業股份有限公司": "精密橡膠模壓與密封產品",
    "德宙佑電股份有限公司": "整廠設備輸出與客製化專用機",
    "新加坡商羅聖股份有限公司台灣分公司": "工業泵浦與流體控制設備",
    "立康興業有限公司": "復健醫學與電刺激器",
    "開放電子有限公司": "專業感測器裝置",
    "兆陽科技股份有限公司": "汽車車燈與後視鏡零組件",
    "全崴科技股份有限公司": "精密光學檢驗儀器與汽車配件",
    "新虎將機械工業股份有限公司": "精密銑床與CNC高速加工機",
    "樺勝環保事業股份有限公司": "廢棄物處理與資源循環再生",
    "大鈁金屬企業有限公司": "戶外電動大門與防撬安全門",
    "長輝事業股份有限公司": "食用油脂與黃豆加工",
    "東煜企業股份有限公司": "金屬零件沖壓與雷射切割",
    "惠答工業有限公司": "軟管夾與管接頭製造",
    "威宇精密股份有限公司": "精密沖壓零件加工",
    "磐采股份有限公司": "光固化化學與奈米分散工藝",
    "聯盟包裝企業股份有限公司": "高阻隔性包裝板材與薄膜",
    "層層包裝事業股份有限公司": "高科技防靜電包裝材料",
    "藍鯨國際科技股份有限公司": "隔音玄關門與別墅藝術大門",
    "民生食品工業股份有限公司": "生鮮蔬菜截切與調理食品",
    "順靖企業有限公司": "智慧物流AGV與商用流通設備",
    "安石鋼管股份有限公司": "管道防腐保護與被覆加工",
    "佑達精密企業有限公司": "精密模具設計與連續沖壓"
}

def format_greeting(contact_name):
    if pd.isna(contact_name) or "官方" in contact_name or "窗口" in contact_name:
        return "您好，"
    return f"{contact_name} 您好，"

for index, row in df.iterrows():
    co_name = row['公司名稱']
    contact = row['聯絡人名稱']
    greeting = format_greeting(contact)
    industry = industry_mapping.get(co_name, "產業")

    # Day 1
    d1_title = f"關於{co_name}的內部管理數位化建議"
    d1_content = f"{greeting}<br><br>我剛瀏覽了貴公司的網站，注意到你們在{industry}領域擁有深厚的基礎與規模。不過我們也發現，許多企業在穩定成長的階段，常會遇到內部管理與流程跟不上的問題，例如：關鍵作業流程只存在資深員工腦中導致交接困難、依賴紙本或 Excel 填寫表單容易出錯，或是人工彙整報表耗時且難以追蹤。<br><br>我們是 PlayPlus，專注於協助中型企業打造「客製化企業內部系統」。我們不推銷動輒數百萬的大型僵化系統，而是從你們最痛的一條流程開始，打造好紀錄、好追蹤、好交接的專屬系統。<br><br>是否方便寄一份我們過去協助企業將表單與流程數位化的案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>感謝您"
    
    # Day 7
    d7_title = f"快速跟進：關於{co_name}的內部流程優化"
    d7_content = f"{greeting}<br><br>想快速跟進一下我上週寄出的信件。我知道您業務繁忙，可能不小心漏看了。<br><br>如果您對打造專屬的內部管理系統，解決目前人工報表與表單混亂的問題有興趣，隨時讓我知道。<br><br>感謝您"
    
    # Day 14
    d14_title = "如何解決跨部門資源預約與流程混亂？"
    d14_content = f"{greeting}<br><br>許多企業在評估內部系統時，常擔心系統不合用或導入困難。我們曾協助「神達電腦」開發專屬的會議室預約系統，成功解決了他們跨部門資源預約混亂、難以追蹤的問題。<br><br>透過客製化開發，我們能確保系統完全貼合您現有的運作邏輯，而不是讓員工去適應僵化的套裝軟體。您可以參考這個案例的細節：https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system<br><br>如果您近期有考慮優化內部流程，我很樂意為您提供初步的免費諮詢。<br><br>感謝您"
    
    # Day 30
    d30_title = "打造專屬內部系統，其實不需要漫長開發"
    d30_content = f"{greeting}<br><br>在與許多企業主交流時，我們發現大家對於「客製化系統」最大的顧慮就是：怕太貴、怕開發時間太長影響營運。<br><br>在 PlayPlus，我們提供「模組化開發」與「分階段優化方案」，能配合您的預算彈性進行。更重要的是，在開發期間，主管每週只需花大約 15 分鐘確認進度，大幅降低溝通成本。<br><br>我們從最痛的單一流程開始解決，見效後再逐步擴展。您可以從這邊參考我們過去的成功經驗：https://playplus.com.tw/<br><br>若您有興趣了解這樣的模式如何應用在貴公司，歡迎隨時回覆。<br><br>感謝您"
    
    # Day 60
    d60_title = "未來若有流程數位化需求，隨時保持聯繫"
    d60_content = f"{greeting}<br><br>這是我近期發給您的最後一封信，不再主動打擾您。了解您目前業務繁忙，或許現在並非導入或優化內部系統的最佳時機。<br><br>如果您未來在營運擴張時，面臨表單管理混亂、交接斷層或現有系統不合用的痛點，需要專業的客製化系統開發協助，我們的大門隨時為您敞開。<br><br>再次附上我們的服務與作品集供您未來參考：https://playplus.com.tw/<br><br>祝貴公司業績蒸蒸日上。<br><br>感謝您"

    # Write back to df
    df.at[index, 'day1_title'] = d1_title
    df.at[index, 'day1_content'] = d1_content
    df.at[index, 'day7_title'] = d7_title
    df.at[index, 'day7_content'] = d7_content
    df.at[index, 'day14_title'] = d14_title
    df.at[index, 'day14_content'] = d14_content
    df.at[index, 'day30_title'] = d30_title
    df.at[index, 'day30_content'] = d30_content
    df.at[index, 'day60_title'] = d60_title
    df.at[index, 'day60_content'] = d60_content

# Save to CSV
df.to_csv(csv_path, index=False, encoding='utf-8')
print("Successfully generated and saved all 5 days of emails for all rows!")
