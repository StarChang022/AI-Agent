#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
將大企業_企業內部系統場景的冷郵件更新至 名單副本.csv 與 temporary_104.json。
"""

import os
import csv
import json
import shutil

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
BACKUP_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本_backup_mails.csv")
TEMP_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104.json")

# 定義大企業製造業的冷郵件標題與內文模板
MAIL_TEMPLATES = {
    "day1_title": "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例",
    "day1_content": "您好，<br>\n<br>\n在精密製造與供應鏈管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。<br>\n<br>\n我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。<br>\n<br>\n作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄、跨部門人力調度及供應商管理等核心營運系統，專注於流程梳理與動線重構，特別是針對其供應商管理與跨部門人力調度等核心流程，大幅降低人工比例，實質為他們提升集團綜效。<br>\n<br>\n隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。<br>\n<br>\n只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？<br>\n<br>\n祝順利。",
    
    "day7_title": "Re: 內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例",
    "day7_content": "您好，<br>\n<br>\n我是 PlayPlus 的阿星，上週曾寄信向您致意。理解您平時公務繁忙，特地寫這封信簡單追蹤，希望沒有打擾到您。<br>\n<br>\n我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，特別是針對貴產業常見的「跨國據點協作／複雜的供應商對帳／跨部門單據審核」，打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。<br>\n<br>\n若貴司近期正計畫重構舊系統或調整內部流程，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br>\n<br>\n祝順利。",
    
    "day14_title": "-",
    "day14_content": "-",
    
    "day30_title": "企業內部系統優化的最後一封信",
    "day30_content": "您好，<br>\n<br>\n打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br>\n<br>\n在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型提升供應鏈數位韌性，我們 PlayPlus 能提供專業服務，為您盤點並梳理現在的營運流程，透過 UI/UX 與前後端開發服務，進行企業內部系統的長期規劃。<br>\n<br>\n我再次將附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。若未來貴司有優化營運流程的需求，隨時歡迎您與我們取得聯繫。<br>\n<br>\n祝順利。",
    
    "day60_title": "-",
    "day60_content": "-"
}

def load_existing_cache():
    """載入既有的暫存檔，若不存在則返回空字典"""
    merged_data = {}
    if os.path.exists(TEMP_JSON_PATH):
        try:
            with open(TEMP_JSON_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                for name, item in data.items():
                    merged_data[name.strip()] = item
            print(f"✅ 已載入既有暫存，共 {len(merged_data)} 筆公司資料。")
        except Exception as e:
            print(f"⚠️ 載入暫存檔失敗: {e}，將建立新的暫存。")
    return merged_data

def save_cache(cache_data):
    """保存暫存資料"""
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    with open(TEMP_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(cache_data, f, ensure_ascii=False, indent=2)

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

    header = rows[0]
    try:
        name_idx = header.index("公司名稱")
        scenario_idx = header.index("Scenarios")
        
        # 尋找所有待填入的郵件欄位索引
        col_indices = {
            k: header.index(k) for k in MAIL_TEMPLATES.keys()
        }
    except ValueError as e:
        print(f"❌ CSV 標頭缺少必要欄位：{e}")
        return

    # 3. 載入既有暫存 JSON
    cache_data = load_existing_cache()
    
    # 4. 更新 CSV 與暫存記憶體
    updated_rows_count = 0
    updated_companies = set()
    
    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(col_indices.values()) or len(row) <= scenario_idx:
            continue
        
        scenario = row[scenario_idx].strip()
        comp_name = row[name_idx].strip()
        
        # 僅針對 K 欄 Scenarios 為「大企業_企業內部系統」的資料列進行處理
        if scenario == "大企業_企業內部系統":
            # 確保資料列的欄位長度足夠
            while len(row) < len(header):
                row.append("")
                
            # 填入郵件標題與內文至 CSV 欄位
            for key, col_idx in col_indices.items():
                row[col_idx] = MAIL_TEMPLATES[key]
            
            # 更新/補充暫存檔 JSON 中的對應項目
            if comp_name:
                updated_companies.add(comp_name)
                # 若暫存中已有此公司，則補充郵件資料
                if comp_name in cache_data:
                    for key, val in MAIL_TEMPLATES.items():
                        cache_data[comp_name][key] = val
                else:
                    # 若暫存中尚無此公司，則新增項目
                    cache_data[comp_name] = {
                        "company_name": comp_name,
                        "original_description": "",
                        "summary": ""
                    }
                    for key, val in MAIL_TEMPLATES.items():
                        cache_data[comp_name][key] = val
            
            updated_rows_count += 1

    # 5. 一次性寫回 CSV
    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    # 寫回暫存 JSON
    save_cache(cache_data)

    print(f"=== 任務完成 ===")
    print(f"✅ CSV 更新總列數: {updated_rows_count}")
    print(f"✅ 暫存檔已更新公司數: {len(updated_companies)}")
    print(f"✅ 暫存檔已儲存於：{TEMP_JSON_PATH}")

if __name__ == "__main__":
    main()
