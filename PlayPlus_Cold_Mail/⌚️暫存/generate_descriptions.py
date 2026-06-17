#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
讀取 company_descriptions_to_rewrite.json，調用 Vertex AI (Gemini 1.5 Flash) 重新撰寫公司介紹，
並寫入到 temporary_104.json。
"""

import os
import json
import time
import vertexai
from vertexai.generative_models import GenerativeModel

BASE_DIR = "/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail"
INPUT_JSON = os.path.join(BASE_DIR, '⌚️暫存', 'company_descriptions_to_rewrite.json')
TEMP_JSON_PATH = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')
KEY_PATH = os.path.join(BASE_DIR, '⚙️參數設定', 'eternal-skyline-494002-j8-356884d3e786.json')

# 設置 GCP 認證
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = KEY_PATH

def load_json(filepath):
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}

def save_json(data, filepath):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def rewrite_description(model, company_name, original_desc):
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
    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        # 清理可能被模型加上去的引號或 Markdown 格式
        text = text.replace('"', '').replace('「', '').replace('」', '').replace('`', '').strip()
        return text
    except Exception as e:
        print(f"❌ 調用 API 處理 {company_name} 時發生錯誤: {e}")
        return None

def main():
    print("=== 開始調用 Vertex AI 重新撰寫公司介紹 ===")
    
    # 初始化 Vertex AI
    try:
        with open(KEY_PATH, 'r') as f:
            key_data = json.load(f)
        project_id = key_data["project_id"]
        vertexai.init(project=project_id, location="us-central1")
        model = GenerativeModel("gemini-1.5-flash-002")
        print(f"✅ Vertex AI 初始化成功，專案：{project_id}")
    except Exception as e:
        print(f"❌ Vertex AI 初始化失敗: {e}")
        return

    # 讀取待處理的名單
    to_rewrite = load_json(INPUT_JSON)
    if not to_rewrite:
        print("❌ 找不到待處理的名單 JSON")
        return
    print(f"待處理公司總數：{len(to_rewrite)}")

    # 讀取現有的暫存 JSON (為了保留舊資料，並且避免重複處理)
    temp_data = load_json(TEMP_JSON_PATH)
    print(f"現有 temporary_104.json 已記錄公司數：{len(temp_data)}")

    updated_count = 0
    
    for idx, (company_name, original_desc) in enumerate(to_rewrite.items(), 1):
        # 如果該公司已經有處理好的 new_description，且 original_description 相同，則跳過
        if company_name in temp_data and temp_data[company_name].get("new_description"):
            # 檢查原始說明是否一致（或差不多），如果一致則不用重複跑
            print(f"[{idx}/{len(to_rewrite)}] 跳過已處理的公司：{company_name}")
            continue

        print(f"[{idx}/{len(to_rewrite)}] 正在處理：{company_name}...")
        
        # 進行重寫
        new_desc = rewrite_description(model, company_name, original_desc)
        if new_desc:
            print(f"  → 重新撰寫成功：{new_desc}")
            temp_data[company_name] = {
                "original_description": original_desc,
                "new_description": new_desc
            }
            updated_count += 1
            # 每次處理成功都寫入，防止中途斷電或中斷遺失進度
            save_json(temp_data, TEMP_JSON_PATH)
            # 稍微延遲避免頻率限制
            time.sleep(0.5)
        else:
            print(f"  ⚠️ {company_name} 處理失敗，跳過...")

    print(f"=== 重新撰寫完成！共更新 {updated_count} 筆公司介紹 ===")

if __name__ == "__main__":
    main()
