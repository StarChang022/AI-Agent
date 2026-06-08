import pandas as pd
import json
import os
import shutil

# Define file paths
csv_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
backup_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本_backup_emails.csv"
json_output_path = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_emails.json"

# Company configuration dictionary for the 25 unique companies in 名單副本.csv
configs = {
    "品正機械工業股份有限公司": {
        "short_name": "品正機械",
        "day1_title": "工具機製造排程與機台利用率的自動化管理挑戰",
        "day1_hook": "對品正機械用心40年從事工具機製造，行銷歐美的CNC綜合加工中心機與龍門銑床技術非常敬佩。隨產品規格增加，許多金屬加工廠的夥伴提到，工件生產排程與機台利用率資料若靠人工 Excel 彙整，交接時容易出錯。",
        "pain_point_brief": "現場排單與產能追蹤",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "瑞士商柏泰有限公司台灣分公司": {
        "short_name": "瑞士商柏泰",
        "day1_title": "高科技緊固件物流與智慧組裝流程的數據串接",
        "day1_hook": "對貴司在緊固件研發與智慧工廠整合方案（SFL/SFA）的深厚實力非常敬佩。隨 AI 伺服器與半導體供應鏈需求攀升，許多高科技供應商提到，零件組裝與物流出貨的批次數據如果缺乏即時系統串接，容易在跨部門核對上耗費大量時間。",
        "pain_point_brief": "智慧物流出貨與組裝數據核對",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "聚惠工業股份有限公司": {
        "short_name": "聚惠工業",
        "day1_title": "機車排氣管製造與電鍍加工工單的即時追蹤",
        "day1_hook": "對聚惠工業在機車排氣管製造與電鍍加工的卓越技術印象深刻。在汽機車零組件製程中，電鍍加工工單與產線現場派工的資訊往往極為分散，許多同業提到，若全靠紙本流轉，不僅主管難以即時掌握進度，還容易在出貨交期上產生誤差。",
        "pain_point_brief": "電鍍工單與派工進度管理",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "永紡企業股份有限公司": {
        "short_name": "永紡企業",
        "day1_title": "針織布設計打樣與國際訂單進度追蹤的流程優化",
        "day1_hook": "對永紡企業在針織布設計開發與為國際服飾大廠提供一站式行銷的實力非常讚佩。當面對多樣化的布樣設計與客製化打樣需求時，許多紡織同業常遇到設計變更、樣布進度與國際訂單追蹤分散在不同 Excel，導致跨部門溝通成本極高的挑戰。",
        "pain_point_brief": "設計打樣變更與訂單進度追蹤",
        "social_proof_name": "大管家包租代管系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/chrb",
        "social_proof_desc": "將龐雜的物件管理與租約流程全面數位化，降低人為疏失與管理成本"
    },
    "欣欣龍精密工業有限公司": {
        "short_name": "欣欣龍精密",
        "day1_title": "汽機車零件OEM工單排產與打樣履歷的數位管理",
        "day1_hook": "對貴司在汽機車與沙灘車精密零件的製造技術印象深刻。隨著多國汽車貿易商與客製化訂單成長，工廠的工單排程與零件打樣履歷若僅以傳統報表管理，現場組裝與品管文件的交接往往需要耗費大量時間反覆確認。",
        "pain_point_brief": "生產排產與打樣品質履歷",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "月村科技股份有限公司": {
        "short_name": "月村科技",
        "day1_title": "粉末成形機製造與零件裝配進度的數位化挑戰",
        "day1_hook": "對月村科技在粉末成形機與冶金周邊設備的專業研發技術印象深刻。製造大噸位粉末成形機涉及多樣化的零件採購與精密裝配，許多同業提到，若裝配排程與機台測試報告仍靠人工手動核對，極易發生裝配錯誤或交期延遲的狀況。",
        "pain_point_brief": "設備裝配排程與機台測試追蹤",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "震錩塑膠機械廠股份有限公司": {
        "short_name": "震錩塑膠機械",
        "day1_title": "吹袋機與押出系統裝配零件清單（BOM）的數位流程管理",
        "day1_hook": "對震錩塑膠機械在吹袋機、抽絲機等押出系統設備的研發實力十分佩服。高精密押出機械的客製化程度極高，涉及大量零組件 BOM 表與設計變更管理，若缺乏系統化追蹤，研發端與生產裝配端極易發生資訊落差。",
        "pain_point_brief": "零組件BOM表與裝配設計變更管理",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "慶家食品有限公司": {
        "short_name": "慶家食品",
        "day1_title": "科技廠團膳與罐頭製造食品安全查核的系統化管理",
        "day1_hook": "對貴司在科技廠團膳服務與罐頭調理食品製造的嚴格品質管理深表敬佩。在應對量販店與鮮食代工時，從原料批次查驗到現場配方比對，都需要高密度的查核紀錄，靠傳統紙本或 Excel 彙整，往往增加品管人員的負擔。",
        "pain_point_brief": "食品原料批次與查核履歷管理",
        "social_proof_name": "食安智幫手APP",
        "social_proof_link": "https://playplus.com.tw/portfolio/tfif-app",
        "social_proof_desc": "解決食品安全查核與流程追蹤的難題，將繁瑣的品管表單數位化與系統化"
    },
    "福陽企業股份有限公司": {
        "short_name": "福陽企業",
        "day1_title": "食品軟包裝袋與客製化卷膜品質查核流程優化",
        "day1_hook": "對福陽企業在真空袋、站立袋及自動卷膜軟包裝的一貫化設計印刷技術印象深刻。隨著包裝材需要符合 ISO 22000 與 HACCP 等多項認證，現場檢驗報告與印刷版模管理若仍採用人工登記，在跨部門調閱與合規查核時非常耗費時間。",
        "pain_point_brief": "包材檢驗報告與製程品質查核",
        "social_proof_name": "食安智幫手APP",
        "social_proof_link": "https://playplus.com.tw/portfolio/tfif-app",
        "social_proof_desc": "解決食品安全查核與流程追蹤的難題，將繁瑣的品管表單數位化與系統化"
    },
    "承德科技股份有限公司": {
        "short_name": "承德科技",
        "day1_title": "鋰電池活化與測試設備客製化裝配的數位管理",
        "day1_hook": "對承德科技在動力電池測試、ESS/AFC 儲能控制系統研發製造的領先地位非常讚佩。當面對各大電池與儲能客戶的客製化機台開發需求時，現場裝配材料進度、設備出廠測試數據若靠人工表單整理，容易在關鍵階段產生交接瓶頸。",
        "pain_point_brief": "設備客製裝配進度與測試數據管理",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "熱映光電股份有限公司": {
        "short_name": "熱映光電",
        "day1_title": "紅外線溫度儀與電子醫療產品合規履歷的數位流程",
        "day1_hook": "對熱映光電在紅外線精密溫度儀與耳溫槍晶片研發製造的專業技術深感讚佩。高精度電子醫療產品在取得國際品質認證時，伴隨著極為嚴格的研發履歷、測試報告與合規表單查核，若靠人工手動整理，常耗費大量研發與品管資源。",
        "pain_point_brief": "醫療器材合規與測試報告管理",
        "social_proof_name": "腎臟醫學會 TSN 病理系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/tsn",
        "social_proof_desc": "整合龐大的病理數據與申報表單，讓跨單位的協作與資料申報變得透明且高效"
    },
    "聞祺企業有限公司": {
        "short_name": "聞祺企業",
        "day1_title": "車用逆變器與電鍍零配件 OEM 訂單進度的數位追蹤",
        "day1_hook": "對聞祺企業在車用電源轉換器與汽車金屬電鍍配件製造上擁有超過 38 年一條龍服務的實力印象深刻。當面對 25 家以上全球品牌合作夥伴的客製代工需求時，從模具開發、生產排程到出貨進度的管理，往往需要更高精準度的流程追蹤系統以減少人為核對時間。",
        "pain_point_brief": "模具開發與出貨進度管理",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "中光電智能物流股份有限公司": {
        "short_name": "中光電智能物流",
        "day1_title": "自主移動機器人（AMR）現場裝配與研發變更的流程追蹤",
        "day1_hook": "對貴司在自主移動機器人（AMR/SAV/UGV）以及 iMEC/VMS 智慧管理系統的深厚光機電研發實力非常讚佩。當針對精密製造及物流客戶提供高度客製化的一站式方案時，現場裝配零件、軟硬體整合測試進度若以傳統 Excel 記錄，主管在掌控進度時容易產生資訊落差。",
        "pain_point_brief": "系統裝配進度與軟硬體測試追蹤",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "城紹科技股份有限公司": {
        "short_name": "城紹科技",
        "day1_title": "健身與醫療器材客製化 ODM 製程品質檢驗的數位整合",
        "day1_hook": "對城紹科技（SolidFocus）在划船機、照護床及訓練機的 ODM/OEM 研發與製造實力非常讚佩。在滿足國際品牌高品質承諾的過程中，針對不同健身或醫療產品都需要設計專門的檢驗與測試機制，若品檢報告與倉儲出貨紀錄多以人工整理，容易造成跨部門調閱困難。",
        "pain_point_brief": "產品檢驗報告與出貨追溯管理",
        "social_proof_name": "腎臟醫學會 TSN 病理系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/tsn",
        "social_proof_desc": "整合龐大的病理數據與申報表單，讓跨單位的協作與資料申報變得透明且高效"
    },
    "力固工業股份有限公司": {
        "short_name": "力固工業",
        "day1_title": "電腦控制地磅與計量自動化工程的派工管理",
        "day1_hook": "對力固工業推動工廠計量自動化、研發電腦控制地磅系統的專業技術印象深刻。隨著計量與工業控制系統專案增多，各案場的施工進度、維修派工與設備調試紀錄若缺乏整合系統，主管在人力調度與進度統計上容易面臨資訊分散的挑戰。",
        "pain_point_brief": "案場派工與施工進度管理",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "濟生股份有限公司": {
        "short_name": "濟生股份",
        "day1_title": "香辛料調味粉配方開發與 OEM 生產批次履歷管理",
        "day1_hook": "對濟生股份在香辛料與調味粉製造深耕百年的品質非常敬佩。在應對食品量販供應與餐飲代工時，從原料採購、配方開發到調味粉包裝，都有嚴格的食品安全與 HACCP 認證要求，若批次檢驗報告多以人工登打，將耗費大量人力於品管表單整理。",
        "pain_point_brief": "配方履歷與生產批次檢驗管理",
        "social_proof_name": "食安智幫手APP",
        "social_proof_link": "https://playplus.com.tw/portfolio/tfif-app",
        "social_proof_desc": "解決食品安全查核與流程追蹤的難題，將繁瑣的品管表單數位化與系統化"
    },
    "長廣精機股份有限公司": {
        "short_name": "長廣精機",
        "day1_title": "真空壓膜機高度自動化裝配與零件BOM表流程優化",
        "day1_hook": "對長廣精機在真空壓膜機研發製造、在全球IC載板產業市占率達95%的實力深表敬佩。作為高度自動化的半導體與PCB製程設備，壓膜機涉及眾多精密零組件的裝配與研發圖紙變更，若流程管理缺乏好紀錄的系統，容易在產線裝配時造成交接誤差。",
        "pain_point_brief": "零件BOM表與裝配流程追蹤",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "帝固鑽石企業有限公司": {
        "short_name": "帝固鑽石",
        "day1_title": "鑽石刀具客製化生產與修磨工單的即時追蹤",
        "day1_hook": "對貴司在單晶、聚晶鑽石切削刀具（MCD/PCD）與特殊鎢鋼刀具製造的精湛技術非常讚賞。當面對大量汽機車零件、光學及電子客戶的客製化與代送鍍層、修磨保養單時，若工單進度與客戶刀具修磨履歷仍採紙本或手動 Excel 彙整，極易造成交期延誤。",
        "pain_point_brief": "刀具修磨工單與生產進度管理",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "亞台富士精機股份有限公司": {
        "short_name": "亞台富士精機",
        "day1_title": "鼓風機與真空泵客製加工零件清單的數位化挑戰",
        "day1_hook": "對亞台富士在鼓風機、切削液幫浦與真空泵研發製造並居日本市占率第一的品質印象深刻。乾式螺旋式真空泵及 NC 車床切削液幫浦在配合客戶客製加工時，涉及多種規格零件的管理，若現場裝配用料與測試報告多以人工登打，常成為跨部門協作瓶頸。",
        "pain_point_brief": "加工用料與測試報告追蹤",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "寬豐工業股份有限公司": {
        "short_name": "寬豐工業",
        "day1_title": "高級鎖具研發設計與 ODM 客製化打樣的流程優化",
        "day1_hook": "對寬豐工業（REAL Locks）在高級鎖具研發並擁有數十項國際發明大獎的創新實力深表讚佩。在推動電子與機械鎖具跨業整合的同時，各類 ODM 鎖具客製化打樣與安全系統機制測試報告繁多，若缺乏系統化管理，在研發設計到量產的交接上容易耗費大量溝通成本。",
        "pain_point_brief": "客製打樣與安全測試報告管理",
        "social_proof_name": "大管家包租代管系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/chrb",
        "social_proof_desc": "將龐雜的物件管理與租約流程全面數位化，降低人為疏失與管理成本"
    },
    "員彰金屬工業股份有限公司": {
        "short_name": "員彰金屬",
        "day1_title": "金屬零件熱處理加工工單與製程開發的數位管理",
        "day1_hook": "對員彰金屬在彰濱工業區深耕金屬零件熱處理加工及製程開發設計的實力印象深刻。熱處理製程對溫度與時間控制有極高要求，各批次加工工單與品檢硬度紀錄若缺乏系統化追溯，主管將面臨現場進度難以即時掌握且查核報表耗時的瓶頸。",
        "pain_point_brief": "加工工單與品檢硬度紀錄追溯",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "燦和食品工業股份有限公司": {
        "short_name": "燦和食品",
        "day1_title": "麵包粉龍頭廠 FSSC 22000 安全查核的數位系統流程",
        "day1_hook": "對燦和食品作為國內麵包粉生產龍頭，並取得 FSSC 22000 與 HACCP 等多項認證的嚴格管理非常佩服。隨產品線（麵包油炸粉、脆酥粉等）擴增，原料配料批次與生產現場查核文件的整理工作益發繁重，若靠人工手動登記，容易在稽核或調閱時造成延遲。",
        "pain_point_brief": "原料配料批次與生產安全查核",
        "social_proof_name": "食安智幫手APP",
        "social_proof_link": "https://playplus.com.tw/portfolio/tfif-app",
        "social_proof_desc": "解決食品安全查核與流程追蹤的難題，將繁瑣的品管表單數位化與系統化"
    },
    "森昌有限公司": {
        "short_name": "森昌",
        "day1_title": "頂尖醫療器材進口代理與醫院供貨追溯的數位化優化",
        "day1_hook": "對貴司代理眾多世界第一醫療品牌（如輸血過濾器、無針接頭）並服務全台各醫療院所的實力非常讚佩。醫療耗材與設備的進口批號管理與醫院合約供貨追溯要求極高，若出貨資料與各分公司供貨中心的報表主要靠人工核對，主管將難以即時掌握全局銷售數據。",
        "pain_point_brief": "進口批號管理與供貨合約追溯",
        "social_proof_name": "腎臟醫學會 TSN 病理系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/tsn",
        "social_proof_desc": "整合龐大的病理數據與申報表單，讓跨單位的協作與資料申報變得透明且高效"
    },
    "中央炭素股份有限公司": {
        "short_name": "中央炭素",
        "day1_title": "半導體石墨配件客製規格與製程加工工單的數位追蹤",
        "day1_hook": "對中央炭素在半導體用石墨配件與炭精製品專業製造的領先地位深表敬佩。隨著客戶對半導體配件的精密規格要求提高，現場工單生產排程、特殊材質用料與品檢紀錄若仍採用傳統報表，容易在跨部門派工及交貨核對時增加溝通成本。",
        "pain_point_brief": "生產派工與加工料件規格管理",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    },
    "億勝企業有限公司": {
        "short_name": "億勝企業",
        "day1_title": "車用與船用電子配線製程用料與外銷訂單的數位追蹤",
        "day1_hook": "對億勝企業在車用與船用開關面板、DC 電力系統配件製造及以自有品牌行銷全球的實力深感讚佩。在應對多通路外銷與客製配線訂單時，多樣化零組件 BOM 表與現場排產進度管理若靠人工彙整 Excel，容易造成物料短缺或出貨安排的誤差。",
        "pain_point_brief": "外銷排產進度與零組件BOM表管理",
        "social_proof_name": "神達會議室預約系統",
        "social_proof_link": "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system",
        "social_proof_desc": "解決跨部門資源預約的混亂問題，讓內部營運不再因為繁瑣流程卡關"
    }
}

# 1. Back up the original file
if not os.path.exists(backup_path):
    shutil.copy2(csv_path, backup_path)
    print(f"Successfully backed up {csv_path} to {backup_path}")
else:
    print(f"Backup already exists at {backup_path}")

# 2. Read original CSV file
df = pd.read_csv(csv_path, encoding='utf-8')

# Dynamic greeting logic
def get_greeting(contact_name):
    clean_name = str(contact_name).strip()
    if clean_name == "官方" or "窗口" in clean_name or pd.isna(contact_name) or clean_name == "" or clean_name == "nan":
        return "您好，<br><br>"
    else:
        return f"嗨 {clean_name}，<br><br>"

print("Generating emails for each prospect...")
log_data = {}

for index, row in df.iterrows():
    co_name = str(row['公司名稱']).strip()
    contact_name = row['聯絡人名稱']
    
    if co_name not in configs:
        print(f"Warning: {co_name} is not defined in configs dictionary!")
        continue
        
    cfg = configs[co_name]
    greeting = get_greeting(contact_name)
    
    # 1. Day 1
    d1_title = cfg['day1_title']
    d1_content = (
        f"{greeting}"
        f"我們剛瀏覽了貴司的網站，{cfg['day1_hook']}<br>"
        f"<br>"
        f"我們是 PlayPlus，專注於協助中型企業打造「客製化企業內部系統」。我們不推銷動輒數百萬的大型套裝軟體，而是從你們最痛的一條流程（例如：{cfg['pain_point_brief']}）開始，打造好紀錄、好追蹤、好交接的專屬系統。<br>"
        f"<br>"
        f"是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br>"
        f"<br>"
        f"感謝您"
    )
    
    # 2. Day 7
    d7_title = f"快速確認：關於{cfg['short_name']}的內部流程優化"
    d7_content = (
        f"{greeting}"
        f"不知道您是否有空看一下我上封信提到的內部流程優化想法？<br>"
        f"<br>"
        f"若這週有幾分鐘時間，我們可以用最無壓力的方式聊聊現有的系統是否真正符合你們的需求。<br>"
        f"<br>"
        f"感謝您"
    )
    
    # 3. Day 14
    d14_title = f"分享我們如何協助優化{cfg['short_name']}的製程與流程管理"
    d14_content = (
        f"{greeting}"
        f"我們深知{cfg['short_name']}在行業內的專業性，但在處理{cfg['pain_point_brief']}時，好用的數位工具能事半功倍。<br>"
        f"<br>"
        f"我們曾協助開發了{cfg['social_proof_name']}（{cfg['social_proof_link']}），成功{cfg['social_proof_desc']}。<br>"
        f"<br>"
        f"對於貴司來說，一套客製化的進度追蹤或管理系統，同樣能大幅降低人力盤點與報表彙整的時間成本。<br>"
        f"<br>"
        f"感謝您"
    )
    
    # 4. Day 30
    d30_title = f"擔心導入客製化系統會耗時又昂貴嗎？"
    d30_content = (
        f"{greeting}"
        f"我知道許多企業在評估內部系統時，常擔心開發費用昂貴或影響日常產能。為了降低您的顧慮，我們提供「模組化開發」與「分階段優化方案」，您可以根據預算選擇最迫切需要解決的流程先進行數位化。<br>"
        f"<br>"
        f"而且我們極度重視溝通效率，主管每週只需 15 分鐘確認進度，絕不影響日常生產。<br>"
        f"<br>"
        f"下週方便撥個 5 分鐘簡單交流，評估一下可能性嗎？<br>"
        f"<br>"
        f"感謝您"
    )
    
    # 5. Day 60
    d60_title = f"最後一次跟進：祝{cfg['short_name']}業務蒸蒸日上"
    d60_content = (
        f"{greeting}"
        f"因為一直沒有收到您的回覆，我假設{cfg['short_name']}目前的內部管理系統運作良好，這是近期我發給您的最後一封信。<br>"
        f"<br>"
        f"未來若在擴展市場或面臨交接傳承時，需要一套好追蹤、好交接的客製化內部系統，PlayPlus 隨時能為您提供協助。<br>"
        f"<br>"
        f"感謝您"
    )
    
    # Save to dataframe
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
    
    # Log rewritten emails for temporary backup
    log_data[index] = {
        "company": co_name,
        "contact": contact_name,
        "day1": {"title": d1_title, "content": d1_content},
        "day7": {"title": d7_title, "content": d7_content},
        "day14": {"title": d14_title, "content": d14_content},
        "day30": {"title": d30_title, "content": d30_content},
        "day60": {"title": d60_title, "content": d60_content}
    }

# Save updated CSV
df.to_csv(csv_path, index=False, encoding='utf-8')
print("Successfully generated and saved cold email templates back to 名單副本.csv!")

# Save to temporary rewritten JSON file
with open(json_output_path, 'w', encoding='utf-8') as f:
    json.dump(log_data, f, ensure_ascii=False, indent=2)
print(f"Backup log saved to {json_output_path}")
