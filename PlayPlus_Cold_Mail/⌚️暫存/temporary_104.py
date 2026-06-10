#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
將 名單副本.csv 中的潛在客戶資料，自動生成 Day 1、Day 7 與 Day 30 的客製化冷郵件內容，
並將 Day 14 與 Day 60 的欄位設為 "-"。
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
    根據 CSV 產業名稱歸類為 製造／科技業, 零售／家電／電子商務, 金融／保險／專業服務, 或其他
    """
    name = industry_name.strip()
    if any(k in name for k in ["製造", "科技", "工業", "機械", "半導體", "光電", "電子", "太陽能", "LED"]):
        return "manufacturing"
    elif any(k in name for k in ["零售", "家電", "電子商務", "生鮮", "百貨", "食品", "貿易", "商業"]):
        return "retail"
    elif any(k in name for k in ["金融", "保險", "服務", "銀行", "證券", "諮詢", "顧問"]):
        return "financial"
    else:
        # 預設為製造業（一般製造業）
        return "manufacturing"

def generate_emails(contact_name, industry_name):
    # 規則 1 ： 正式商務稱謂
    if contact_name == "官方" or not contact_name.strip():
        greeting = "您好，"
    else:
        greeting = f"{contact_name.strip()} 您好，"

    # 產業類型
    category = get_industry_category(industry_name)

    # 規則 2 ： Day 1 根據「公司產業」融入情境字
    if category == "manufacturing":
        day1_p1 = "在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。"
    elif category == "retail":
        day1_p1 = "在多通路零售與總部後勤管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。"
    elif category == "financial":
        day1_p1 = "在高度合規與高頻率審核的日常營運中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。"
    else:
        day1_p1 = "在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。"

    # 規則 3 ： Day 1 神達案例的「投射效應」微調
    if category == "manufacturing":
        day1_p3 = "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的供應商管理、跨部門人力調度等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。"
    else:
        day1_p3 = "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄及簽核流程重構等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。"

    day1_p2 = "我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。"
    day1_p4 = "隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。"
    day1_p5 = "只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？"
    day1_sign = "祝順利。"

    day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day1_content = f"{greeting}<br><br>{day1_p1}<br><br>{day1_p2}<br><br>{day1_p3}<br><br>{day1_p4}<br><br>{day1_p5}<br><br>{day1_sign}"

    # 規則 4 ： Day 7 與 Day 30 的 Follow-up 郵件的產業呼應
    if category == "manufacturing":
        day7_p2 = "我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，特別是針對製造業常見的「複雜的供應商對帳／跨部門單據審核」，打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。"
    elif category == "retail":
        day7_p2 = "我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，特別是針對零售業常見的「跨國據點協作／跨部門單據審核」，打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。"
    else:
         day7_p2 = "我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，特別是針對金融與專業服務常見的「跨部門單據審核／高頻率合規流程」，打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。"

    day7_p1 = "我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。"
    day7_p3 = "若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。"
    day7_sign = "祝順利。"

    day7_title = "Re: 內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day7_content = f"{greeting}<br><br>{day7_p1}<br><br>{day7_p2}<br><br>{day7_p3}<br><br>{day7_sign}"

    # Day 30
    if category == "manufacturing":
        day30_p2 = "在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型提升供應鏈數位韌性，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。"
    elif category == "retail":
        day30_p2 = "在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型提升後勤自動化，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。"
    else:
        day30_p2 = "在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型提升營運流程自動化，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。"

    day30_p1 = "打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。"
    day30_p3 = "我再次將附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。"
    day30_sign = "祝順利。"

    day30_title = "企業內部系統優化的最後一封信"
    day30_content = f"{greeting}<br><br>{day30_p1}<br><br>{day30_p2}<br><br>{day30_p3}<br><br>{day30_sign}"

    return {
        "day1_title": day1_title,
        "day1_content": day1_content,
        "day7_title": day7_title,
        "day7_content": day7_content,
        "day30_title": day30_title,
        "day30_content": day30_content
    }

def main():
    # 1. 備份原始檔案
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案: {CSV_PATH}")
        return

    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份原始 CSV 檔案至: {BACKUP_PATH}")

    # 2. 讀取 CSV
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        rows = list(csv.reader(f))

    if not rows:
        print("❌ CSV 檔案內容為空")
        return

    header = [h.strip() for h in rows[0]]
    
    # 必填欄位對應
    col_idx = {}
    for col_name in [
        '公司名稱', '聯絡人名稱', '產業',
        'day1_title', 'day1_content',
        'day7_title', 'day7_content',
        'day14_title', 'day14_content',
        'day30_title', 'day30_content',
        'day60_title', 'day60_content'
    ]:
        if col_name not in header:
            print(f"❌ CSV 標頭缺少必填欄位: {col_name}")
            return
        col_idx[col_name] = header.index(col_name)

    # 3. 逐行生成冷郵件
    updated_count = 0
    json_export_data = {}

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

        # 寫入 CSV 欄位
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

        # 用於 JSON 存檔
        json_export_data[comp_name] = {
            "contact": contact_name,
            "industry": industry_name,
            "emails": emails
        }

        updated_count += 1

    # 4. 寫回 CSV
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    print(f"✅ 已成功為 {updated_count} 家公司生成並寫入冷郵件欄位。")

    # 5. 輸出 temporary_104.json
    with open(JSON_PATH, 'w', encoding='utf-8') as f:
        json.dump(json_export_data, f, ensure_ascii=False, indent=2)
    print(f"✅ 已成功輸出詳細對照 JSON 檔至: {JSON_PATH}")

if __name__ == '__main__':
    main()
