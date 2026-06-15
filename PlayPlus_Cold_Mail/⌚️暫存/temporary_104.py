#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自動為 名單副本.csv 中的大企業客戶生成 Day 1、Day 7 與 Day 30 的客製化冷郵件，
並將 Day 14 與 Day 60 的欄位設為 "-"。
符合大企業 (企業內部系統) 規則，包含 HTML 換行與真實換行格式。
"""

import csv
import json
import os
import shutil

CSV_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本.csv"
BACKUP_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/冷郵件對象/名單副本_backup.csv"
JSON_PATH = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⌚️暫存/temporary_104.json"

def get_industry_category(industry_name):
    """
    根據產業名稱將其分類，並回傳情境文字、神達投射重點、Day 7跟Day 30對應的文字。
    """
    name = industry_name.strip()
    
    # 預設為製造／科技業 (因為目前CSV中均為一般製造業)
    if any(k in name for k in ["零售", "家電", "電子商務", "生鮮", "百貨", "食品", "貿易", "商業"]):
        # 零售／家電／電子商務
        return {
            "p1": "在多通路零售與總部後勤管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "p3_mitac": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄及簽核流程重構等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "特別是針對零售業常見的「跨國據點協作／跨部門單據審核」，",
            "day30_target": "提升後勤自動化"
        }
    elif any(k in name for k in ["金融", "保險", "服務", "銀行", "證券", "諮詢", "顧問"]):
        # 金融／保險／專業服務
        return {
            "p1": "在高度合規與高頻率審核的日常營運中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "p3_mitac": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄及簽核流程重構等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "特別是針對金融與專業服務常見的「跨部門單據審核／高頻率合規流程」，",
            "day30_target": "提升營運流程自動化"
        }
    else:
        # 製造／科技業 (及其他未明確歸類產業之預設值)
        return {
            "p1": "在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "p3_mitac": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的供應商管理、跨部門人力調度等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "特別是針對製造業常見的「複雜的供應商對帳／跨部門單據審核」，",
            "day30_target": "提升供應鏈數位韌性"
        }

def generate_emails(contact_name, industry_name):
    # 規則 1 ： 正式商務稱謂
    contact = contact_name.strip()
    if contact == "官方" or not contact:
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    # 取得產業客製化欄位
    ind_data = get_industry_category(industry_name)
    p1 = ind_data["p1"]
    p3 = ind_data["p3_mitac"]
    day7_p2_detail = ind_data["day7_detail"]
    day30_target = ind_data["day30_target"]

    # ------------------ Day 1 ------------------
    day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    
    day1_p2 = "我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。"
    day1_p4 = "隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。"
    day1_p5 = "只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？"
    
    # 雙重換行格式 (HTML <br> + 實際 \n 換行)
    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{p1}<br>\n"
        f"<br>\n"
        f"{day1_p2}<br>\n"
        f"<br>\n"
        f"{p3}<br>\n"
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
    day7_p2 = f"我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，{day7_p2_detail}打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。"
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
    day30_p2 = f"在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型{day30_target}，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。"
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
    # 1. 備份
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份 CSV 至：{BACKUP_PATH}")

    # 2. 讀取
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        rows = list(csv.reader(f))

    if not rows:
        print("❌ CSV 檔案內容為空")
        return

    header = [h.strip() for h in rows[0]]
    
    # 欄位定位
    col_idx = {}
    required_cols = [
        '公司名稱', '聯絡人名稱', '產業',
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

    # 3. 逐行更新
    updated_count = 0
    export_logs = {}

    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(col_idx.values()):
            continue

        comp_name = row[col_idx['公司名稱']].strip()
        if not comp_name:
            continue

        contact_name = row[col_idx['聯絡人名稱']].strip()
        industry_name = row[col_idx['產業']].strip()

        emails = generate_emails(contact_name, industry_name)

        # 寫入 CSV
        row[col_idx['day1_title']] = emails['day1_title']
        row[col_idx['day1_content']] = emails['day1_content']
        row[col_idx['day7_title']] = emails['day7_title']
        row[col_idx['day7_content']] = emails['day7_content']
        row[col_idx['day30_title']] = emails['day30_title']
        row[col_idx['day30_content']] = emails['day30_content']

        # Day 14 and Day 60 set to "-"
        row[col_idx['day14_title']] = "-"
        row[col_idx['day14_content']] = "-"
        row[col_idx['day60_title']] = "-"
        row[col_idx['day60_content']] = "-"

        export_logs[f"{comp_name}_{contact_name}"] = emails
        updated_count += 1

    # 4. 寫回 CSV
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print(f"✅ 已成功更新 {updated_count} 家公司的冷郵件欄位。")

    # 5. 輸出暫存對照
    with open(JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(export_logs, f, ensure_ascii=False, indent=2)
    print(f"✅ 已輸出詳細對照 JSON 檔至: {JSON_PATH}")

if __name__ == '__main__':
    main()
