import os
import json
import asyncio
import time
import gspread
from google.oauth2.service_account import Credentials

# ================= 參數設定 =================
BASE_DIR         = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚙️參數 目錄
CREDENTIALS_FILE = os.path.join(BASE_DIR, 'eternal-skyline-494002-j8-356884d3e786.json')
TEMP_FILE        = os.path.join(BASE_DIR, 'temporary_104_profile.json')

SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'
WORKSHEET_NAME = '名單副本'  # gid=1539228012

# 並行爬蟲設定
CONCURRENT_PAGES = 2    # 同時開啟的瀏覽器分頁數（越高越快，但風險越大）
PAGE_TIMEOUT     = 25000  # 每頁等待上限 (ms)

# ⚠️ Cloudflare 會識別 headless 瀏覽器並封鎖 API。
# headless=False 讓 Chromium 以完整視窗模式運行，可通過 Cloudflare 驗證。
HEADLESS = False
# ==========================================


# ===== 步驟 1：從 Google Sheets 讀取名單 =====

def load_companies_from_sheet():
    """
    從 Google Sheets「名單」工作表讀取所有列，
    篩選 G欄（index 6）開頭為 https://www.104.com.tw/ 的列。
    回傳 list of dict，每筆含 row_index（1-based，含標題）、company_name、source_url。
    """
    print("[步驟 1] 連接 Google Sheets，讀取「名單」工作表...")
    scope = ['https://www.googleapis.com/auth/spreadsheets',
             'https://www.googleapis.com/auth/drive']
    creds  = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    sheet  = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)

    all_values = sheet.get_all_values()
    if not all_values:
        print("[警告] Google Sheets 內無資料。")
        return [], sheet

    headers = all_values[0]
    print(f"  → 標題列：{headers}")

    companies = []
    for i, row in enumerate(all_values[1:], start=2):  # 第 2 列起（sheet 1-based）
        # 補齊欄位防止 index out of range
        while len(row) < 9:
            row.append('')

        source_url   = row[6].strip()  # G欄（index 6）
        company_name = row[0].strip()  # A欄（index 0）
        profile_col  = row[8].strip()  # I欄（index 8）

        # 補齊至 H 欄（index 7）
        while len(row) < 8:
            row.append('')
        website_col  = row[7].strip()  # H欄（index 7）

        # 只處理 G欄以 https://www.104.com.tw/ 開頭的列
        if not source_url.startswith('https://www.104.com.tw/'):
            continue

        # 若 H欄（官方網站）和 I欄（公司介紹）都已有內容，跳過（避免重複爬取）
        if website_col and profile_col:
            print(f"  [略過] 第 {i} 列 {company_name}（H欄和I欄皆已有資料）")
            continue

        companies.append({
            'row_index':    i,
            'company_name': company_name,
            'source_url':   source_url,
        })

    print(f"  → 找到 {len(companies)} 間待爬取公司（G欄為 104 網址且 H欄或 I欄為空）")
    return companies, sheet


# ===== 步驟 2：Playwright 並行爬取各公司 104 頁面 =====

async def scrape_one_company(page, company):
    """
    爬取單一公司 104 頁面，透過頁面內 fetch() 呼叫 104 後端 JSON API，
    繼承 Cloudflare Cookie，取回公司簡介、經營理念、主要商品/服務。
    """
    url = company['source_url']

    # 解析 104 公司 ID（custNo）
    try:
        clean_url = url.split('?')[0].split('#')[0]
        cust_no   = clean_url.rstrip('/').split('/')[-1]
    except Exception:
        cust_no = ''

    if not cust_no:
        print(f"  [警告] 無法解析公司 ID：{url}")
        return {'row_index': company['row_index'], 'company_name': company['company_name'],
                'company_url': '', 'profile': '', 'success': False}

    try:
        # 步驟 A：載入公司主頁，觸發 Cloudflare 驗證並取得必要 Cookie
        await page.goto(url, wait_until='load', timeout=PAGE_TIMEOUT)
        await asyncio.sleep(1)  # 等待 Cookie 寫入

        # 步驟 B：在頁面 JS context 中呼叫 104 後端 API
        api_url = f'https://www.104.com.tw/api/companies/{cust_no}/content'
        data = await page.evaluate("""
            async (args) => {
                const { apiUrl, refererUrl } = args;
                try {
                    const res = await fetch(apiUrl, {
                        headers: {
                            'Accept': 'application/json, text/plain, */*',
                            'Referer': refererUrl,
                            'Origin': 'https://www.104.com.tw'
                        },
                        credentials: 'include'
                    });
                    if (!res.ok) return { error: res.status };
                    return await res.json();
                } catch(e) {
                    return { error: e.toString() };
                }
            }
        """, {'apiUrl': api_url, 'refererUrl': url})

        if not data or 'error' in data:
            err = data.get('error', 'unknown') if data else 'null response'
            print(f"  [除錯] API 回傳錯誤 ({cust_no}): {err}")
            return {'row_index': company['row_index'], 'company_name': company['company_name'],
                    'company_url': '', 'profile': '', 'success': False}

        # 步驟 C：解析 JSON 欄位
        # 已確認欄位：
        #   custLink → 公司官方網站 URL
        #   profile  → 公司簡介
        #   operate  → 經營理念
        #   product  → 主要商品 / 服務項目
        d = data.get('data', {}) or {}

        company_url = (d.get('custLink') or '').strip()  # 官方網站
        profile1    = (d.get('profile')  or '').strip()  # 公司簡介
        profile2    = (d.get('operate')  or '').strip()  # 經營理念
        profile3    = (d.get('product')  or '').strip()  # 主要商品/服務

        parts   = [p for p in [profile1, profile2, profile3] if p]
        profile = '\n\n'.join(parts)

        if not profile and not company_url:
            print(f"  [除錯] API 成功但欄位全空 ({cust_no})，keys: {list(d.keys())[:12]}")
            return {'row_index': company['row_index'], 'company_name': company['company_name'],
                    'company_url': '', 'profile': '', 'success': False}

        return {
            'row_index':    company['row_index'],
            'company_name': company['company_name'],
            'company_url':  company_url,
            'profile':      profile,
            'success':      True
        }

    except Exception as e:
        print(f"  [警告] {company['company_name']} ({url}) 爬取失敗：{e}")
        return {'row_index': company['row_index'], 'company_name': company['company_name'],
                'company_url': '', 'profile': '', 'success': False}


async def scrape_all_companies(companies):
    """使用 Playwright 並行爬取所有公司頁面"""
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print("[錯誤] 找不到 playwright。請先執行：")
        print("  python3 -m pip install playwright")
        print("  python3 -m playwright install chromium")
        return []

    results  = []
    semaphore = asyncio.Semaphore(CONCURRENT_PAGES)

    async def bounded_scrape(context, company):
        async with semaphore:
            page = await context.new_page()
            try:
                return await scrape_one_company(page, company)
            finally:
                await page.close()

    async with async_playwright() as p:
        mode_label = "有界面模式（繞過 Cloudflare）" if not HEADLESS else "Headless 模式"
        print(f"\n[步驟 2] 啟動 Chromium（並行 {CONCURRENT_PAGES} 頁，{mode_label}）...")
        browser = await p.chromium.launch(
            headless=HEADLESS,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--no-sandbox',
                '--disable-dev-shm-usage'
            ]
        )
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800},
            locale="zh-TW",
            timezone_id="Asia/Taipei"
        )

        # 抹除 navigator.webdriver 自動化特徵
        await context.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            });
        """)

        tasks = [bounded_scrape(context, c) for c in companies]
        total = len(tasks)
        done  = 0

        for coro in asyncio.as_completed(tasks):
            result = await coro
            results.append(result)
            done += 1
            status = '✓' if result['success'] else '✗'
            print(f"  [{status}] ({done}/{total}) {result['company_name']}")

        await context.close()
        await browser.close()
        print("  → 瀏覽器已關閉。")

    return results


# ===== 步驟 3：暫存結果至本地 JSON =====

def save_temp(results):
    os.makedirs(os.path.dirname(TEMP_FILE), exist_ok=True)
    with open(TEMP_FILE, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"\n[暫存] 已儲存至 {TEMP_FILE}")


# ===== 步驟 4：批次寫回 Google Sheets（更新 H 欄官方網站 + I 欄公司介紹）=====

def write_back_to_sheet(sheet, results):
    """
    精確更新各列的 H 欄（官方網站，index 7）和 I 欄（公司介紹，index 8），
    不觸碰其他欄位。使用 batch_update 一次送出所有更新，減少 API 呼叫次數。
    """
    success_results = [r for r in results if r['success']]
    if not success_results:
        print("[警告] 無成功結果可寫回。")
        return

    print(f"\n[步驟 4] 批次寫回 Google Sheets，共 {len(success_results)} 筆...")

    BATCH = 200
    for i in range(0, len(success_results), BATCH):
        chunk = success_results[i:i + BATCH]
        updates = []
        for r in chunk:
            row_idx = r['row_index']
            # H欄：官方網站（只在有值時才更新，避免覆蓋已有資料）
            if r.get('company_url'):
                updates.append({
                    'range':  f'H{row_idx}',
                    'values': [[r['company_url']]]
                })
            # I欄：公司介紹（只在有值時才更新）
            if r.get('profile'):
                updates.append({
                    'range':  f'I{row_idx}',
                    'values': [[r['profile']]]
                })
        try:
            if updates:
                sheet.batch_update(updates)
        except Exception as e:
            print(f"  [警告] 批次寫入失敗：{e}")
        rows_info = f"{chunk[0]['row_index']} ~ {chunk[-1]['row_index']}"
        print(f"  → 已寫入第 {rows_info} 列的 H欄（官方網站）和 I欄（公司介紹）")
        if i + BATCH < len(success_results):
            time.sleep(1)  # 避免觸發 API 速率限制

    print("  → Google Sheets H欄、I欄 寫入完成！")


# ===== 主程式 =====

def main():
    print("=== 104 撈取公司資料爬蟲 (PlayPlus_Sales 版) ===\n")

    # 1. 從 Google Sheets 讀取名單，取得待爬取公司清單
    companies, sheet = load_companies_from_sheet()
    if not companies:
        print("  → 無公司需要爬取，結束。")
        return

    # 2. 並行爬取所有公司 104 頁面
    results = asyncio.run(scrape_all_companies(companies))
    success_count = sum(1 for r in results if r['success'])
    print(f"\n  → 完成：{success_count}/{len(results)} 筆成功爬取。")

    # 3. 暫存至本地 JSON（支援事後查閱）
    print("\n[步驟 3] 暫存爬蟲結果...")
    save_temp(results)

    # 4. 精確寫回 Google Sheets I欄
    write_back_to_sheet(sheet, results)

    print("\n=== 全部完成 ===")


if __name__ == '__main__':
    main()
