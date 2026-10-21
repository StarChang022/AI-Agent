import re

with open('/Users/starchang/Documents/CloudFolder/GitHub/AI-Agent/PlayPlus_Cold_Mail/⚙️參數設定/Python/crawler_104_3_email.py', 'r') as f:
    code = f.read()

# Add debug prints to scrape_emails_from_web
code = code.replace("page = await context.new_page()", "print(f'DEBUG: new_page {target_url} or {sub_url if \"sub_url\" in locals() else \"\"}'); page = await context.new_page()")
code = code.replace("await page.goto(target_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT)", "print(f'DEBUG: goto {target_url}'); await page.goto(target_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT); print(f'DEBUG: goto done {target_url}')")
code = code.replace("await page.goto(sub_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT)", "print(f'DEBUG: goto {sub_url}'); await page.goto(sub_url, wait_until='domcontentloaded', timeout=PAGE_TIMEOUT); print(f'DEBUG: goto done {sub_url}')")
code = code.replace("await page.close()", "print('DEBUG: closing page'); await page.close(); print('DEBUG: page closed')")

with open('debug_crawler.py', 'w') as f:
    f.write(code)
