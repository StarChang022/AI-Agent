#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
為「中小企業_企業內部系統」的客戶生成 Day 1、Day 7、Day 14、Day 30 與 Day 60 的客製化冷郵件。
符合中小企業規則，包含 HTML 換行與真實換行格式。
"""

import os
import csv
import json
import shutil

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
BACKUP_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本_backup_sme_emails.csv')
TEMP_JSON_PATH = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')

def classify_portfolio(comp_name, desc):
    """
    根據公司名稱及說明文字，挑選最適合的 Social Proof 作品集。
    """
    comp_lower = comp_name.lower()
    desc_lower = desc.lower()
    
    # 醫療/生技/輔具相關
    medical_keywords = ["生技", "藥", "醫", "病理", "醫療", "製藥", "生化", "牙科", "骨科", "輔具", "輸液", "注射筒"]
    # 食品/餐飲/農業相關
    food_keywords = ["食品", "製菓", "農畜", "肉品", "果汁", "茶", "餐飲", "咖啡", "燕麥", "瓜子", "堅果", "果凍", "麵條", "調味"]
    # 物業/租賃/家具/文具/包裝/收納相關
    property_keywords = ["租", "房", "代管", "物業", "車套", "家具", "文具", "紙器", "包裝", "收納", "印刷", "製版", "貼紙"]
    
    if any(k in comp_lower for k in medical_keywords) or any(k in desc_lower for k in medical_keywords):
        return "腎臟醫學會 TSN 病理系統", "https://playplus.com.tw/portfolio/tsn", "病理數據與醫療流程追蹤"
    elif any(k in comp_lower for k in food_keywords) or any(k in desc_lower for k in food_keywords):
        return "食安智幫手APP", "https://playplus.com.tw/portfolio/tfif-app", "食品履歷與合規流程追蹤"
    elif any(k in comp_lower for k in property_keywords) or any(k in desc_lower for k in property_keywords):
        return "大管家包租代管系統", "https://playplus.com.tw/portfolio/chrb", "跨部門與外部合約流程管理"
    else:
        # 預設使用神達會議室預約系統（適用於一般製造/辦公室協作）
        return "神達會議室預約系統", "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system", "跨部門資源預約"

def generate_emails(comp_name, contact_name, desc):
    contact = contact_name.strip()
    if contact == "官方" or not contact:
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    port_name, port_url, port_desc = classify_portfolio(comp_name, desc)
    
    # ------------------ Day 1 ------------------
    day1_title = "內部系統與表單流程可以更好嗎？"
    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我剛瀏覽了貴公司的網站，注意到你們近期業務與團隊規模成長非常快速。不過我們也發現，許多企業在快速擴張的階段，常會遇到內部管理與流程跟不上的問題，例如：新人交接困難、報表多半靠人工彙整等。<br>\n"
        f"<br>\n"
        f"我們是 PlayPlus，專注於協助中型企業打造「**客製化企業內部系統**」。我們避開動輒數百萬的大型套裝軟體，選擇從你們最卡關的一條流程切入，量身建構好紀錄、好追蹤、好交接的專屬系統。例如我們曾協助客戶開發{port_name}（{port_url}），解決{port_desc}的混亂問題。<br>\n"
        f"<br>\n"
        f"是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # ------------------ Day 7 ------------------
    day7_title = "Re: 內部系統與表單流程可以更好嗎？"
    day7_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。<br>\n"
        f"<br>\n"
        f"若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # ------------------ Day 14 ------------------
    day14_title = "如何以數位系統解決中型企業的流程管理痛點"
    day14_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"許多中型企業在成長階段都會面臨流程缺乏紀錄、交接困難的痛點。我這幾天在思考，這是否也是貴司目前遇到的挑戰？<br>\n"
        f"<br>\n"
        f"我們過去曾協助客戶打造專屬的{port_name}（{port_url}），將繁瑣的手工作業全面線上化，不僅大幅降低了同仁重複輸入與手動彙整表單的時間，更讓管理者能即時掌握營運數據。<br>\n"
        f"<br>\n"
        f"我們團隊累積了超過 10 年的系統開發與 UI/UX 設計經驗。我們相信，優秀的系統應該融入同仁現有的工作習慣，而非強迫團隊去適應僵化老舊的軟體。<br>\n"
        f"<br>\n"
        f"若您有興趣了解我們是如何在短短幾週內協助客戶完成數位化，歡迎隨時回信，我可以寄一份簡報給您參考。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # ------------------ Day 30 ------------------
    day30_title = "開發內部系統會很耗費時間或預算嗎？"
    day30_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"在評估重構舊系統或開發新功能時，許多企業主管最擔心預算過高或需要投入大量溝通時間。我完全理解這些顧慮。<br>\n"
        f"<br>\n"
        f"為了降低風險，PlayPlus 採用「模組化開發」與「分階段優化方案」，讓企業可以從最痛的一條流程開始，逐步擴充系統，符合預算彈性。此外，我們的開發流程高度標準化，主管每週僅需 15 分鐘確認進度，絕不佔用您寶貴的日常業務時間。<br>\n"
        f"<br>\n"
        f"如果您想了解如何以最低的開發風險與溝通成本優化現有流程，歡迎回信與我們聊聊。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # ------------------ Day 60 ------------------
    day60_title = "這是最後一封信，後續我不會再打擾您"
    day60_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"由於先前寄出的幾封郵件皆未收到您的回覆，我想目前優化內部流程可能不是貴司的首要任務。這也是最後一封信，後續我不會再主動發信到您的收件匣。<br>\n"
        f"<br>\n"
        f"若貴司未來有計畫重新規劃企業內部系統、重構舊軟體或梳理營運表單，我們 PlayPlus 的大門隨時為您敞開。您可以透過我們的官網（https://playplus.com.tw/）了解更多，也歡迎隨時與我們取得聯繫。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    return {
        "day1_title": day1_title,
        "day1_content": day1_content,
        "day7_title": day7_title,
        "day7_content": day7_content,
        "day14_title": day14_title,
        "day14_content": day14_content,
        "day30_title": day30_title,
        "day30_content": day30_content,
        "day60_title": day60_title,
        "day60_content": day60_content
    }

def main():
    print("=== 開始生成中小企業客製化冷郵件 ===")

    # 1. 備份 CSV
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份 CSV 至：{BACKUP_PATH}")

    # 2. 讀取 CSV
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV 檔案內容為空")
        return

    header = rows[0]
    
    # 尋找所需欄位的 index
    try:
        scenarios_idx = header.index("Scenarios")
        comp_idx = header.index("公司名稱")
        contact_idx = header.index("聯絡人名稱")
        desc_idx = header.index("說明")
        
        # 郵件欄位 index
        day1_title_idx = header.index("day1_title")
        day1_content_idx = header.index("day1_content")
        day7_title_idx = header.index("day7_title")
        day7_content_idx = header.index("day7_content")
        day14_title_idx = header.index("day14_title")
        day14_content_idx = header.index("day14_content")
        day30_title_idx = header.index("day30_title")
        day30_content_idx = header.index("day30_content")
        day60_title_idx = header.index("day60_title")
        day60_content_idx = header.index("day60_content")
    except ValueError as e:
        print(f"❌ 欄位尋找錯誤：{e}")
        return

    updated_count = 0
    skipped_count = 0
    temp_logs = {}

    # 3. 遍歷並在記憶體中生成與更新
    for i in range(1, len(rows)):
        row = rows[i]
        if not row or len(row) <= max(scenarios_idx, day60_content_idx):
            continue
            
        sc = row[scenarios_idx].strip()
        comp_name = row[comp_idx].strip()
        contact_name = row[contact_idx].strip()
        desc = row[desc_idx].strip()

        # 僅當 Scenarios 為「中小企業_企業內部系統」時處理
        if sc == "中小企業_企業內部系統":
            emails = generate_emails(comp_name, contact_name, desc)

            row[day1_title_idx] = emails["day1_title"]
            row[day1_content_idx] = emails["day1_content"]
            row[day7_title_idx] = emails["day7_title"]
            row[day7_content_idx] = emails["day7_content"]
            row[day14_title_idx] = emails["day14_title"]
            row[day14_content_idx] = emails["day14_content"]
            row[day30_title_idx] = emails["day30_title"]
            row[day30_content_idx] = emails["day30_content"]
            row[day60_title_idx] = emails["day60_title"]
            row[day60_content_idx] = emails["day60_content"]

            updated_count += 1
            # 使用 row_index 確保 key 唯一
            temp_logs[f"{i}_{comp_name}_{contact_name}"] = emails
        else:
            skipped_count += 1

    # 4. 一次性覆寫寫回 CSV
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print(f"✅ CSV 更新成功。生成中小企業郵件筆數: {updated_count}, 跳過非中小企業筆數: {skipped_count}")

    # 5. 寫入暫存 JSON 檔
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    with open(TEMP_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(temp_logs, f, ensure_ascii=False, indent=2)
    print(f"✅ 詳細暫存紀錄已寫入：{TEMP_JSON_PATH}")

if __name__ == "__main__":
    main()
