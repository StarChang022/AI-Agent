#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自動為 名單副本.csv 中的中小企業客戶（Scenarios 為「中小企業_企業內部系統」）生成 Day 1、Day 7 與 Day 30 的客製化冷郵件，
並將 Day 14 與 Day 60 的欄位設為 "-"。同時同步更新與合併至 temporary_104.json。
"""

import os
import csv
import json
import shutil

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
BACKUP_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本_backup_mails_sme.csv")
TEMP_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104.json")

def get_category_data(comp_name):
    """
    根據公司名稱分析其行業特性，返回客製化的中小企業郵件內容片段。
    """
    clean_name = "".join(comp_name.split())
    
    if any(k in clean_name for k in ["生技", "醫", "藥", "健康", "診所", "保健", "長照"]):
        return {
            "pain_point": "許多醫療與生技團隊在快速擴張時，常面臨表單管理混亂、資料分散的問題，且為了符合合規性，每個月總要花費大量人工彙整報表，既耗時又容易出錯。",
            "portfolio_text": "例如我們曾協助「台灣腎臟醫學會」開發 TSN 病理系統（https://playplus.com.tw/portfolio/tsn），解決龐雜病理資料的跨系統彙整問題，大幅降低人工登打錯誤率。",
            "day7_detail": "減少人工紙本抄寫與合規資料彙整的痛點",
            "day30_target": "將複雜的醫療與行政流程真正數位化"
        }
    elif any(k in clean_name for k in ["建設", "營造", "工程", "不動產", "物業", "房屋"]):
        return {
            "pain_point": "許多工程與物業團隊在快速擴張時，常面臨「流程隱形」的危機，前線巡檢或派工仍依賴紙本或 Excel，總部難以即時追蹤進度與彙整資訊。",
            "portfolio_text": "例如我們曾協助「大管家房屋管理」開發包租代管系統（https://playplus.com.tw/portfolio/chrb），將原本分散在各個業務與門市的房東/房客管理流程全面數位化，解決交接斷層危機。",
            "day7_detail": "改善前線表單填寫與總部追蹤不同步的問題",
            "day30_target": "將跨據點的營運管理真正數位化"
        }
    elif any(k in clean_name for k in ["食品", "餐飲", "零售", "商行", "百貨", "貿易"]):
        return {
            "pain_point": "許多零售與食品團隊在快速擴張時，常面臨表單管理混亂的問題，門市與總部之間仍依賴紙本或通訊軟體回報，每個月都要花費大量時間手動彙整，難以支援快速決策。",
            "portfolio_text": "例如我們曾開發「食安智幫手APP」（https://playplus.com.tw/portfolio/tfif-app），協助將複雜的現場稽核與食品安全回報流程直接行動化，解決總部與前線的溝通落差。",
            "day7_detail": "降低門市與總部之間的人工彙整成本",
            "day30_target": "將總部後勤管理真正數位化"
        }
    else:
        return {
            "pain_point": "許多企業在快速擴張的階段，常會遇到內部管理與流程跟不上的問題，關鍵流程往往只存在資深員工腦中，新人交接困難，且跨部門表單多半靠 Excel 人工彙整。",
            "portfolio_text": "例如我們曾協助「神達電腦」開發會議室預約系統（https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system），從他們最痛的跨部門資源預約流程開始梳理，打造好紀錄、好追蹤、好交接的專屬系統。",
            "day7_detail": "降低員工對僵化系統的排斥感，打造符合操作習慣的直觀介面",
            "day30_target": "將繁瑣的跨部門營運流程真正數位化"
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
    pain_point = cat_data["pain_point"]
    portfolio_text = cat_data["portfolio_text"]
    day7_detail = cat_data["day7_detail"]
    day30_target = cat_data["day30_target"]

    # Day 1
    day1_title = f"關於{comp_name}的內部系統與流程升級"
    day1_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我剛瀏覽了貴公司的網站，注意到你們近期業務與團隊規模成長非常快速。<br>\n"
        f"<br>\n"
        f"不過我們也發現，{pain_point}<br>\n"
        f"<br>\n"
        f"我們是 PlayPlus，專注於協助中型企業打造客製化的企業內部系統。有別於動輒數百萬的大型僵化系統，我們從你們最痛的一條流程開始，重新梳理並開發專屬系統。{portfolio_text}<br>\n"
        f"<br>\n"
        f"是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # Day 7
    day7_title = f"Re: 關於{comp_name}的內部系統與流程升級"
    day7_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"我是 PlayPlus 的阿星，上週曾寄信向您簡單分享流程數位化的經驗。我知道您業務繁忙，若無法回覆我完全能理解。<br>\n"
        f"<br>\n"
        f"在實際開發系統前，我們非常重視「流程梳理」。我們會深度盤點並標準化作業動線，特別是協助企業{day7_detail}。<br>\n"
        f"<br>\n"
        f"若貴司近期正計畫重構現有系統，歡迎隨時回信。我們可以用 10 分鐘的時間線上交流，看看能如何協助。<br>\n"
        f"<br>\n"
        f"感謝您"
    )

    # Day 30
    day30_title = "企業內部系統優化的最後一封信"
    day30_content = (
        f"{greeting}<br>\n"
        f"<br>\n"
        f"這是我近期針對內部系統優化的最後一封追蹤信。<br>\n"
        f"<br>\n"
        f"若貴司一直有優化系統的需求，但擔心客製化開發預算過高或太花時間，我們也提供「模組化開發」與「分階段優化方案」以符合預算彈性，主管每週只需 15 分鐘確認進度，大幅降低溝通成本。<br>\n"
        f"<br>\n"
        f"在優雅退場前，還是想再次提醒，若貴司未來有計畫透過系統升級{day30_target}，隨時歡迎您與我們取得聯繫（https://playplus.com.tw/）。<br>\n"
        f"<br>\n"
        f"感謝您"
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
    print("=== 開始更新中小企業冷郵件及暫存 ===")

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

        # 僅針對 K 欄 Scenarios 為「中小企業_企業內部系統」的資料列進行處理
        if scenario == "中小企業_企業內部系統":
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
    print(f"✅ 已完成寫回 CSV 檔案！共更新 {updated_rows_count} 行中小企業郵件資料。")

    # 6. 寫回暫存 JSON
    with open(TEMP_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(cache_data, f, ensure_ascii=False, indent=2)
    print(f"✅ 暫存對照表已完成更新！目前總筆數：{len(cache_data)}。")

if __name__ == "__main__":
    main()
