import asyncio
from playwright.async_api import async_playwright
import sys
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.append(os.path.join(BASE_DIR, '⚙️參數設定', 'Python'))

from crawler_104_3_email import scrape_emails_from_web

import crawler_104_3_email
original_extract = crawler_104_3_email.extract_emails_from_html
def mock_extract(html):
    print("  Called extract_emails_from_html")
    return original_extract(html)
crawler_104_3_email.extract_emails_from_html = mock_extract

original_collect = crawler_104_3_email.collect_all_subpage_urls
def mock_collect(base, html):
    print("  Called collect_all_subpage_urls")
    urls = original_collect(base, html)
    print(f"  Got {len(urls)} urls")
    return urls
crawler_104_3_email.collect_all_subpage_urls = mock_collect

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        print("Starting twpemay.com...")
        emails = await scrape_emails_from_web(context, "Twpemay", "http://twpemay.com", "twpemay.com")
        print("Twpemay:", emails)
        await browser.close()

asyncio.run(run())
