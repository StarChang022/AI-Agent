import asyncio
from playwright.async_api import async_playwright

import sys
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.append(os.path.join(BASE_DIR, '⚙️參數設定', 'Python'))

from crawler_104_3_email import scrape_emails_from_web

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        print("Starting ksnak.com...")
        emails = await scrape_emails_from_web(context, "Ksnak", "http://ksnak.com", "ksnak.com")
        print("Ksnak:", emails)
        
        print("Starting twpemay.com...")
        emails = await scrape_emails_from_web(context, "Twpemay", "http://twpemay.com", "twpemay.com")
        print("Twpemay:", emails)
        await browser.close()

asyncio.run(run())
