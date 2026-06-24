import asyncio
from playwright.async_api import async_playwright
import time

PAGE_TIMEOUT = 15000
CONTACT_PATHS = ['', '/contact', '/contact-us', '/contactus', '/about', '/about-us', '/about/qa', '/service', '/agents', '/contactus/agents']
MAX_EXTRA_SUBPAGES = 10

async def scrape_emails_from_web(context, base_url):
    print(f"Starting {base_url}")
    visited = set()
    homepage_html = None
    all_emails = set()
    
    start_time = time.time()
    for path in CONTACT_PATHS:
        target_url = base_url + path
        if target_url in visited:
            continue
        visited.add(target_url)
        print(f"  -> {target_url}")
        page = await context.new_page()
        try:
            await page.goto(target_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT)
            if path == '':
                homepage_html = await page.content()
        except Exception as e:
            print(f"  Error on {target_url}: {type(e).__name__}")
        finally:
            await page.close()
    
    print(f"Finished paths in {time.time() - start_time:.1f}s")
    
    if homepage_html:
        # just fake subpage URLs
        subpage_urls = [f"{base_url}/fake{i}" for i in range(MAX_EXTRA_SUBPAGES)]
        extra_count = 0
        for sub_url in subpage_urls:
            if extra_count >= MAX_EXTRA_SUBPAGES: break
            if sub_url in visited: continue
            visited.add(sub_url)
            extra_count += 1
            print(f"  -> {sub_url}")
            page = await context.new_page()
            try:
                await page.goto(sub_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT)
            except Exception as e:
                print(f"  Error on {sub_url}: {type(e).__name__}")
            finally:
                await page.close()
                
    print(f"Total time for {base_url}: {time.time() - start_time:.1f}s")

async def run():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context()
        await scrape_emails_from_web(context, "http://twpemay.com")
        await scrape_emails_from_web(context, "http://ksnak.com")
        await browser.close()

asyncio.run(run())
