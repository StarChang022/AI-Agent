import os
import csv
import asyncio

# ================= 參數設定 =================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
URL_LIST_FILE = os.path.join(BASE_DIR, '⌚️暫存', '104_early_list.csv')  # 讀取網址清單
TEMP_FILE = os.path.join(BASE_DIR, '⌚️暫存', '104_early_list_temporary.csv')

PAGE_DELAY = 2   # 換頁等待秒數（避免被封鎖）
# ==========================================

def load_urls():
    """從 104_early_list.csv 讀取要爬取的網址清單"""
    if not os.path.exists(URL_LIST_FILE):
        print(f"[錯誤] 找不到網址清單：{URL_LIST_FILE}")
        return []
    urls = []
    with open(URL_LIST_FILE, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        next(reader, None)  # 跳過標題列
        for row in reader:
            if row and row[0].strip():
                urls.append(row[0].strip())
    return urls

async def scrape_all_pages(urls):
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print("[錯誤] 找不到 playwright。請先執行：")
        print("  python3 -m pip install playwright")
        print("  python3 -m playwright install chromium")
        return []

    all_companies = []
    seen_urls = set()

    async with async_playwright() as p:
        # 優先嘗試使用本機真實安裝的 Chrome（最有效繞過反爬蟲）
        # 若沒有安裝 Chrome，則退回使用 Playwright 的 Chromium（顯示視窗模式）
        print("啟動瀏覽器（顯示視窗模式，可最有效繞過反爬蟲）...")
        try:
            browser = await p.chromium.launch(
                channel='chrome',   # 使用本機安裝的 Google Chrome
                headless=False,     # 顯示視窗，繞過 headless 偵測
                args=['--no-sandbox', '--disable-blink-features=AutomationControlled']
            )
            print("  → 使用本機 Google Chrome")
        except Exception:
            browser = await p.chromium.launch(
                headless=False,     # 至少確保非 headless
                args=['--no-sandbox', '--disable-blink-features=AutomationControlled']
            )
            print("  → 使用 Playwright Chromium（視窗模式）")

        context = await browser.new_context(
            user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            locale='zh-TW',
            timezone_id='Asia/Taipei',
            viewport={'width': 1440, 'height': 900},
        )
        page = await context.new_page()

        for i, url in enumerate(urls, 1):
            print(f"[進度] 第 {i}/{len(urls)} 頁：{url}")

            success = False
            for attempt in range(1, 4):  # 最多重試 3 次
                try:
                    await page.goto(url, wait_until='domcontentloaded', timeout=30000)
                    # 等待 3 秒讓 JS 渲染
                    await asyncio.sleep(3)
                    # 嘗試等待公司連結（不需可見，只要在 DOM 存在）
                    await page.wait_for_selector('a[class*="company-name-link"]', state='attached', timeout=10000)
                    success = True
                    break
                except Exception as e:
                    # 截圖協助診斷（只在第一次失敗時）
                    if attempt == 1:
                        debug_path = os.path.join(BASE_DIR, '⌚️暫存', f'debug_page_{i}.png')
                        try:
                            await page.screenshot(path=debug_path)
                            print(f"  [診斷] 截圖已儲存：{debug_path}")
                        except Exception:
                            pass
                    print(f"[警告] 第 {i} 頁第 {attempt} 次嘗試失敗：{e}")
                    if attempt < 3:
                        print(f"  → 等待 5 秒後重試...")
                        await asyncio.sleep(5)

            if not success:
                print(f"[錯誤] 第 {i} 頁連續失敗 3 次，跳過此頁。")
                continue

            # 小等 1 秒讓 JS 渲染完成
            await asyncio.sleep(1)

            # 抓取公司名稱與 URL（同時支援 PC 和 mobile 版結構）
            companies = await page.evaluate('''
                () => {
                    // a[class*="company-name-link"] 同時配對 PC(–-pc) 和 mobile(–-mobile)
                    // 共會抓到兩個版本的同一公司，用 URL 去重即可
                    const links = document.querySelectorAll('a[class*="company-name-link"]');
                    const seen = new Set();
                    const results = [];
                    for (const a of links) {
                        const href = a.href;
                        if (href && href.includes('/company/') && !seen.has(href)) {
                            seen.add(href);
                            results.push({
                                name: (a.getAttribute('title') || a.innerText || '').trim(),
                                url: href
                            });
                        }
                    }
                    return results.filter(c => c.name && c.url);
                }
            ''')

            print(f"  [調試] JS 共發現 {len(companies)} 個公司")


            new_count = 0
            for c in companies:
                if c['url'] not in seen_urls:
                    seen_urls.add(c['url'])
                    all_companies.append({'CompanyName': c['name'], '104URL': c['url']})
                    new_count += 1

            print(f"  → 此頁取得 {len(companies)} 筆，新增 {new_count} 筆，累計 {len(all_companies)} 筆")

            # 換頁前等待（非最後一頁才等）
            if i < len(urls):
                await asyncio.sleep(PAGE_DELAY)

        await browser.close()
        print("瀏覽器已關閉。")

    return all_companies





def main():
    print("=== 104 初期名單爬蟲 (Playwright 版) ===\n")

    # 讀取網址清單
    urls = load_urls()
    if not urls:
        return
    print(f"從 {URL_LIST_FILE} 讀取到 {len(urls)} 個頁面網址。\n")

    # 執行非同步爬蟲
    companies = asyncio.run(scrape_all_pages(urls))
    print(f"\n總計爬取到 {len(companies)} 間公司。")

    if not companies:
        print("未取得任何資料，請確認 Playwright 是否已安裝。")
        print("安裝指令：")
        print("  python3 -m pip install playwright")
        print("  python3 -m playwright install chromium")
        return

    # 儲存至本地 CSV
    os.makedirs(os.path.dirname(TEMP_FILE), exist_ok=True)
    print(f"儲存至：{TEMP_FILE}")
    with open(TEMP_FILE, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['CompanyName', '104URL'])
        writer.writeheader()
        writer.writerows(companies)
    print(f"儲存完成，共 {len(companies)} 筆。")


if __name__ == '__main__':
    main()
