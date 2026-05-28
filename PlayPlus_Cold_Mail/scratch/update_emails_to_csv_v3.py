import pandas as pd
import json

csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
df = pd.read_csv(csv_path, encoding='utf-8')

industry_mapping = {
    "惠洋工業股份有限公司": "金屬帷幕牆加工與塗裝",
    "川奇機械股份有限公司": "製鞋與輸送機械",
    "常琪鋁業股份有限公司": "金屬與鋁合金錠製造",
    "群瑞股份有限公司": "機構件與零組件供應",
    "福基創新材料股份有限公司": "高分子與特殊內裝材料",
    "尚福企業股份有限公司": "精密橡膠與密封元件",
    "德宙佑電股份有限公司": "自動化與專用機設備",
    "新加坡商羅聖股份有限公司台灣分公司": "工業流體控制設備",
    "立康興業有限公司": "復健與醫療器材",
    "開放電子有限公司": "自動化感測器裝置",
    "兆陽科技股份有限公司": "汽車零組件製造",
    "全崴科技股份有限公司": "精密光學檢驗與車用配件",
    "新虎將機械工業股份有限公司": "精密工具機與CNC",
    "樺勝環保事業股份有限公司": "環保與資源再生",
    "大鈁金屬企業有限公司": "戶外電動門與安防建材",
    "長輝事業股份有限公司": "食品加工與油脂製造",
    "東煜企業股份有限公司": "金屬沖壓與雷射加工",
    "惠答工業有限公司": "工業管夾與接頭製造",
    "威宇精密股份有限公司": "精密沖壓零件加工",
    "磐采股份有限公司": "化學配方與光固化材料",
    "聯盟包裝企業股份有限公司": "高科技與工業包材",
    "層層包裝事業股份有限公司": "特殊與環保包裝材料",
    "藍鯨國際科技股份有限公司": "高級隔音門窗與建材",
    "民生食品工業股份有限公司": "生鮮加工與調理食品",
    "順靖企業有限公司": "物流商用設備與建材",
    "安石鋼管股份有限公司": "金屬管線與防腐保護",
    "佑達精密企業有限公司": "精密模具與連續沖壓"
}

def format_greeting(contact_name):
    if pd.isna(contact_name) or "官方" in contact_name or "窗口" in contact_name:
        return "您好，"
    return f"{contact_name} 您好，"

for index, row in df.iterrows():
    co_name = row['公司名稱']
    contact = row['聯絡人名稱']
    greeting = format_greeting(contact)
    industry = industry_mapping.get(co_name, "傳統製造與實業")

    # Day 1 - purely industry hook, no "growth" observation, completely friendly
    d1_title = f"交流：關於 {industry} 在內部流程升級的一些觀察"
    d1_content = f"{greeting}<br><br>最近我在與幾家{industry}領域的企業交流時，發現大家在業務漸趨穩定後，常常會遇到類似的管理瓶頸。<br><br>很多老闆或主管跟我們分享，公司早期許多關鍵的作業流程，往往只存在資深員工的腦袋裡，新人一來交接就非常痛苦；要不然就是到現在都還在用紙本或 Excel 填表單，資料散落各處，每個月底光是人工彙整報表就耗掉大半精力。<br><br>這讓我滿好奇貴公司目前是不是也剛好在經歷這段轉換期？我和我的團隊（PlayPlus）這陣子主要都在協助企業解決這類問題，幫大家量身打造好紀錄、好交接的輕量級內部系統。<br><br>如果這剛好也是您最近在苦惱的事，不知道方不方便讓我和您分享幾個我們幫別人處理過的真實案例？就當作交個朋友、交流一下心得也可以。<br><br>這是我們團隊的網站，有空可以看看：https://playplus.com.tw/<br><br>感謝您"
    
    # Day 7 
    d7_title = f"快速問候一下（關於上週的流程交流）"
    d7_content = f"{greeting}<br><br>想說快速跟進一下我上週寄給您的信件。<br><br>我知道您平日業務肯定非常繁忙，信件可能被淹沒了。如果您對我們如何幫企業解決人工報表混亂、或是打造專屬內部系統有任何好奇，又或者單純想聊聊業界的做法，都歡迎隨時讓我知道喔！<br><br>感謝您"
    
    # Day 14 
    d14_title = "分享：大家是怎麼解決跨部門預約與流程混亂的？"
    d14_content = f"{greeting}<br><br>很多企業主在跟我們聊到內部系統時，常常很擔心花大錢買了套裝軟體，結果員工嫌難用不適應。<br><br>這確實是個大問題。像我們之前幫「神達電腦」評估時，他們就有跨部門資源預約混亂、難以追蹤的痛點。後來我們直接幫他們客製了專屬的會議室預約系統，完全貼合他們原本的工作習慣去走，解決了他們很大一個麻煩。<br><br>如果您有興趣看看我們是怎麼做的，這邊有詳細的案例可以參考：https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system<br><br>如果您最近也有稍微動念想優化公司內部流程，我很樂意和您喝杯咖啡聊聊，提供一些初步的想法。<br><br>感謝您"
    
    # Day 30
    d30_title = "其實打造專屬內部系統，不需要花幾百萬跟等大半年"
    d30_content = f"{greeting}<br><br>這陣子跟幾位企業老闆交流，我發現大家對「客製化系統」最大的顧慮，不外乎就是怕太貴，或是怕開發期太長拖累營運。<br><br>這點我很感同身受。所以我們在做的時候，通常會建議「模組化開發」或是分階段來做。我們先挑公司目前「最痛」的一個流程來解決，看到效果再繼續。而且開發期間，主管每週其實大概只要花 15 分鐘跟我們對一下進度就好，溝通成本非常低。<br><br>您可以到我們的網站看看我們過去是怎麼幫大家解決痛點的：https://playplus.com.tw/<br><br>如果您也覺得這樣的合作模式比較沒有負擔，歡迎隨時回信和我聊聊。<br><br>感謝您"
    
    # Day 60 
    d60_title = "先不打擾您了！未來若有流程數位化的想法，隨時保持聯繫"
    d60_content = f"{greeting}<br><br>這應該是我近期發給您的最後一封信了，接下來就不會再主動打擾您。<br><br>我完全理解您目前的業務一定非常忙碌，或許現在公司也還沒到需要導入或優化內部系統的時候。<br><br>這封信主要是想留個紀錄給您。如果您未來在營運擴張時，剛好面臨表單管理混亂、交接斷層，或是覺得現有系統不合用、需要找人幫忙開發客製化系統，請記得我們的大門隨時為您敞開。<br><br>再次附上我們的服務與作品集，您可以先留存著：https://playplus.com.tw/<br><br>祝貴公司業績蒸蒸日上，未來有機會再交流。<br><br>感謝您"

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
print("Successfully generated fully compliant, highly friendly emails and saved to CSV!")
