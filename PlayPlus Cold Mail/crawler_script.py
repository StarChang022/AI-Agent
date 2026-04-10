import csv
import re
import requests
from bs4 import BeautifulSoup
import os
from urllib.parse import urlparse

def find_emails(url):
    try:
        if not url.startswith('http'):
            url = 'http://' + url
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }
        # Disable SSL verification temporarily to avoid issues with some company sites
        response = requests.get(url, headers=headers, timeout=15, verify=False)
        response.raise_for_status()
        
        # Extract emails using regex
        email_pattern = r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
        emails = set(re.findall(email_pattern, response.text))
        
        # Filter out common false positives (image files, etc.)
        filtered_emails = set()
        for email in emails:
            email = email.lower()
            if not email.endswith(('.png', '.jpg', '.jpeg', '.gif', '.svg', '.wixpress.com', 'sentry.io')):
                filtered_emails.add(email)
                
        return list(filtered_emails), response.text
    except Exception as e:
        print(f"無法爬取或解析 {url}: {e}")
        return [], ""

# 電商平台網域清單
ECOMMERCE_DOMAINS = [
    'shopify.com', 'shopee.com', 'shopee.com.tw', 'shop.line.me',
    '91app.com', 'cyberbiz.io', 'shopline.me', 'shopline.com',
    'pchome.com.tw', 'momo.com.tw', 'rakuten.com.tw', 'ruten.com.tw',
    'books.com.tw', 'yahooauctions', 'wixsite.com'
]

# 電商關鍵字（頁面內文）
ECOMMERCE_KEYWORDS = [
    '加入購物車', '立即購買', '選購商品', 'add to cart', 'checkout',
    'shopping cart', '結帳', '購物車', 'buy now', '立刻購買'
]

def detect_ecommerce(url, html_text):
    """判斷該網站是否具備電商購物功能"""
    parsed = urlparse(url)
    netloc = parsed.netloc.lower()
    # 1. 以網域名稱判斷
    for domain in ECOMMERCE_DOMAINS:
        if domain in netloc:
            return True
    # 2. 以頁面內文關鍵字判斷
    if html_text:
        for kw in ECOMMERCE_KEYWORDS:
            if kw in html_text:
                return True
    return False

def main():
    input_file = os.path.join('冷郵件對象', '名單官網副本.csv')
    
    # 確保輸入檔案存在
    if not os.path.exists(input_file):
        print(f"找不到檔案: {input_file}")
        return

    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)
        rows = list(reader)
        
    new_rows = []
    
    print("開始爬取網站 Email...")
    
    for i, row in enumerate(rows):
        # 確保該列有足夠的欄位（備註為第 12 欄，index 11）
        while len(row) < 12:
            row.append("")

        company = row[0]
        url = row[2]
        existing_email = row[5]

        # 如果有網址且 Email 欄位為空，則進行爬蟲
        if url.strip() and not existing_email.strip():
            print(f"[{i+1}/{len(rows)}] 正在爬取 {company} ({url})...")
            # 忽略 requests 的 insecure request 警告
            requests.packages.urllib3.disable_warnings()
            emails, html_text = find_emails(url)

            # ── 備註：判斷官方網站 / 電商購物車 ──────────────────
            remarks = []
            if url.strip():
                remarks.append("已經有官方網站。")
            if detect_ecommerce(url, html_text):
                remarks.append("已經有電商購物車。")
            if remarks:
                row[11] = "".join(remarks)
            # ─────────────────────────────────────────────────────

            if emails:
                print(f"  -> 找到 Email: {', '.join(emails)}")
                for email in emails:
                    new_row = row.copy()
                    new_row[5] = email
                    new_rows.append(new_row)
                continue
            else:
                print("  -> 未找到 Email")

        # 如果原本就有 Email、沒有網址，或是爬不到 Email，保留原始資料
        new_rows.append(row)
        
    # 直接覆寫原本的檔案 (依據您的需求：直接覆寫於 csv 檔)
    with open(input_file, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(new_rows)
        
    print(f"\n✅ 爬蟲完成！已更新 {input_file}")

if __name__ == '__main__':
    main()
