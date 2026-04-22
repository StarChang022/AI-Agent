"""
crawler_104_company_profile.py
==============================
搭配 3.104crawler撰寫公司說明.md 執行。
使用 Playwright 自動進入 104 公司頁面，抓取「公司簡介」與「主要商品」，
並匯出成 temp_profiles.json 供 AI Agent 進行摘要與寫入。

流程：
  1. 讀取 ../../冷郵件對象/名單副本.csv 的「來源」欄位
  2. 使用 Playwright 進入每個 104 URL，抓取文字資訊
  3. 儲存為 temp_profiles.json（格式：{"公司品牌簡稱": "原始文本", ...}）

CSV 欄位（共 8 欄）：
  公司品牌簡稱, 序號, 官方網站, 產業, 員工人數, email, 聯絡人名稱, 來源, 說明（本腳本透過 AI 填寫）
"""

import csv
import json
import os
import time
import random
from typing import List, Dict

from playwright.sync_api import sync_playwright

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "..", "冷郵件對象", "名單副本.csv")
)
TEMP_JSON_PATH = os.path.join(SCRIPT_DIR, "temp_profiles.json")

DELAY_MIN = 1.0
DELAY_MAX = 2.5
TIMEOUT = 30000


def load_csv(csv_path: str) -> List[Dict]:
    rows = []
    if not os.path.exists(csv_path):
        return rows
    with open(csv_path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(dict(row))
    return rows


def fetch_company_info(page, url: str) -> str:
    """抓取 104 頁面的公司簡介與產品"""
    try:
        page.goto(url, wait_until="domcontentloaded", timeout=TIMEOUT)
        page.wait_for_timeout(1000)

        info_text = ""

        # 策略 1: 尋找 p 標籤 (104 常用的簡介段落)
        # 公司簡介通常在某個包含 description 關鍵字的區塊內
        desc_element = page.query_selector('.profile__desc')
        if desc_element:
            info_text += "【公司簡介】\n" + desc_element.inner_text().strip() + "\n\n"

        # 找尋包含「主要商品 / 服務項目」的區塊
        products_element = page.query_selector('.product__desc')
        if products_element:
            info_text += "【主要商品】\n" + products_element.inner_text().strip()

        # 如果找不到新的 CSS selector，嘗試通用的備用抓取方法
        if not info_text:
            elements = page.query_selector_all('p')
            for el in elements:
                text = el.inner_text().strip()
                if len(text) > 30:
                    info_text += text + "\n"

        # 如果文字太長，截斷避免 token 爆炸 (大約保留 1000 字供 AI 判讀)
        return info_text[:1000].strip() if info_text else "無公司資訊"

    except Exception as e:
        print(f"        [錯誤] 抓取失敗：{e}")
        return "無法取得公司資訊"


def main():
    print("=" * 60)
    print("  104 公司簡介抓取工具 (提供 AI 摘要用)")
    print("=" * 60)

    rows = load_csv(CSV_PATH)
    if not rows:
        print(f"[錯誤] CSV 不存在或為空：{CSV_PATH}")
        return

    company_data = {}

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
        page = context.new_page()

        total = len(rows)
        for i, row in enumerate(rows, start=1):
            company_name = row.get("公司品牌簡稱", "").strip()
            source_url = row.get("來源", "").strip()

            if not source_url:
                continue

            print(f"[{i:>3}/{total}] 抓取中: {company_name}")
            info = fetch_company_info(page, source_url)
            
            # 將資料存入字典中
            company_data[company_name] = info
            
            if info and info != "無公司資訊" and info != "無法取得公司資訊":
                 print(f"        ✅ 取得資訊 (長度: {len(info)})")
            else:
                 print(f"        ❌ 未取得有效資訊")

            if i < total:
                time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))

        browser.close()

    # 將結果輸出成 JSON 供 Agent 讀取
    with open(TEMP_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(company_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 60)
    print(f"  抓取完成！資料已存至 {TEMP_JSON_PATH}")
    print(f"  請交由 AI Agent 進行摘要與寫入。")
    print("=" * 60)


if __name__ == "__main__":
    main()
