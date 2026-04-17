"""
crawler_104_early_list.py (Playwright 版本)
=========================================
從 104 人力銀行公司搜尋頁面爬取「公司名稱」與「公司連結」，
使用 Playwright 以處理 JavaScript 動態渲染。

寫入 ../../冷郵件對象/名單副本.csv 的
  - 公司品牌簡稱（欄位索引 0）
  - 來源（欄位索引 8）

依照 1.104crawler初期名單.md 指令執行。

使用方式：
    python3 crawler_104_early_list.py

需要安裝的套件：
    pip install playwright
    playwright install chromium
"""

import csv
import os
import time
import random
import re

from playwright.sync_api import sync_playwright

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

# 腳本所在目錄
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# 從 ⌚️暫存/104_early_list.csv 讀取要爬取的頁面網址
PAGE_URL_CSV = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "..", "⌚️暫存", "104_early_list.csv")
)

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

URLS = load_urls_from_csv(PAGE_URL_CSV)

# 名單 CSV 路徑
CSV_PATH = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "..", "冷郵件對象", "名單副本.csv")
)

# CSV 欄位定義
FIELDNAMES = [
    "公司品牌簡稱", "序號", "官方網站", "產業", "員工人數",
    "email", "聯絡人名稱", "聯絡人職稱", "來源",
    "徵才職缺名稱", "說明", "備註"
]

# 每次請求之間的間隔秒數
DELAY_MIN = 3.0
DELAY_MAX = 6.0


# ──────────────────────────────────────────────
# 工具函式
# ──────────────────────────────────────────────

def load_existing_sources(csv_path: str) -> set:
    """讀取 CSV，回傳已存在的「來源」URL 集合（避免重複寫入）。"""
    existing = set()
    if not os.path.exists(csv_path):
        return existing
    try:
        with open(csv_path, newline="", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                src = row.get("來源", "").strip()
                if src:
                    # 標準化 URL 比對
                    clean_src = src.split("?")[0].rstrip("/")
                    existing.add(clean_src)
    except Exception as e:
        print(f"[警告] 讀取既有 CSV 失敗：{e}")
    return existing


def fetch_companies_with_playwright(page, url: str) -> list[dict]:
    """
    使用 Playwright 爬取單一 104 公司搜尋頁面。
    """
    print(f"  正在載入頁面：{url}")
    companies = []
    
    try:
        # 導向 URL 並等待基礎頁面載入
        page.goto(url, wait_until="load", timeout=60000)
        
        # 104 是高度動態網站，強制等待幾秒讓 AJAX 數據跑完並渲染列表
        print("    等待頁面渲染動態內容...")
        time.sleep(5)
        
        # 模擬滾動頁面
        page.mouse.wheel(0, 1500)
        time.sleep(1)
        
        # 直接抓取所有可能是公司連結的標籤，並將範圍限縮在使用者指定的容器內
        links = page.query_selector_all('.company-lists__container a[href*="/company/"]')
        print(f"    偵測到 {len(links)} 個潛在公司連結")
        
        for link in links:
            href = link.get_attribute("href") or ""
            name = link.inner_text().strip()
            
            # 過濾條件：
            # 1. 網址必須包含 /company/
            # 2. 名稱長度必須大於 2 (過濾掉圖示、按鈕或空白)
            if "/company/" in href and len(name) >= 2:
                # 標準化 URL
                clean_url = href.split("?")[0].rstrip("/")
                if not clean_url.startswith("http"):
                    clean_url = "https:" + clean_url if clean_url.startswith("//") else "https://www.104.com.tw" + clean_url
                
                # 排除一些常見的非公司列表連結 (如有)
                if "/main?" in clean_url: continue 
                
                # 排除雜訊名稱
                blacklist = ["查看工作機會", "推薦好公司", "贊助", "為你推薦", "薪資排行榜", "外商公司", "產業地圖"]
                if any(kw in name for kw in blacklist):
                    continue
                
                # 排除純數字評分 (例如 5.0) 或太短的名稱
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


def append_to_csv(csv_path: str, companies: list[dict], existing_sources: set) -> int:
    """將新公司資料附加寫入 CSV。"""
    written = 0
    file_exists = os.path.exists(csv_path) and os.path.getsize(csv_path) > 0
    
    current_fieldnames = FIELDNAMES
    if file_exists:
        # 動態讀取現有檔案的標題列（欄位）
        with open(csv_path, newline="", encoding="utf-8-sig") as f:
            reader = csv.reader(f)
            header = next(reader, None)
            if header:
                current_fieldnames = header
    
    # 若檔案不存在或大小為0，則載入時 existing_sources 會是空的，且需要寫入 header
    mode = "a" if file_exists else "w"
    
    with open(csv_path, newline="", encoding="utf-8-sig", mode=mode) as f:
        writer = csv.DictWriter(f, fieldnames=current_fieldnames, lineterminator="\r\n")
        if not file_exists:
            writer.writeheader()
            
        for company in companies:
            clean_url = company["url"].split("?")[0].rstrip("/")
            if clean_url in existing_sources:
                continue
                
            row = {field: "" for field in current_fieldnames}
            if "公司品牌簡稱" in current_fieldnames:
                row["公司品牌簡稱"] = company["name"]
            if "來源" in current_fieldnames:
                row["來源"] = company["url"]
            writer.writerow(row)
            existing_sources.add(clean_url)
            written += 1
            
    return written


# ──────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  104 人力銀行公司清單爬蟲 (Playwright 版本)")
    print("=" * 60)
    print(f"目標 CSV：{CSV_PATH}\n")

    # 確保目錄存在
    os.makedirs(os.path.dirname(CSV_PATH), exist_ok=True)

    # 載入已存在的來源（用於去重）
    existing_sources = load_existing_sources(CSV_PATH)
    print(f"CSV 中已有 {len(existing_sources)} 筆來源記錄\n")

    total_written = 0

    with sync_playwright() as p:
        # 啟動瀏覽器（開啟無頭模式，讓腳本安靜在背景執行不干擾使用者）
        browser = p.chromium.launch(headless=True)
        # 設定 context (模擬正常的瀏覽器環境)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800}
        )
        page = context.new_page()

        for i, url in enumerate(URLS, start=1):
            print(f"[{i}/{len(URLS)}] 處理頁面：{url}")
            companies = fetch_companies_with_playwright(page, url)

            if companies:
                written = append_to_csv(CSV_PATH, companies, existing_sources)
                total_written += written
                print(f"    → 成功寫入 {written} 筆新資料")
            else:
                print("    [警告] 該頁未抓取到任何資料。")

            # 等待隨機時間
            if i < len(URLS):
                sleep_time = random.uniform(DELAY_MIN, DELAY_MAX)
                print(f"    等待 {sleep_time:.1f} 秒後處理下一頁...\n")
                time.sleep(sleep_time)

        browser.close()

    print("\n" + "=" * 60)
    print(f"  任務完成！共新增 {total_written} 筆公司資料")
    print(f"  最終資料筆數：{len(existing_sources)}")
    print(f"  檔案位置：{CSV_PATH}")
    print("=" * 60)


if __name__ == "__main__":
    main()
