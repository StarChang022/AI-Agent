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
PAGE_TIMEOUT = 20000    # 每頁等待上限 (ms)
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
        # 確保 row 有足夠欄位
        while len(row) < 11:
            row.append('')

        # H欄（index=7）是來源（104 公司頁面 URL）
        source_url = row[7].strip() if len(row) > 7 else ''
        company_name = row[0].strip() if len(row) > 0 else ''

        if source_url and source_url.startswith('http'):
            companies.append({
                'row_index': i,     # CSV 中的列號（從 1 計算）
                'row_data': row,    # 原始列資料
                'company_name': company_name,
                'source_url': source_url,   # H欄：104 公司頁面
            })

    print(f"  → 找到 {len(companies)} 間有效公司（H欄有網址）")
    return companies


# ===== 步驟 3：Playwright 並行爬取各公司頁面資料 =====

async def scrape_one_company(page, company):
    """爬取單一公司的 104 頁面資料"""
    url = company['source_url']
    try:
        await page.goto(url, wait_until='load', timeout=PAGE_TIMEOUT)
        
        # 等待特定元素出現，確保 CSR 渲染完成（最多等 10 秒）
        try:
            await page.wait_for_selector('p.intro-profile', timeout=10000)
        except Exception as e:
            print(f"  [除錯] 等待元素超時 ({url})")
        
        await asyncio.sleep(2)  # 額外等待確保元素綁定完成

        company_url = ''
        try:
            url_el = await page.query_selector('a[data-gtm-content="公司網址"]')
            if url_el:
                company_url = await url_el.get_attribute('href')
        except:
            pass
            
        profile1 = ''
        try:
            p1 = await page.query_selector('p.intro-profile')
            if p1:
                profile1 = await p1.text_content()
        except:
            pass
            
        profile2 = ''
        try:
            p2 = await page.query_selector('p.r3')
            if p2:
                profile2 = await p2.text_content()
        except:
            pass

        return {
            'row_index': company['row_index'],
            'row_data': company['row_data'],
            'companyURL': company_url.strip() if company_url else '',
            'profile1': profile1.strip() if profile1 else '',
            'profile2': profile2.strip() if profile2 else '',
            'success': True
        }
    except Exception as e:
        print(f"  [警告] {company['company_name']} ({url}) 爬取失敗：{e}")
        return {
            'row_index': company['row_index'],
            'row_data': company['row_data'],
            'companyURL': '',
            'profile1': '',
            'profile2': '',
            'success': False
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

    async def bounded_scrape(browser, company):
        async with semaphore:
            page = await browser.new_page()
            try:
                r = await scrape_one_company(page, company)
                return r
            finally:
                await page.close()

    async with async_playwright() as p:
        print(f"\n[步驟 3] 啟動 Chromium（並行 {CONCURRENT_PAGES} 頁）...")
        browser = await p.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )
        context = await browser.new_context()

        tasks = [bounded_scrape(context, c) for c in companies]
        total = len(tasks)

        # 分批執行並顯示進度
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
            # A B D E F G H J K 維持現狀

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
            sheet.update(f'A{start_row}', chunk)
        except TypeError:
            sheet.update(range_name=f'A{start_row}', values=chunk)
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
    # 讀取最新版本的本地 CSV（含完整列資料）
    with open(LOCAL_CSV, 'r', encoding='utf-8') as f:
        all_rows = list(csv.reader(f))

    companies_map = {r['row_index']: r for r in results}
    updated_rows = update_local_csv(companies_map, all_rows)

    # 6. 批次寫回 Google Sheets
    write_back_to_sheet(updated_rows)

    print("\n=== 全部完成 ===")


if __name__ == '__main__':
    main()
