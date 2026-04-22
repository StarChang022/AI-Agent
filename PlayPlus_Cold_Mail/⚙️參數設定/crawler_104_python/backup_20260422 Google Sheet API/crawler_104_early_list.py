"""
crawler_104_early_list.py (Playwright + Google Sheets 版本)
===========================================================
從 104 人力銀行公司搜尋頁面爬取「公司名稱」與「公司連結」，
使用 Playwright 以處理 JavaScript 動態渲染。

資料來源（輸入）：
  ⌚️暫存/104_early_list.csv  → 要爬取的 104 搜尋頁 URL 清單

資料目的地（輸出）：
  Google Sheets 『名單副本』分頁
  - 公司品牌簡稱（A 欄）
  - 來源（H 欄，104 公司頁面 URL）

依照 1.104crawler初期名單.md 指令執行。

使用方式：
    python3 crawler_104_early_list.py

需要安裝的套件：
    pip install playwright google-auth google-auth-httplib2 google-api-python-client
    playwright install chromium
"""

import csv
import os
import time
import random
import re

from playwright.sync_api import sync_playwright
import gsheet_helper as gs

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# 從 ⌚️暫存/104_early_list.csv 讀取要爬取的頁面網址
PAGE_URL_CSV = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "..", "⌚️暫存", "104_early_list.csv")
)

# 每次請求之間的間隔秒數
DELAY_MIN = 3.0
DELAY_MAX = 6.0


# ──────────────────────────────────────────────
# 工具函式
# ──────────────────────────────────────────────

def load_urls_from_csv(csv_path: str) -> list[str]:
    """讀取 104_early_list.csv，回傳 URL 清單（跳過標題列）。"""
    urls = []
    if not os.path.exists(csv_path):
        print(f"[錯誤] 找不到 URL 設定檔：{csv_path}")
        return urls
    with open(csv_path, newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        for i, row in enumerate(reader):
            if i == 0 or not row:
                continue  # 跳過標題列與空列
            url = row[0].strip()
            if url.startswith("http"):
                urls.append(url)
    return urls


def fetch_companies_with_playwright(page, url: str) -> list[dict]:
    """
    使用 Playwright 爬取單一 104 公司搜尋頁面。
    """
    print(f"  正在載入頁面：{url}")
    companies = []

    try:
        page.goto(url, wait_until="load", timeout=60000)

        print("    等待頁面渲染動態內容...")
        time.sleep(5)

        page.mouse.wheel(0, 1500)
        time.sleep(1)

        links = page.query_selector_all('.company-lists__container a[href*="/company/"]')
        print(f"    偵測到 {len(links)} 個潛在公司連結")

        for link in links:
            href = link.get_attribute("href") or ""
            name = link.inner_text().strip()

            if "/company/" in href and len(name) >= 2:
                clean_url = href.split("?")[0].rstrip("/")
                if not clean_url.startswith("http"):
                    clean_url = "https:" + clean_url if clean_url.startswith("//") else "https://www.104.com.tw" + clean_url

                if "/main?" in clean_url:
                    continue

                blacklist = ["查看工作機會", "推薦好公司", "贊助", "為你推薦", "薪資排行榜", "外商公司", "產業地圖"]
                if any(kw in name for kw in blacklist):
                    continue

                if re.match(r'^\d+\.\d+$', name):
                    continue

                companies.append({"name": name, "url": clean_url})

    except Exception as e:
        print(f"  [錯誤] 爬取過程中發生異常：{e}")
        try:
            debug_path = f"debug_screenshot_{int(time.time())}.png"
            page.screenshot(path=debug_path)
            print(f"  [除錯] 已儲存錯誤截圖至：{debug_path}")
        except:
            pass

    # 去重
    unique_companies = []
    seen = set()
    for c in companies:
        if c["url"] not in seen:
            seen.add(c["url"])
            unique_companies.append(c)

    print(f"    → 找到 {len(unique_companies)} 筆公司資料")
    return unique_companies


# ──────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  104 人力銀行公司清單爬蟲 (Playwright + Google Sheets 版本)")
    print("=" * 60)

    # 讀取目標 URL 清單
    urls = load_urls_from_csv(PAGE_URL_CSV)
    if not urls:
        print("[錯誤] 沒有可爬取的網址，請確認 104_early_list.csv 內容。")
        return
    print(f"共讀取 {len(urls)} 個頁面網址\n")

    # 連接 Google Sheets
    print("[GSheet] 連接 Google Sheets...")
    service = gs.get_service()

    # 確保標題列存在，並取得現有來源（用於去重）
    gs.ensure_header(service)
    existing_sources = gs.get_existing_sources(service)
    print(f"[GSheet] 工作表已有 {len(existing_sources)} 筆來源記錄\n")

    # 取得現有欄位（以 Sheet 實際標題為準）
    _, fieldnames = gs.read_all_rows(service)
    if not fieldnames:
        fieldnames = gs.FIELDNAMES

    total_written = 0

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
        page = context.new_page()

        for i, url in enumerate(urls, start=1):
            print(f"[{i}/{len(urls)}] 處理頁面：{url}")
            companies = fetch_companies_with_playwright(page, url)

            if companies:
                # 過濾已存在的公司
                new_rows = []
                for c in companies:
                    clean_url = c["url"].split("?")[0].rstrip("/")
                    if clean_url not in existing_sources:
                        row = {field: "" for field in fieldnames}
                        row["公司品牌簡稱"] = c["name"]
                        row["來源"] = c["url"]
                        new_rows.append(row)
                        existing_sources.add(clean_url)

                if new_rows:
                    written = gs.append_rows(service, new_rows, fieldnames)
                    total_written += written
                    print(f"    → 成功寫入 {written} 筆新資料至 Google Sheets")
                else:
                    print("    → 全部已存在，無新資料")
            else:
                print("    [警告] 該頁未抓取到任何資料。")

            if i < len(urls):
                sleep_time = random.uniform(DELAY_MIN, DELAY_MAX)
                print(f"    等待 {sleep_time:.1f} 秒後處理下一頁...\n")
                time.sleep(sleep_time)

        browser.close()

    print("\n" + "=" * 60)
    print(f"  任務完成！共新增 {total_written} 筆公司資料")
    print(f"  Google Sheets：https://docs.google.com/spreadsheets/d/{gs.SPREADSHEET_ID}/edit")
    print("=" * 60)


if __name__ == "__main__":
    main()
