#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""為名單副本.csv 中每位潛在客戶生成企業內部系統版本的 Day1/7/14/30/60 高度客製化冷郵件"""
import csv
import os

CSV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '冷郵件對象', '名單副本.csv')

COMPANIES = {
    '台灣應達股份有限公司': {
        'short_name': '台灣應達',
        'obs': '貴司在感應加熱與熔解設備領域的深厚技術，身為美國應達集團在台核心基地，產能與技術服務均為業界領導品牌',
        'pain': '許多工業設備製造廠在訂單與維修服務持續成長時，常會遇到跨部門排程與工單追蹤仍仰賴紙本或人工確認的情形，容易造成資訊同步與新人交接的落差',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '解決跨部門資源預約與排程調度的混亂問題',
        'angle': '設備製造廠的流程數位化'
    },
    '華冠乳品股份有限公司': {
        'short_name': '華冠乳品',
        'obs': '貴司作為全台前三大專業乳品供應商，在低溫倉儲與無塵加工的嚴謹品質把關與先進規模',
        'pain': '食品原料供應鏈在面對批號追蹤、效期管理與出貨檢驗時，若依賴人工彙整報表或傳統 Excel 紀錄，往往耗時且容易在快速出貨時產生追蹤盲區',
        'case_name': '食安智幫手APP',
        'case_url': 'https://playplus.com.tw/portfolio/tfif-app',
        'case_desc': '梳理食品進銷存與品管追蹤流程，讓關鍵數據一目瞭然',
        'angle': '乳品供應鏈的內部系統升級'
    },
    '台灣電能股份有限公司': {
        'short_name': '台灣電能',
        'obs': '貴司作為台灣規模最大的電漿切割與焊接機製造廠，行銷全球且擁有三座廠房的產能配置',
        'pain': '當廠區多、自動化系統整合訂單繁重時，常會遇到各廠區間的生產進度追蹤與零組件料件管理跟不上速度，多半仰賴資深同仁記憶或人工重複確認',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '建立清晰的跨單位資源調度與預約機制，降低溝通摩擦',
        'angle': '多廠區設備製造的流程梳理'
    },
    '貫煜工業股份有限公司': {
        'short_name': '貫煜工業',
        'obs': '貴司深耕金屬熱鍛造 OEM 領域逾四十年，且通過 ISO 與 IATF 車載品質認證，製程實力深厚',
        'pain': '面對嚴格的車載零組件交期與加工需求，傳統依靠紙本表單或試算表紀錄模具進度與生產履歷，不僅後續追蹤不易，在面對客戶稽核時也常需耗費大量人工彙整報表',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '將內部跨部門協作與排程標準化，大幅降低溝通失誤',
        'angle': '鍛造代工廠的營運管理數位化'
    },
    '碩瑋精密股份有限公司': {
        'short_name': '碩瑋精密',
        'obs': '貴司在塑膠及電木精密模具設計製造的全方位實力，產品廣泛打入車用與光纖通訊等高階市場',
        'pain': '精密模具從設計、開模到射出成型工序繁多，若每個階段的交接與修改紀錄僅留在工程師的私下溝通或本地檔案中，極易造成進度追蹤斷層與新人交接困難',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '實現內部排程與資源調配的透明化管理',
        'angle': '精密模具廠的專案流程數位化'
    },
    '縉錩工業股份有限公司': {
        'short_name': '縉錩工業',
        'obs': '貴司自 1976 年起在 CNC 電腦自動車床與客製化專用機領域的創新研發，產品線完整且行銷全球',
        'pain': '工具機大廠在面對高度客製化的機台組裝與測試排程時，常面臨各工段資訊不同步的問題，依賴人工填寫進度單不僅即時性差，主管也難以快速掌握整體營運全貌',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '優化跨部門排程與資源配置的協作效率',
        'angle': '工具機製造的內部管理升級'
    },
    '日堡全球精密科技股份有限公司': {
        'short_name': '日堡全球精密',
        'obs': '貴司成功從精密五金零組件轉型並打造自有品牌 SCG 智慧電子鎖，積極導入自動化生產的卓越成效',
        'pain': '在產線自動化升級的同時，許多企業常忽略辦公室端與跨部門協作流程的數位化，導致前線自動化生產、後勤卻仍仰賴人工產出報表與手動交接，形成效率瓶頸',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '消弭跨部門溝通壁壘，讓後勤管理跟上前線自動化的速度',
        'angle': '智慧五金廠的內部流程優化'
    },
    '美商瑞盟亞洲股份有限公司台灣分公司': {
        'short_name': '瑞盟亞洲',
        'obs': '貴司作為頂尖打擊樂品牌 REMO 的亞洲區核心樞紐，統籌全亞洲的業務推廣、配銷與技術服務，運籌規模廣大',
        'pain': '跨國配銷與技術支援體系龐大時，經銷商需求單、出貨排程與技術服務紀錄若缺乏整合的內部追蹤系統，很容易造成溝通往返耗時與交接遺漏',
        'case_name': '大管家包租代管系統',
        'case_url': 'https://playplus.com.tw/portfolio/chrb',
        'case_desc': '打造高效的狀態追蹤與派工管理機制，讓繁雜事務井然有序',
        'angle': '跨國配銷中心的內部追蹤系統'
    },
    '金上達科技股份有限公司': {
        'short_name': '金上達科技',
        'obs': '貴司在精密連接器與醫材研發的高度整合製造能力，且同時取得 ISO 13485 及 GMP 等權威醫規認證',
        'pain': '兼營電子與醫療器材 OEM/ODM 的製造商，面臨極高的法規與製程追蹤要求，若品管紀錄與開發履歷仍高度依賴紙本歸檔或試算表，不僅查詢費力，交接成本也居高不下',
        'case_name': '腎臟醫學會 TSN 病理系統',
        'case_url': 'https://playplus.com.tw/portfolio/tsn',
        'case_desc': '建構符合嚴謹醫學規範的深度資料追蹤與審核流程',
        'angle': '醫材與電子製造的流程追蹤'
    },
    '賀電實業股份有限公司': {
        'short_name': '賀電實業',
        'obs': '貴司在低壓電氣與自動控制盤領域深耕逾三十年，取得多國權威安全認證，是業界極具信賴度的領導廠',
        'pain': '隨著產品線擴增與客製控制盤訂單增加，傳統廠區常面臨料件領用紀錄與組裝工單仰賴人工傳遞的痛點，資深員工腦中的隱性流程知識難以有效轉化為系統化資產',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '梳理內部排程與資源調配邏輯，讓協作流程好紀錄、好交接',
        'angle': '工控設備廠的營運數位化'
    },
    '普聯國際股份有限公司': {
        'short_name': '普聯國際',
        'obs': '貴司在橡塑膠機械整廠設備與前瞻綠能再生系統的卓越技術，客製化研發能量行銷全球百國令人驚豔',
        'pain': '整廠輸出與大型客製化專案的週期長、參與部門多，若專案進度與機電整合資訊分散在不同單位的 Excel 中，往往導致每週需耗費大量時間進行人工對焦與報表彙整',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '打造跨部門高透明度的協作與預約追蹤平台',
        'angle': '整廠設備製造的專案流程數位化'
    },
    '天葆股份有限公司': {
        'short_name': '天葆',
        'obs': '貴司自 1978 年起對高品質尼龍纖維的專注，並積極導入數位化精實生產以服務全球紡織供應鏈',
        'pain': '在生產線邁向精實管理的同時，企業內部的行政審核、採購領用或跨廠區溝通若仍維持傳統的紙本簽核，往往會拖慢整體決策速度，產生管理斷層',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '落實內部資源調度與行政流程的輕量數位化',
        'angle': '纖維材料廠的行政流程升級'
    },
    '亞護開發股份有限公司': {
        'short_name': '亞護開發',
        'obs': '貴司作為亞太區高階智慧醫療床製造大廠，全線產品通過歐盟 MDR 與美國 FDA 嚴格把關，研發實力出眾',
        'pain': '面對嚴苛的國際醫療法規，產品從設計變更、履歷追蹤到售後維修紀錄都需要極為嚴謹的控管，依賴分散的本地檔案或人工表單極易造成追蹤漏洞與過高的核對成本',
        'case_name': '腎臟醫學會 TSN 病理系統',
        'case_url': 'https://playplus.com.tw/portfolio/tsn',
        'case_desc': '建構高規格、高穩定度的專業資料追蹤與審核閉環',
        'angle': '醫療設備廠的履歷追蹤系統'
    },
    '立明板金股份有限公司': {
        'short_name': '立明板金',
        'obs': '貴司專精於半導體及電子製程設備的客製化精密機械板金與機台骨架打造，極致工藝深獲客戶依賴',
        'pain': '半導體關聯設備的板金樣式多變且修改頻繁，若打樣工單與設計變更缺乏專屬的內部追蹤系統，經常導致現場師傅與設計端的溝通落差，增加重工成本',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '梳理跨單位協作秩序，讓排程與工單流轉更加順暢',
        'angle': '精密板金廠的工單追蹤數位化'
    },
    "空服員的手作甜點 Crew's dessert_糕飛有限公司": {
        'short_name': '空服員的手作甜點',
        'obs': '貴司由退役空服員打造的高質感甜點品牌形象，堅持頂級天然食材與零人工添加物的理念在市場上極具口碑',
        'pain': '隨著品牌規模擴大、彌月與客製訂單湧入，中央廚房的生產排程、食材批次管理與訂單交接若純靠人工謄寫或試算表追蹤，極易在出貨高峰期引發混亂與交接失誤',
        'case_name': '食安智幫手APP',
        'case_url': 'https://playplus.com.tw/portfolio/tfif-app',
        'case_desc': '優化原物料追蹤與生產履歷管理，確保每一批出貨的品質與效率',
        'angle': '烘焙品牌的生產排程與訂單管理'
    },
    '廣呈工業股份有限公司': {
        'short_name': '廣呈工業',
        'obs': '貴司深耕高精密齒輪與傳動軸加工，產品廣泛滲透至汽機車與重型機械產業，供應鏈實力穩固',
        'pain': '傳統金屬零件加工廠在面對多批次、少量多樣的客製化訂單時，各機台的加工進度與品管檢驗紀錄多半依賴現場手工填表，主管難以即時掌握確實進度，交接也容易出現斷層',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '建立直覺的排程視覺化與現場資源追蹤平台',
        'angle': '金屬加工廠的現場進度管理'
    },
    '金冠鑫興業股份有限公司': {
        'short_name': '金冠鑫',
        'obs': '貴司在食品包裝容器與環保材料製品的自產自銷上具備多項專利，穩健拓展國內外市場的表現極為出色',
        'pain': '包裝容器製造業出貨頻率高、規格品項繁雜，若業務端的訂單需求與廠端的生產排程缺乏一套好用的內部系統對接，常需花費大量時間溝通與人工重複確認庫存',
        'case_name': '食安智幫手APP',
        'case_url': 'https://playplus.com.tw/portfolio/tfif-app',
        'case_desc': '讓品項規格與出貨檢驗追蹤流程系統化，降低人為疏漏',
        'angle': '包裝容器廠的訂單排程追蹤'
    },
    '太子螺絲股份有限公司': {
        'short_name': '太子螺絲',
        'obs': '貴司作為頂尖自鑽螺絲與緊固件製造廠的深厚底蘊，導入多沖程成型設備快速響應全球產業鏈的實力令人欽佩',
        'pain': '緊固件生產涉及多道成型與表面加工環節，當外銷訂單量大時，外包工序的追蹤與廠內交期確認若僅靠 Excel 追蹤，資訊常有滯後，且耗費大量人力彙整報表',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '實現跨環節資訊同步與排程自動化追蹤',
        'angle': '螺絲製造廠的工序追蹤系統'
    },
    '台灣銅業科技股份有限公司': {
        'short_name': '台灣銅業',
        'obs': '貴司透過獨家高規格回收提煉技術產製高純度無氧銅條，在綠色循環經濟與半導體原料供應鏈中扮演關鍵角色',
        'pain': '高科技原料熔煉廠對製程參數與批次回收履歷有著極高要求，若關鍵的檢驗報告與流轉紀錄仍需人工手動建檔或缺乏系統化整合，將大幅增加跨班別交接的隱形成本',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '將內部流程節點數位化，打造好追蹤、好交接的專屬機制',
        'angle': '科技原料廠的批次流程管理'
    },
    '鼎霖醫療器材股份有限公司': {
        'short_name': '鼎霖醫療',
        'obs': '貴司深耕全台各大醫學中心與區域醫院，提供主治醫師群高階骨科植入物與即時的臨床支援，通路服務極為扎實',
        'pain': '醫療器材寄售與手術器械調度的時效性極強，若業務同仁進出醫院的器械借還紀錄與批號追蹤仰賴紙本或人工回報，不僅盤點耗時，也容易產生帳物核對的管理痛點',
        'case_name': '腎臟醫學會 TSN 病理系統',
        'case_url': 'https://playplus.com.tw/portfolio/tsn',
        'case_desc': '打造符合醫療臨床通路需求的高效追蹤與資料管理機制',
        'angle': '醫材代理商的器械調度系統'
    },
    '昇暘工業有限公司': {
        'short_name': '昇暘工業',
        'obs': '貴司身為國際車廠指定的關鍵金屬組件製造廠，具備深引伸與沖鍛複合工藝，並通過 IATF 16949 認證，技術卓越',
        'pain': '汽車零組件供應鏈面對嚴格的開發流程與品質審查，若各階段的工程變更與品管紀錄分散在資深員工腦中或獨立表單裡，日後追蹤極為費力，且不利於經驗傳承',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '標準化跨部門溝通與專案進度的透明追蹤',
        'angle': '車用零件廠的開發流程管理'
    },
    '合騏工業股份有限公司': {
        'short_name': '合騏工業',
        'obs': '貴司自創品牌 ADLY 暢銷歐美市場，身為資深上櫃車輛製造大廠，整車研發與精密組裝工藝備受肯定',
        'pain': '整車組裝涉及龐大的零組件料件與跨廠區供料，若現場缺料通報、工程進度流轉仍依賴傳統紙單傳遞，資訊落差常會導致產線等待與無謂的協調成本',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '建置即時透明的內部通報與排程協作機制',
        'angle': '車輛製造大廠的內部協作升級'
    },
    '大發金屬工業股份有限公司': {
        'short_name': '大發金屬',
        'obs': '貴司具備深厚金屬加工底蘊，積極導入系統化製程管理並建置完善員工設施，是穩健發展的優質製造廠',
        'pain': '隨著業務持續擴展，傳統製造廠常面臨現場工單排程與品質檢驗單據過多、仰賴人工重複建檔的問題，不僅耗費時間，也容易造成跨班別交接時的資訊遺漏',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '從小處著手梳理作業流程，打造好紀錄、好追蹤的專屬數位工具',
        'angle': '金屬工業廠的工單數位化'
    },
    '金瑛發機械工業股份有限公司': {
        'short_name': '金瑛發機械',
        'obs': '貴司在食品高溫高壓殺菌釜與調理包整廠產線的權威地位，交鑰匙工程廣銷大中華與東南亞逾千套，實力享譽國際',
        'pain': '大型整廠設備的客製化程度高、專案交期長，若工程設計、物料採購與現場安調的進度回報僅依賴會議與人工試算表更新，極易產生跨部門資訊不對稱與隱形成本',
        'case_name': '食安智幫手APP',
        'case_url': 'https://playplus.com.tw/portfolio/tfif-app',
        'case_desc': '將關鍵設備履歷與專案進度追蹤邏輯系統化，大幅提升管理效率',
        'angle': '食品設備整廠規劃的專案追蹤'
    },
    '集圓科技工業股份有限公司': {
        'short_name': '集圓科技',
        'obs': '貴司研發製造的工業級六角扳手與精密工具深獲歐美主流市場青睞，全線通過嚴格國際安全檢驗，品質卓越耐用',
        'pain': '外銷手工具的品項規格與包裝要求極為多元，若出貨前的品管報告與客製化進度仰賴人工反覆核對，不僅容易在出貨旺季造成瓶頸，新人交接也相當困難',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '建立條理分明的內部排程與檢驗核對機制',
        'angle': '手工具製造的出貨檢驗數位化'
    },
    '新可大國際股份有限公司': {
        'short_name': '新可大國際',
        'obs': '貴司在高階自行車關鍵組件的創新設計實力，並建構完善的企業學院體系落實共好職場，企業文化令人嚮往',
        'pain': '在團隊快速成長與落實各項管理制度的同時，內部的教育訓練紀錄、跨部門提案或工程變更申請若仍以紙本或簡單試算表流轉，主管常需耗費額外精力進行人工追蹤與彙整',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '提供直覺高效的內部流程數位化方案，降低行政溝通負擔',
        'angle': '自行車零件廠的內部行政優化'
    },
    '阡懋實業股份有限公司': {
        'short_name': '阡懋實業',
        'obs': '貴司以極致輕量的高階鋁合金鍛造工藝深獲全球一線自行車廠信賴，堅持根留台灣在地精密製造的精神令人敬佩',
        'pain': '精品級零組件對製程參數與批次生產追蹤的要求極高，若現場鍛造批號與品管數據仰賴人工手寫紀錄，不僅日後回溯困難，也難以快速轉化為改善製程的數位資產',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '將現場資訊同步與進度追蹤流程化繁為簡',
        'angle': '高階鍛造廠的生產批號追蹤'
    },
    '帝谷企業股份有限公司': {
        'short_name': '帝谷企業',
        'obs': '貴司具備精密射出成型至高規格電鍍表面處理的一貫化嚴謹製程，長年穩定供應海內外知名車燈大廠，產能完善',
        'pain': '一貫化製程跨越了塑膠射出與表面處理等多個工段廠區，若工序間的轉運交接與進度紀錄未能透過內部系統即時串聯，常需依賴人工查核與電話確認，增加管理盲點',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '串接跨工段的資訊流，打造好追蹤、好交接的專屬營運工具',
        'angle': '複合製程廠區的資訊串聯系統'
    },
    '富潤股份有限公司': {
        'short_name': '富潤',
        'obs': '貴司在頂級家飾布料與特殊昇華轉印工藝的深厚藝術底蘊，極具張力的色彩美學為全球頂尖空間建構尊榮體驗',
        'pain': '布料印花產業的圖稿版本多、客製打樣頻繁，若業務與設計部門間的版樣確認與修改進度缺乏系統化紀錄，容易產生溝通落差，且依賴人工反覆核對常影響交貨效率',
        'case_name': '大管家包租代管系統',
        'case_url': 'https://playplus.com.tw/portfolio/chrb',
        'case_desc': '梳理繁複的版品與進度追蹤邏輯，讓跨部門協作透明高效',
        'angle': '印花布料廠的樣版追蹤系統'
    },
    '凱悅國際貿易有限公司': {
        'short_name': '凱悅國際',
        'obs': '貴司作為全球手搖飲供應鏈的關鍵推手，具備將珍奶原物料與包裝直達海外四大洲倉儲的強大運籌配銷實力',
        'pain': '跨國物流與多品項原物料併櫃出貨的環節極度繁瑣，若各國客戶訂單與船期進度高度依賴人工操作 Excel 彙整，不僅耗時，一旦遇到突發船期異動更是難以即時同步交接',
        'case_name': '食安智幫手APP',
        'case_url': 'https://playplus.com.tw/portfolio/tfif-app',
        'case_desc': '優化跨國進銷與批次追蹤流程，降低人為出錯率',
        'angle': '跨國餐飲供應鏈的訂單追蹤'
    },
    '台灣鉅邁股份有限公司': {
        'short_name': '台灣鉅邁',
        'obs': '貴司深耕石化、鋼鐵及半導體等重工業領域的專業水化學處理與技術服務，在協助企業節能減碳與設備防護上貢獻卓著',
        'pain': '專業水處理高度依賴工程師定期到廠採樣與加藥系統檢測，若前線技術服務報告與客戶端水質追蹤數據仍需人工回辦公室重複建檔，不僅耗費同仁心力，也難以維持連貫追蹤',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '打造外勤派工與技術服務紀錄即時追蹤的專屬數位機制',
        'angle': '工業技術服務的派工與紀錄數位化'
    },
    '華聯工程股份有限公司': {
        'short_name': '華聯工程',
        'obs': '貴司擁有超過一甲子的深厚石化建廠與超低溫儲槽統包實績，長年支撐國內外指標性發電廠與氣體廠的安全營運，令人肅然起敬',
        'pain': '大型統包工程的工單派發、管線檢驗單據與施工進度節點極為龐大，若現場安調紀錄與派工仍依賴傳統紙本或繁複的人工報表往返，極易衍生跨單位的溝通落差與追蹤盲區',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '將複雜的跨單位資源調度與現場排程回報化繁為簡',
        'angle': '重工業統包工程的現場工單數位化'
    }
}

def get_titles(idx, short_name, angle):
    # 利用 idx 實現交替切換句型，避免重複
    t1 = [
        f"給{short_name}的內部流程優化建議：告別人工彙整報表",
        f"{short_name}的內部協作流程，是否跟得上業務擴張的速度？",
        f"如何實現{short_name}{angle}的高效數位化？",
        f"為{short_name}量身打造專屬內部系統的初步構想",
        f"{short_name}在業務擴張期，有沒有更直覺的營運追蹤方式？"
    ][idx % 5]

    t7 = [
        f"快速跟進：關於{short_name}{angle}的想法",
        f"一個簡短的確認：給{short_name}的內部管理建議",
        f"不知您是否有空閱覽：關於客製化系統的構想",
        f"{short_name}專屬系統打造建議：一封簡短的追蹤信",
        f"給{short_name}的小提醒：營運流程數位化探討"
    ][idx % 5]

    t14 = [
        f"實戰案例分享：{angle}如何實現無痛升級",
        f"流程數位化的實質價值：協助同仁省下人工核對時間",
        f"從小流程啟動轉型：分享我們過去的系統導入經歷",
        f"消除系統導入顧慮：給{short_name}的實戰經驗參考",
        f"打造好紀錄、好交接的系統：實戰案例分享"
    ][idx % 5]

    t30 = [
        f"評估內部系統開發時，您可能會顧慮的幾個問題",
        f"預算彈性與溝通成本：關於{short_name}系統升級的解方",
        f"主管每週只需15分鐘：高彈性的客製化開發方案",
        f"擔心開發費用或耗費時間？我們的模組化解方",
        f"關於客製化內部系統，多數決策者最關心的三件事"
    ][idx % 5]

    t60 = [
        f"最後一封信：祝{short_name}持續蓬勃成長",
        f"停止主動聯繫：未來若有專屬系統需求隨時歡迎聯繫",
        f"不再打擾您的業務：PlayPlus隨時為您敞開大門",
        f"優雅退場：期待未來與{short_name}在數位化領域合作",
        f"給{short_name}的最後一封信——祝 貴司業務蒸蒸日上"
    ][idx % 5]

    return t1, t7, t14, t30, t60

def gen_emails(idx, name, contact):
    c = COMPANIES.get(name, {
        'short_name': name,
        'obs': '貴司在產業中具備深厚的基礎與卓越的運營表現',
        'pain': '企業在快速擴張階段，常面臨內部管理與流程紀錄跟不上速度的問題，依賴人工或傳統試算表容易造成資訊落差',
        'case_name': '神達電腦開發會議室預約系統',
        'case_url': 'https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system',
        'case_desc': '梳理跨單位協作邏輯，實現流程透明化管理',
        'angle': '營運流程的客製化升級'
    })
    
    short_name = c['short_name']
    angle = c['angle']
    
    # 稱謂處理：官方或非具名僅寫「您好，」
    if any(k in contact for k in ['官方', '客服', '窗口', '服務']) or contact == '':
        g = "您好，"
    else:
        g = f"{contact} 您好，"

    t1, t7, t14, t30, t60 = get_titles(idx, short_name, angle)

    emails = {}
    emails['day1_title'] = t1
    emails['day1_content'] = (
        f"{g}<br><br>"
        f"我剛研究了{c['obs']}。<br><br>"
        f"不過我們觀察到，{c['pain']}，例如：流程紀錄在資深同仁腦中、過度仰賴人工彙整報表或試算表對接等。<br><br>"
        f"我們是 PlayPlus，專注於協助中型企業打造「**客製化企業內部系統**」。我們不推銷動輒數百萬的大型 ERP，而是從你們最痛的一條流程開始，打造好紀錄、好追蹤、好交接的專屬系統。例如我們曾協助{c['case_name']}（{c['case_url']}），{c['case_desc']}。<br><br>"
        f"是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        f"感謝您"
    )

    emails['day7_title'] = t7
    emails['day7_content'] = (
        f"{g}<br><br>"
        f"上週寄了一封關於優化內部管理流程與專屬系統打造的簡短建議，不知道您是否有機會看過？<br><br>"
        f"我知道您業務繁忙，若無法回覆我完全能理解。只是想確認這封信有沒有順利抵達您的收件匣。<br><br>"
        f"您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        f"感謝您"
    )

    emails['day14_title'] = t14
    emails['day14_content'] = (
        f"{g}<br><br>"
        f"接著上一封信，我想進一步分享我們過去協助企業推動流程數位化的實戰經歷。許多正處於快速成長期的公司，常擔心引進新系統會面臨員工反彈或適應期過長的問題。<br><br>"
        f"因此，我們採取「**從小流程著手**」的策略，先針對內部最耗費人工核對的節點開發專屬工具。這不僅能讓前線同仁立即感受到省時的價值，更能有效消除內部對數位轉型的顧慮與不信任。<br><br>"
        f"如果您有興趣了解具體的導入成效與做法，我很樂意提供相關的實戰分析。您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        f"感謝您"
    )

    emails['day30_title'] = t30
    emails['day30_content'] = (
        f"{g}<br><br>"
        f"這段時間陸續跟您分享了一些想法，我猜測您在評估內部系統開發時，可能會擔心費用超出預期，或是需要投入大量寶貴的時間成本？<br><br>"
        f"其實為了讓企業保有最大的彈性，我們提供「**模組化開發**」與「**分階段優化方案**」，完全能配合您的年度預算逐步推進。此外，我們的專案協作流程極度精簡，**主管每週只需 15 分鐘確認進度**，能大幅降低雙方的溝通成本。<br><br>"
        f"這或許能讓您在不增加營運負擔的情況下，輕鬆啟動流程升級。您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        f"感謝您"
    )

    emails['day60_title'] = t60
    emails['day60_content'] = (
        f"{g}<br><br>"
        f"這是我最後一封主動追蹤的郵件。這段時間未收到您的回覆，我想梳理內部營運流程或導入客製化系統，或許不是貴司目前的優先事項。我會停止主動聯繫，以免打擾您的日常業務。<br><br>"
        f"不過，若未來{short_name}在團隊持續擴張的過程中，有任何打造專屬內部系統、讓工作流程更好紀錄與交接的需求，PlayPlus 的大門隨時為您敞開。我們將持續在客製化系統開發領域深耕。<br><br>"
        f"祝 貴司業務蒸蒸日上。您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br><br>"
        f"感謝您"
    )

    return emails

def main():
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        rows = list(csv.reader(f))
    
    header = rows[0]
    col = {h: i for i, h in enumerate(header)}

    # 確保寫入的欄位存在
    keys = ['day1_title', 'day1_content', 'day7_title', 'day7_content',
            'day14_title', 'day14_content', 'day30_title', 'day30_content',
            'day60_title', 'day60_content']
            
    for i in range(1, len(rows)):
        r = rows[i]
        comp_name = r[col['公司品牌簡稱']]
        contact_name = r[col['聯絡人名稱']]
        
        emails = gen_emails(i, comp_name, contact_name)
        for key in keys:
            r[col[key]] = emails[key]

    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        csv.writer(f).writerows(rows)
        
    print(f"✅ 成功完成 {len(rows)-1} 筆潛在客戶的企業內部系統冷郵件撰寫（Day 1 ~ Day 60），名單副本.csv 覆寫完畢！")

if __name__ == '__main__':
    main()
