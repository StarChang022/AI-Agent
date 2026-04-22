"""
crawler_104_company_url.py
==========================
依照 2.104crawler公司網址.md 指令執行。
使用 Playwright 以處理 JavaScript 動態渲染。

流程：
  1. 讀取 ../../冷郵件對象/名單副本.csv 的「來源」欄位（104 公司頁面 URL）
  2. 使用 Playwright 進入每個 URL，等待頁面渲染後尋找「公司網址」
  3. 找到 → 將網址寫入「官方網站」欄位
     找不到 → 刪除該列
  4. 結果回存至同一個 CSV（過程中自動建立備份）。

CSV 欄位（共 8 欄）：
  公司品牌簡稱, 序號, 官方網站（本腳本填寫）, 產業, 員工人數, email, 聯絡人名稱, 來源, 說明

使用方式：
    python3 crawler_104_company_url.py

需要安裝的套件：
    pip install playwright
    playwright install chromium
"""

import csv
import os
import re
import shutil
import time
import random
from datetime import datetime
from typing import List, Dict, Optional

from playwright.sync_api import sync_playwright

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "..", "冷郵件對象", "名單副本.csv")
)

# 請求間隔（秒）：降低延遲加速執行
DELAY_MIN = 1.0
DELAY_MAX = 2.5

# 連線逾時（秒）
TIMEOUT = 30000  # Playwright 使用毫秒


# ──────────────────────────────────────────────
# 工具函式
# ──────────────────────────────────────────────

def backup_csv(csv_path: str) -> str:
    """備份 CSV，回傳備份路徑。"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = csv_path.replace(".csv", f"_backup_{timestamp}.csv")
    shutil.copy2(csv_path, backup_path)
    print(f"[備份] 已建立備份：{os.path.basename(backup_path)}")
    return backup_path


def load_csv(csv_path: str) -> tuple[List[Dict], List[str]]:
    """讀取 CSV，回傳所有列（dict 格式）與欄位名稱清單。"""
    rows = []
    fieldnames = []
    if not os.path.exists(csv_path):
        return rows, fieldnames
    with open(csv_path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames) if reader.fieldnames else []
        for row in reader:
            rows.append(dict(row))
    return rows, fieldnames


def save_csv(csv_path: str, rows: List[Dict], fieldnames: List[str]) -> None:
    """將列清單重新寫入 CSV。"""
    with open(csv_path, newline="", encoding="utf-8-sig", mode="w") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, lineterminator="\r\n")
        writer.writeheader()
        writer.writerows(rows)


def fetch_company_website(page, url: str) -> Optional[str]:
    """
    使用 Playwright 進入 104 公司頁面，嘗試取得「公司網址」。
    """
    try:
        # 導向 URL，使用 domcontentloaded 可加快進入頁面速度
        page.goto(url, wait_until="domcontentloaded", timeout=TIMEOUT)
        
        # 等待主要內容區塊載入
        print("        等待頁面渲染...")
        page.wait_for_timeout(1000)
        
        # 優先策略 1: 使用 104 的 data-gtm-content 標籤 (非常準確)
        website_link = page.query_selector('a[data-gtm-content="公司網址"]')
        if website_link:
            href = website_link.get_attribute("href")
            if href and "104.com.tw" not in href:
                return href

        # 優先策略 2: 尋找 .intro-table__data 中包含的連結
        items = page.query_selector_all('.intro-table__data')
        for item in items:
            # 檢查其前一個兄弟元素是否包含「公司網址」
            header = item.evaluate("el => el.previousElementSibling ? el.previousElementSibling.innerText : \"\"")
            if "公司網址" in str(header):
                anchor = item.query_selector('a')
                if anchor:
                    href = anchor.get_attribute("href")
                    if href and "104.com.tw" not in href:
                        return href

        # 策略 3: 搜尋所有連結，過濾出非 104 的外部連結
        all_links = page.query_selector_all('a[href^="http"]')
        for link in all_links:
            href = link.get_attribute("href") or ""
            
            # 排除 104 內部連結與常見社群媒體 (除非是官網)
            if any(domain in href for domain in ["104.com.tw", "facebook.com", "line.me", "instagram.com", "youtube.com"]):
                continue
                
            # 檢查其父層或連結文字是否包含關鍵字
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
    print("  104 公司頁面 → 官方網站爬蟲 (Playwright 版)")
    print("=" * 60)
    print(f"目標 CSV：{CSV_PATH}\n")

    if not os.path.exists(CSV_PATH):
        print(f"[錯誤] CSV 不存在：{CSV_PATH}")
        return

    # 備份原始 CSV
    backup_csv(CSV_PATH)

    # 讀取所有列與欄位名
    rows, fieldnames = load_csv(CSV_PATH)
    print(f"共讀取 {len(rows)} 列資料 (欄位數: {len(fieldnames)})\n")

    kept_rows = []      # 保留的列
    deleted_count = 0   # 刪除的列數
    updated_count = 0   # 成功填入官方網站的列數
    skipped_count = 0   # 略過的列數

    with sync_playwright() as p:
        # 啟動瀏覽器
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
        page = context.new_page()

        total = len(rows)
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
                # 找不到公司網址 → 刪除該列
                deleted_count += 1
                print(f"        ❌ 無公司網址，刪除此列")

            # 隨機間隔
            if i < total:
                delay = random.uniform(DELAY_MIN, DELAY_MAX)
                time.sleep(delay)

        browser.close()

    # 回存 CSV
    save_csv(CSV_PATH, kept_rows, fieldnames)

    print("\n" + "=" * 60)
    print(f"  完成！")
    print(f"  ✅ 填入官方網站：{updated_count} 列")
    print(f"  ❌ 刪除（無官網）：{deleted_count} 列")
    print(f"  ⏭  略過：{skipped_count} 列")
    print(f"  📄 最終保留：{len(kept_rows)} 列")
    print(f"  寫入位置：{CSV_PATH}")
    print("=" * 60)


if __name__ == "__main__":
    main()
