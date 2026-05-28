import os
import csv
import json
import asyncio
import time
import gspread
from google.oauth2.service_account import Credentials

# ================= 參數設定 =================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCAL_CSV = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
TEMP_FILE = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')
CREDENTIALS_FILE = os.path.join(BASE_DIR, '⚙️參數設定', 'eternal-skyline-494002-j8-356884d3e786.json')

SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'
WORKSHEET_NAME = '名單副本'  # gid=1168472169

# 並行爬蟲設定
CONCURRENT_PAGES = 1    # 同時開啟的瀏覽器分頁數（越高越快，但風險越大）
PAGE_TIMEOUT = 25000    # 每頁等待上限 (ms)

# ⚠️ Cloudflare 會識別 headless 瀏覽器並封鎖 API。
# headless=False 讓 Chromium 以完整視窗模式運行，可通過 Cloudflare 驗證。
# 若需要在伺服器（無螢幕環境）執行，可改用 Xvfb 虛擬顯示。
HEADLESS = False
# ==========================================


# ===== 步驟 1：從 Google Sheets 下載名單至本地 =====

def download_sheet_to_csv():
    """從 Google Sheets 下載「名單副本」並覆寫至本地 CSV"""
    print("[步驟 1] 連接 Google Sheets，下載名單副本...")
    scope = ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
    creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    sheet = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)

    all_values = sheet.get_all_values()
    if not all_values:
        print("[警告] Google Sheets 內無資料。")
        return []

    os.makedirs(os.path.dirname(LOCAL_CSV), exist_ok=True)
    with open(LOCAL_CSV, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(all_values)

    print(f"  → 已下載 {len(all_values) - 1} 筆資料至 {LOCAL_CSV}")
    return all_values


# ===== 步驟 2：讀取本地 CSV，取得公司 104 頁面 URL =====

def load_companies_from_csv():
    """讀取本地 CSV，回傳公司列表（含 row index 和 H欄的 104URL）"""
    if not os.path.exists(LOCAL_CSV):
        print(f"[錯誤] 找不到本地 CSV：{LOCAL_CSV}")
        return []

    companies = []
    with open(LOCAL_CSV, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        rows = list(reader)

    if len(rows) < 2:
        print("[警告] CSV 內無資料列。")
        return []

    headers = rows[0]
    print(f"  → CSV 標題列：{headers}")

    for i, row in enumerate(rows[1:], start=2):  # 第 2 列起（1-indexed）
        while len(row) < 11:
            row.append('')

        # H欄（index=7）是來源（104 公司頁面 URL）
        source_url = row[7].strip() if len(row) > 7 else ''
        company_name = row[0].strip() if len(row) > 0 else ''

        if source_url and source_url.startswith('http'):
            companies.append({
                'row_index': i,
                'row_data': row,
                'company_name': company_name,
                'source_url': source_url,
            })

    print(f"  → 找到 {len(companies)} 間有效公司（H欄有網址）")
    return companies


# ===== 步驟 3：Playwright 並行爬取各公司頁面資料 =====

async def scrape_one_company(page, company):
    """
    爬取單一公司的 104 頁面資料。

    核心策略：
    1. 以 headless=False（非無頭模式）啟動 Chromium，通過 Cloudflare 指紋檢測。
    2. 載入公司主頁後，在頁面 JS 上下文中以 fetch() 呼叫 104 後端 JSON API，
       繼承頁面 Cookie（包含 Cloudflare cf_clearance）取回完整資料。

    已確認的 API 回傳欄位：
      - custLink  : 公司官方網站 URL
      - profile   : 公司簡介（長文）
      - product   : 主要商品/服務（可作為 profile2）
    """
    url = company['source_url']

    try:
        cust_no = url.rstrip('/').split('/')[-1]
    except Exception:
        cust_no = ''

    if not cust_no:
        print(f"  [警告] 無法解析公司 ID：{url}")
        return {
            'row_index': company['row_index'], 'row_data': company['row_data'],
            'companyURL': '', 'profile1': '', 'profile2': '', 'success': False
        }

    try:
        # 步驟 A：載入公司主頁，觸發 Cloudflare 驗證並取得必要 Cookie
        await page.goto(url, wait_until='load', timeout=PAGE_TIMEOUT)
        await asyncio.sleep(1)  # 等待 Cookie 寫入

        # 步驟 B：在頁面 JS context 中以 fetch() 呼叫 API
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
            return {
                'row_index': company['row_index'], 'row_data': company['row_data'],
                'companyURL': '', 'profile1': '', 'profile2': '', 'success': False
            }

        # 步驟 C：解析 JSON 欄位（依實測確認欄位名稱）
        d = data.get('data', {}) or {}

        company_url = (d.get('custLink') or '').strip()
        profile1    = (d.get('profile') or '').strip()
        profile2    = (d.get('product') or '').strip()   # 主要商品/服務

        if not profile1 and not profile2 and not company_url:
            print(f"  [除錯] API 成功但欄位全空 ({cust_no})，keys: {list(d.keys())[:12]}")
            return {
                'row_index': company['row_index'], 'row_data': company['row_data'],
                'companyURL': '', 'profile1': '', 'profile2': '', 'success': False
            }

        return {
            'row_index': company['row_index'],
            'row_data':  company['row_data'],
            'companyURL': company_url,
            'profile1':   profile1,
            'profile2':   profile2,
            'success': True
        }

    except Exception as e:
        print(f"  [警告] {company['company_name']} ({url}) 爬取失敗：{e}")
        return {
            'row_index': company['row_index'], 'row_data': company['row_data'],
            'companyURL': '', 'profile1': '', 'profile2': '', 'success': False
        }


async def scrape_all_companies(companies):
    """使用 Playwright 並行爬取所有公司頁面"""
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print("[錯誤] 找不到 playwright。請先執行：")
        print("  python3 -m pip install playwright")
        print("  python3 -m playwright install chromium")
        return []

    results = []
    semaphore = asyncio.Semaphore(CONCURRENT_PAGES)

    async def bounded_scrape(context, company):
        async with semaphore:
            page = await context.new_page()
            try:
                r = await scrape_one_company(page, company)
                return r
            finally:
                await page.close()

    async with async_playwright() as p:
        mode_label = "有界面模式（繞過 Cloudflare）" if not HEADLESS else "Headless 模式"
        print(f"\n[步驟 3] 啟動 Chromium（並行 {CONCURRENT_PAGES} 頁，{mode_label}）...")
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

        done = 0
        for coro in asyncio.as_completed(tasks):
            result = await coro
            results.append(result)
            done += 1
            status = '✓' if result['success'] else '✗'
            print(f"  [{status}] ({done}/{total}) {result['row_data'][0] if result['row_data'] else '?'}")

        await context.close()
        await browser.close()
        print("  → 瀏覽器已關閉。")

    return results


# ===== 步驟 4：暫存結果至本地 JSON =====

def save_temp(results):
    os.makedirs(os.path.dirname(TEMP_FILE), exist_ok=True)
    with open(TEMP_FILE, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"\n[暫存] 已儲存至 {TEMP_FILE}")


# ===== 步驟 5：更新本地 CSV =====

def update_local_csv(companies_map, all_rows):
    """根據爬取結果更新本地 CSV"""
    updated_rows = [all_rows[0]]  # 保留標題列

    for i, row in enumerate(all_rows[1:], start=2):
        while len(row) < 11:
            row.append('')

        if i in companies_map:
            r = companies_map[i]
            # 拼接兩段說明
            profile_parts = [r['profile1'], r['profile2']]
            profile_combined = '\n'.join(p for p in profile_parts if p)

            row[2] = r['companyURL']    # C欄: 官方網站
            row[8] = profile_combined   # I欄: 說明

        updated_rows.append(row)

    with open(LOCAL_CSV, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(updated_rows)

    print(f"[本地] 已更新 {LOCAL_CSV}")
    return updated_rows


# ===== 步驟 6：批次寫回 Google Sheets =====

def write_back_to_sheet(updated_rows):
    """將更新後的資料批次覆寫至 Google Sheets（保留標題列）"""
    if len(updated_rows) < 2:
        print("[警告] 無資料可寫回。")
        return

    print(f"\n[步驟 6] 連接 Google Sheets，批次寫入 {len(updated_rows) - 1} 筆...")
    scope = ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
    creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    sheet = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)

    data_rows = updated_rows[1:]  # 只寫資料列，不蓋標題

    try:
        sheet.batch_clear(['A2:K'])
    except Exception as e:
        print(f"  [警告] 清除舊資料失敗：{e}")

    BATCH = 500
    for i in range(0, len(data_rows), BATCH):
        chunk = data_rows[i:i + BATCH]
        start_row = 2 + i
        try:
            sheet.update(values=chunk, range_name=f'A{start_row}')
        except Exception as e:
            print(f"  [警告] 寫入失敗：{e}")
        print(f"  → 已寫入第 {start_row} ~ {start_row + len(chunk) - 1} 列")
        if i + BATCH < len(data_rows):
            time.sleep(1)

    print("  → Google Sheets 寫入完成！")


# ===== 主程式 =====

def main():
    print("=== 104 撈取公司資料爬蟲 (Playwright 版) ===\n")

    # 1. 下載 Google Sheets → 本地 CSV
    all_rows_raw = download_sheet_to_csv()
    if not all_rows_raw:
        return

    # 2. 讀取本地 CSV，找出有效公司清單
    print("\n[步驟 2] 讀取本地 CSV，解析有效公司...")
    companies = load_companies_from_csv()
    if not companies:
        print("  → 無公司可爬，結束。")
        return

    # 3. 並行爬取所有公司頁面
    results = asyncio.run(scrape_all_companies(companies))
    success_count = sum(1 for r in results if r['success'])
    print(f"\n  → 完成：{success_count}/{len(results)} 筆成功爬取。")

    # 4. 暫存至本地 JSON
    print("\n[步驟 4] 暫存爬蟲結果...")
    save_temp(results)

    # 5. 更新本地 CSV
    print("\n[步驟 5] 更新本地 CSV...")
    with open(LOCAL_CSV, 'r', encoding='utf-8') as f:
        all_rows = list(csv.reader(f))

    # 僅篩選 success == True 的項目進行更新，防止空資料覆寫現有名單
    companies_map = {r['row_index']: r for r in results if r['success']}
    updated_rows = update_local_csv(companies_map, all_rows)

    # 6. 批次寫回 Google Sheets
    write_back_to_sheet(updated_rows)

    print("\n=== 全部完成 ===")


if __name__ == '__main__':
    main()
