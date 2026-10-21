import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import re
import time

EMAIL_REGEX = re.compile(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}')

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()
        print("Navigating...")
        await page.goto("http://twpemay.com", wait_until='domcontentloaded', timeout=15000)
        html = await page.content()
        print(f"HTML size: {len(html)}")
        
        t0 = time.time()
        print("Running BeautifulSoup...")
        soup = BeautifulSoup(html, 'html.parser')
        print(f"BeautifulSoup took {time.time()-t0:.2f}s")
        
        t0 = time.time()
        print("Running soup.get_text()...")
        decoded_text = soup.get_text()
        print(f"get_text() took {time.time()-t0:.2f}s")
        
        t0 = time.time()
        print("Running regex on decoded_text...")
        EMAIL_REGEX.findall(decoded_text)
        print(f"Regex 1 took {time.time()-t0:.2f}s")
        
        t0 = time.time()
        print("Running regex on html...")
        EMAIL_REGEX.findall(html)
        print(f"Regex 2 took {time.time()-t0:.2f}s")
        
        await browser.close()

asyncio.run(run())
