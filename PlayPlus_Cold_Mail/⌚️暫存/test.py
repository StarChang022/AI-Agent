import requests
import re
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
import os

def decode_cloudflare_email(encoded_str):
    """
    解密 Cloudflare Email Obfuscation（data-cfemail 屬性）。
    Cloudflare 使用 XOR 加密：第一個字節是 Key，其餘字節與 Key 做 XOR 還原。
    """
    try:
        key = int(encoded_str[:2], 16)  # 前兩個 Hex 字元是 Key
        email = ''.join(
            chr(int(encoded_str[i:i+2], 16) ^ key)
            for i in range(2, len(encoded_str), 2)
        )
        return email
    except Exception:
        return None

def find_emails_in_page(url, html_text):
    emails = set()
    soup = BeautifulSoup(html_text, 'html.parser')

    # 方法 1: 解密 Cloudflare 保護的 Email（data-cfemail 屬性）
    for el in soup.select('span[data-cfemail]'):
        encoded = el.get('data-cfemail', '')
        if encoded:
            decoded = decode_cloudflare_email(encoded)
            if decoded and '@' in decoded:
                print(f"   🔓 解密 Cloudflare Email: {decoded}")
                emails.add(decoded)

    # 方法 2: 尋找 mailto: 連結
    for a in soup.find_all('a', href=True):
        href = a['href']
        if href.lower().startswith('mailto:'):
            email = href[7:].split('?')[0].strip()
            if email and '@' in email:
                emails.add(email)

    # 方法 3: 解密 Cloudflare /cdn-cgi/l/email-protection#<hash> 連結
    # 這種 href 不是 mailto:，而是指向 Cloudflare 的保護路徑，hash 後的編碼與 data-cfemail 相同
    for a in soup.find_all('a', href=True):
        href = a['href']
        if '/cdn-cgi/l/email-protection#' in href:
            encoded = href.split('#', 1)[-1]
            decoded = decode_cloudflare_email(encoded)
            if decoded and '@' in decoded:
                print(f"   🔓 解密 Cloudflare /cdn-cgi/ Email: {decoded}")
                emails.add(decoded)

    # 方法 4: 掃描 BeautifulSoup 解碼後的純文字（自動還原 &#x40; 等 HTML 實體）
    email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    decoded_text = soup.get_text()
    text_emails = re.findall(email_pattern, decoded_text)
    invalid_extensions = ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.css', '.js')
    for email in text_emails:
        if not email.lower().endswith(invalid_extensions):
            emails.add(email)

    # 方法 5: 正則表達式在原始 HTML 中搜尋（補漏網之魚）
    raw_emails = re.findall(email_pattern, html_text)
    for email in raw_emails:
        if not email.lower().endswith(invalid_extensions):
            emails.add(email)

    return emails

def get_internal_links(base_url, html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    links = set()
    base_domain = urlparse(base_url).netloc

    for a in soup.find_all('a', href=True):
        href = a['href']
        abs_url = urljoin(base_url, href)
        parsed_abs = urlparse(abs_url)

        if parsed_abs.netloc == base_domain:
            # 移除錨點和查詢字串
            clean_url = abs_url.split('#')[0].split('?')[0].rstrip('/')
            if clean_url:
                links.add(clean_url)
    return links

def crawl_and_extract_emails(start_url, max_pages=10):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }

    visited = set()
    all_emails = set()

    # --- 第一步：爬取首頁 ---
    print(f"🔗 正在分析首頁: {start_url}")
    try:
        response = requests.get(start_url, headers=headers, timeout=10)
        response.raise_for_status()
    except Exception as e:
        print(f"❌ 無法連接首頁: {e}")
        return all_emails

    visited.add(start_url.rstrip('/'))
    homepage_emails = find_emails_in_page(start_url, response.text)
    all_emails.update(homepage_emails)

    # --- 第二步：收集所有內部連結 ---
    internal_links = get_internal_links(start_url, response.content)

    # 優先爬取含聯絡/關於資訊的頁面
    priority_keywords = ['contact', 'about', 'agent', 'service', '聯絡', '關於']
    priority_urls, other_urls = [], []

    for link in internal_links:
        if link in visited:
            continue
        if any(k in link.lower() for k in priority_keywords):
            priority_urls.append(link)
        else:
            other_urls.append(link)

    to_visit = priority_urls + other_urls
    pages_crawled = 1

    print(f"🔍 找到 {len(to_visit)} 個內部連結，優先爬取聯絡/關於等頁面 (最多爬取 {max_pages} 頁)...")

    # --- 第三步：爬取子頁面 ---
    for link in to_visit:
        if pages_crawled >= max_pages:
            break
        if link in visited:
            continue

        print(f"📄 正在掃描 ({pages_crawled + 1}/{max_pages}): {link}")
        visited.add(link)
        pages_crawled += 1

        try:
            res = requests.get(link, headers=headers, timeout=10)
            if res.status_code == 200:
                emails = find_emails_in_page(link, res.text)
                if emails:
                    print(f"   ✨ 找到 Email: {', '.join(emails)}")
                    all_emails.update(emails)
        except Exception as e:
            print(f"   ❌ 讀取頁面失敗: {e}")

    return all_emails

if __name__ == "__main__":
    target_url = "https://zh-tw.yunghua.com.tw/"
    emails = crawl_and_extract_emails(target_url, max_pages=10)

    # 儲存路徑：與 test.py 同一個資料夾下的 scraped_emails.txt
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_file = os.path.join(script_dir, "scraped_emails.txt")

    print("\n" + "="*50)
    if emails:
        print(f"🎉 任務完成！共找到 {len(emails)} 個 Email：")
        for idx, email in enumerate(sorted(emails), 1):
            print(f"  {idx}. {email}")

        with open(output_file, "w", encoding="utf-8") as f:
            for email in sorted(emails):
                f.write(email + "\n")
        print(f"\n💾 結果已儲存至: {output_file}")
    else:
        print("⚠️ 未找到任何 Email。")
    print("="*50)
