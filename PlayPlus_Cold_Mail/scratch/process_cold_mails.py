#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自動為 名單副本.csv：
1. 重新撰寫公司說明（I 欄）為 200 字以內的一句話公司簡介（使用 Gemini API）。
2. 為 Scenarios 欄位為「大企業_企業內部系統」的行撰寫 Day 1 / Day 7 / Day 30 的客製化冷郵件，並將 Day 14 / Day 60 的欄位設為 "-"。

暫存資料均儲存於 ⌚️暫存/temporary_104.json，並在所有處理完畢後一次性覆寫回 CSV。
"""

import os
import csv
import json
import time
import sys

# ================= 參數設定 =================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
TEMP_JSON_PATH = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')

# ================= 環境變數載入 =================
def load_env():
    """手動解析 .env 檔案並載入環境變數"""
    env_paths = [
        os.path.join(BASE_DIR, '.env'),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'),
        '/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/Trading/⚙️參數設定/business-report.env'
    ]
    for path in env_paths:
        if os.path.exists(path):
            print(f"[環境變數] 偵測到環境檔案: {path}")
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#'):
                            parts = line.split('=', 1)
                            if len(parts) == 2:
                                key = parts[0].strip()
                                val = parts[1].strip()
                                # 去除引號
                                if val.startswith('"') and val.endswith('"'):
                                    val = val[1:-1]
                                elif val.startswith("'") and val.endswith("'"):
                                    val = val[1:-1]
                                os.environ[key] = val
                                print(f"  → 載入變數: {key}")
            except Exception as e:
                print(f"  → 讀取檔案失敗: {e}")

load_env()

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    print("\n[錯誤] 找不到 GEMINI_API_KEY！")
    print("請於環境變數中設定，或在專案根目錄下建立 .env 檔案並寫入 GEMINI_API_KEY=您的金鑰")
    sys.exit(1)

# 初始化 Gemini Client
try:
    from google import genai
    from google.genai import errors
    client = genai.Client(api_key=GEMINI_API_KEY)
except ImportError:
    print("[錯誤] 找不到 google-genai 庫。請安裝：pip install google-genai")
    sys.exit(1)

# ================= 暫存檔管理 =================
def load_cache():
    """讀取暫存 JSON，若不存在或損壞則返回空 dict，但保留其他無衝突的 crawler 鍵值"""
    if not os.path.exists(TEMP_JSON_PATH):
        return {}
    try:
        with open(TEMP_JSON_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"[警告] 讀取暫存檔失敗: {e}，將初始化新暫存")
        return {}

def save_cache(cache_data):
    """保存 cache_data 到 JSON，確保保留原有 email 爬蟲的 numeric keys"""
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    # 再次讀取磁碟上的最新狀態以進行合併，防止多進程/多指令覆蓋其他進程寫入的 crawler 鍵值
    latest_disk_cache = {}
    if os.path.exists(TEMP_JSON_PATH):
        try:
            with open(TEMP_JSON_PATH, 'r', encoding='utf-8') as f:
                latest_disk_cache = json.load(f)
        except Exception:
            pass
    
    # 合併：保留 latest_disk_cache 中所有的數字鍵值 (email crawler 的 progress)
    for k, v in latest_disk_cache.items():
        # 如果是純數字字串，且我們沒有在 cache_data 中寫入相同的鍵，就保留它
        if k.isdigit() and k not in cache_data:
            cache_data[k] = v

    try:
        with open(TEMP_JSON_PATH, 'w', encoding='utf-8') as f:
            json.dump(cache_data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[錯誤] 寫入暫存檔失敗: {e}")

# ================= 任務 1：呼叫 Gemini API 重新撰寫公司介紹 =================
def rewrite_intro(company_name, original_desc):
    """呼叫 Gemini 重新撰寫公司介紹"""
    if not original_desc.strip():
        return ""
    
    prompt = f"""你是一位專業的企業品牌與數位轉型顧問。請閱讀以下公司的介紹/說明，並將其整理成一句話的公司簡介。
    
公司名稱：{company_name}
原始說明內容：
{original_desc}

請嚴格遵循以下規定：
1. 必須使用繁體中文。
2. 語氣必須專業、精煉、具信服力。
3. 長度在大約 200 字以內。
4. 僅輸出最終整理好的一句話簡介，不要包含任何前綴（例如「這是一句話介紹：」）、說明、引號或額外廢話。
"""
    
    max_retries = 3
    for attempt in range(1, max_retries + 1):
        try:
            response = client.models.generate_content(
                model='gemini-2.5-flash',
                contents=prompt
            )
            text = response.text.strip()
            # 清理引號 (若模型仍輸出了引號)
            if text.startswith('「') and text.endswith('」'):
                text = text[1:-1]
            if text.startswith('"') and text.endswith('"'):
                text = text[1:-1]
            return text
        except errors.ClientError as ce:
            if "leaked" in str(ce).lower() or "permission_denied" in str(ce).lower():
                print(f"[錯誤] API 金鑰無效或被封鎖: {ce}")
                sys.exit(1)
            print(f"  [API 錯誤] {company_name} 嘗試 {attempt}/{max_retries} 失敗: {ce}")
            if attempt == max_retries:
                raise ce
            time.sleep(2)
        except Exception as e:
            print(f"  [連線錯誤] {company_name} 嘗試 {attempt}/{max_retries} 失敗: {e}")
            if attempt == max_retries:
                raise e
            time.sleep(2)

# ================= 任務 2：產生冷郵件 =================
def get_industry_category(industry_name):
    """
    根據產業名稱將其分類，並回傳情境文字、神達投射重點、Day 7跟Day 30對應的文字。
    """
    name = industry_name.strip()
    
    # 預設為製造／科技業 (因為目前CSV中均為一般製造業)
    if any(k in name for k in ["零售", "家電", "電子商務", "生鮮", "百貨", "食品", "貿易", "商業"]):
        return {
            "p1": "在多通路零售與總部後勤管理中，同仁每天經常在多個內部系統花費大量時間進行重複性的人工操作，這會悄悄消耗團隊精力，也為企業增加龐大的隱形營運成本。",
            "p3_mitac": "作為神達集團長期合作的數位轉型與陪跑顧問，我們協助重新整合集團的入口、工時登錄及簽核流程重構等核心營運系統，專注於流程梳理與動線重構，將繁瑣的流程大幅降低人工比例，實質為他們提升集團綜效。",
            "day7_detail": "特別是針對零售業常見的「跨國據點協作／跨部門單據審核」，",
            "day30_target": "提升後勤自動化"
        }
    elif any(k in name for k in ["金融", "保險", "服務", "銀行", "證券", "諮詢", "顧問"]):
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
    """生成大企業冷郵件內容，包含 Html 換行符與真實換行"""
    contact = contact_name.strip()
    if contact == "官方" or not contact:
        greeting = "您好，"
    else:
        greeting = f"{contact} 您好，"

    ind_data = get_industry_category(industry_name)
    p1 = ind_data["p1"]
    p3 = ind_data["p3_mitac"]
    day7_p2_detail = ind_data["day7_detail"]
    day30_target = ind_data["day30_target"]

    # ------------------ Day 1 ------------------
    day1_title = "內部系統與營運流程需要重新梳理嗎？分享神達集團的數位轉型案例"
    day1_p2 = "我們 PlayPlus 是擁有超過 10 年經驗 of UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。"
    # 修正為中文
    day1_p2 = "我們 PlayPlus 是擁有超過 10 年經驗的 UI/UX 設計與系統開發團隊，同時也是客戶的數位系統顧問。我們的核心價值是「幫客戶多想一步」，為客戶規劃長期發展，透過客製化 UI/UX 設計與前後端開發，重新整頓營運流程與內部系統，協助已經意識到需求的企業。"
    day1_p4 = "隨信附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。"
    day1_p5 = "只需 10-15 分鐘的線上會議，就能為貴司評估數位解決方案，請問您這週是否有空檔撥冗簡單聊聊？"
    
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
    day7_p2 = f"我們能與大型集團維持長期穩定合作，關鍵在於我們非常注重「前半段」的設計與研究討論。在實際開發前，我們會深度盤點商業邏輯並將營運流程標準化，{day7_p2_detail}我們在實際開發前打造出融入同仁工作習慣的直觀系統，降低員工排斥感與學習成本。"
    # 調整語句，移除重複的 "在實際開發前"
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
    day30_p3 = "我再次將附上案例簡報，您可以在 https://playplus.com.tw/internal-system-briefing.pdf 裡面參考詳細資訊。若未來貴司有營運流程的優化需求，隨時歡迎您與我們取得聯繫。"
    # 配合規定與微調
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

# ================= 主程式執行 =================
def main():
    print("=== PlayPlus 冷郵件/公司介紹 處理腳本 ===\n")
    
    if not os.path.exists(CSV_PATH):
        print(f"[錯誤] 找不到 CSV 檔案：{CSV_PATH}")
        sys.exit(1)
        
    # 讀取 CSV
    with open(CSV_PATH, 'r', encoding='utf-8-sig', newline='') as f:
        rows = list(csv.reader(f))
        
    if not rows:
        print("[錯誤] CSV 檔案為空")
        sys.exit(1)
        
    header = [h.strip() for h in rows[0]]
    print(f"CSV 載入成功，標頭：{header}")
    
    # 定位欄位
    try:
        comp_name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
        scen_idx = header.index("Scenarios")
        contact_idx = header.index("聯絡人名稱")
        ind_idx = header.index("產業")
        
        day1_t_idx = header.index("day1_title")
        day1_c_idx = header.index("day1_content")
        day7_t_idx = header.index("day7_title")
        day7_c_idx = header.index("day7_content")
        day14_t_idx = header.index("day14_title")
        day14_c_idx = header.index("day14_content")
        day30_t_idx = header.index("day30_title")
        day30_c_idx = header.index("day30_content")
        day60_t_idx = header.index("day60_title")
        day60_c_idx = header.index("day60_content")
    except ValueError as e:
        print(f"[錯誤] CSV 缺少必要欄位：{e}")
        sys.exit(1)

    # 載入暫存
    cache = load_cache()
    if "company_intros" not in cache:
        cache["company_intros"] = {}
    if "enterprise_emails" not in cache:
        cache["enterprise_emails"] = {}

    # ----------------------------------------------------
    # 步驟 1：重新撰寫公司說明 (Task 1)
    # ----------------------------------------------------
    print("\n--- 步驟 1: 重新撰寫公司簡介 (Gemini API) ---")
    
    # 收集需要處理的唯一公司清單以節省 API 呼叫
    unique_companies = {}
    for i, row in enumerate(rows[1:], start=2):
        if not row or len(row) <= max(comp_name_idx, desc_idx):
            continue
        c_name = row[comp_name_idx].strip()
        c_desc = row[desc_idx].strip()
        if c_name and c_desc:
            unique_companies[c_name] = c_desc

    total_companies = len(unique_companies)
    print(f"找到 {total_companies} 間獨立公司需要處理說明欄位")

    processed_intros_count = 0
    for idx, (c_name, c_desc) in enumerate(unique_companies.items(), 1):
        # 判斷是否已暫存
        if c_name in cache["company_intros"]:
            processed_intros_count += 1
            continue
            
        print(f"  [{idx}/{total_companies}] 處理中: {c_name} ...")
        new_intro = rewrite_intro(c_name, c_desc)
        cache["company_intros"][c_name] = new_intro
        processed_intros_count += 1
        
        # 每筆增量儲存暫存
        save_cache(cache)
        # 頻率限制防護
        time.sleep(0.5)

    print(f"公司簡介處理完成：{processed_intros_count}/{total_companies} 筆已在暫存中")

    # ----------------------------------------------------
    # 步驟 2：大企業冷郵件生成 (Task 2)
    # ----------------------------------------------------
    print("\n--- 步驟 2: 大企業冷郵件生成 (Rule-based) ---")
    
    target_scenario = "大企業_企業內部系統"
    large_corp_rows = []
    
    for i, row in enumerate(rows[1:], start=2):
        if not row or len(row) <= scen_idx:
            continue
        scen = row[scen_idx].strip()
        if scen == target_scenario:
            large_corp_rows.append((i, row))
            
    total_large_corp = len(large_corp_rows)
    print(f"找到 {total_large_corp} 行 Scenario 為「{target_scenario}」")

    processed_emails_count = 0
    for idx, (row_num, row) in enumerate(large_corp_rows, 1):
        c_name = row[comp_name_idx].strip()
        contact = row[contact_idx].strip()
        industry = row[ind_idx].strip()
        
        cache_key = f"{row_num}_{c_name}"
        
        if cache_key in cache["enterprise_emails"]:
            processed_emails_count += 1
            continue
            
        print(f"  [{idx}/{total_large_corp}] 正在生成冷郵件: {c_name} (Row {row_num})")
        emails = generate_emails(contact, industry)
        cache["enterprise_emails"][cache_key] = emails
        processed_emails_count += 1
        
        # 增量儲存暫存
        save_cache(cache)

    print(f"冷郵件生成完成：{processed_emails_count}/{total_large_corp} 筆已在暫存中")

    # ----------------------------------------------------
    # 步驟 3：寫回 CSV
    # ----------------------------------------------------
    print("\n--- 步驟 3: 寫回 CSV 檔案 ---")
    
    # 備份原始 CSV
    backup_path = CSV_PATH + ".backup"
    try:
        import shutil
        shutil.copy2(CSV_PATH, backup_path)
        print(f"已備份原始 CSV 至 {backup_path}")
    except Exception as e:
        print(f"[警告] 備份 CSV 失敗: {e}")

    updated_rows_count = 0
    
    for i, row in enumerate(rows[1:], start=2):
        if not row or len(row) <= max(comp_name_idx, desc_idx):
            continue
        
        c_name = row[comp_name_idx].strip()
        
        # 更新公司介紹 (對所有行都更新)
        if c_name in cache["company_intros"]:
            row[desc_idx] = cache["company_intros"][c_name]
            
        # 更新冷郵件 (僅限大企業_企業內部系統)
        scen = row[scen_idx].strip()
        if scen == target_scenario:
            cache_key = f"{i}_{c_name}"
            if cache_key in cache["enterprise_emails"]:
                emails = cache["enterprise_emails"][cache_key]
                row[day1_t_idx] = emails["day1_title"]
                row[day1_c_idx] = emails["day1_content"]
                row[day7_t_idx] = emails["day7_title"]
                row[day7_c_idx] = emails["day7_content"]
                row[day30_t_idx] = emails["day30_title"]
                row[day30_c_idx] = emails["day30_content"]
                
                # Day 14 and Day 60 set to "-"
                row[day14_t_idx] = "-"
                row[day14_c_idx] = "-"
                row[day60_t_idx] = "-"
                row[day60_c_idx] = "-"
                
                updated_rows_count += 1

    # 一次性寫回
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
        
    print(f"成功將更新內容覆寫至 {CSV_PATH}！共更新 {updated_rows_count} 筆大企業冷郵件資料。")
    print("=== 執行完畢 ===")

if __name__ == '__main__':
    main()
