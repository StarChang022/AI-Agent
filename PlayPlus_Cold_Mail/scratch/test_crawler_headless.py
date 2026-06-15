import asyncio
from playwright.async_api import async_playwright

async def test_one(context, url):
    cust_no = url.rstrip('/').split('/')[-1]
    page = await context.new_page()
    try:
        await page.goto(url, wait_until='load', timeout=20000)
        await asyncio.sleep(1)
        api_url = f'https://www.104.com.tw/api/companies/{cust_no}/content'
        data = await page.evaluate("""
            async (args) => {
                const { apiUrl, refererUrl } = args;
                try {
                    const res = await fetch(apiUrl, {
                        headers: {
                            'Accept': 'application/json, text/plain, */*',
                            'Referer': refererUrl,
                            'Origin': 'https://www.104.com.tw'
                        },
                        credentials: 'include'
                    });
                    if (!res.ok) return { error: res.status };
                    return await res.json();
                } catch(e) {
                    return { error: e.toString() };
                }
            }
        """, {'apiUrl': api_url, 'refererUrl': url})
        
        if not data or 'error' in data:
            print(f"Failed for {cust_no}: {data}")
            return False
        else:
            d = data.get('data', {}) or {}
            print(f"Success for {cust_no}: {d.get('custLink')}")
            return True
    except Exception as e:
        print(f"Exception for {cust_no}: {e}")
        return False
    finally:
        await page.close()

async def main():
    urls = [
        'https://www.104.com.tw/company/cl5koqw',
        'https://www.104.com.tw/company/sg93e3c',
        'https://www.104.com.tw/company/ggev8dc'
    ]
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--no-sandbox',
                '--disable-dev-shm-usage'
            ]
        )
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            viewport={"width": 1280, "height": 800},
            locale="zh-TW",
            timezone_id="Asia/Taipei"
        )
        await context.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            });
        """)
        for url in urls:
            await test_one(context, url)
        await browser.close()

if __name__ == '__main__':
    asyncio.run(main())
