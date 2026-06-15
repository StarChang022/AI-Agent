import os
import re
import csv
from typing import Optional, List, Set
import json
import asyncio
import time
import smtplib
from urllib.parse import urlparse, urljoin
import gspread
from google.oauth2.service_account import Credentials

try:
    import dns.resolver
except ImportError:
    print("[警告] 找不到 dnspython，SMTP 驗證功能將受限。請執行: pip install dnspython")

# ================= 參數設定 =================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LOCAL_CSV = os.path.join(BASE_DIR, '冷郵件對象', '名單副本.csv')
TEMP_FILE = os.path.join(BASE_DIR, '⌚️暫存', 'temporary_104_emails.json')
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
CONTACT_PATHS = ['', '/contact', '/contact-us', '/contactus', '/about', '/about-us', '/about/qa', '/service', '/agents', '/contactus/agents']

# 子頁面爬取：優先掃描含以下關鍵字的連結
PRIORITY_KEYWORDS = ['contact', 'about', 'agent', 'service', '聯絡', '關於', '代理']

# 子頁面爬取：每間公司最多額外掃描幾個子頁（首頁 + CONTACT_PATHS 之外的連結）
MAX_EXTRA_SUBPAGES = 10

# 過濾誤判：這些副檔名結尾不是真實 Email
INVALID_EMAIL_SUFFIXES = ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.css', '.js', '.ico')

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
    """檢查是否為 Catch-all（任何信箱都回傳存在）"""
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
        print(f"    [SMTP] {domain} 為 Catch-all 伺服器，略過驗證。")
        return []

    valid_emails = []
    for prefix in COMMON_PREFIXES:
        email = f"{prefix}@{domain}"
        if verify_email_smtp(mx_server, 'test@gmail.com', email):
            valid_emails.append(email)
            if len(valid_emails) >= 2:
                break
    return valid_emails

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
    return True

def dedup_emails(emails) -> List[str]:
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
    """只保留符合公司主網域的 Email（向下相容舊版呼叫）"""
    seen = set()
    valid = []
    for email in raw_emails:
        email = email.lower().strip()
        if email.endswith(f'@{domain}') and email not in seen:
            seen.add(email)
            valid.append(email)
    return valid

# =========== Email 搜尋三大管道 ===========

def decode_cloudflare_email(encoded_str: str) -> Optional[str]:
    """
    管道一：解密 Cloudflare Email Obfuscation（data-cfemail 屬性）。
    Cloudflare 將 Email 以 XOR 加密後存入 data-cfemail，
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

    ★ 不過濾網域：同時收集公司主網域以外的 Email
       （例如 yunghuam@ms26.hinet.net、youji@ms15.hinet.net 這類 ISP 信箱）
    """
    from bs4 import BeautifulSoup
    emails = set()
    soup = BeautifulSoup(html, 'html.parser')

    # 管道一：Cloudflare Email 解密 (data-cfemail 屬性)
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

    # 管道三：解密 Cloudflare /cdn-cgi/l/email-protection#<hash> 連結
    # 這種 href 不是 mailto:，而是指向 Cloudflare 保護路徑，hash 後編碼與 data-cfemail 相同
    for a in soup.find_all('a', href=True):
        href = a['href']
        if '/cdn-cgi/l/email-protection#' in href:
            encoded = href.split('#', 1)[-1]
            decoded = decode_cloudflare_email(encoded)
            if decoded and is_valid_email(decoded):
                emails.add(decoded.lower())

    # 管道四：掃描 BeautifulSoup 解碼後的純文字（自動還原 &#x40; 等 HTML 實體）
    decoded_text = soup.get_text()
    for email in EMAIL_REGEX.findall(decoded_text):
        if is_valid_email(email):
            emails.add(email.lower())

    # 管道五：正則表達式掃描原始 HTML（補漏網之魚）
    for email in EMAIL_REGEX.findall(html):
        if is_valid_email(email):
            emails.add(email.lower())

    return emails

def collect_all_subpage_urls(base_url: str, html: str) -> List[str]:
    """
    從 HTML 中收集同網域內部連結，
    將含有關鍵字（contact/about/service 等）的連結排在前面。
    （參考 test.py 的 get_internal_links 邏輯）
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

# ==========================================

async def scrape_emails_from_web(context, company_name: str, website_url: str, domain: str) -> List[str]:
    """
    官網爬取策略（升級版）：

    1. 先逐一訪問 CONTACT_PATHS 的常見路徑
    2. 若仍未找到，從首頁抓出所有子頁面連結（優先聯絡/關於等），
       再額外掃描最多 MAX_EXTRA_SUBPAGES 個頁面

    ★ 關鍵改動：
       - 每個頁面使用三大管道提取「所有」 Email，不限網域
       - 優先回傳公司主網域的 Email；若無，回傳非網域 Email（如 ISP 信箱）
    """
    all_emails: Set[str] = set()
    base_url = website_url.rstrip('/')
    homepage_html = None
    visited = set()

    # --- 第一輪：掃描已知的常見路徑 ---
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
                homepage_html = content  # 記住首頁 HTML 供後續子頁面收集用
            emails = extract_emails_from_html(content)
            all_emails.update(emails)
            # 如果已找到主網域 Email，提前結束
            if filter_emails_by_domain(list(all_emails), domain):
                break
        except Exception:
            pass
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

    # --- 回傳策略：優先主網域 Email，其次所有找到的 Email ---
    domain_emails = filter_emails_by_domain(list(all_emails), domain)
    if domain_emails:
        return dedup_emails(domain_emails)

    # 若主網域找不到，回傳「所有」找到的 Email（含非主網域，如 ISP 信箱）
    # 過濾掉明顯無關的系統 Email（常見 no-reply、noreply 等）
    NOISE_PREFIXES = ('noreply', 'no-reply', 'mailer-daemon', 'postmaster', 'bounce', 'donotreply')
    other_emails = [
        e for e in all_emails
        if not any(e.startswith(p) for p in NOISE_PREFIXES)
    ]
    return dedup_emails(other_emails)

async def scrape_emails_for_company(context, company):
    """綜合策略：SMTP 驗證 + 官網爬取"""
    name = company['company_name']
    url = company['website_url']
    domain = company['domain']

    # 1. 優先執行：SMTP 驗證 (選項 A)
    smtp_emails = smtp_search_emails(domain)
    if smtp_emails:
        return smtp_emails

    # 2. 備案：官網爬取（含非主網域 Email）
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
            if emails:
                for e in emails:
                    print(f"         → {e}")
            return company['row_index'], emails

    async with async_playwright() as p:
        print(f"\n[步驟 3] 啟動爬蟲與 SMTP 驗證 (並行 {CONCURRENT_PAGES})...")
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        )

        tasks = [bounded_scrape(context, c) for c in companies]
        for coro in asyncio.as_completed(tasks):
            row_idx, emails = await coro
            results[row_idx] = emails

        await browser.close()
    return results

def apply_management_rules(all_rows, email_results):
    output_rows = [all_rows[0]]
    for i, row in enumerate(all_rows[1:], start=2):
        while len(row) < 27:
            row.append('')
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
    if len(data_rows) < 2:
        return
    print(f"\n[步驟 5] 更新 Google Sheets ({len(data_rows)-1} 筆)...")
    scope = ['https://www.googleapis.com/auth/spreadsheets', 'https://www.googleapis.com/auth/drive']
    creds = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    sheet = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)
    sheet.batch_clear(['A2:Z'])
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
        print("找不到名單副本.csv")
        return
    with open(LOCAL_CSV, 'r', encoding='utf-8') as f:
        all_rows = list(csv.reader(f))

    companies_to_scrape = []
    for i, row in enumerate(all_rows[1:], start=2):
        while len(row) < 27:
            row.append('')
        website = row[2].strip()
        existing_email = row[5].strip()
        domain = extract_domain(website)
        if website and not existing_email and domain:
            companies_to_scrape.append({
                'row_index': i,
                'company_name': row[0].strip(),
                'website_url': website,
                'domain': domain
            })

    if not companies_to_scrape:
        print("沒有需要執行的資料。")
        return

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
