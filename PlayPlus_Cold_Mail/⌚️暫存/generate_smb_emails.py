#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
為 Scenarios 為「中小企業_企業內部系統」的潛在客戶生成 Day 1, Day 7, Day 14, Day 30, Day 60 冷郵件。
採用歐美俐落風格，排除「建議」二字與「不是...而是...」句型。
"""

import csv
import json
import os
import shutil

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
BACKUP_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本_backup_smb.csv')
JSON_PATH = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')

# 定義特定作品集分類名單
FOOD_COMPANIES = {
    "東聚國際食品有限公司",
    "Rosa 羅撒食品_佳糧股份有限公司",
    "東陽穀物股份有限公司"
}

MEDICAL_COMPANIES = {
    "台灣荃新股份有限公司",
    "加捷生醫股份有限公司",
    "美樂迪股份有限公司",
    "冠亞生技股份有限公司"
}

def get_portfolio_category(name):
    name = name.strip()
    if name in FOOD_COMPANIES:
        return "tfif-app"
    elif name in MEDICAL_COMPANIES:
        return "tsn"
    return "mitac"

def generate_smb_emails(contact_name, company_name):
    # 規則 1 ： 正式商務稱謂
    contact = contact_name.strip()
    if contact == "官方" or not contact:
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    category = get_portfolio_category(company_name)

    # ------------------ Day 1 ------------------
    if category == "tfif-app":
        day1_title = f"針對 {company_name} 的食品生產與品管數位化：分享食安智幫手案例"
        day1_p1 = f"我剛瀏覽了 {company_name} 的資料，注意到你們在食品與生鮮製造領域已經有非常深厚的基礎。但在食品廠成長的階段，許多團隊常會面臨食安檢測、生產紀錄與品管數據多半靠紙本或 Excel 人工紀錄，導致彙整耗時且後續稽核追蹤不便的問題。"
        day1_p2 = "我們是 PlayPlus，專注於協助企業打造「客製化內部系統」。我們專注於從您最痛的流程開始，打造好紀錄、好追蹤、好交接的專屬系統。例如我們曾協助食品業者開發食安智幫手APP（https://playplus.com.tw/portfolio/tfif-app），協助現場同仁進行智慧化食安檢測與生產紀錄。"
        day1_p3 = "是否方便寄一份我們過去在食品相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/"
    elif category == "tsn":
        day1_title = f"針對 {company_name} 的醫療流程與數據化管理：分享醫學會系統案例"
        day1_p1 = f"我剛瀏覽了 {company_name} 的資料，注意到你們在生技與醫療健康領域已經有非常深厚的基礎。但在企業成長的階段，許多團隊常會面臨數據追蹤、檢驗報告紀錄與出貨品管等多個系統分散，導致人工彙整耗時且難以即時支援決策的問題。"
        day1_p2 = "我們是 PlayPlus，專注於協助企業打造「客製化內部系統」。我們專注於從研發或管理同仁最痛的一條流程開始，打造好紀錄、好追蹤、好交接的專屬系統。例如我們曾協助腎臟醫學會開發 TSN 病理系統（https://playplus.com.tw/portfolio/tsn），整合病理數據與醫療流程，提升臨床管理的精準度。"
        day1_p3 = "是否方便寄一份我們過去在醫療與健康相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/"
    else:
        # mitac
        day1_title = f"針對 {company_name} 的營運流程與系統優化：分享神達電腦案例"
        day1_p1 = f"我剛瀏覽了 {company_name} 的資料，注意到你們在製造與實業領域已經有非常深厚的基礎。但在企業成長的階段，許多團隊常會遇到內部管理與協作流程跟不上的問題，例如新人交接困難、流程只在資深同仁腦中，或是表單分散在 Excel 難以追蹤。"
        day1_p2 = "我們是 PlayPlus，專注於協助企業打造「客製化企業內部系統」。我們專注於從您最痛的一條流程開始，打造好紀錄、好追蹤、好交接的專屬系統。例如我們曾協助神達電腦開發會議室預約系統（https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system），解決跨部門資源預約與協作的混亂問題。"
        day1_p3 = "是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/"

    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{day1_p1}<br>\n"
        f"<br>\n"
        f"{day1_p2}<br>\n"
        f"<br>\n"
        f"{day1_p3}<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # ------------------ Day 7 ------------------
    day7_title = f"Re: {day1_title}"
    day7_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。<br>\n"
        f"<br>\n"
        f"我們很重視協助企業將繁雜的人工表單與流程標準化，不知道貴司近期是否有計畫重構舊系統或調整內部流程？<br>\n"
        f"<br>\n"
        f"如果這週有 10 分鐘的時間，歡迎隨時回信，我們可以用線上會議聊聊，看看能如何協助。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # ------------------ Day 14 ------------------
    day14_title = f"分享 {company_name} 所屬產業流程數位化的實戰經歷"
    if category == "tfif-app":
        day14_p1 = "在許多食品業合作中，我們看到流程順暢的關鍵在於現場操作流程的細緻梳理。在實際開發前，我們會深度盤點貴司從原料品管到出貨的商業邏輯，將紙本紀錄轉化為最適合現場操作的數位介面。"
        day14_p2 = "以我們開發的食安智幫手APP為例，現場品檢同仁現在只需在平板或手機上點選，就能即時上傳 HACCP 規範數據，報表彙整效率提升了 60% 以上。我們將這些實戰經驗整理成了一份「食品工廠數位化轉型指南」，您可以在 https://playplus.com.tw/ 參考。"
    elif category == "tsn":
        day14_p1 = "在許多醫療與健康領域合作中，我們看到數據精準的關鍵在於專業流程的細緻梳理。在實際開發前，我們會深度盤點貴司研發或品管的商業邏輯，將分散的數據整合為單一且直觀的管理後台。"
        day14_p2 = "以我們協助醫學會開發的 TSN 病理系統為例，目前已協助整合了數萬筆繁雜的病理數據與醫療流程，大幅提升臨床管理的精準度。我們將這些實戰經驗整理成了一份「醫療與醫材產業數據化指南」，您可以在 https://playplus.com.tw/ 參考。"
    else:
        # mitac
        day14_p1 = "在許多成長中企業的合作中，我們看到系統好用與否的關鍵在於早期的流程梳理。在實際開發前，我們會深度盤點貴司的商業邏輯，將隱形的流程轉化為標準化、數位化的動線。"
        day14_p2 = "以神達電腦為例，在我們協助重構其簽核與流程後，不僅大幅降低了人工重疊輸入的比例，同仁的日常操作學習成本也降低了近 40%。我們將這些實戰經驗與步驟整理成了一份「企業內部流程數位化指南」，您可以在 https://playplus.com.tw/ 參考。"

    day14_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{day14_p1}<br>\n"
        f"<br>\n"
        f"{day14_p2}<br>\n"
        f"<br>\n"
        f"如果貴司想優化現有流程以降低隱形營運成本，這週是否有空回信聊聊？<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # ------------------ Day 30 ------------------
    day30_title = f"針對 {company_name} 的系統開發疑慮：分享我們的分階段優化方案"
    day30_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"在推動數位轉型時，許多中型企業常會擔心：「客製化系統是不是很貴？」或是「主管要花很多時間與軟體商溝通？」<br>\n"
        f"<br>\n"
        f"我們 PlayPlus 理解這些顧慮，我們采取分階段付費與模組化開發，讓您先從一條最痛的流程（如報表彙整或交接紀錄）開始優化，看到成效後再逐步擴展。此外，我們的專業專案管理機制，每週只需佔用主管 15 分鐘確認進度，絕不增加團隊額外的溝通負擔。<br>\n"
        f"<br>\n"
        f"您可以在我們的案例簡報（https://playplus.com.tw/internal-system-briefing.pdf）中參考詳細的分階段實施案例。若未來貴司有優化營運流程的規劃，隨時歡迎與我們聯繫。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # ------------------ Day 60 ------------------
    day60_title = f"最後一封追蹤信：祝 {company_name} 業務蒸蒸日上"
    day60_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣，以保持您的信箱整潔。<br>\n"
        f"<br>\n"
        f"在優雅退場前，還是想再次提醒，若貴司未來有計畫重新梳理營運流程，透過 UI/UX 與客製化前後端開發來提升工作效率，PlayPlus 隨時歡迎您隨時與我們聯繫。<br>\n"
        f"<br>\n"
        f"您依然可以透過官網（https://playplus.com.tw/）參考我們的最新案例與服務。祝貴司業務蒸蒸日上，同仁工作順利。<br>\n"
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
    print("=== 開始為中小企業_企業內部系統潛在客戶生成冷郵件 ===")

    # 1. 備份原始 CSV
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份 CSV 至：{BACKUP_PATH}")

    # 2. 讀取 CSV
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        rows = list(csv.reader(f))

    if not rows:
        print("❌ CSV 檔案內容為空")
        return

    header = [h.strip() for h in rows[0]]
    
    # 欄位定位
    col_idx = {}
    required_cols = [
        '公司名稱', '聯絡人名稱', '產業', 'Scenarios',
        'day1_title', 'day1_content',
        'day7_title', 'day7_content',
        'day14_title', 'day14_content',
        'day30_title', 'day30_content',
        'day60_title', 'day60_content'
    ]
    for col_name in required_cols:
        if col_name not in header:
            print(f"❌ CSV 標頭缺少必填欄位: {col_name}")
            return
        col_idx[col_name] = header.index(col_name)

    # 3. 讀取現有的 temporary_104.json，以便進行「累積暫存」
    existing_logs = {}
    if os.path.exists(JSON_PATH):
        try:
            with open(JSON_PATH, 'r', encoding='utf-8') as f:
                existing_logs = json.load(f)
            print(f"✅ 已載入既有暫存 {len(existing_logs)} 筆資料。")
        except Exception as e:
            print(f"⚠️ 載入暫存檔失敗或檔案為空，將重新建立。原因: {e}")

    # 4. 逐行更新（僅針對 Scenarios 為「中小企業_企業內部系統」的列）
    updated_count = 0

    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(col_idx.values()):
            continue

        scenarios = row[col_idx['Scenarios']].strip()
        # 如果不是中小企業_企業內部系統，則跳過
        if scenarios != "中小企業_企業內部系統":
            continue

        comp_name = row[col_idx['公司名稱']].strip()
        contact_name = row[col_idx['聯絡人名稱']].strip()

        emails = generate_smb_emails(contact_name, comp_name)

        # 寫入 CSV
        row[col_idx['day1_title']] = emails['day1_title']
        row[col_idx['day1_content']] = emails['day1_content']
        row[col_idx['day7_title']] = emails['day7_title']
        row[col_idx['day7_content']] = emails['day7_content']
        row[col_idx['day14_title']] = emails['day14_title']
        row[col_idx['day14_content']] = emails['day14_content']
        row[col_idx['day30_title']] = emails['day30_title']
        row[col_idx['day30_content']] = emails['day30_content']
        row[col_idx['day60_title']] = emails['day60_title']
        row[col_idx['day60_content']] = emails['day60_content']

        # 累積暫存
        existing_logs[f"{comp_name}_{contact_name}"] = emails
        updated_count += 1

    # 5. **最後執行一次**寫回 CSV
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print(f"✅ 已成功更新 {updated_count} 家中小企業的冷郵件欄位。")

    # 6. 寫回 temporary_104.json
    with open(JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(existing_logs, f, ensure_ascii=False, indent=2)
    print(f"✅ 已將累積暫存寫入至: {JSON_PATH}，目前共有 {len(existing_logs)} 筆資料。")

if __name__ == '__main__':
    main()
