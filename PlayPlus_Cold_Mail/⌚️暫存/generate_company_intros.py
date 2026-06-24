#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自動為 名單副本.csv 中的公司重新撰寫簡介內容（I欄），並寫入 temporary_104.json。
"""

import os
import csv
import json
import time
import shutil
import vertexai
from vertexai.generative_models import GenerativeModel

# 檔案路徑設定
BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
CSV_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本.csv")
BACKUP_PATH = os.path.join(BASE_DIR, "冷郵件對象", "名單副本_backup_intro.csv")
TEMP_JSON_PATH = os.path.join(BASE_DIR, "⌚️暫存", "temporary_104.json")
KEY_PATH = os.path.join(BASE_DIR, "⚙️參數設定", "eternal-skyline-494002-j8-356884d3e786.json")

# 設置 GCP 認證
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = KEY_PATH

def load_existing_cache():
    """載入既有的暫存檔，若不存在或損壞則返回空字典"""
    merged_data = {}
    if os.path.exists(TEMP_JSON_PATH):
        try:
            with open(TEMP_JSON_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, list):
                for item in data:
                    name = item.get("company_name")
                    if name:
                        merged_data[name.strip()] = item
            elif isinstance(data, dict):
                for name, item in data.items():
                    merged_data[name.strip()] = item
            print(f"✅ 已載入既有暫存，共 {len(merged_data)} 筆資料。")
        except Exception as e:
            print(f"⚠️ 載入暫存檔失敗: {e}，將建立新的暫存。")
    return merged_data

def save_cache(cache_data):
    """保存暫存資料"""
    os.makedirs(os.path.dirname(TEMP_JSON_PATH), exist_ok=True)
    with open(TEMP_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(cache_data, f, ensure_ascii=False, indent=2)

def rewrite_description(model, company_name, original_desc):
    """調用 Vertex AI Gemini API 生成簡短公司簡介"""
    if not original_desc or original_desc.strip() in ["", "無", "暫無"]:
        # 若無說明，給予一個預設的專業代稱
        return f"{company_name}為業界專業製造加工與製造商，致力於為客戶提供高品質的產品與一站式服務。"

    prompt = f"""請根據以下公司的原始介紹，使用繁體中文、專業且具備商業氣息的顧問口吻，寫出大約 200 字以內的一句話公司簡介。

規定與限制：
1. 必須以繁體中文撰寫。
2. 必須是一句話，語氣專業、俐落，適合用於商業合作開發或冷郵件（Cold Mail）的開頭。
3. 長度控制在約 200 字以內（建議在 50 至 120 字之間）。
4. 句首通常以公司名稱或簡稱開場，例如「[公司名稱]創立於[年份]，專注於...」或「[公司名稱]深耕[領域]多年，提供...」。
5. 不要包含多餘的客套話、自我介紹、廣告詞、引號或換行符號。
6. 請只輸出這一句公司介紹，不要有任何其他前導文字、後續解釋、標記或引號。

【公司名稱】
{company_name}

【原始說明】
{original_desc}
"""

    for attempt in range(3):
        try:
            response = model.generate_content(prompt)
            text = response.text.strip()
            # 清理引號及多餘的符號
            text = text.replace('"', '').replace('「', '').replace('」', '').replace('`', '').strip()
            # 確保是一行
            text = " ".join(text.split())
            if text:
                return text
        except Exception as e:
            print(f"⚠️ [嘗試 {attempt+1}/3] 呼叫 API 處理 {company_name} 時發生錯誤: {e}")
            time.sleep(2 ** attempt)
    return None

def main():
    print("=== 開始執行公司簡介撰寫任務 ===")

    # 1. 檢查並備份原始 CSV
    if not os.path.exists(CSV_PATH):
        print(f"❌ 找不到 CSV 檔案：{CSV_PATH}")
        return
    shutil.copy2(CSV_PATH, BACKUP_PATH)
    print(f"✅ 已成功備份 CSV 至：{BACKUP_PATH}")

    # 2. 初始化 Vertex AI
    try:
        with open(KEY_PATH, "r") as f:
            key_data = json.load(f)
        project_id = key_data["project_id"]
        vertexai.init(project=project_id, location="us-central1")
        model = GenerativeModel("gemini-1.5-flash-002")
        print(f"✅ Vertex AI 初始化成功，專案：{project_id}")
    except Exception as e:
        print(f"❌ Vertex AI 初始化失敗: {e}")
        return

    # 3. 載入 CSV
    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print("❌ CSV 檔案內容為空")
        return

    header = rows[0]
    try:
        name_idx = header.index("公司名稱")
        desc_idx = header.index("說明")
    except ValueError as e:
        print(f"❌ CSV 標頭缺少必要欄位：{e}")
        return

    # 4. 載入並比對暫存檔
    cache_data = load_existing_cache()

    # 5. 處理資料
    unique_companies = {}
    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(name_idx, desc_idx):
            continue
        comp_name = row[name_idx].strip()
        original_desc = row[desc_idx].strip()
        if comp_name:
            # 以公司名稱為鍵值保留唯一的原始描述
            if comp_name not in unique_companies:
                unique_companies[comp_name] = original_desc

    print(f"📊 CSV 總行數 (不含標頭): {len(rows)-1}，獨特公司數: {len(unique_companies)}")

    # 逐一生成或取得暫存介紹
    summaries = {}
    updated_count = 0

    for idx, (company_name, original_desc) in enumerate(unique_companies.items(), 1):
        # 檢查暫存中是否已有此公司的 new_description 或 summary
        cached_item = cache_data.get(company_name)
        if cached_item and (cached_item.get("summary") or cached_item.get("new_description")):
            summary_text = cached_item.get("summary") or cached_item.get("new_description")
            summaries[company_name] = summary_text
            print(f"[{idx}/{len(unique_companies)}] ⏩ 使用暫存介紹：{company_name}")
            continue

        print(f"[{idx}/{len(unique_companies)}] 🤖 正在為 {company_name} 生成新介紹...")
        summary_text = rewrite_description(model, company_name, original_desc)
        if summary_text:
            summaries[company_name] = summary_text
            # 寫入暫存
            cache_data[company_name] = {
                "company_name": company_name,
                "original_description": original_desc,
                "new_description": summary_text,
                "summary": summary_text
            }
            updated_count += 1
            print(f"  → 生成成功: {summary_text}")
            # 每次生成成功立即儲存 JSON
            save_cache(cache_data)
            time.sleep(0.5)  # 避免觸發頻率限制
        else:
            print(f"  ❌ {company_name} 生成失敗")

    # 6. 一次性更新記憶體中的 CSV 行並寫回檔案
    updated_rows_count = 0
    for idx in range(1, len(rows)):
        row = rows[idx]
        if not row or len(row) <= max(name_idx, desc_idx):
            continue
        comp_name = row[name_idx].strip()
        if comp_name in summaries:
            row[desc_idx] = summaries[comp_name]
            updated_rows_count += 1

    # 一次性寫回 CSV 檔案
    with open(CSV_PATH, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(rows)

    print(f"=== 任務完成 ===")
    print(f"✅ 新生成公司簡介數: {updated_count}")
    print(f"✅ CSV 更新總列數: {updated_rows_count}")
    print(f"✅ 暫存檔已儲存於：{TEMP_JSON_PATH}")

if __name__ == "__main__":
    main()
