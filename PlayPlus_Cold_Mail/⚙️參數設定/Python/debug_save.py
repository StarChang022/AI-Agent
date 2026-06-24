import asyncio
from playwright.async_api import async_playwright
import sys
import os

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()
        await page.goto("http://twpemay.com", wait_until='domcontentloaded', timeout=15000)
        html = await page.content()
        with open("twpemay.html", "w") as f:
            f.write(html)
        await browser.close()

asyncio.run(run())
