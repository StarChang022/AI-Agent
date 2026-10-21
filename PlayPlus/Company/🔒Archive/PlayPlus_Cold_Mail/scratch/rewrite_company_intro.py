#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自動為 名單副本.csv 重新撰寫公司說明（I 欄）為 200 字以內的一句話公司簡介（使用 Gemini API）。
暫存資料均儲存於 ⌚️暫存/temporary_104.json，並在所有處理完畢後一次性覆寫回 CSV。
"""

import os
import csv
import json
import time
import sys

# ================= 參數設定 =================
BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
TEMP_JSON_PATH = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')

# ================= 環境變數載入 =================
def load_env():
    """手動解析 .env 檔案並載入環境變數"""
    env_paths = [
        os.path.join(BASE_DIR, '.env'),
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
    """讀取暫存 JSON，若不存在或損壞則返回空 dict"""
    if not os.path.exists(TEMP_JSON_PATH):
        return {}
    try:
        with open(TEMP_JSON_PATH, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"[警告] 讀取暫存檔失敗: {e}，將初始化新暫存")
        return {}

def save_cache(cache_data):
    """保存 cache_data 到 JSON，確保保留原有 numeric keys 及其他不衝突之欄位"""
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    latest_disk_cache = {}
    if os.path.exists(TEMP_JSON_PATH):
        try:
            with open(TEMP_JSON_PATH, 'r', encoding='utf-8') as f:
                latest_disk_cache = json.load(f)
        except Exception:
            pass
    
    # 進行合併
    merged = latest_disk_cache.copy()
    
    # 用 cache_data 中更新過的值覆蓋/新增
    for k, v in cache_data.items():
        merged[k] = v

    try:
        with open(TEMP_JSON_PATH, 'w', encoding='utf-8') as f:
            json.dump(merged, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[錯誤] 寫入暫存檔失敗: {e}")

# ================= 呼叫 Gemini API 重新撰寫公司介紹 =================
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

def main():
    print("=== PlayPlus 公司介紹重新撰寫任務 ===\n")
    
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
    print(f"CSV 載入成功，總共 {len(rows)-1} 筆資料")
    
    try:
        comp_name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
    except ValueError as e:
        print(f"[錯誤] CSV 缺少必要欄位：{e}")
        sys.exit(1)

    # 載入暫存
    cache = load_cache()
    if "company_intros" not in cache:
        cache["company_intros"] = {}

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
    skipped_count = 0
    
    for idx, (c_name, c_desc) in enumerate(unique_companies.items(), 1):
        # 判斷是否已暫存且不為空
        if c_name in cache["company_intros"] and cache["company_intros"][c_name]:
            skipped_count += 1
            processed_intros_count += 1
            continue
            
        print(f"  [{idx}/{total_companies}] 處理中: {c_name} ...")
        new_intro = rewrite_intro(c_name, c_desc)
        cache["company_intros"][c_name] = new_intro
        processed_intros_count += 1
        
        # 增量儲存暫存
        save_cache(cache)
        # 頻率限制防護
        time.sleep(0.5)

    print(f"\n公司簡介處理完成：共處理 {processed_intros_count}/{total_companies} 筆（其中 {skipped_count} 筆已在暫存中跳過）")

    # ----------------------------------------------------
    # 寫回 CSV
    # ----------------------------------------------------
    print("\n--- 正在寫回 CSV 檔案 ---")
    
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
        if c_name in cache["company_intros"]:
            row[desc_idx] = cache["company_intros"][c_name]
            updated_rows_count += 1

    # 一次性寫回
    with open(CSV_PATH, 'w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(rows)
        
    print(f"成功將更新內容覆寫至 {CSV_PATH}！共更新 {updated_rows_count} 行。")
    print("=== 執行完畢 ===")

if __name__ == '__main__':
    main()
