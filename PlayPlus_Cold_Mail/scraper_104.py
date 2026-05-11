#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
104.com.tw 公司搜尋爬蟲
-----------------------------------------------
功能：抓取 104 公司搜尋結果（100 頁），收集：
  - 公司名稱
  - 104 公司內頁連結

輸出：冷郵件對象/104_company_list.csv

使用技術：Playwright（headless 模式，不開啟可見瀏覽器）

安裝依賴（執行前請先安裝）：
  pip install playwright
  playwright install chromium
"""

import asyncio
import csv
import os
import time
import random
from pathlib import Path

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError


# ── 設定 ─────────────────────────────────────────────────────────────────────

BASE_URL = "https://www.104.com.tw/company/search/"
QUERY_PARAMS = "indcat=1002000000&emp=5"   # 行業別＋員工規模篩選
TOTAL_PAGES = 100                          # 要抓取的頁數
ITEMS_PER_PAGE = 20                        # 每頁約 20 筆

OUTPUT_DIR = Path(__file__).parent / "冷郵件對象"
OUTPUT_FILE = OUTPUT_DIR / "104_company_list.csv"

# 頁面等待設定（秒）
PAGE_LOAD_WAIT = 8        # 等待頁面初次載入
BETWEEN_PAGE_MIN = 2      # 翻頁後最短等待（秒）
BETWEEN_PAGE_MAX = 4      # 翻頁後最長等待（秒）

# CSS 選擇器（依 104 DOM 結構）
COMPANY_ITEM_SELECTOR  = "article.company-card, div.company-card, a[href*='/company/']"
COMPANY_LINK_SELECTOR  = "a[href*='104.com.tw/company/']"
COMPANY_NAME_SELECTOR  = "h2, h3, .company-name, [class*='name']"

# ── 主爬蟲邏輯 ───────────────────────────────────────────────────────────────

async def scrape_page(page, page_num: int) -> list[dict]:
    """抓取單一搜尋頁面，回傳公司清單。"""
    url = f"{BASE_URL}?page={page_num}&{QUERY_PARAMS}"
    results = []

    print(f"[Page {page_num:>3}/100] 正在讀取：{url}")

    try:
        await page.goto(url, wait_until="networkidle", timeout=30_000)
    except PlaywrightTimeoutError:
        print(f"  ⚠️  Page {page_num} 載入逾時，嘗試繼續解析...")

    # 等待公司清單元素出現
    try:
        # 104 公司卡片的常見 selector
        await page.wait_for_selector(
            "a[href*='104.com.tw/company/']",
            timeout=15_000
        )
    except PlaywrightTimeoutError:
        print(f"  ❌  Page {page_num} 找不到公司卡片，跳過。")
        return results

    # 取得所有包含公司連結的 <a> 標籤
    anchors = await page.query_selector_all("a[href*='104.com.tw/company/']")

    seen_links = set()  # 去除重複
    for anchor in anchors:
        href = await anchor.get_attribute("href")
        if not href:
            continue
        # 過濾掉非公司內頁的連結（如搜尋頁、js 連結等）
        if "/company/search" in href or href.count("/company/") == 0:
            continue
        # 確保是完整 URL
        if href.startswith("//"):
            href = "https:" + href
        elif not href.startswith("http"):
            href = "https://www.104.com.tw" + href
        # 只保留 /company/{id} 格式
        if href in seen_links:
            continue
        seen_links.add(href)

        # 嘗試取得連結文字（公司名稱）
        text = (await anchor.inner_text()).strip()

        # 若連結本身文字為空，往父層找公司名稱
        if not text:
            parent = await anchor.query_selector("..")
            if parent:
                text = (await parent.inner_text()).strip()
            text = text.split("\n")[0].strip()  # 取第一行

        if text:
            results.append({
                "公司名稱": text,
                "104內頁連結": href,
            })

    print(f"  ✅  Page {page_num} 取得 {len(results)} 筆")
    return results


async def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    all_companies = []

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(
            headless=True,           # 不開啟可見視窗
            args=[
                "--no-sandbox",
                "--disable-blink-features=AutomationControlled",
            ]
        )
        context = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1280, "height": 800},
            locale="zh-TW",
        )

        # 隱藏 Playwright 特徵（避免被反爬機制偵測）
        await context.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
        """)

        page = await context.new_page()

        for page_num in range(1, TOTAL_PAGES + 1):
            companies = await scrape_page(page, page_num)
            all_companies.extend(companies)

            # 避免頻率過高被封鎖，隨機等待
            if page_num < TOTAL_PAGES:
                delay = random.uniform(BETWEEN_PAGE_MIN, BETWEEN_PAGE_MAX)
                await asyncio.sleep(delay)

        await browser.close()

    # ── 去重（以連結為唯一鍵）─────────────────────────────────────────────
    seen = set()
    unique_companies = []
    for item in all_companies:
        key = item["104內頁連結"]
        if key not in seen:
            seen.add(key)
            unique_companies.append(item)

    # ── 寫入 CSV ──────────────────────────────────────────────────────────
    with open(OUTPUT_FILE, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=["公司名稱", "104內頁連結"])
        writer.writeheader()
        writer.writerows(unique_companies)

    print("\n" + "=" * 60)
    print(f"✅ 爬蟲完成！共抓取 {len(unique_companies)} 家公司（去重後）")
    print(f"📄 輸出檔案：{OUTPUT_FILE}")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
