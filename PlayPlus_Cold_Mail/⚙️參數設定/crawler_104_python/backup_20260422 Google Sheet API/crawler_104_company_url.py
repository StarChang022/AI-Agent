"""
crawler_104_company_url.py (Playwright + Google Sheets 版本)
============================================================
依照 2.104crawler公司網址.md 指令執行。
使用 Playwright 以處理 JavaScript 動態渲染。

流程：
  1. 從 Google Sheets 『名單副本』讀取所有列
  2. 使用 Playwright 進入「來源」欄的 104 公司頁面，尋找「公司網址」
  3. 找到 → 將網址寫入「官方網站」欄位
     找不到 → 刪除該列
  4. 結果完整覆寫回 Google Sheets

CSV 欄位（共 9 欄，A~I）：
  公司品牌簡稱, 序號, 官方網站（本腳本填寫）, 產業, 員工人數, email, 聯絡人名稱, 來源, 說明

使用方式：
    python3 crawler_104_company_url.py

需要安裝的套件：
    pip install playwright google-auth google-auth-httplib2 google-api-python-client
    playwright install chromium
"""

import os
import re
import time
import random
from typing import List, Dict, Optional

from playwright.sync_api import sync_playwright
import gsheet_helper as gs

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

# 請求間隔（秒）
DELAY_MIN = 1.0
DELAY_MAX = 2.5

# 連線逾時（毫秒）
TIMEOUT = 30000


# ──────────────────────────────────────────────
# 工具函式
# ──────────────────────────────────────────────

def fetch_company_website(page, url: str) -> Optional[str]:
    """
    使用 Playwright 進入 104 公司頁面，嘗試取得「公司網址」。
    """
    try:
        page.goto(url, wait_until="domcontentloaded", timeout=TIMEOUT)
        print("        等待頁面渲染...")
        page.wait_for_timeout(1000)

        # 策略 1: data-gtm-content 標籤（最準確）
        website_link = page.query_selector('a[data-gtm-content="公司網址"]')
        if website_link:
            href = website_link.get_attribute("href")
            if href and "104.com.tw" not in href:
                return href

        # 策略 2: .intro-table__data 中的連結
        items = page.query_selector_all('.intro-table__data')
        for item in items:
            header = item.evaluate("el => el.previousElementSibling ? el.previousElementSibling.innerText : \"\"")
            if "公司網址" in str(header):
                anchor = item.query_selector('a')
                if anchor:
                    href = anchor.get_attribute("href")
                    if href and "104.com.tw" not in href:
                        return href

        # 策略 3: 搜尋所有外部連結
        all_links = page.query_selector_all('a[href^="http"]')
        for link in all_links:
            href = link.get_attribute("href") or ""
            if any(domain in href for domain in ["104.com.tw", "facebook.com", "line.me", "instagram.com", "youtube.com"]):
                continue
            text = link.inner_text().strip()
            parent_text = ""
            try:
                parent_text = link.evaluate("el => el.parentElement.innerText")
            except:
                pass
            if "公司網址" in parent_text or "官方網站" in parent_text or re.match(r'^https?://[^\s]+$', text):
                return href

        # 策略 4: 舊版 CSS selector 相容
        items_old = page.query_selector_all('.company-description__item')
        for item in items_old:
            inner_text = item.inner_text()
            if "公司網址" in inner_text:
                anchor = item.query_selector('a')
                if anchor:
                    href = anchor.get_attribute("href")
                    if href and "104.com.tw" not in href:
                        return href

        return None

    except Exception as e:
        print(f"        [錯誤] 抓取失敗：{e}")
        return None


# ──────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  104 公司頁面 → 官方網站爬蟲 (Playwright + Google Sheets 版)")
    print("=" * 60)

    # 連接 Google Sheets，讀取所有列
    print("[GSheet] 連接 Google Sheets，讀取資料...")
    service = gs.get_service()
    rows, fieldnames = gs.read_all_rows(service)

    if not rows:
        print("[錯誤] Google Sheets 工作表為空或無資料列")
        return

    print(f"共讀取 {len(rows)} 列資料 (欄位數: {len(fieldnames)})\n")

    kept_rows: List[Dict] = []
    deleted_count = 0
    updated_count = 0
    skipped_count = 0
    total = len(rows)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
        page = context.new_page()

        for i, row in enumerate(rows, start=1):
            source_url = row.get("來源", "").strip()
            company_name = row.get("公司品牌簡稱", "").strip()
            existing_website = row.get("官方網站", "").strip()

            print(f"[{i:>3}/{total}] {company_name}")

            # 來源欄為空 → 略過
            if not source_url:
                print(f"        [略過] 來源欄位為空")
                kept_rows.append(row)
                skipped_count += 1
                continue

            # 官方網站欄已有值 → 略過
            if existing_website:
                print(f"        [略過] 官方網站已存在：{existing_website}")
                kept_rows.append(row)
                skipped_count += 1
                continue

            # 進入 104 公司頁面取得官方網站
            print(f"        來源：{source_url}")
            website = fetch_company_website(page, source_url)

            if website:
                row["官方網站"] = website
                kept_rows.append(row)
                updated_count += 1
                print(f"        ✅ 官方網站：{website}")
            else:
                deleted_count += 1
                print(f"        ❌ 無公司網址，刪除此列")

            if i < total:
                delay = random.uniform(DELAY_MIN, DELAY_MAX)
                time.sleep(delay)

        browser.close()

    # 覆寫回 Google Sheets
    print("\n[GSheet] 覆寫資料至 Google Sheets...")
    gs.write_all_rows(service, kept_rows, fieldnames)

    print("\n" + "=" * 60)
    print(f"  完成！")
    print(f"  ✅ 填入官方網站：{updated_count} 列")
    print(f"  ❌ 刪除（無官網）：{deleted_count} 列")
    print(f"  ⏭  略過：{skipped_count} 列")
    print(f"  📄 最終保留：{len(kept_rows)} 列")
    print(f"  Google Sheets：https://docs.google.com/spreadsheets/d/{gs.SPREADSHEET_ID}/edit")
    print("=" * 60)


if __name__ == "__main__":
    main()
