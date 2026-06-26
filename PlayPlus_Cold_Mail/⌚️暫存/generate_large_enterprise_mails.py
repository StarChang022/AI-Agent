#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自動為 名單副本.csv 中的大企業客戶（Scenarios 為「大企業_企業內部系統」）生成 Day 1、Day 7 與 Day 30 的客製化冷郵件，
並將 Day 14 與 Day 60 的欄位設為 "-"。同時同步更新與合併至 temporary_104.json。
"""

import os
import csv
import json
import shutil

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
BACKUP_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本_backup_mails.csv")
TEMP_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104.json")

def get_category_data(comp_name):
    """
    根據公司名稱分析其行業特性，返回客製化的郵件內容片段。
    """
    clean_name = "".join(comp_name.split())
    
    # 1. 生技醫療與高度合規管理
    if any(k in clean_name for k in ["普生", "大豐膠囊", "天一藥廠", "雙鶴"]):
        return {
            "p1": "在生技醫療與高度合規的製程管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "p3_mitac": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，特別是針對其一站式入口、工時登錄及簽核流程重構等核心流程，大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "品質稽核文件登錄／跨部門單據審核",
            "day30_target": "提升營運流程自動化與合規管理"
        }
    
    # 2. 設備工程服務 (Otis 電梯安裝維修)
    elif "奧的斯" in clean_name:
        return {
            "p1": "在設備工程與售後維修管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "p3_mitac": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，特別是針對其跨部門人力調度與派工管理等核心流程，大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "現場派工調度／跨部門單據審核",
            "day30_target": "提升售後服務與後勤管理自動化"
        }
        
    # 3. 零售、食品、家電、電商
    elif any(k in clean_name for k in ["富佰客", "鴻茂", "瓜瓜園", "如記食品"]):
        return {
            "p1": "在多通路零售與總部後勤管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "p3_mitac": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，特別是針對其一站式入口、工時登錄及簽核流程重構等核心流程，大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "跨國據點協作／跨部門單據審核",
            "day30_target": "提升後勤自動化"
        }
        
    # 4. 預設：精密製造與科技
    else:
        return {
            "p1": "在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "p3_mitac": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，特別是針對其供應商管理與跨部門人力調度等核心流程，大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "複雜的供應商對帳／跨部門單據審核",
            "day30_target": "提升供應鏈數位韌性"
        }

def generate_emails(contact_name, comp_name):
    # 招呼語
    contact = contact_name.strip()
    if contact in ["官方", "", "無"] or contact.endswith("窗口") or "聯絡人" in contact:
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    # 取得行業客製化內容
    cat_data = get_category_data(comp_name)
    p1 = cat_data["p1"]
    p3 = cat_data["p3_mitac"]
    day7_p2_detail = cat_data["day7_detail"]
    day30_target = cat_data["day30_target"]

    # Day 1
    day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"{p1}<br>\n"
        f"<br>\n"
        f"我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。<br>\n"
        f"<br>\n"
        f"{p3}<br>\n"
        f"<br>\n"
        f"隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。<br>\n"
        f"<br>\n"
        f"只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    # Day 7
    day7_title = "Re: 內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day7_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。<br>\n"
        f"<br>\n"
        f"我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，特別是針對貴產業常見的「{day7_p2_detail}」，打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。<br>\n"
        f"<br>\n"
        f"若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    # Day 30
    day30_title = "企業內部系統優化的最後一封信"
    day30_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br>\n"
        f"<br>\n"
        f"在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型{day30_target}，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。<br>\n"
        f"<br>\n"
        f"我再次將附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。<br>\n"
        f"<br>\n"
        f"祝順利。"
    )

    return {
        "day1_title": day1_title,
        "day1_content": day1_content,
        "day7_title": day7_title,
        "day7_content": day7_content,
        "day14_title": "-",
        "day14_content": "-",
        "day30_title": day30_title,
        "day30_content": day30_content,
        "day60_title": "-",
        "day60_content": "-"
    }

def main():
    print("=== 開始更新大企業冷郵件及暫存 ===")

    # 1. 備份原始 CSV
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份 CSV 至：{BACKUP_PATH}")

    # 2. 載入 CSV
    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV 檔案內容為空")
        return

    header = [h.strip() for h in rows[0]]
    try:
        name_idx = header.index("公司名稱")
        contact_idx = header.index("聯絡人名稱")
        scenario_idx = header.index("Scenarios")
        
        # 取得所有郵件欄位的索引
        mail_fields = [
            "day1_title", "day1_content",
            "day7_title", "day7_content",
            "day14_title", "day14_content",
            "day30_title", "day30_content",
            "day60_title", "day60_content"
        ]
        col_indices = {field: header.index(field) for field in mail_fields}
    except ValueError as e:
        print(f"❌ CSV 標頭缺少必要欄位：{e}")
        return

    # 3. 載入既有暫存 JSON
    cache_data = {}
    if os.path.exists(TEMP_JSON_PATH):
        try:
            with open(TEMP_JSON_PATH, "r", encoding="utf-8") as f:
                cache_data = json.load(f)
            print(f"✅ 已載入既有暫存 JSON 檔，共 {len(cache_data)} 筆公司資料。")
        except Exception as e:
            print(f"⚠️ 載入暫存檔失敗: {e}，將建立新的暫存。")

    # 4. 更新 CSV 與暫存記憶體
    updated_rows_count = 0
    updated_companies = set()

    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= scenario_idx:
            continue

        scenario = row[scenario_idx].strip()
        comp_name = row[name_idx].strip()
        contact_name = row[contact_idx].strip()

        # 僅針對 K 欄 Scenarios 為「大企業_企業內部系統」的資料列進行處理
        if scenario == "大企業_企業內部系統":
            # 確保資料列的欄位長度足夠
            while len(row) < len(header):
                row.append("")

            # 生成客製化郵件
            emails = generate_emails(contact_name, comp_name)

            # 填入郵件標題與內文至 CSV 欄位
            for key, c_idx in col_indices.items():
                row[c_idx] = emails[key]

            # 更新/補充暫存檔 JSON 中的對應項目
            if comp_name:
                updated_companies.add(comp_name)
                if comp_name not in cache_data:
                    cache_data[comp_name] = {
                        "company_name": comp_name,
                        "original_description": "",
                        "summary": ""
                    }
                
                # 寫入冷郵件欄位到 JSON 暫存中
                for key, val in emails.items():
                    cache_data[comp_name][key] = val

            updated_rows_count += 1

    # 5. 一次性寫回 CSV
    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(rows)
    print(f"✅ 已完成寫回 CSV 檔案！共更新 {updated_rows_count} 行大企業郵件資料。")

    # 6. 寫回暫存 JSON
    with open(TEMP_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(cache_data, f, ensure_ascii=False, indent=2)
    print(f"✅ 暫存對照表已完成更新！目前總筆數：{len(cache_data)}。")

if __name__ == "__main__":
    main()
