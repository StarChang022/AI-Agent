# -*- coding: utf-8 -*-
import os
import csv
import json
import pandas as pd
import shutil

# Paths
BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
csv_path = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
backup_path = os.path.join(BASE_DIR, "冷郵件對象", "名單副本_backup_emails.csv")
json_temp_path = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104_emails.json")

# 1. Back up CSV
if not os.path.exists(backup_path):
    shutil.copy2(csv_path, backup_path)
    print(f"Backed up original CSV to {backup_path}")
else:
    print(f"Backup already exists at {backup_path}")

# 2. Define custom pain points for Day 7 based on company activities
pain_points = {
    "欣展工業股份有限公司": "多模具與生產排程管理、射出參數紀錄數位化、跨部門品管審核",
    "集泉塑膠工業股份有限公司": "自動化裝箱出貨追蹤、模具生命週期管理、跨部門品質檢驗簽核",
    "創奕能源科技股份有限公司": "客製化電池模組BOM表管理、車輛組裝進度追蹤、跨部門工程變更簽核",
    "歐萊德國際股份有限公司": "綠色供應鏈碳足跡盤查、配方研發專案進度管理、跨據點庫存調撥單據審核",
    "台灣翔登股份有限公司": "中高壓電力設備測試履歷追蹤、物料BOM表版本管理、跨部門採購單據審核",
    "順天堂藥廠股份有限公司": "中藥材批次生產履歷追蹤、藥品合規流程簽核管理、跨部門庫存批號追蹤",
    "台灣農畜產工業股份有限公司屏東工廠": "冷鏈物流配送進度追蹤、原料批次與食品安全追溯、跨部門採購與銷貨單據審核",
    "立督科技股份有限公司": "CNC工單排程與進度追蹤、陽極表面處理製程管理、跨部門品質異常簽核",
    "耀億工業股份有限公司": "多據點跨國生產排程管理、線材規格BOM表管理、跨部門單據審核",
    "羅一國際股份有限公司": "安全眼鏡開模打樣進度追蹤、外銷訂單出貨排程管理、跨部門品檢簽核",
    "亞崴機電股份有限公司": "大型加工設備組裝進度追蹤、售後保養與維修派工管理、跨部門工程變更簽核",
    "啟鑫科技股份有限公司": "醫療器材合規生產履歷追蹤、客製化模具設計變更管理、跨部門專案排程",
    "華福食品股份有限公司": "多門市配貨與即時訂單處理、烘焙原料保鮮期與庫存管理、跨部門採購單據審核",
    "良聯工業股份有限公司": "EPC專案工程進度與工時登錄、統包工程派工管理、跨部門單據審核",
    "PGO比雅久_摩特動力工業股份有限公司": "機車零組件BOM表管理、組裝產線進度與多廠區派工、跨部門工程變更簽核",
    "翰陽開發股份有限公司": "健身器材外銷出貨排程、打樣研發進度追蹤、跨部門資源排程審核",
    "奇鼎科技股份有限公司": "半導體恆溫設備客製化設計管理、無塵室工程進度追蹤、跨部門品質簽核",
    "寶緯工業股份有限公司": "鋁擠型工單排程與擠型模具管理、帷幕牆工程專案進度追蹤、跨部門單據審核",
    "纖福企業股份有限公司": "外銷成衣打樣與打版進度追蹤、跨國代工廠生產進度管理、跨部門採購單據審核",
    "高明鐵企業股份有限公司": "傳動元件庫存與出貨管理、精密模座排產與進度追蹤、跨部門品質簽核",
    "世紀鋼鐵結構股份有限公司": "大型鋼結構專案進度追蹤、離岸風電水下基礎施工日誌管理、跨部門工程簽證審核",
    "坤成實業廠股份有限公司": "安全帽認證合規測試履歷、外銷訂單與出貨排程追蹤、跨部門品質簽核",
    "大中鋼鐵股份有限公司": "鋼鐵加工工單排程與進度追蹤、原料捲鋼與產線物料追溯、跨部門單據審核",
    "元穩實業股份有限公司": "冷鍛製程工單排產與模具管理、氣動工具零件庫存調撥、跨部門品質簽核",
    "造隆股份有限公司": "汽機車儀表零件BOM表管理、車廠供應商交期與進度追蹤、跨部門工程變更簽核",
    "新進工業股份有限公司": "電子零件研發與開模打樣追蹤、客製化開關規格BOM表管理、跨部門品質檢驗簽核"
}

# 3. Read original CSV
df = pd.read_csv(csv_path, encoding='utf-8')

# 4. Generate content
results_json = []

for idx, row in df.iterrows():
    co_name = str(row['公司名稱']).strip()
    contact = str(row['聯絡人名稱']).strip()
    
    # Salutation logic
    salutation = "您好，" if contact == "官方" else f"{contact} 您好，"
    
    # Day 1 Title & Content
    day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day1_content = f"{salutation}<br>\n<br>\n在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。<br>\n<br>\n我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。<br>\n<br>\n作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。<br>\n<br>\n隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。<br>\n<br>\n只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？<br>\n<br>\n祝順利。"
    
    # Day 7 Title & Content
    day7_title = "Re: 內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    flow = pain_points.get(co_name, "跨部門單據審核與流程追蹤")
    day7_content = f"{salutation}<br>\n<br>\n我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。<br>\n<br>\n我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，特別是針對貴產業常見的「{flow}」，我們在實際開發前就會梳理完畢，打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。<br>\n<br>\n若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br>\n<br>\n祝順利。"
    
    # Day 30 Title & Content
    day30_title = "企業內部系統優化的最後一封信"
    day30_content = f"{salutation}<br>\n<br>\n打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br>\n<br>\n在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型提升供應鏈數位韌性，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。<br>\n<br>\n我再次將附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。<br>\n<br>\n祝順利。"
    
    # Write to dataframe
    df.at[idx, 'day1_title'] = day1_title
    df.at[idx, 'day1_content'] = day1_content
    df.at[idx, 'day7_title'] = day7_title
    df.at[idx, 'day7_content'] = day7_content
    df.at[idx, 'day14_title'] = "-"
    df.at[idx, 'day14_content'] = "-"
    df.at[idx, 'day30_title'] = day30_title
    df.at[idx, 'day30_content'] = day30_content
    df.at[idx, 'day60_title'] = "-"
    df.at[idx, 'day60_content'] = "-"
    
    results_json.append({
        "company": co_name,
        "contact": contact,
        "day1": {"title": day1_title, "content": day1_content},
        "day7": {"title": day7_title, "content": day7_content},
        "day14": {"title": "-", "content": "-"},
        "day30": {"title": day30_title, "content": day30_content},
        "day60": {"title": "-", "content": "-"}
    })

# 5. Save temporary JSON
with open(json_temp_path, 'w', encoding='utf-8') as f:
    json.dump(results_json, f, ensure_ascii=False, indent=2)
print(f"Saved temporary JSON to {json_temp_path}")

# 6. Save updated CSV
df.to_csv(csv_path, index=False, encoding='utf-8')
print(f"Successfully saved updated CSV to {csv_path}")
