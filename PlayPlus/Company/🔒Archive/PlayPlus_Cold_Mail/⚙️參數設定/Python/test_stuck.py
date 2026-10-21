import asyncio
from playwright.async_api import async_playwright

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        page = await context.new_page()
        print("Navigating to floorworks.net...")
        try:
            await page.goto("http://floorworks.net", wait_until='domcontentloaded', timeout=15000)
            print("Loaded floorworks.net")
        except Exception as e:
            print("Error floorworks.net:", e)
        finally:
            await page.close()

        page2 = await context.new_page()
        print("Navigating to twpemay.com...")
        try:
            await page2.goto("http://twpemay.com", wait_until='domcontentloaded', timeout=15000)
            print("Loaded twpemay.com")
        except Exception as e:
            print("Error twpemay.com:", e)
        finally:
            await page2.close()

        page3 = await context.new_page()
        print("Navigating to ksnak.com...")
        try:
            await page3.goto("http://ksnak.com", wait_until='domcontentloaded', timeout=15000)
            print("Loaded ksnak.com")
        except Exception as e:
            print("Error ksnak.com:", e)
        finally:
            await page3.close()

        await browser.close()

asyncio.run(run())
