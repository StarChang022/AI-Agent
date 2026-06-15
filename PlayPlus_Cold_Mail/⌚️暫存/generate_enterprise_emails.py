#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
為「大企業_企業內部系統」的客戶生成 Day 1、Day 7 與 Day 30 的客製化冷郵件，
並將 Day 14 與 Day 60 的欄位設為 "-"。符合大企業規則，包含 HTML 換行與真實換行格式。
"""

import os
import csv
import json
import shutil

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
BACKUP_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本_backup_emails.csv')
TEMP_JSON_PATH = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')

def get_industry_customization(industry_name):
    """
    根據產業名稱做分類，並回傳對應的客製化語句。
    """
    name = industry_name.strip()
    
    # 零售／家電／電子商務
    if any(k in name for k in ["零售", "家電", "電子商務", "生鮮", "百貨", "食品", "貿易", "商業"]):
        return {
            "day1_p1": "在多通路零售與總部後勤管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "day1_p3": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄及簽核流程重構等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "特別是針對零售業常見的「跨國據點協作／跨部門單據審核」，",
            "day30_target": "提升後勤自動化"
        }
    # 金融／保險／專業服務
    elif any(k in name for k in ["金融", "保險", "服務", "銀行", "證券", "諮詢", "顧問"]):
        return {
            "day1_p1": "在高度合規與高頻率審核的日常營運中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "day1_p3": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄及簽核流程重構等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "特別是針對金融與專業服務常見的「跨部門單據審核／高頻率合規流程」，",
            "day30_target": "提升營運流程自動化"
        }
    # 製造／科技業（預設值，如「一般製造業」）
    else:
        return {
            "day1_p1": "在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "day1_p3": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的供應商管理、跨部門人力調度等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "特別是針對製造業常見的「複雜的供應商對帳／跨部門單據審核」，",
            "day30_target": "提升供應鏈數位韌性"
        }

def generate_emails(contact_name, industry_name):
    contact = contact_name.strip()
    if contact == "官方" or not contact:
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    custom = get_industry_customization(industry_name)
    
    # ------------------ Day 1 ------------------
    day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day1_p2 = "我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。"
    day1_p4 = "隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。"
    day1_p5 = "只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？"
    
    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{custom['day1_p1']}<br>\n"
        f"<br>\n"
        f"{day1_p2}<br>\n"
        f"<br>\n"
        f"{custom['day1_p3']}<br>\n"
        f"<br>\n"
        f"{day1_p4}<br>\n"
        f"<br>\n"
        f"{day1_p5}<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    # ------------------ Day 7 ------------------
    day7_title = "Re: 內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day7_p1 = "我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。"
    day7_p2 = f"我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，{custom['day7_detail']}打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。"
    day7_p3 = "若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。"
    
    day7_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{day7_p1}<br>\n"
        f"<br>\n"
        f"{day7_p2}<br>\n"
        f"<br>\n"
        f"{day7_p3}<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    # ------------------ Day 30 ------------------
    day30_title = "企業內部系統優化的最後一封信"
    day30_p1 = "打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。"
    day30_p2 = f"在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型{custom['day30_target']}，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。"
    day30_p3 = "我再次將附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。"
    
    day30_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{day30_p1}<br>\n"
        f"<br>\n"
        f"{day30_p2}<br>\n"
        f"<br>\n"
        f"{day30_p3}<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    return {
        "day1_title": day1_title,
        "day1_content": day1_content,
        "day7_title": day7_title,
        "day7_content": day7_content,
        "day30_title": day30_title,
        "day30_content": day30_content
    }

def main():
    print("=== 開始生成大企業客製化冷郵件 ===")

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
        industry_idx = header.index("產業")
        
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
        industry_name = row[industry_idx].strip()

        # 僅當 Scenarios 為「大企業_企業內部系統」時處理
        if sc == "大企業_企業內部系統":
            emails = generate_emails(contact_name, industry_name)

            row[day1_title_idx] = emails["day1_title"]
            row[day1_content_idx] = emails["day1_content"]
            row[day7_title_idx] = emails["day7_title"]
            row[day7_content_idx] = emails["day7_content"]
            row[day30_title_idx] = emails["day30_title"]
            row[day30_content_idx] = emails["day30_content"]

            # Day 14 & Day 60 設為 "-"
            row[day14_title_idx] = "-"
            row[day14_content_idx] = "-"
            row[day60_title_idx] = "-"
            row[day60_content_idx] = "-"

            updated_count += 1
            temp_logs[f"{i}_{comp_name}_{contact_name}"] = emails
        else:
            skipped_count += 1

    # 4. 一次性覆寫寫回 CSV
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print(f"✅ CSV 更新成功。生成大企業郵件筆數: {updated_count}, 跳過非大企業筆數: {skipped_count}")

    # 5. 寫入暫存 JSON 檔
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    with open(TEMP_JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(temp_logs, f, ensure_ascii=False, indent=2)
    print(f"✅ 詳細暫存紀錄已寫入：{TEMP_JSON_PATH}")

if __name__ == "__main__":
    main()
