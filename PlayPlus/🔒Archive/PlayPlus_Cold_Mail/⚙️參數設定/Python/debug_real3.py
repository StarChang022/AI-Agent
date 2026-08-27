import asyncio
from playwright.async_api import async_playwright
import sys
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.append(os.path.join(BASE_DIR, '⚙️參數設定', 'Python'))

import crawler_104_3_email

def mock_extract(html):
    print("  extract 1: starting")
    from bs4 import BeautifulSoup
    emails = set()
    print("  extract 2: BeautifulSoup")
    soup = BeautifulSoup(html, 'html.parser')
    print("  extract 3: soup.select")
    for el in soup.select('span[data-cfemail]'):
        pass
    print("  extract 4: mailto")
    for a in soup.find_all('a', href=True):
        pass
    print("  extract 5: cdn-cgi")
    for a in soup.find_all('a', href=True):
        pass
    print("  extract 6: get_text")
    decoded_text = soup.get_text()
    print("  extract 7: regex decoded")
    for email in crawler_104_3_email.EMAIL_REGEX.findall(decoded_text):
        pass
    print("  extract 8: regex html")
    for email in crawler_104_3_email.EMAIL_REGEX.findall(html):
        pass
    print("  extract 9: done")
    return emails

crawler_104_3_email.extract_emails_from_html = mock_extract

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        print("Starting twpemay.com...")
        emails = await crawler_104_3_email.scrape_emails_from_web(context, "Twpemay", "http://twpemay.com", "twpemay.com")
        print("Twpemay:", emails)
        await browser.close()

asyncio.run(run())
