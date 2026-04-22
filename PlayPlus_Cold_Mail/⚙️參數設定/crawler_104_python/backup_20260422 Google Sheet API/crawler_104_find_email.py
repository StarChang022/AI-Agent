"""
crawler_104_find_email.py (Google Sheets 版本)
==============================================
依照 4.104crawler查找網域信箱.md 指令執行。

流程：
  1. 從 Google Sheets 『名單副本』讀取「官方網站」與「來源」欄位
  2. 從網址解析網域（domain）
  3. 依序執行四大 OSINT 策略：
       ① 直接爬取 104 公司頁面
       ② WHOIS 查詢（過濾代理信箱）
       ③ DuckDuckGo 搜尋「@domain」
       ④ Google Dorks（Facebook 專頁、官網站內搜尋）
  4. 找到 1 筆 → 填入「email」欄位
     找到 2 筆以上 → 複製該列，每筆一列，分別填入對應信箱
     找不到 → 保留原列不動
  5. 結果完整覆寫回 Google Sheets

GSheet 欄位（共 9 欄，A~I）：
  公司品牌簡稱, 序號, 官方網站, 產業, 員工人數,
  email（本腳本填寫）, 聯絡人名稱（本腳本填寫）, 來源, 說明

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
from urllib.parse import urlparse, quote_plus

import requests
from bs4 import BeautifulSoup

import gsheet_helper as gs

# ──────────────────────────────────────────────
# 設定區
# ──────────────────────────────────────────────

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "zh-TW,zh;q=0.9,en-US;q=0.8",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}

DELAY_MIN = 1.5
DELAY_MAX = 3.5
MAX_SEARCH_PAGES = 3
RESULTS_PER_PAGE = 10
GOOGLE_BLOCK_WAIT = 0
MAX_EMAILS_PER_DOMAIN = 10


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
        email_lower = email.lower()
        if email_lower not in seen:
            seen.add(email_lower)
            unique.append(email_lower)
    return unique


def search_google_for_emails(domain: str, query: str = None) -> list[str]:
    """使用 Google 搜尋，從結果頁面文字抓取符合網域的 email。"""
    all_emails = []
    seen_emails = set()

    if query is None:
        query = f"\"@{domain}\""
    encoded_query = quote_plus(query)

    for page_num in range(MAX_SEARCH_PAGES):
        start = page_num * RESULTS_PER_PAGE
        google_url = (
            f"https://www.google.com/search"
            f"?q={encoded_query}&num={RESULTS_PER_PAGE}&start={start}&hl=zh-TW"
        )

        try:
            resp = requests.get(google_url, headers=HEADERS, timeout=15)
        except requests.RequestException as e:
            print(f"      [錯誤] Google 請求失敗（頁面 {page_num+1}）：{e}")
            break

        if resp.status_code == 429 or "sorry/index" in resp.url:
            print(f"      [警告] Google 封鎖，立即停止搜尋")
            if GOOGLE_BLOCK_WAIT > 0:
                time.sleep(GOOGLE_BLOCK_WAIT)
            break

        if resp.status_code != 200:
            print(f"      [警告] HTTP {resp.status_code}，停止搜尋")
            break

        soup = BeautifulSoup(resp.text, "html.parser")
        page_text = soup.get_text(separator=" ")

        emails = extract_emails_from_text(page_text, domain)
        for email in emails:
            if email not in seen_emails:
                seen_emails.add(email)
                all_emails.append(email)

        if len(all_emails) >= MAX_EMAILS_PER_DOMAIN:
            all_emails = all_emails[:MAX_EMAILS_PER_DOMAIN]
            break

        if "下一頁" not in page_text and "Next" not in page_text:
            break

        time.sleep(random.uniform(2.0, 4.0))

    return all_emails


def search_duckduckgo_for_emails(domain: str) -> list[str]:
    """備用方案：使用 DuckDuckGo 搜尋「@domain」。"""
    all_emails = []
    seen_emails = set()

    query = f"@{domain}"
    encoded_query = quote_plus(query)
    ddg_url = f"https://html.duckduckgo.com/html/?q={encoded_query}"

    try:
        resp = requests.get(ddg_url, headers=HEADERS, timeout=15)
        resp.raise_for_status()
    except requests.RequestException as e:
        print(f"      [錯誤] DuckDuckGo 請求失敗：{e}")
        return []

    soup = BeautifulSoup(resp.text, "html.parser")
    page_text = soup.get_text(separator=" ")
    emails = extract_emails_from_text(page_text, domain)
    for email in emails:
        if email not in seen_emails:
            seen_emails.add(email)
            all_emails.append(email)

    return all_emails[:MAX_EMAILS_PER_DOMAIN]


def search_104_page(url: str, domain: str) -> list[str]:
    """爬取 104 公司頁面文字，尋找 Email"""
    if not url or "104.com.tw/company" not in url:
        return []
    try:
        resp = requests.get(url, headers=HEADERS, timeout=10)
        if resp.status_code == 200:
            return extract_emails_from_text(resp.text, domain)
    except Exception as e:
        print(f"      [警告] 104 頁面請求失敗：{e}")
    return []


def search_whois_for_emails(domain: str) -> list[str]:
    """透過 OS whois 指令查詢，排除常見代理信箱"""
    try:
        proc = subprocess.run(["whois", domain], capture_output=True, text=True, timeout=10)
        emails = extract_emails_from_text(proc.stdout, domain)
        blacklist = {"abuse", "privacy", "host", "twnoc", "twnic", "domain", "admin", "service@"}
        return [e for e in emails if not any(b in e for b in blacklist)]
    except Exception as e:
        print(f"      [警告] WHOIS 查詢失敗：{e}")
        return []


def find_emails_for_company(row: dict, domain: str) -> list[str]:
    """主搜尋函式：整合四種 OSINT 策略，去重回傳信箱清單。"""
    all_found = []
    seen = set()
    company_name = row.get("公司品牌簡稱", "").strip()
    source_url = row.get("來源", "").strip()

    def add_emails(emails: list[str], source_msg: str):
        added = False
        for e in emails:
            e_lower = e.lower()
            if e_lower not in seen:
                seen.add(e_lower)
                all_found.append(e_lower)
                added = True
        if added:
            print(f"      ✅ [{source_msg}] 找到信箱：{emails}")

    print(f"      開始 OSINT 搜尋網域：@{domain}")

    found_104 = search_104_page(source_url, domain)
    add_emails(found_104, "104 頁面")
    if len(all_found) >= MAX_EMAILS_PER_DOMAIN:
        return all_found

    found_whois = search_whois_for_emails(domain)
    add_emails(found_whois, "WHOIS")
    if len(all_found) >= MAX_EMAILS_PER_DOMAIN:
        return all_found

    found_ddg = search_duckduckgo_for_emails(domain)
    add_emails(found_ddg, "DuckDuckGo")
    if len(all_found) >= MAX_EMAILS_PER_DOMAIN:
        return all_found

    dorks = [
        f'"{company_name}" site:facebook.com "email"',
        f'site:{domain} "email" OR "聯絡"'
    ]
    for dork in dorks:
        found_dork = search_google_for_emails(domain, query=dork)
        add_emails(found_dork, "Google Dork")
        if len(all_found) >= MAX_EMAILS_PER_DOMAIN:
            return all_found
        time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))

    return all_found


def is_official_email(email: str) -> bool:
    """判斷是否為官方/通用信箱。"""
    official_prefixes = {
        "info", "contact", "service", "support", "hello", "admin",
        "sales", "marketing", "hr", "mail", "office", "general",
        "inquiry", "enquiry", "business", "team", "help", "cs",
        "customer", "pr", "press", "media", "tw", "taiwan"
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
    print("  104 公司網域信箱查找工具 (Google Sheets 版本)")
    print("=" * 60)

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
        elif len(emails) == 1:
            email = emails[0]
            new_row = dict(row)
            new_row["email"] = email
            new_row["聯絡人名稱"] = "官方" if is_official_email(email) else (guess_name_from_email(email) or "官方")
            result_rows.append(new_row)
            updated_count += 1
            print(f"        ✅ 信箱：{email}")
        else:
            print(f"        ✅ 找到 {len(emails)} 個信箱，複製 {len(emails)} 列：")
            for email in emails:
                new_row = dict(row)
                new_row["email"] = email
                new_row["聯絡人名稱"] = "官方" if is_official_email(email) else (guess_name_from_email(email) or "官方")
                result_rows.append(new_row)
                print(f"           - {email}")
            updated_count += 1

        if i < total:
            delay = random.uniform(DELAY_MIN, DELAY_MAX)
            print(f"        等待 {delay:.1f} 秒...\n")
            time.sleep(delay)

    # 覆寫回 Google Sheets
    print("\n[GSheet] 覆寫資料至 Google Sheets...")
    gs.write_all_rows(service, result_rows, fieldnames)

    print("\n" + "=" * 60)
    print(f"  完成！")
    print(f"  ✅ 成功找到信箱：{updated_count} 間公司")
    print(f"  ⏭  略過：{skipped_count} 列")
    print(f"  📄 最終共 {len(result_rows)} 列")
    print(f"  Google Sheets：https://docs.google.com/spreadsheets/d/{gs.SPREADSHEET_ID}/edit")
    print("=" * 60)


if __name__ == "__main__":
    main()
