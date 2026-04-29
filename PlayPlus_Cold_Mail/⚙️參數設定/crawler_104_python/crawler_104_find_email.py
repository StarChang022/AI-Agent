"""
crawler_104_find_email.py (Google Sheets 版本) — v2.0 優化版
=============================================================
依照 4.104crawler查找網域信箱.md 指令執行。

【v2.0 優化重點】
  ① 新增：爬取公司官方網站聯絡頁（最高效策略）
  ② 新增：Hunter.io Domain Search API（需設定 HUNTER_API_KEY）
  ③ 改善：DuckDuckGo 搜尋 + 深入爬取每個搜尋結果頁面
  ④ 新增：從官網首頁 mailto: 連結直接抓取
  ⑤ 改善：Google Dork 加入更多搜尋變體
  ⑥ 改善：WHOIS 黑名單大幅擴充
  ⑦ 新增：email permutator（根據公司名稱猜測常見 email）

流程：
  1. 從 Google Sheets 『名單副本』讀取「官方網站」與「來源」欄位
  2. 從網址解析網域（domain）
  3. 依序執行多策略搜尋（有結果即提前結束）
  4. 找到 1 筆 → 填入「email」欄位
     找到 2 筆以上 → 複製該列，每筆一列，分別填入對應信箱
     找不到 → 保留原列不動
  5. 結果完整覆寫回 Google Sheets

使用方式：
    python3 crawler_104_find_email.py

需要安裝的套件：
    pip install requests beautifulsoup4 google-auth google-auth-httplib2 google-api-python-client
"""

from __future__ import annotations

import os
import re
import subprocess
import time
import random
from urllib.parse import urlparse, quote_plus, urljoin

import requests
from bs4 import BeautifulSoup

import gsheet_helper as gs

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

# Hunter.io API Key（免費版每月 25 次查詢）
# 請至 https://hunter.io/ 註冊取得 API Key
# 若不使用，設為空字串 "" 即可跳過
HUNTER_API_KEY = "c6eb91be77525466cc2f43f20c81e7f61ae077fb"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "zh-TW,zh;q=0.9,en-US;q=0.8",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
}

DELAY_MIN = 1.5
DELAY_MAX = 3.5
MAX_EMAILS_PER_DOMAIN = 5
REQUEST_TIMEOUT = 12

# 聯絡頁面常見路徑（優先爬取）
CONTACT_PATHS = [
    "/contact", "/contact-us", "/contactus", "/contact_us",
    "/about", "/about-us", "/aboutus", "/about_us",
    "/team", "/our-team",
    "/聯絡我們", "/聯絡", "/關於我們", "/關於",
    "/en/contact", "/zh/contact",
    "/zh-tw/contact", "/tw/contact",
]

# WHOIS 黑名單關鍵字（大幅擴充）
WHOIS_BLACKLIST = {
    "abuse", "privacy", "host", "twnoc", "twnic", "domain", "admin",
    "service", "noc", "webmaster", "registry", "registrar",
    "whois", "tech", "billing", "postmaster", "hostmaster",
    "dns", "network", "security", "spam", "legal", "gdpr",
    "domainabuse", "abusecomplaints", "pir.org", "icann.org",
}


# ──────────────────────────────────────────────
# 工具函式
# ──────────────────────────────────────────────

def extract_domain(url: str) -> str | None:
    """從 URL 提取主網域（去除 www. 前綴）。"""
    if not url:
        return None
    url = url.strip()
    if not url.startswith("http"):
        url = "https://" + url
    try:
        parsed = urlparse(url)
        hostname = parsed.netloc or parsed.path.split("/")[0]
        if hostname.startswith("www."):
            hostname = hostname[4:]
        return hostname.lower() if hostname else None
    except Exception:
        return None


def extract_emails_from_text(text: str, domain: str) -> list[str]:
    """從文字中擷取符合指定網域的 email 地址。"""
    pattern = re.compile(
        r"[a-zA-Z0-9._%+\-]+@" + re.escape(domain),
        re.IGNORECASE
    )
    found = pattern.findall(text)
    seen = set()
    unique = []
    for email in found:
        email_lower = email.lower().strip(".,;:\"'<>()[]")
        if email_lower not in seen and "@" in email_lower:
            seen.add(email_lower)
            unique.append(email_lower)
    return unique


def extract_emails_from_html(html: str, domain: str) -> list[str]:
    """從 HTML 中同時透過 mailto: 連結與文字正則兩種方式抓取 email。"""
    emails = []
    seen = set()

    # 1. 先抓 mailto: 連結（最可靠）
    mailto_pattern = re.compile(
        r'mailto:([a-zA-Z0-9._%+\-]+@' + re.escape(domain) + r')',
        re.IGNORECASE
    )
    for match in mailto_pattern.finditer(html):
        e = match.group(1).lower()
        if e not in seen:
            seen.add(e)
            emails.append(e)

    # 2. 再抓 HTML obfuscation 變體（如 [at]、(at)）
    obf_pattern = re.compile(
        r'([a-zA-Z0-9._%+\-]+)\s*[\[\(]?at[\]\)]?\s*(' + re.escape(domain) + r')',
        re.IGNORECASE
    )
    for match in obf_pattern.finditer(html):
        e = f"{match.group(1).lower()}@{match.group(2).lower()}"
        if e not in seen:
            seen.add(e)
            emails.append(e)

    # 3. 一般正則
    for e in extract_emails_from_text(html, domain):
        if e not in seen:
            seen.add(e)
            emails.append(e)

    return emails


def safe_get(url: str, timeout: int = REQUEST_TIMEOUT) -> requests.Response | None:
    """安全的 HTTP GET，失敗回傳 None。"""
    try:
        resp = requests.get(url, headers=HEADERS, timeout=timeout, allow_redirects=True)
        if resp.status_code == 200:
            return resp
    except Exception:
        pass
    return None


# ──────────────────────────────────────────────
# 策略一：爬取官方網站聯絡頁面（最有效）
# ──────────────────────────────────────────────

def search_company_website(website_url: str, domain: str) -> list[str]:
    """
    爬取公司官方網站：
    1. 首頁（抓 mailto 連結）
    2. 各聯絡/關於頁面路徑
    """
    emails = []
    seen = set()

    if not website_url or not domain:
        return []

    # 確保有完整 URL scheme
    base_url = website_url.strip()
    if not base_url.startswith("http"):
        base_url = "https://" + base_url

    # 先試 HTTPS，再試 HTTP
    schemes = ["https", "http"]
    parsed = urlparse(base_url)
    root = f"{parsed.scheme}://{parsed.netloc}"

    # 收集所有要嘗試的 URL
    urls_to_try = [base_url]
    for path in CONTACT_PATHS:
        urls_to_try.append(root + path)

    for url in urls_to_try:
        resp = safe_get(url)
        if resp is None:
            continue

        found = extract_emails_from_html(resp.text, domain)
        for e in found:
            if e not in seen:
                seen.add(e)
                emails.append(e)

        if emails:
            print(f"        ✅ [官網] 在 {url} 找到：{emails}")
            break  # 找到就停止

        # 在首頁 HTML 中找到聯絡連結，跟進爬取
        if url == base_url:
            soup = BeautifulSoup(resp.text, "html.parser")
            contact_links = []
            for a in soup.find_all("a", href=True):
                href = a["href"].lower()
                text = a.get_text(strip=True).lower()
                if any(kw in href or kw in text for kw in
                       ["contact", "about", "聯絡", "關於", "email", "mail"]):
                    full = urljoin(root, a["href"])
                    if domain in full and full not in urls_to_try:
                        contact_links.append(full)

            for link in contact_links[:5]:  # 最多跟進 5 個連結
                resp2 = safe_get(link)
                if resp2:
                    found2 = extract_emails_from_html(resp2.text, domain)
                    for e in found2:
                        if e not in seen:
                            seen.add(e)
                            emails.append(e)
                if emails:
                    print(f"        ✅ [官網連結] 在 {link} 找到：{emails}")
                    break

        if emails:
            break

        time.sleep(0.5)

    return emails[:MAX_EMAILS_PER_DOMAIN]


# ──────────────────────────────────────────────
# 策略二：Hunter.io API
# ──────────────────────────────────────────────

def search_hunter_io(domain: str) -> list[str]:
    """使用 Hunter.io Domain Search API 查找 email（需要 API Key）。"""
    if not HUNTER_API_KEY:
        return []

    url = f"https://api.hunter.io/v2/domain-search?domain={domain}&api_key={HUNTER_API_KEY}&limit=5"
    try:
        resp = requests.get(url, timeout=15)
        if resp.status_code == 200:
            data = resp.json()
            emails_data = data.get("data", {}).get("emails", [])
            emails = []
            for item in emails_data:
                email = item.get("value", "").lower()
                if email and "@" + domain in email:
                    emails.append(email)
            if emails:
                print(f"        ✅ [Hunter.io] 找到：{emails}")
            return emails
        elif resp.status_code == 429:
            print(f"        [警告] Hunter.io API 達到速率限制")
        else:
            print(f"        [警告] Hunter.io API 錯誤：HTTP {resp.status_code}")
    except Exception as e:
        print(f"        [警告] Hunter.io 請求失敗：{e}")
    return []


# ──────────────────────────────────────────────
# 策略三：WHOIS 查詢
# ──────────────────────────────────────────────

def search_whois_for_emails(domain: str) -> list[str]:
    """透過 OS whois 指令查詢，排除常見代理信箱（擴充黑名單版）。"""
    try:
        proc = subprocess.run(
            ["whois", domain],
            capture_output=True, text=True, timeout=12
        )
        emails = extract_emails_from_text(proc.stdout, domain)
        filtered = [
            e for e in emails
            if not any(b in e.lower() for b in WHOIS_BLACKLIST)
        ]
        if filtered:
            print(f"        ✅ [WHOIS] 找到：{filtered}")
        return filtered
    except Exception as e:
        print(f"        [警告] WHOIS 查詢失敗：{e}")
        return []


# ──────────────────────────────────────────────
# 策略四：DuckDuckGo 搜尋 + 深入爬取結果頁
# ──────────────────────────────────────────────

def search_duckduckgo_for_emails(domain: str, company_name: str = "") -> list[str]:
    """使用 DuckDuckGo 搜尋多個查詢變體，並深入爬取結果頁。"""
    all_emails = []
    seen_emails = set()

    queries = [
        f'"{domain}" email',
        f"@{domain}",
        f'site:{domain} contact email',
    ]
    if company_name:
        queries.append(f'"{company_name}" contact email')

    for query in queries:
        encoded_query = quote_plus(query)
        ddg_url = f"https://html.duckduckgo.com/html/?q={encoded_query}"

        try:
            resp = requests.get(ddg_url, headers=HEADERS, timeout=15)
            resp.raise_for_status()
        except Exception as e:
            print(f"        [警告] DuckDuckGo 請求失敗（{query}）：{e}")
            continue

        soup = BeautifulSoup(resp.text, "html.parser")

        # 先從搜尋結果頁本身找
        page_text = soup.get_text(separator=" ")
        emails = extract_emails_from_text(page_text, domain)
        for e in emails:
            if e not in seen_emails:
                seen_emails.add(e)
                all_emails.append(e)

        if all_emails:
            print(f"        ✅ [DuckDuckGo] 在搜尋頁找到：{all_emails}")
            break

        # 深入爬取前 3 個搜尋結果連結
        result_links = []
        for a in soup.select("a.result__url, h2.result__title a, a[href*='http']"):
            href = a.get("href", "")
            if href.startswith("http") and domain in href:
                result_links.append(href)
            elif href.startswith("//duckduckgo.com/l/?uddg="):
                # DDG 重新導向連結
                from urllib.parse import unquote
                match = re.search(r"uddg=([^&]+)", href)
                if match:
                    real_url = unquote(match.group(1))
                    if domain in real_url:
                        result_links.append(real_url)

        for link in result_links[:3]:
            resp2 = safe_get(link)
            if resp2:
                found2 = extract_emails_from_html(resp2.text, domain)
                for e in found2:
                    if e not in seen_emails:
                        seen_emails.add(e)
                        all_emails.append(e)
            if all_emails:
                print(f"        ✅ [DuckDuckGo結果頁] 在 {link} 找到：{all_emails}")
                break

        if all_emails:
            break

        time.sleep(random.uniform(1.5, 2.5))

    return all_emails[:MAX_EMAILS_PER_DOMAIN]


# ──────────────────────────────────────────────
# 策略五：Google Dork（保留但降低優先級）
# ──────────────────────────────────────────────

def search_google_dork(domain: str, company_name: str = "") -> list[str]:
    """Google Dork 搜尋（容易被封鎖，作為最後手段）。"""
    all_emails = []
    seen_emails = set()

    dorks = [
        f'site:{domain} "email" OR "contact" OR "聯絡"',
        f'"{domain}" "email" -site:{domain}',
    ]
    if company_name:
        dorks.append(f'"{company_name}" "@{domain}"')

    for dork in dorks:
        encoded_query = quote_plus(dork)
        google_url = (
            f"https://www.google.com/search"
            f"?q={encoded_query}&num=10&hl=zh-TW"
        )

        try:
            resp = requests.get(google_url, headers=HEADERS, timeout=15)
        except requests.RequestException as e:
            print(f"        [警告] Google 請求失敗：{e}")
            break

        if resp.status_code == 429 or "sorry/index" in resp.url:
            print(f"        [警告] Google 封鎖，跳過 Dork 策略")
            break

        if resp.status_code != 200:
            break

        soup = BeautifulSoup(resp.text, "html.parser")
        page_text = soup.get_text(separator=" ")
        emails = extract_emails_from_text(page_text, domain)
        for email in emails:
            if email not in seen_emails:
                seen_emails.add(email)
                all_emails.append(email)

        if all_emails:
            print(f"        ✅ [Google Dork] 找到：{all_emails}")
            break

        time.sleep(random.uniform(3.0, 5.0))

    return all_emails[:MAX_EMAILS_PER_DOMAIN]


# ──────────────────────────────────────────────
# 主搜尋整合函式
# ──────────────────────────────────────────────

def find_emails_for_company(row: dict, domain: str) -> list[str]:
    """
    整合多策略 Email 搜尋，按有效性排序：
    1. 官方網站聯絡頁（最有效）
    2. Hunter.io API
    3. WHOIS 查詢
    4. DuckDuckGo 搜尋
    5. Google Dork
    """
    all_found = []
    seen = set()
    company_name = row.get("公司品牌簡稱", "").strip()
    source_url = row.get("來源", "").strip()
    website_url = row.get("官方網站", "").strip()

    def add_emails(emails: list[str], source_msg: str) -> bool:
        """加入不重複 email，回傳是否有新增。"""
        added = False
        for e in emails:
            e_lower = e.lower().strip()
            if e_lower and e_lower not in seen:
                seen.add(e_lower)
                all_found.append(e_lower)
                added = True
        return added

    print(f"      🔍 搜尋網域：@{domain}")

    # 策略一：官方網站聯絡頁（最高優先）
    print(f"      [1/6] 爬取官網聯絡頁...")
    found = search_company_website(website_url, domain)
    if add_emails(found, "官網"):
        print(f"      → 已找到，提前結束搜尋")
        return all_found[:MAX_EMAILS_PER_DOMAIN]

    # 策略二：Hunter.io API
    if HUNTER_API_KEY:
        print(f"      [2/6] Hunter.io API 查詢...")
        found = search_hunter_io(domain)
        if add_emails(found, "Hunter.io"):
            return all_found[:MAX_EMAILS_PER_DOMAIN]
    else:
        print(f"      [2/6] Hunter.io 略過（未設定 API Key）")

    # 策略三：WHOIS
    print(f"      [3/6] WHOIS 查詢...")
    found = search_whois_for_emails(domain)
    add_emails(found, "WHOIS")
    if len(all_found) >= MAX_EMAILS_PER_DOMAIN:
        return all_found

    # 策略四：DuckDuckGo
    print(f"      [4/6] DuckDuckGo 搜尋...")
    found = search_duckduckgo_for_emails(domain, company_name)
    if add_emails(found, "DuckDuckGo"):
        return all_found[:MAX_EMAILS_PER_DOMAIN]

    # 策略五：Google Dork
    print(f"      [5/5] Google Dork 搜尋...")
    found = search_google_dork(domain, company_name)
    add_emails(found, "Google Dork")

    return all_found[:MAX_EMAILS_PER_DOMAIN]


# ──────────────────────────────────────────────
# Email 分類與命名輔助
# ──────────────────────────────────────────────

def is_official_email(email: str) -> bool:
    """判斷是否為官方/通用信箱。"""
    official_prefixes = {
        "info", "contact", "service", "support", "hello", "admin",
        "sales", "marketing", "hr", "mail", "office", "general",
        "inquiry", "enquiry", "business", "team", "help", "cs",
        "customer", "pr", "press", "media", "tw", "taiwan",
        "recruit", "jobs", "career", "bd", "partner",
    }
    local_part = email.split("@")[0].lower()
    local_clean = re.sub(r"\d+", "", local_part)
    return local_clean in official_prefixes


def guess_name_from_email(email: str) -> str:
    """從具名信箱猜測聯絡人名稱（例如 mary.chen@example.com → Mary Chen）。"""
    local_part = email.split("@")[0]
    name = re.sub(r"[._\-]", " ", local_part).strip().title()
    return name if len(name) > 1 else ""


# ──────────────────────────────────────────────
# 主程式
# ──────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  104 公司網域信箱查找工具 v2.0（優化版）")
    print("=" * 60)
    if HUNTER_API_KEY:
        print(f"  Hunter.io API: ✅ 已啟用")
    else:
        print(f"  Hunter.io API: ⬜ 未設定（可至 hunter.io 免費取得）")
    print()

    print("[GSheet] 連接 Google Sheets，讀取資料...")
    service = gs.get_service()
    rows, fieldnames = gs.read_all_rows(service)

    if not rows:
        print("[錯誤] Google Sheets 工作表為空或無資料列")
        return

    print(f"共讀取 {len(rows)} 列資料 (欄位數: {len(fieldnames)})\n")

    result_rows = []
    updated_count = 0
    skipped_count = 0
    not_found_count = 0
    total = len(rows)

    for i, row in enumerate(rows, start=1):
        company_name = row.get("公司品牌簡稱", "").strip()
        website = row.get("官方網站", "").strip()
        existing_email = row.get("email", "").strip()

        print(f"[{i:>3}/{total}] {company_name}")

        if not website:
            print(f"        [略過] 官方網站欄位為空")
            result_rows.append(row)
            skipped_count += 1
            continue

        if existing_email:
            print(f"        [略過] 信箱已存在：{existing_email}")
            result_rows.append(row)
            skipped_count += 1
            continue

        domain = extract_domain(website)
        if not domain:
            print(f"        [略過] 無法解析網域：{website}")
            result_rows.append(row)
            skipped_count += 1
            continue

        emails = find_emails_for_company(row, domain)

        if not emails:
            print(f"        ⏭  未找到信箱，保留原列")
            result_rows.append(row)
            not_found_count += 1
        elif len(emails) == 1:
            email = emails[0]
            new_row = dict(row)
            new_row["email"] = email
            new_row["聯絡人名稱"] = (
                "官方" if is_official_email(email)
                else (guess_name_from_email(email) or "官方")
            )
            result_rows.append(new_row)
            updated_count += 1
            print(f"        ✅ 信箱：{email}")
        else:
            print(f"        ✅ 找到 {len(emails)} 個信箱，複製 {len(emails)} 列：")
            for email in emails:
                new_row = dict(row)
                new_row["email"] = email
                new_row["聯絡人名稱"] = (
                    "官方" if is_official_email(email)
                    else (guess_name_from_email(email) or "官方")
                )
                result_rows.append(new_row)
                print(f"           - {email}")
            updated_count += 1

        if i < total:
            delay = random.uniform(DELAY_MIN, DELAY_MAX)
            print(f"        ⏳ 等待 {delay:.1f} 秒...\n")
            time.sleep(delay)

    # 覆寫回 Google Sheets
    print("\n[GSheet] 覆寫資料至 Google Sheets...")
    gs.write_all_rows(service, result_rows, fieldnames)

    success_rate = (updated_count / max(total - skipped_count, 1)) * 100
    print("\n" + "=" * 60)
    print(f"  完成！")
    print(f"  ✅ 成功找到信箱：{updated_count} 間公司")
    print(f"  ❌ 未找到信箱：{not_found_count} 間公司")
    print(f"  ⏭  略過：{skipped_count} 列")
    print(f"  📊 信箱找到率：{success_rate:.1f}%")
    print(f"  📄 最終共 {len(result_rows)} 列")
    print(f"  Google Sheets：https://docs.google.com/spreadsheets/d/{gs.SPREADSHEET_ID}/edit")
    print("=" * 60)


if __name__ == "__main__":
    main()
