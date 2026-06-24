#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
將中小企業_企業內部系統場景的冷郵件更新至 名單副本.csv 與 temporary_104.json。
"""

import os
import csv
import json
import shutil

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
BACKUP_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本_backup_sme_mails.csv")
TEMP_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104.json")

# 38 家不重複公司的專屬業務領域關鍵字
BUSINESS_KEYWORDS = {
    "松讚實業股份有限公司": "鋁合金及特殊合金的生產加工與 CNC 精密製造",
    "得禎興業股份有限公司": "幼兒傢俱、學校設備及安全兒童玩具的射出製造",
    "新加坡商傑樂生技股份有限公司台灣分公司": "明膠與膠原蛋白生技研發生產",
    "兆捷科技國際股份有限公司": "半導體電子化學特殊氣體的製造與儲運",
    "重宙企業股份有限公司": "粉體塗裝、OA 辦公傢俱設計與五金鋼管製造",
    "百城機械企業股份有限公司": "自動食品包餡成型機研發製造",
    "台灣科尼起重機設備有限公司": "大型起重機設備銷售、保養與客製化服務",
    "捷惠自動機械股份有限公司": "印刷電路板（PCB）製程設備與自動化手臂整合",
    "鍱德股份有限公司": "光學級塑料加工與工程塑膠複合材料研發",
    "產機送料機股份有限公司": "馬達煞車器及振動送料機等自動化設備製造",
    "高緯科技股份有限公司": "精密玻璃加工、玻璃強化與玻璃切割技術",
    "陸合企業股份有限公司": "3C 機構件、半導體零組件與筆記型電腦散熱片精密製造",
    "立橋自動化有限公司": "LCD 面板及半導體自動化設備規劃與設計",
    "銓麥企業股份有限公司": "中央烘焙工廠規劃與烘焙機械設備製造",
    "嘉碁科技股份有限公司": "電磁波防護材料（EMI）及工業用膠膜等積層材料研發",
    "更新實業股份有限公司": "廢棄物資源化、再生材料（CLSM）製造",
    "德聿佳工業股份有限公司": "車用電子零配件、車用門鎖與鏡頭製造",
    "沂春企業股份有限公司": "精密表面處理（硬鉻、化學鎳）與藝術建材開發",
    "伸長彩色印刷股份有限公司": "彩色包裝紙盒與說明書製造",
    "玉豐海洋科儀股份有限公司": "水下無人載具（ROV）與水下科技配件供應",
    "丞曜通達國際實業股份有限公司": "五金扣件與五金螺絲外銷製造",
    "宏森鋼品有限公司": "彩鋼金屬帷幕牆規劃設計與施工",
    "利達製藥股份有限公司": "西藥製劑與保健食品研發製造",
    "駿維實業股份有限公司": "防卡專利輸送滾輪與物料輸送系統製造",
    "華淨醫材股份有限公司": "醫療規格口罩與醫材研發製造",
    "松勁科技股份有限公司": "半導體石英與陶瓷等耗材精密加工",
    "宗聯機器股份有限公司": "精密機械哥林柱與機械零件加工製造",
    "長耕國際股份有限公司": "金屬建材與帷幕牆氟碳烤漆加工",
    "天賜爾生物科技股份有限公司": "益生菌發酵技術與女性私密防護保健品研發",
    "鴻佑機械鈑金有限公司": "精密機械鈑金、控制箱及配電盤製造",
    "慶同貿易股份有限公司": "富士電機高低壓配電與自動控制元件代理",
    "感官文化印刷有限公司": "設計打樣、印刷、裝訂及特殊後加工服務",
    "尚永眼鏡股份有限公司": "運動防護眼鏡與滑雪護目鏡設計製造",
    "台旺企業有限公司": "鋅合金壓鑄、汽車與機車零配件加工",
    "信元製藥股份有限公司": "動物用藥與寵物營養保健品研發製造",
    "聯宬企業股份有限公司": "紙容器與全分解綠色環保餐盒製造",
    "沛美生醫科技股份有限公司": "化妝品與美容保養品客製化代工研發",
    "詳暉工業股份有限公司": "汽油泵、化油器及機車零配件研發製造"
}

# 食品、生技、製藥相關公司，將使用「食安智幫手APP」案例作為 Social Proof
FOOD_BIOTECH_COMPANIES = {
    "新加坡商傑樂生技股份有限公司台灣分公司",
    "百城機械企業股份有限公司",
    "利達製藥股份有限公司",
    "天賜爾生物科技股份有限公司",
    "信元製藥股份有限公司",
    "聯宬企業股份有限公司"
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

def generate_mail_for_company(comp_name):
    """根據公司類型與業務領域關鍵字生成客製化郵件"""
    keyword = BUSINESS_KEYWORDS.get(comp_name, "精密製造與加工")
    
    # 決定 Social Proof 作品案例
    if comp_name in FOOD_BIOTECH_COMPANIES:
        portfolio_name = "食安智幫手APP"
        portfolio_url = "https://playplus.com.tw/portfolio/tfif-app"
        portfolio_desc = "協助將現場食安管控與檢驗流程行動化與標準化"
    else:
        portfolio_name = "神達會議室預約系統"
        portfolio_url = "https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system"
        portfolio_desc = "解決跨部門資源預約的混亂問題，將繁雜的預約與簽核流程標準化"

    # Day 1: Outreach
    day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達的數位轉型案例"
    day1_content = f"您好，<br>\n<br>\n在貴司專注的{keyword}領域中，同仁是否也常面臨內部流程繁瑣、資料分散在 Excel 甚至只存在個別資深同仁腦中的情況，導致交接與管理面臨挑戰？<br>\n<br>\n我們是 PlayPlus，專注於協助中型企業打造「客製化企業內部系統」。我們不推銷動輒數百萬的大型系統，而是從你們最痛的一條流程開始，打造好紀錄、好追蹤、好交接的專屬系統。例如我們曾協助神達電腦開發會議室預約系統（https://playplus.com.tw/portfolio/mitac-meeting-room-booking-system），解決跨部門資源預約的混亂問題。<br>\n<br>\n是否方便寄一份我們過去在相關產業的流程數位化案例給您參考？您可以從這邊參考我們的服務及作品集：https://playplus.com.tw/<br>\n<br>\n感謝您"

    # Day 7: The Gentle Nudge
    day7_title = "Re: 內部系統與營運流程需要重新梳理嗎？分享神達的數位轉型案例"
    day7_content = "您好，<br>\n<br>\n上週曾寄信向您致意。理解您平時公務繁忙，這封信只是簡單追蹤，希望沒有打擾到您。<br>\n<br>\n如果貴司近期正遇到內部管理流程混亂、或是 Excel 報表彙整非常耗時的問題，我們可以用 10 分鐘的時間線上交流，聊聊如何最安全且快速地將流程標準化。<br>\n<br>\n感謝您"

    # Day 14: Social Proof
    day14_title = "如何為企業同仁降低新系統的學習與排斥成本？"
    day14_content = f"您好，<br>\n<br>\n許多企業在評估內部系統數位化時，常擔心同仁排斥新系統或學習成本過高。其實，關鍵在於開發前的流程盤點與融入工作習慣的 UI/UX 設計。<br>\n<br>\n以我們開發的「{portfolio_name}」（{portfolio_url}）為例，我們針對真實的工作習慣進行動線重構，{portfolio_desc}，實質降低學習負擔並提升日常管理效率。<br>\n<br>\n我們整理了一份關於企業流程數位化的案例分析，是否方便寄給您參考？<br>\n<br>\n感謝您"

    # Day 30: Handling Objections
    day30_title = "客製化企業內部系統開發的成本與時程考量"
    day30_content = "您好，<br>\n<br>\n在與許多企業主交流時，我們發現大家最在意的通常是「客製化系統會不會很貴？」以及「開發會不會佔用團隊太多時間？」。<br>\n<br>\n為了降低風險，我們提供「模組化開發」與「分階段優化方案」，讓您能先針對最痛的單一流程進行開發，確認效果後再逐步擴充，大幅降低預算壓力；同時，我們有專屬的專案顧問跟進，主管每週只需花費 15 分鐘確認進度即可。<br>\n<br>\n若您有興趣了解這樣的分階段合作模式，我們可以用 10 分鐘的時間線上交流，看看能如何協助貴司。<br>\n<br>\n感謝您"

    # Day 60: The Break-up
    day60_title = "企業內部系統優化的最後一封信"
    day60_content = "您好，<br>\n<br>\n打擾了，這是最後一封追蹤信，後續我不會再發信打擾您的收件匣。<br>\n<br>\n在優雅退場前，還是想再次提醒，若貴司未來有計畫透過數位轉型重新盤點並梳理營運流程，我們 PlayPlus 能提供專業服務，為您進行內部的長期系統規劃。<br>\n<br>\n您隨時可以透過 https://playplus.com.tw/ 找到我們。若未來有需要，歡迎隨時聯繫。<br>\n<br>\n感謝您"

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

    header = rows[0]
    try:
        name_idx = header.index("公司名稱")
        scenario_idx = header.index("Scenarios")
        
        # 定義全部郵件欄位名稱
        mail_keys = [
            "day1_title", "day1_content", "day7_title", "day7_content",
            "day14_title", "day14_content", "day30_title", "day30_content",
            "day60_title", "day60_content"
        ]
        
        col_indices = {k: header.index(k) for k in mail_keys}
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
        
        # 僅針對 K 欄 Scenarios 為「中小企業_企業內部系統」的資料列進行處理
        if scenario == "中小企業_企業內部系統":
            # 確保資料列的欄位長度足夠
            while len(row) < len(header):
                row.append("")
                
            # 生成客製化郵件
            mails = generate_mail_for_company(comp_name)
            
            # 填入郵件標題與內文至 CSV 欄位
            for key, col_idx in col_indices.items():
                row[col_idx] = mails[key]
            
            # 更新/補充暫存檔 JSON 中的對應項目
            if comp_name:
                updated_companies.add(comp_name)
                # 若暫存中已有此公司，則補充郵件資料
                if comp_name in cache_data:
                    for key, val in mails.items():
                        cache_data[comp_name][key] = val
                else:
                    # 若暫存中尚無此公司，則新增項目
                    cache_data[comp_name] = {
                        "company_name": comp_name,
                        "original_description": "",
                        "summary": ""
                    }
                    for key, val in mails.items():
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
