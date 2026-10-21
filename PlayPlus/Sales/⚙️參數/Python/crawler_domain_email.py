import os
import re
import time
import json
import random
import smtplib
import requests
import gspread
from urllib.parse import urlparse, urljoin
from bs4 import BeautifulSoup
from google.oauth2.service_account import Credentials

try:
    import dns.resolver
    HAS_DNSPYTHON = True
except ImportError:
    HAS_DNSPYTHON = False

# ================= 參數設定 =================
BASE_DIR         = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ⚙️參數 目錄
CREDENTIALS_FILE = os.path.join(BASE_DIR, 'eternal-skyline-494002-j8-356884d3e786.json')
TEMP_DIR         = os.path.join(os.path.dirname(BASE_DIR), '⌚️暫存')
TEMP_FILE        = os.path.join(TEMP_DIR, 'temp_domain_email.json')

SPREADSHEET_ID = '14H99Ks5UFbdNnM9OoNQ2XWoVz4UHyp2QK0GiIym_1pE'
WORKSHEET_NAME = '名單副本'  # gid=1539228012

# HTTP 請求設定
REQUEST_TIMEOUT = 10    # 秒
REQUEST_DELAY   = 1.0   # 每次請求間的間隔（秒），避免觸發反爬
MAX_SUBPAGES    = 10    # 最多額外探索子頁面數

# SMTP 常見前綴（按優先序）
SMTP_PREFIXES = [
    'info', 'contact', 'service', 'sales', 'office',
    'mail', 'support', 'hello', 'admin', 'marketing',
]

# 常見聯絡頁路徑
CONTACT_PATHS = [
    '/contact', '/contact-us', '/contactus',
    '/about', '/about-us', '/aboutus',
    '/service', '/services',
    '/reach-us', '/get-in-touch',
]

# 子頁面優先關鍵字
PRIORITY_KEYWORDS = [
    'contact', 'about', 'agent', 'service',
    '聯絡', '關於', '服務', '客服',
]

# 過濾廢號前綴
BLACKLIST_PREFIXES = [
    'noreply', 'no-reply', 'postmaster', 'mailer-daemon',
    'bounce', 'donotreply', 'do-not-reply', 'spam',
]

# 常規 Email 正則
EMAIL_REGEX = re.compile(
    r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',
    re.IGNORECASE
)

# HTTP 請求 Headers
HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Safari/537.36'
    ),
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
}
# ==========================================


# ===== 工具函式 =====

def extract_domain(url: str) -> str:
    """
    從 URL 萃取主域名（去除 www. 前綴），例如：
    https://www.apple.com/ -> apple.com
    """
    if not url:
        return ''
    try:
        parsed = urlparse(url if url.startswith('http') else 'http://' + url)
        hostname = parsed.hostname or ''
        if hostname.startswith('www.'):
            hostname = hostname[4:]
        return hostname.lower()
    except Exception:
        return ''


def is_valid_email(email: str, target_domain: str) -> bool:
    """
    驗證 Email 是否：
    1. 非廢號前綴（noreply、postmaster 等）
    2. 後綴符合 target_domain（含子域名允許，例 mail.apple.com）
    """
    email = email.lower().strip()
    parts = email.split('@')
    if len(parts) != 2:
        return False

    prefix, domain = parts

    # 黑名單前綴
    for bl in BLACKLIST_PREFIXES:
        if prefix == bl or prefix.startswith(bl + '+'):
            return False

    # 域名須等於 target_domain 或為其子域名
    if domain == target_domain or domain.endswith('.' + target_domain):
        return True

    return False


def decode_cloudflare_email(encoded: str) -> str:
    """
    解密 Cloudflare data-cfemail XOR 編碼的 Email。
    """
    try:
        r = int(encoded[:2], 16)
        email = ''.join(
            chr(int(encoded[i:i+2], 16) ^ r)
            for i in range(2, len(encoded), 2)
        )
        return email
    except Exception:
        return ''


def fetch_html(url: str) -> str:
    """
    使用 requests 抓取指定 URL 的 HTML。失敗回傳空字串。
    """
    try:
        resp = requests.get(url, headers=HEADERS, timeout=REQUEST_TIMEOUT, allow_redirects=True)
        resp.encoding = resp.apparent_encoding or 'utf-8'
        return resp.text
    except Exception as e:
        print(f"    [警告] 無法抓取 {url}：{e}")
        return ''


def extract_emails_from_html(html: str, target_domain: str) -> set:
    """
    使用 5 種管道從 HTML 萃取 Email：
    1. Cloudflare data-cfemail XOR 解密
    2. <a href="mailto:"> 超連結
    3. /cdn-cgi/l/email-protection#<hash> URL 解密
    4. BeautifulSoup 純文字正則掃描
    5. 原始 HTML 全文正則比對（補漏）
    """
    found = set()
    if not html:
        return found

    soup = BeautifulSoup(html, 'html.parser')

    # --- 管道一：Cloudflare data-cfemail XOR 解密 ---
    for tag in soup.find_all(attrs={'data-cfemail': True}):
        decoded = decode_cloudflare_email(tag['data-cfemail'])
        if EMAIL_REGEX.match(decoded):
            found.add(decoded.lower())

    # --- 管道二：<a href="mailto:"> ---
    for tag in soup.find_all('a', href=True):
        href = tag['href']
        if href.lower().startswith('mailto:'):
            email = href[7:].split('?')[0].strip()
            if EMAIL_REGEX.match(email):
                found.add(email.lower())

    # --- 管道三：cdn-cgi email-protection URL ---
    cdn_pattern = re.compile(r'/cdn-cgi/l/email-protection#([0-9a-fA-F]+)')
    for match in cdn_pattern.finditer(html):
        decoded = decode_cloudflare_email(match.group(1))
        if EMAIL_REGEX.match(decoded):
            found.add(decoded.lower())

    # --- 管道四：BeautifulSoup 純文字掃描 ---
    text = soup.get_text(separator=' ')
    for match in EMAIL_REGEX.finditer(text):
        found.add(match.group(0).lower())

    # --- 管道五：原始 HTML 全文正則補漏 ---
    for match in EMAIL_REGEX.finditer(html):
        found.add(match.group(0).lower())

    # 以 target_domain 過濾
    filtered = {e for e in found if is_valid_email(e, target_domain)}
    return filtered


def collect_all_subpage_urls(base_url: str, homepage_html: str, domain: str) -> list:
    """
    解析首頁所有同網域連結，優先排列含關鍵字的聯絡 / 關於頁面。
    回傳最多 MAX_SUBPAGES 個子頁面 URL（去除首頁本身）。
    """
    if not homepage_html:
        return []

    soup = BeautifulSoup(homepage_html, 'html.parser')
    seen = set()
    priority = []
    others = []

    for tag in soup.find_all('a', href=True):
        href = tag['href'].strip()
        full_url = urljoin(base_url, href)
        parsed = urlparse(full_url)

        # 僅保留同網域
        hostname = (parsed.hostname or '').lower()
        if not (hostname == domain or hostname == 'www.' + domain):
            continue

        # 清理 fragment
        clean = full_url.split('#')[0].rstrip('/')
        if clean == base_url.rstrip('/') or clean in seen:
            continue
        seen.add(clean)

        path_lower = parsed.path.lower()
        if any(kw in path_lower for kw in PRIORITY_KEYWORDS):
            priority.append(clean)
        else:
            others.append(clean)

    return (priority + others)[:MAX_SUBPAGES]


# ===== SMTP 驗證 =====

def smtp_search_emails(domain: str) -> set:
    """
    透過 SMTP RCPT 握手主動測試常見前綴是否存在於該網域。
    流程：
    1. 查詢 MX Record
    2. Catch-all 檢測（避免誤判）
    3. 逐一測試前綴
    回傳已驗證存在的 Email 集合。
    """
    found = set()

    if not HAS_DNSPYTHON:
        print("    [SMTP] dnspython 未安裝，略過 SMTP 驗證。")
        return found

    # 1. 查詢 MX Record
    try:
        mx_records = dns.resolver.resolve(domain, 'MX')
        mx_host = sorted(mx_records, key=lambda r: r.preference)[0].exchange.to_text().rstrip('.')
    except Exception as e:
        print(f"    [SMTP] {domain} MX 查詢失敗：{e}")
        return found

    print(f"    [SMTP] MX: {mx_host}")

    def smtp_check(email_addr: str) -> bool:
        """對單一 Email 做 SMTP RCPT 握手，回傳是否 250 OK。"""
        try:
            server = smtplib.SMTP(timeout=8)
            server.connect(mx_host, 25)
            server.helo('verify.example.com')
            server.mail('verify@verify.example.com')
            code, _ = server.rcpt(email_addr)
            server.quit()
            return code == 250
        except Exception:
            return False

    # 2. Catch-all 檢測
    random_prefix = 'xk9z' + str(random.randint(10000, 99999))
    dummy_email = f'{random_prefix}@{domain}'
    if smtp_check(dummy_email):
        print(f"    [SMTP] {domain} 為 Catch-all 伺服器，略過 SMTP 測試。")
        return found

    # 3. 逐一測試前綴
    for prefix in SMTP_PREFIXES:
        email = f'{prefix}@{domain}'
        try:
            if smtp_check(email):
                print(f"    [SMTP] ✓ {email}")
                found.add(email)
            time.sleep(0.3)
        except Exception:
            pass

    return found


# ===== 核心：查找單一網域的 Email =====

def find_emails_for_domain(website_url: str) -> list:
    """
    綜合使用三大策略查找一個網域下的 Email：
    1. SMTP 主動握手
    2. 已知路徑輪詢（CONTACT_PATHS）
    3. 子頁面探索（首頁連結解析）

    回傳所有符合後綴的不重複 Email 串列（list）。
    """
    domain = extract_domain(website_url)
    if not domain:
        return []

    # 取得首頁基底 URL
    parsed = urlparse(website_url if website_url.startswith('http') else 'http://' + website_url)
    base_url = f"{parsed.scheme}://{parsed.netloc}"

    all_emails = set()

    # --- 策略一：SMTP 主動握手 ---
    print(f"  [策略一] SMTP 握手測試 {domain}...")
    smtp_emails = smtp_search_emails(domain)
    all_emails.update(smtp_emails)
    if smtp_emails:
        print(f"    → 找到 {len(smtp_emails)} 筆：{smtp_emails}")

    # --- 策略二：已知路徑輪詢 ---
    print(f"  [策略二] 已知路徑輪詢...")
    homepage_html = fetch_html(base_url)
    emails_from_home = extract_emails_from_html(homepage_html, domain)
    all_emails.update(emails_from_home)
    if emails_from_home:
        print(f"    → 首頁找到：{emails_from_home}")

    for path in CONTACT_PATHS:
        if len(all_emails) >= 5:  # 找到足夠數量後提早停止
            break
        url = base_url + path
        html = fetch_html(url)
        emails = extract_emails_from_html(html, domain)
        if emails:
            print(f"    → {path} 找到：{emails}")
            all_emails.update(emails)
        time.sleep(REQUEST_DELAY)

    # --- 策略三：子頁面探索 ---
    if not all_emails:
        print(f"  [策略三] 子頁面探索...")
        subpages = collect_all_subpage_urls(base_url, homepage_html, domain)
        for sub_url in subpages:
            html = fetch_html(sub_url)
            emails = extract_emails_from_html(html, domain)
            if emails:
                print(f"    → {sub_url} 找到：{emails}")
                all_emails.update(emails)
            time.sleep(REQUEST_DELAY)
            if len(all_emails) >= 5:
                break

    print(f"  → 最終找到 {len(all_emails)} 筆符合後綴的 Email：{all_emails}")
    return sorted(all_emails)


# ===== Google Sheets 操作 =====

def connect_sheet():
    """建立 Google Sheets 連線，回傳 (sheet, all_values)。"""
    print("[步驟 1] 連接 Google Sheets，讀取「名單副本」工作表...")
    scope = [
        'https://www.googleapis.com/auth/spreadsheets',
        'https://www.googleapis.com/auth/drive',
    ]
    creds  = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scope)
    client = gspread.authorize(creds)
    sheet  = client.open_by_key(SPREADSHEET_ID).worksheet(WORKSHEET_NAME)
    all_values = sheet.get_all_values()
    print(f"  → 共讀取 {len(all_values)} 列（含標題）。")
    return sheet, all_values


def load_pending_rows(all_values: list) -> list:
    """
    篩選需要處理的列：
    - H欄（官方網站）非空
    - E欄（email）為空
    回傳 list of dict，含 row_index、website_url、row_data。
    """
    pending = []
    for i, row in enumerate(all_values[1:], start=2):  # 第 2 列起
        # 補齊欄位，避免 index out of range
        while len(row) < 8:
            row.append('')

        website_url = row[7].strip()   # H欄（index 7）
        email_col   = row[4].strip()   # E欄（index 4）

        # 管理規則 1：H欄為空 → 略過
        if not website_url:
            continue

        # 管理規則 2：E欄已有值 → 略過
        if email_col:
            continue

        pending.append({
            'row_index':   i,
            'website_url': website_url,
            'row_data':    list(row),    # 複製一份，供多列複製使用
        })

    print(f"  → 待處理列數：{len(pending)}")
    return pending


def save_temp(data):
    """暫存處理結果至 ⌚️暫存 資料夾。"""
    os.makedirs(TEMP_DIR, exist_ok=True)
    with open(TEMP_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"  [暫存] 已儲存至 {TEMP_FILE}")


def write_results_to_sheet(sheet, all_values: list, results: list):
    """
    根據管理規則寫回 Google Sheets，並保持原始 A 欄公司排序：
    - 找到 1 筆 Email → 直接更新 E欄
    - 找到 2 筆以上 → 在該列後方依序插入複製列，分別填入 Email
    - 找不到 → 略過

    處理策略：從前往後依序處理（row_index 升序），
    用 inserted_offset 追蹤已累計插入的列數，
    自動修正後續列的實際行號，確保順序不被打亂。

    results: list of {row_index, emails: list, row_data: list}
    """
    if not results:
        print("[警告] 無結果可寫回。")
        return

    print(f"\n[步驟 4] 開始寫回 Google Sheets，共 {len(results)} 筆有結果的列...")

    # 按原始行號升序排列，保持公司原始順序
    results_sorted = sorted(results, key=lambda r: r['row_index'])

    # 累計已插入的列數（每插入一列，後續所有列的實際行號 +1）
    inserted_offset = 0

    for res in results_sorted:
        # 修正後的實際行號（含累計插入偏移）
        row_idx  = res['row_index'] + inserted_offset
        emails   = res['emails']
        row_data = res['row_data']

        if not emails:
            # 管理規則 5：找不到 → 略過
            continue

        if len(emails) == 1:
            # 管理規則 3：找到 1 筆 → 直接更新 E欄
            email = emails[0]
            try:
                sheet.update_cell(row_idx, 5, email)  # E欄 = column 5
                print(f"  ✓ 第 {row_idx} 列（{row_data[0]}）→ E欄填入 {email}")
            except Exception as e:
                print(f"  [警告] 第 {row_idx} 列寫入失敗：{e}")

        else:
            # 管理規則 4：找到 2 筆以上
            # 第一列：直接更新現有列的 E欄
            # 第 2..N 列：在第一列正下方依序插入
            try:
                # 更新第一列 E欄
                row_data_first = list(row_data)
                row_data_first[4] = emails[0]
                # 補齊到標準欄位長度
                while len(row_data_first) < len(all_values[0]):
                    row_data_first.append('')
                col_end = chr(ord('A') + len(row_data_first) - 1)
                sheet.update(f'A{row_idx}:{col_end}{row_idx}', [row_data_first])
                print(f"  ✓ 第 {row_idx} 列（{row_data[0]}）→ E欄填入 {emails[0]}")

                # 依序在下方插入剩餘 Email 列（從第 2 筆到第 N 筆，由上往下插入）
                # 每次插入後，insert 位置 +1，確保順序正確
                for i, email in enumerate(emails[1:], start=1):
                    insert_pos = row_idx + i
                    new_row = list(row_data)
                    new_row[4] = email
                    while len(new_row) < len(all_values[0]):
                        new_row.append('')
                    # insert_row 直接帶入完整列資料，避免二次 update
                    sheet.insert_row(new_row, insert_pos)
                    print(f"    → 插入第 {insert_pos} 列，E欄填入 {email}")
                    time.sleep(0.5)  # 避免 API 速率限制

                # 更新累計偏移（本公司插入了 len(emails)-1 列）
                inserted_offset += len(emails) - 1
                print(f"    → 共寫入 {len(emails)} 筆 Email，累計偏移 +{len(emails) - 1}")

            except Exception as e:
                print(f"  [警告] 第 {row_idx} 列多 Email 寫入失敗：{e}")

        time.sleep(0.5)  # 避免觸發 Google API 速率限制

    print("  → Google Sheets 寫入完成！")


# ===== 主程式 =====

def main():
    print("=== 網域信箱爬蟲 (PlayPlus_Sales 版) ===\n")

    # 1. 連接 Google Sheets，讀取資料
    sheet, all_values = connect_sheet()

    # 2. 篩選待處理列（H欄有值且 E欄為空）
    print("\n[步驟 2] 篩選待處理列（H欄有官方網站、E欄 email 為空）...")
    pending = load_pending_rows(all_values)
    if not pending:
        print("  → 沒有需要處理的列，結束。")
        return

    # 3. 逐列查找 Email
    print(f"\n[步驟 3] 開始查找 Email（共 {len(pending)} 間公司）...")
    all_results = []
    temp_buffer = []

    for idx, item in enumerate(pending, start=1):
        company_name = item['row_data'][0] if item['row_data'] else '未知'
        website_url  = item['website_url']
        print(f"\n  [{idx}/{len(pending)}] {company_name} → {website_url}")

        emails = find_emails_for_domain(website_url)

        result = {
            'row_index':    item['row_index'],
            'company_name': company_name,
            'website_url':  website_url,
            'emails':       emails,
            'row_data':     item['row_data'],
        }
        all_results.append(result)
        temp_buffer.append({k: v for k, v in result.items() if k != 'row_data'})

        # 每處理 10 筆暫存一次
        if idx % 10 == 0:
            save_temp(temp_buffer)

        time.sleep(REQUEST_DELAY)

    # 最終暫存
    save_temp(temp_buffer)

    # 4. 寫回 Google Sheets
    results_with_email = [r for r in all_results if r['emails']]
    print(f"\n  → 找到 Email 的公司：{len(results_with_email)}/{len(all_results)} 筆")
    write_results_to_sheet(sheet, all_values, results_with_email)

    print("\n=== 全部完成 ===")


if __name__ == '__main__':
    main()
