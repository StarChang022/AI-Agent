import os
import re
import csv
import json
import asyncio
import time
import smtplib
from typing import Optional, List, Set
from urllib.parse import urlparse, urljoin
import gspread
from google.oauth2.service_account import Credentials

try:
    import dns.resolver
except ImportError:
    print("[警告] 找不到 dnspython，SMTP 驗證功能將受限。請執行: pip install dnspython")

# ================= 參數設定 =================
BASE_DIR         = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚙️參數 目錄
SALES_DIR        = os.path.dirname(BASE_DIR)                                     # PlayPlus_Sales 目錄
TEMP_DIR         = os.path.join(SALES_DIR, '⌚️暫存')
TEMP_FILE        = os.path.join(TEMP_DIR, 'temporary_domain_emails.json')
LOCAL_CSV        = os.path.join(TEMP_DIR, 'domain_email_list.csv')
CREDENTIALS_FILE = os.path.join(BASE_DIR, 'eternal-skyline-494002-j8-356884d3e786.json')

SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'
WORKSHEET_NAME = '名單副本'  # gid=1539228012

# 欄位索引（0-based）
COL_COMPANY   = 0   # A欄 公司名稱
COL_EMAIL     = 4   # E欄 email
COL_WEBSITE   = 7   # H欄 官方網站
TOTAL_COLS    = 18  # A~R = 18 欄

# 爬蟲效能設定
CONCURRENT_PAGES  = 5    # 同時開啟的 Playwright 分頁數
PAGE_TIMEOUT      = 15000  # 每頁等待上限 (ms)

# SMTP 驗證設定
SMTP_TIMEOUT   = 10
COMMON_PREFIXES = ['info', 'service', 'contact', 'sales', 'office', 'mail']

# 常見聯絡頁路徑
CONTACT_PATHS = ['', '/contact', '/contact-us', '/contactus', '/about',
                 '/about-us', '/about/qa', '/service', '/agents', '/contactus/agents']

# 子頁面優先掃描關鍵字
PRIORITY_KEYWORDS = ['contact', 'about', 'agent', 'service', '聯絡', '關於', '代理']

# 每間公司最多額外掃描幾個子頁
MAX_EXTRA_SUBPAGES = 10

# 過濾誤判副檔名
INVALID_EMAIL_SUFFIXES = ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.css', '.js', '.ico')

# 過濾系統雜訊前綴
NOISE_PREFIXES = ('noreply', 'no-reply', 'mailer-daemon', 'postmaster', 'bounce', 'donotreply')

EMAIL_REGEX = re.compile(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')
# ==========================================


# ===== 工具函式 =====

def ensure_dirs():
    os.makedirs(TEMP_DIR, exist_ok=True)


def extract_domain(url: str) -> str:
    """從 URL 取得主網域（去除 www.）"""
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


def is_valid_email(email: str) -> bool:
    """基本 Email 格式驗證，過濾常見誤判"""
    email = email.lower().strip()
    if email.endswith(INVALID_EMAIL_SUFFIXES):
        return False
    if '@' not in email:
        return False
    local, _, domain_part = email.partition('@')
    if not local or not domain_part or '.' not in domain_part:
        return False
    # 排除特定系統前綴
    if local in ('hr', 'ir', 'admin') or \
       any(local.startswith(f"{p}{sep}") for p in ('hr', 'ir', 'admin') for sep in ('-', '_', '.')):
        return False
    return True


def dedup_emails(emails: list) -> List[str]:
    """去重，保持順序"""
    seen = set()
    result = []
    for e in emails:
        e_lower = e.lower().strip()
        if e_lower not in seen:
            seen.add(e_lower)
            result.append(e_lower)
    return result


def filter_emails_by_domain(raw_emails: list, domain: str) -> list:
    """只保留符合公司主網域後綴的 Email"""
    seen = set()
    valid = []
    for email in raw_emails:
        email = email.lower().strip()
        if email.endswith(f'@{domain}') and email not in seen:
            seen.add(email)
            valid.append(email)
    return valid


# ===== SMTP 驗證管道 =====

def get_mx_records(domain):
    """查詢網域 MX 記錄"""
    try:
        answers = dns.resolver.resolve(domain, 'MX')
        mx_targets = sorted([(a.preference, str(a.exchange).rstrip('.')) for a in answers])
        return [t[1] for t in mx_targets]
    except Exception:
        return []


def verify_email_smtp(mx_server, from_email, to_email):
    """透過 SMTP Handshake 驗證單一信箱是否存在"""
    try:
        server = smtplib.SMTP(mx_server, timeout=SMTP_TIMEOUT)
        server.set_debuglevel(0)
        server.helo('mail.google.com')
        server.mail(from_email)
        code, message = server.rcpt(to_email)
        server.quit()
        return code == 250
    except Exception:
        return False


def check_catch_all(mx_server, domain):
    """檢查是否為 Catch-all 伺服器"""
    random_email = f"testing_catch_all_{int(time.time())}@{domain}"
    return verify_email_smtp(mx_server, 'test@gmail.com', random_email)


def smtp_search_emails(domain):
    """SMTP 驗證版 - 批次測試常用前綴"""
    print(f"    [SMTP] 正在驗證 {domain} 的常用前綴...")
    mx_servers = get_mx_records(domain)
    if not mx_servers:
        print(f"    [SMTP] 找不到 {domain} 的 MX 記錄。")
        return []

    mx_server = mx_servers[0]
    if check_catch_all(mx_server, domain):
        print(f"    [SMTP] {domain} 為 Catch-all 伺服器，略過 SMTP 驗證。")
        return []

    valid_emails = []
    for prefix in COMMON_PREFIXES:
        email = f"{prefix}@{domain}"
        if verify_email_smtp(mx_server, 'test@gmail.com', email):
            valid_emails.append(email)
            if len(valid_emails) >= 2:
                break
    return valid_emails


# ===== 網頁爬取管道 =====

def decode_cloudflare_email(encoded_str: str) -> Optional[str]:
    """
    管道一：解密 Cloudflare Email Obfuscation（data-cfemail 屬性）。
    第一個 Byte 為 Key，其餘 Bytes 與 Key 做 XOR 還原真實 Email。
    """
    try:
        key = int(encoded_str[:2], 16)
        email = ''.join(
            chr(int(encoded_str[i:i+2], 16) ^ key)
            for i in range(2, len(encoded_str), 2)
        )
        return email if '@' in email else None
    except Exception:
        return None


def extract_emails_from_html(html: str) -> Set[str]:
    """
    綜合五大管道從 HTML 字串中提取所有 Email：
    管道一：解密 Cloudflare 混淆保護 (data-cfemail 屬性)
    管道二：解析 mailto: 超連結
    管道三：解密 Cloudflare /cdn-cgi/l/email-protection#<hash> 連結
    管道四：BeautifulSoup get_text() 純文字掃描（自動還原 &#x40; 等 HTML 實體）
    管道五：正則表達式掃描原始 HTML（補漏網之魚）
    """
    from bs4 import BeautifulSoup
    emails = set()
    soup = BeautifulSoup(html, 'html.parser')

    # 管道一：Cloudflare Email 解密 (data-cfemail)
    for el in soup.select('span[data-cfemail]'):
        encoded = el.get('data-cfemail', '')
        if encoded:
            decoded = decode_cloudflare_email(encoded)
            if decoded and is_valid_email(decoded):
                emails.add(decoded.lower())

    # 管道二：mailto: 超連結
    for a in soup.find_all('a', href=True):
        href = a['href']
        if href.lower().startswith('mailto:'):
            email = href[7:].split('?')[0].strip().lower()
            if email and is_valid_email(email):
                emails.add(email)

    # 管道三：Cloudflare /cdn-cgi/l/email-protection#<hash> 連結
    for a in soup.find_all('a', href=True):
        href = a['href']
        if '/cdn-cgi/l/email-protection#' in href:
            encoded = href.split('#', 1)[-1]
            decoded = decode_cloudflare_email(encoded)
            if decoded and is_valid_email(decoded):
                emails.add(decoded.lower())

    # 管道四：BeautifulSoup 解碼後純文字掃描
    decoded_text = soup.get_text()
    for email in EMAIL_REGEX.findall(decoded_text):
        if is_valid_email(email):
            emails.add(email.lower())

    # 管道五：原始 HTML 正則補漏
    for email in EMAIL_REGEX.findall(html):
        if is_valid_email(email):
            emails.add(email.lower())

    return emails


def collect_all_subpage_urls(base_url: str, html: str) -> List[str]:
    """
    從 HTML 收集同網域內部連結，含關鍵字的連結優先排前。
    """
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(html, 'html.parser')
    base_domain = urlparse(base_url).netloc
    priority, others = [], []
    seen = set()

    for a in soup.find_all('a', href=True):
        href = a['href']
        abs_url = urljoin(base_url, href).split('#')[0].split('?')[0].rstrip('/')
        parsed = urlparse(abs_url)
        if parsed.netloc != base_domain or abs_url in seen:
            continue
        seen.add(abs_url)
        if any(kw in abs_url.lower() for kw in PRIORITY_KEYWORDS):
            priority.append(abs_url)
        else:
            others.append(abs_url)

    return priority + others


async def scrape_emails_from_web(context, company_name: str, website_url: str, domain: str) -> List[str]:
    """
    官網爬取策略：
    第一輪：掃描已知 CONTACT_PATHS 常見路徑
    第二輪：若未找到主網域 Email，額外掃描子頁面（最多 MAX_EXTRA_SUBPAGES 個）

    回傳策略：
    - 優先回傳符合公司主網域後綴的 Email
    - 若找不到，回傳其他非系統廢號 Email（如 ISP 信箱）
    """
    all_emails: Set[str] = set()
    base_url = website_url.rstrip('/')
    homepage_html = None
    visited = set()

    # --- 第一輪：掃描已知常見路徑 ---
    for path in CONTACT_PATHS:
        target_url = base_url + path
        if target_url in visited:
            continue
        visited.add(target_url)
        page = await context.new_page()
        try:
            await page.goto(target_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT)
            content = await page.content()
            if path == '' and homepage_html is None:
                homepage_html = content  # 記住首頁 HTML 供子頁面收集
            emails = extract_emails_from_html(content)
            all_emails.update(emails)
            # 若已找到主網域 Email，提前結束
            if filter_emails_by_domain(list(all_emails), domain):
                break
        except Exception:
            if path == '':
                break  # 首頁失敗代表整站無法訪問，中斷
        finally:
            try:
                await page.close()
            except Exception:
                pass

    # --- 第二輪：若未找到主網域 Email，額外掃描子頁面 ---
    if not filter_emails_by_domain(list(all_emails), domain) and homepage_html:
        subpage_urls = collect_all_subpage_urls(base_url, homepage_html)
        extra_count = 0
        for sub_url in subpage_urls:
            if extra_count >= MAX_EXTRA_SUBPAGES:
                break
            if sub_url in visited:
                continue
            visited.add(sub_url)
            extra_count += 1
            page = await context.new_page()
            try:
                await page.goto(sub_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT)
                content = await page.content()
                emails = extract_emails_from_html(content)
                all_emails.update(emails)
                if filter_emails_by_domain(list(all_emails), domain):
                    break
            except Exception:
                pass
            finally:
                try:
                    await page.close()
                except Exception:
                    pass

    # --- 回傳：優先主網域，其次備用非系統信箱 ---
    domain_emails = filter_emails_by_domain(list(all_emails), domain)
    if domain_emails:
        return dedup_emails(domain_emails)

    other_emails = [
        e for e in all_emails
        if not any(e.startswith(p) for p in NOISE_PREFIXES)
    ]
    return dedup_emails(other_emails)


async def scrape_emails_for_company(context, company):
    """綜合策略：先 SMTP 驗證，備案官網爬取"""
    name    = company['company_name']
    url     = company['website_url']
    domain  = company['domain']

    # 策略一：SMTP 驗證（在執行緒中執行避免阻塞 event loop）
    loop = asyncio.get_running_loop()
    smtp_emails = await loop.run_in_executor(None, smtp_search_emails, domain)
    if smtp_emails:
        return smtp_emails

    # 策略二：官網爬取
    web_emails = await scrape_emails_from_web(context, name, url, domain)
    return web_emails


async def scrape_all_emails(companies: list) -> dict:
    """並行爬取所有公司的 Email"""
    try:
        from playwright.async_api import async_playwright
    except ImportError:
        print("[錯誤] 找不到 playwright。請先執行：")
        print("  python3 -m pip install playwright")
        print("  python3 -m playwright install chromium")
        return {}

    semaphore = asyncio.Semaphore(CONCURRENT_PAGES)
    results   = {}

    async def bounded_scrape(context, company):
        async with semaphore:
            emails = await scrape_emails_for_company(context, company)
            status = f'✓ {len(emails)} 筆' if emails else '✗ 未找到'
            print(f"  [{status}] {company['company_name']} ({company['domain']})")
            for e in emails:
                print(f"         → {e}")
            return company['row_index'], emails

    async with async_playwright() as p:
        print(f"\n[步驟 3] 啟動爬蟲與 SMTP 驗證（並行 {CONCURRENT_PAGES} 頁）...")
        browser = await p.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-dev-shm-usage',
                  '--disable-blink-features=AutomationControlled']
        )
        context = await browser.new_context(
            user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        )

        tasks = [bounded_scrape(context, c) for c in companies]
        for coro in asyncio.as_completed(tasks):
            row_idx, emails = await coro
            results[row_idx] = emails

        await browser.close()
    return results


# ===== Google Sheets 讀寫 =====

def get_sheet_client():
    scope  = ['https://www.googleapis.com/auth/spreadsheets',
              'https://www.googleapis.com/auth/drive']
    creds  = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    return client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)


def download_sheet(sheet):
    """下載整個工作表並存至本地 CSV（支援斷點續爬）"""
    print("[步驟 1] 下載 Google Sheets「名單副本」...")
    all_values = sheet.get_all_values()
    if not all_values:
        print("  [警告] 工作表內無資料。")
        return []

    ensure_dirs()
    with open(LOCAL_CSV, 'w', encoding='utf-8', newline='') as f:
        csv.writer(f).writerows(all_values)

    print(f"  → 已下載 {len(all_values) - 1} 筆資料至 {LOCAL_CSV}")
    return all_values


def load_companies_to_scrape(all_rows):
    """
    解析所有列，取出需要查找 Email 的公司。
    管理規則：
      - H欄（index 7）為空 → 略過
      - E欄（index 4）已有值 → 略過
    """
    companies = []
    for i, row in enumerate(all_rows[1:], start=2):  # 第 2 列起（1-based）
        while len(row) < TOTAL_COLS:
            row.append('')

        website        = row[COL_WEBSITE].strip()   # H欄
        existing_email = row[COL_EMAIL].strip()     # E欄
        domain         = extract_domain(website)
        company_name   = row[COL_COMPANY].strip()   # A欄

        if not website:
            continue  # 規則 1：H欄為空略過
        if existing_email:
            continue  # 規則 2：E欄已有值略過
        if not domain:
            print(f"  [略過] 第 {i} 列 {company_name}（無法解析網域：{website}）")
            continue

        companies.append({
            'row_index':    i,
            'company_name': company_name,
            'website_url':  website,
            'domain':       domain,
            'row_data':     row,
        })

    print(f"  → 找到 {len(companies)} 間待查找公司（H欄有網址且 E欄為空）")
    return companies


def apply_management_rules(all_rows, email_results):
    """
    依管理規則將 Email 填入 E 欄，建立新的行列表。
    規則 3：找到 1 筆 → 直接填入 E 欄
    規則 4：找到 2+ 筆 → 複製該列對應筆數，各填一個 Email
    規則 5：找不到 → 維持現狀
    """
    output_rows = [all_rows[0]]  # 保留標題列

    for i, row in enumerate(all_rows[1:], start=2):
        while len(row) < TOTAL_COLS:
            row.append('')

        emails = email_results.get(i, None)

        if emails is None:
            # 此列不在爬取範圍（H欄空或 E欄已有值），維持現狀
            output_rows.append(row)
        elif len(emails) == 0:
            # 規則 5：找不到，維持現狀
            output_rows.append(row)
        elif len(emails) == 1:
            # 規則 3：找到 1 筆，填入 E 欄
            new_row = row.copy()
            new_row[COL_EMAIL] = emails[0]
            output_rows.append(new_row)
        else:
            # 規則 4：找到 2+ 筆，複製列數對應筆數
            for email in emails:
                new_row = row.copy()
                new_row[COL_EMAIL] = email
                output_rows.append(new_row)

    return output_rows


def write_back_to_sheet(sheet, updated_rows):
    """批次覆寫 Google Sheets（保留標題列，清空後重寫資料列）"""
    if len(updated_rows) < 2:
        print("[警告] 無資料可寫回。")
        return

    print(f"\n[步驟 5] 寫回 Google Sheets（{len(updated_rows) - 1} 筆）...")

    data_rows = updated_rows[1:]  # 只寫資料列

    try:
        end_col = chr(ord('A') + TOTAL_COLS - 1)  # 'R'
        sheet.batch_clear([f'A2:{end_col}'])
    except Exception as e:
        print(f"  [警告] 清除舊資料失敗：{e}")

    BATCH = 500
    for i in range(0, len(data_rows), BATCH):
        chunk = [r[:TOTAL_COLS] for r in data_rows[i:i + BATCH]]
        start_row = 2 + i
        try:
            sheet.update(values=chunk, range_name=f'A{start_row}')
        except Exception as e:
            print(f"  [警告] 寫入失敗：{e}")
        print(f"  → 已寫入第 {start_row} ~ {start_row + len(chunk) - 1} 列")
        if i + BATCH < len(data_rows):
            time.sleep(1)

    print("  → Google Sheets 寫入完成！")


def save_temp(email_results):
    """暫存爬蟲結果（key 為 row_index 字串）"""
    ensure_dirs()
    with open(TEMP_FILE, 'w', encoding='utf-8') as f:
        json.dump({str(k): v for k, v in email_results.items()},
                  f, ensure_ascii=False, indent=2)
    print(f"\n[暫存] 已儲存至 {TEMP_FILE}")


def load_temp():
    """讀取上次暫存，支援斷點續爬"""
    if os.path.exists(TEMP_FILE):
        try:
            with open(TEMP_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
            return {int(k): v for k, v in data.items()}
        except Exception:
            pass
    return {}


# ===== 主程式 =====

def main():
    print("=== 網域信箱爬蟲（PlayPlus_Sales 版）===\n")

    # 1. 下載 Google Sheets → 本地 CSV
    sheet     = get_sheet_client()
    all_rows  = download_sheet(sheet)
    if not all_rows:
        return

    # 2. 解析待爬取公司清單
    print("\n[步驟 2] 解析待爬取公司（H欄有網域且 E欄為空）...")
    companies = load_companies_to_scrape(all_rows)
    if not companies:
        print("  → 沒有需要查找的公司，結束。")
        return

    # 支援斷點續爬：已暫存的結果直接沿用
    existing = load_temp()
    companies_to_crawl = []
    skipped_results    = {}

    for c in companies:
        idx = c['row_index']
        if idx in existing:
            skipped_results[idx] = existing[idx]
            print(f"  [快取] 第 {idx} 列 {c['company_name']}（已從暫存讀取）")
        else:
            companies_to_crawl.append(c)

    print(f"  → 總計 {len(companies)} 間，快取 {len(skipped_results)} 間，待爬取 {len(companies_to_crawl)} 間")

    # 3. 並行爬取
    new_results = {}
    if companies_to_crawl:
        new_results = asyncio.run(scrape_all_emails(companies_to_crawl))

    # 合併結果
    email_results = {**skipped_results, **new_results}

    # 3b. 暫存
    print("\n[步驟 4] 暫存爬蟲結果...")
    save_temp(email_results)

    success_count = sum(1 for v in email_results.values() if v)
    print(f"  → 共 {success_count}/{len(email_results)} 間找到 Email。")

    # 4. 套用管理規則，建立新的列資料
    # email_results 只包含「本次處理」的列，未在名單內的列不存在於此 dict
    # 將不在爬取範圍的列標記為 None（維持現狀）
    full_email_results = {}
    for c in companies:
        idx = c['row_index']
        full_email_results[idx] = email_results.get(idx, [])

    updated_rows = apply_management_rules(all_rows, full_email_results)

    # 更新本地 CSV
    with open(LOCAL_CSV, 'w', encoding='utf-8', newline='') as f:
        csv.writer(f).writerows(updated_rows)
    print(f"\n[本地] 已更新 {LOCAL_CSV}（{len(updated_rows) - 1} 列）")

    # 5. 批次寫回 Google Sheets
    write_back_to_sheet(sheet, updated_rows)

    print("\n=== 全部完成 ===")


if __name__ == '__main__':
    main()
