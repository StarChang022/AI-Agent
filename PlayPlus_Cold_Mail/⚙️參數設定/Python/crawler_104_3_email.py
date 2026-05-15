import os
import re
import csv
import json
import asyncio
import time
import socket
import smtplib
from urllib.parse import urlparse
import gspread
from google.oauth2.service_account import Credentials

try:
    import dns.resolver
except ImportError:
    print("[警告] 找不到 dnspython，SMTP 驗證功能將受限。請執行: pip install dnspython")

# ================= 參數設定 =================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCAL_CSV = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
TEMP_FILE = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104.json')
CREDENTIALS_FILE = os.path.join(BASE_DIR, '⚙️參數設定', 'eternal-skyline-494002-j8-356884d3e786.json')

SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'
WORKSHEET_NAME = '名單副本'

# 爬蟲效能設定
CONCURRENT_PAGES = 5       # 同時開啟的 Playwright 分頁數
PAGE_TIMEOUT = 15000       # 每頁等待上限 (ms)

# SMTP 驗證設定
SMTP_TIMEOUT = 10          # SMTP 連線超時 (秒)
COMMON_PREFIXES = ['info', 'service', 'contact', 'hr', 'sales', 'admin', 'office', 'mail']

# 每間公司要嘗試的常見聯絡頁路徑
CONTACT_PATHS = ['', '/contact', '/contact-us', '/about', '/about-us']

EMAIL_REGEX = re.compile(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')
# ==========================================

def extract_domain(url: str) -> str:
    if not url or not url.startswith('http'):
        return ''
    try:
        parsed = urlparse(url.strip())
        host = parsed.netloc.lower()
        if host.startswith('www.'):
            host = host[4:]
        return host
    except Exception:
        return ''

def get_mx_records(domain):
    """獲取網域的 MX 記錄"""
    try:
        answers = dns.resolver.resolve(domain, 'MX')
        # 依優先權排序
        mx_targets = sorted([(a.preference, str(a.exchange).rstrip('.')) for a in answers])
        return [t[1] for t in mx_targets]
    except Exception:
        return []

def verify_email_smtp(mx_server, from_email, to_email):
    """透過 SMTP Handshake 驗證單一信箱是否存在"""
    try:
        server = smtplib.SMTP(mx_server, timeout=SMTP_TIMEOUT)
        server.set_debuglevel(0)
        server.helo('mail.google.com') # 偽裝發信網域
        server.mail(from_email)
        code, message = server.rcpt(to_email)
        server.quit()
        # 250 代表 OK, 存在
        if code == 250:
            return True
        return False
    except Exception:
        return False

def check_catch_all(mx_server, domain):
    """檢查是否為 Catch-all (即任何信箱都回傳存在)"""
    random_email = f"testing_catch_all_{int(time.time())}@{domain}"
    return verify_email_smtp(mx_server, 'test@gmail.com', random_email)

def smtp_search_emails(domain):
    """選項 A：SMTP 驗證版 - 批次測試常用前綴"""
    print(f"    [SMTP] 正在驗證 {domain} 的常用前綴...")
    mx_servers = get_mx_records(domain)
    if not mx_servers:
        print(f"    [SMTP] 找不到 {domain} 的 MX 記錄。")
        return []

    mx_server = mx_servers[0]
    # 先檢查是否為 Catch-all，若是則 SMTP 驗證無意義
    if check_catch_all(mx_server, domain):
        print(f"    [SMTP] {domain} 為 Catch-all 伺服器，略過驗證。")
        return []

    valid_emails = []
    for prefix in COMMON_PREFIXES:
        email = f"{prefix}@{domain}"
        if verify_email_smtp(mx_server, 'test@gmail.com', email):
            valid_emails.append(email)
            if len(valid_emails) >= 2: # 找到兩個就夠了
                break
    return valid_emails

def filter_emails_by_domain(raw_emails: list, domain: str) -> list:
    seen = set()
    valid = []
    for email in raw_emails:
        email = email.lower().strip()
        if email.endswith(f'@{domain}') and email not in seen:
            seen.add(email)
            valid.append(email)
    return valid

async def scrape_emails_from_web(context, company_name: str, website_url: str, domain: str):
    """原有策略：官網爬取"""
    found_emails = set()
    base_url = website_url.rstrip('/')
    for path in CONTACT_PATHS:
        target_url = base_url + path
        page = await context.new_page()
        try:
            await page.goto(target_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT)
            content = await page.content()
            emails = EMAIL_REGEX.findall(content)
            for e in emails:
                found_emails.add(e.lower())
            if filter_emails_by_domain(list(found_emails), domain):
                await page.close()
                break
        except Exception:
            pass
        finally:
            try: await page.close()
            except Exception: pass
    return filter_emails_by_domain(list(found_emails), domain)

async def scrape_emails_for_company(context, company):
    """綜合策略：SMTP 驗證 + 官網爬取"""
    name = company['company_name']
    url = company['website_url']
    domain = company['domain']
    
    # 1. 優先執行：SMTP 驗證 (選項 A)
    smtp_emails = smtp_search_emails(domain)
    if smtp_emails:
        return smtp_emails

    # 2. 備案：官網爬取
    web_emails = await scrape_emails_from_web(context, name, url, domain)
    return web_emails

async def scrape_all_emails(companies: list) -> dict:
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print("[錯誤] 找不到 playwright")
        return {}

    semaphore = asyncio.Semaphore(CONCURRENT_PAGES)
    results = {}

    async def bounded_scrape(context, company):
        async with semaphore:
            emails = await scrape_emails_for_company(context, company)
            status = f'✓ {len(emails)} 筆' if emails else '✗ 未找到'
            print(f"  [{status}] {company['company_name']} ({company['domain']})")
            return company['row_index'], emails

    async with async_playwright() as p:
        print(f"\n[步驟 3] 啟動爬蟲與 SMTP 驗證 (並行 {CONCURRENT_PAGES})...")
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(user_agent='Mozilla/5.0...')
        
        tasks = [bounded_scrape(context, c) for c in companies]
        for coro in asyncio.as_completed(tasks):
            row_idx, emails = await coro
            results[row_idx] = emails

        await browser.close()
    return results

def apply_management_rules(all_rows, email_results):
    output_rows = [all_rows[0]]
    for i, row in enumerate(all_rows[1:], start=2):
        while len(row) < 11: row.append('')
        website = row[2].strip()
        existing_email = row[5].strip()
        if not website or existing_email:
            output_rows.append(row)
            continue
        emails = email_results.get(i, [])
        if not emails:
            output_rows.append(row)
            continue
        # 找到 1 筆或多筆的處理
        for j, email in enumerate(emails):
            new_row = row.copy()
            new_row[5] = email
            output_rows.append(new_row)
    return output_rows

def write_back_to_sheet(data_rows):
    if len(data_rows) < 2: return
    print(f"\n[步驟 5] 更新 Google Sheets ({len(data_rows)-1} 筆)...")
    scope = ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
    creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    sheet = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)
    sheet.batch_clear(['A2:K'])
    data = data_rows[1:]
    BATCH = 500
    for i in range(0, len(data), BATCH):
        chunk = data[i:i + BATCH]
        sheet.update(f'A{2+i}', chunk)
        time.sleep(1)
    print("  → 完成！")

def main():
    print("=== 104 網域信箱爬蟲 (SMTP 驗證版) ===\n")
    if not os.path.exists(LOCAL_CSV):
        print("找不到名單副本.csv"); return
    with open(LOCAL_CSV, 'r', encoding='utf-8') as f:
        all_rows = list(csv.reader(f))
    
    companies_to_scrape = []
    for i, row in enumerate(all_rows[1:], start=2):
        while len(row) < 11: row.append('')
        website = row[2].strip()
        existing_email = row[5].strip()
        domain = extract_domain(website)
        if website and not existing_email and domain:
            companies_to_scrape.append({'row_index': i, 'company_name': row[0].strip(), 'website_url': website, 'domain': domain})

    if not companies_to_scrape:
        print("沒有需要執行的資料。"); return

    email_results = asyncio.run(scrape_all_emails(companies_to_scrape))
    
    # 暫存
    os.makedirs(os.path.dirname(TEMP_FILE), exist_ok=True)
    with open(TEMP_FILE, 'w', encoding='utf-8') as f:
        json.dump({str(k): v for k, v in email_results.items()}, f, ensure_ascii=False, indent=2)

    updated_rows = apply_management_rules(all_rows, email_results)
    with open(LOCAL_CSV, 'w', encoding='utf-8', newline='') as f:
        csv.writer(f).writerows(updated_rows)
    
    write_back_to_sheet(updated_rows)
    print("\n=== 全部完成 ===")

if __name__ == '__main__':
    main()
