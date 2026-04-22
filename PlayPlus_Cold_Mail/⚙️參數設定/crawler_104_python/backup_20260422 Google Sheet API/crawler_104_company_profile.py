"""
crawler_104_company_profile.py (Playwright + Google Sheets 版本)
================================================================
搭配 3.104crawler撰寫公司說明.md 執行。

流程：
  1. 從 Google Sheets 『名單副本』讀取「來源」欄位
  2. 使用 Playwright 進入每個 104 URL，抓取公司簡介與主要商品
  3. 儲存為 temp_profiles.json（格式：{"公司品牌簡稱": "原始文本", ...}）
  4. AI Agent 讀取 JSON，撰寫摘要後，將說明寫回 Google Sheets 的「說明」欄位

GSheet 欄位（共 9 欄，A~I）：
  公司品牌簡稱, 序號, 官方網站, 產業, 員工人數, email, 聯絡人名稱, 來源, 說明（AI 填寫）

使用方式：
    python3 crawler_104_company_profile.py

需要安裝的套件：
    pip install playwright google-auth google-auth-httplib2 google-api-python-client
    playwright install chromium
"""

import json
import os
import time
import random
from typing import List, Dict

from playwright.sync_api import sync_playwright
import gsheet_helper as gs

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEMP_JSON_PATH = os.path.join(SCRIPT_DIR, "temp_profiles.json")

DELAY_MIN = 1.0
DELAY_MAX = 2.5
TIMEOUT = 30000


def fetch_company_info(page, url: str) -> str:
    """抓取 104 頁面的公司簡介與主要商品（最多 1000 字）"""
    try:
        page.goto(url, wait_until="domcontentloaded", timeout=TIMEOUT)
        page.wait_for_timeout(1000)

        info_text = ""

        desc_element = page.query_selector('.profile__desc')
        if desc_element:
            info_text += "【公司簡介】\n" + desc_element.inner_text().strip() + "\n\n"

        products_element = page.query_selector('.product__desc')
        if products_element:
            info_text += "【主要商品】\n" + products_element.inner_text().strip()

        if not info_text:
            elements = page.query_selector_all('p')
            for el in elements:
                text = el.inner_text().strip()
                if len(text) > 30:
                    info_text += text + "\n"

        return info_text[:1000].strip() if info_text else "無公司資訊"

    except Exception as e:
        print(f"        [錯誤] 抓取失敗：{e}")
        return "無法取得公司資訊"


def write_profiles_to_sheet(profiles: dict) -> None:
    """
    將 AI 撰寫好的公司說明寫回 Google Sheets 的「說明」欄位。
    profiles 格式：{"公司品牌簡稱": "50~100字說明", ...}
    只更新說明欄為空的列，不覆蓋已有內容。
    """
    service = gs.get_service()
    rows, fieldnames = gs.read_all_rows(service)

    updated = 0
    for row in rows:
        name = row.get("公司品牌簡稱", "").strip()
        if name in profiles and not row.get("說明", "").strip():
            row["說明"] = profiles[name]
            updated += 1

    gs.write_all_rows(service, rows, fieldnames)
    print(f"[GSheet] ✅ 已更新 {updated} 間公司的「說明」欄位")


def main():
    print("=" * 60)
    print("  104 公司簡介抓取工具 (Playwright + Google Sheets 版本)")
    print("=" * 60)

    print("[GSheet] 連接 Google Sheets，讀取資料...")
    service = gs.get_service()
    rows, fieldnames = gs.read_all_rows(service)

    if not rows:
        print("[錯誤] Google Sheets 工作表為空或無資料列")
        return

    print(f"共讀取 {len(rows)} 列資料\n")

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
            company_data[company_name] = info

            if info not in ("無公司資訊", "無法取得公司資訊"):
                print(f"        ✅ 取得資訊 (長度: {len(info)})")
            else:
                print(f"        ❌ 未取得有效資訊")

            if i < total:
                time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))

        browser.close()

    with open(TEMP_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(company_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 60)
    print(f"  抓取完成！資料已存至 {TEMP_JSON_PATH}")
    print(f"  請 AI Agent 讀取 JSON，撰寫摘要後呼叫 write_profiles_to_sheet()")
    print(f"  Google Sheets：https://docs.google.com/spreadsheets/d/{gs.SPREADSHEET_ID}/edit")
    print("=" * 60)


if __name__ == "__main__":
    main()
