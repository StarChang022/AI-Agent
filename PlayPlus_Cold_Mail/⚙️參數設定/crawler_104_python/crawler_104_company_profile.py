"""
crawler_104_company_profile.py (Google Sheets 版本)
====================================================
搭配 3.104crawler撰寫公司說明.md 執行。
使用 Playwright 自動進入 104 公司頁面，抓取「公司簡介」與「主要商品」，
並直接將 AI 摘要結果寫回 Google Sheets『名單副本』的「說明」欄位。

流程：
  1. 從 Google Sheets『名單副本』讀取「來源」欄位
  2. 使用 Playwright 進入每個 104 URL，抓取公司簡介文字
  3. 將摘要結果直接寫回 Google Sheets「說明」欄位
  4. （可選）同時輸出 temp_profiles.json 供外部 AI Agent 使用

使用方式：
    python3 crawler_104_company_profile.py

需要安裝的套件：
    pip install playwright gspread google-auth
    playwright install chromium
"""

import json
import os
import time
import random
from typing import List, Dict

from playwright.sync_api import sync_playwright

import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gs_helper import get_worksheet, load_sheet_as_rows, save_rows_to_sheet

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEMP_JSON_PATH = os.path.join(SCRIPT_DIR, "temp_profiles.json")

DELAY_MIN = 1.0
DELAY_MAX = 2.5
TIMEOUT = 30000


# ──────────────────────────────────────────────
# 工具函式
# ──────────────────────────────────────────────

def fetch_company_info(page, url: str) -> str:
    """抓取 104 頁面的公司簡介與產品"""
    try:
        page.goto(url, wait_until="domcontentloaded", timeout=TIMEOUT)
        page.wait_for_timeout(1000)

        info_text = ""

        # 策略 1: 尋找公司簡介段落
        desc_element = page.query_selector('.profile__desc')
        if desc_element:
            info_text += "【公司簡介】\n" + desc_element.inner_text().strip() + "\n\n"

        # 策略 2: 尋找主要商品/服務項目
        products_element = page.query_selector('.product__desc')
        if products_element:
            info_text += "【主要商品】\n" + products_element.inner_text().strip()

        # 策略 3: 備用通用抓取
        if not info_text:
            elements = page.query_selector_all('p')
            for el in elements:
                text = el.inner_text().strip()
                if len(text) > 30:
                    info_text += text + "\n"

        # 截斷避免 token 爆炸（保留約 1000 字）
        return info_text[:1000].strip() if info_text else "無公司資訊"

    except Exception as e:
        print(f"        [錯誤] 抓取失敗：{e}")
        return "無法取得公司資訊"


def summarize_company_info(info_text: str, company_name: str) -> str:
    """
    根據公司資訊文字，自動生成 50~100 字的繁體中文一句話簡介。
    注意：此函式使用規則式摘要，如需 AI 摘要請改用外部 Agent 讀取 temp_profiles.json。
    """
    if not info_text or info_text in ("無公司資訊", "無法取得公司資訊"):
        return ""

    # 擷取第一段有意義的句子（簡單摘要）
    lines = [l.strip() for l in info_text.replace("【公司簡介】", "").replace("【主要商品】", "").split("\n") if l.strip()]
    if not lines:
        return ""

    # 組合前幾行，截取到合理長度
    summary = " ".join(lines)
    # 去除多餘空白
    summary = " ".join(summary.split())
    # 截取 100 字以內
    if len(summary) > 100:
        # 嘗試在句點處截斷
        truncated = summary[:100]
        last_period = max(truncated.rfind("。"), truncated.rfind("，"), truncated.rfind("、"))
        if last_period > 50:
            summary = truncated[:last_period + 1]
        else:
            summary = truncated + "…"

    return summary


# ──────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  104 公司簡介抓取工具 (Google Sheets 版本)")
    print("=" * 60)

    # 連線 Google Sheets 並讀取所有列
    ws = get_worksheet()
    rows, fieldnames = load_sheet_as_rows(ws)
    print(f"共讀取 {len(rows)} 列資料\n")

    if not rows:
        print("[錯誤] Google Sheets 分頁為空")
        return

    company_data = {}        # 供 temp_profiles.json 輸出（外部 AI Agent 使用）
    updated_count = 0
    skipped_count = 0

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
            existing_desc = row.get("說明", "").strip()

            print(f"[{i:>3}/{total}] {company_name}")

            if not source_url:
                skipped_count += 1
                continue

            # 已有說明 → 略過
            if existing_desc:
                print(f"        [略過] 說明已存在")
                skipped_count += 1
                continue

            info = fetch_company_info(page, source_url)
            company_data[company_name] = info

            if info and info not in ("無公司資訊", "無法取得公司資訊"):
                print(f"        ✅ 取得資訊（長度：{len(info)}）")
                # 自動摘要後寫回 row
                summary = summarize_company_info(info, company_name)
                if summary:
                    row["說明"] = summary
                    updated_count += 1
                    print(f"        📝 摘要：{summary[:60]}...")
            else:
                print("        ❌ 未取得有效資訊")

            if i < total:
                time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))

        browser.close()

    # 覆寫回 Google Sheets
    save_rows_to_sheet(ws, rows, fieldnames)
    print(f"\n[GS] 已將說明欄位更新寫回 Google Sheets（{updated_count} 筆）")

    # 同時輸出 temp_profiles.json 供外部 AI Agent 進行更細緻的摘要（可選）
    with open(TEMP_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(company_data, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 60)
    print(f"  抓取完成！")
    print(f"  ✅ 更新說明欄位：{updated_count} 筆")
    print(f"  ⏭  略過：{skipped_count} 筆")
    print(f"  📊 已寫回 Google Sheets『名單副本』")
    print(f"  💾 raw 資料同時儲存至：{TEMP_JSON_PATH}")
    print(f"     （如需 AI Agent 精緻化摘要，請讀取此 JSON 後手動覆寫「說明」欄位）")
    print("=" * 60)


if __name__ == "__main__":
    main()
